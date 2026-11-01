from datetime import date, datetime, time, timedelta
from io import BytesIO
from uuid import uuid4

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from PIL import Image

from hotel.models import (
    AuditLog,
    Booking,
    Customer,
    Room,
    RoomType,
    ServiceItem,
    ServiceUsage,
    Stay,
)

pytestmark = pytest.mark.django_db


def image():
    data = BytesIO()
    Image.new("RGB", (40, 30), "blue").save(data, format="PNG")
    return SimpleUploadedFile("service.png", data.getvalue(), content_type="image/png")


def test_room_filters_combine_type_floor_status_and_search(client, users, room):
    second_type = RoomType.objects.create(name="Suite", capacity=4, base_rate=1500000)
    Room.objects.create(number="201", floor=2, room_type=second_type, condition="maintenance")
    Room.objects.create(number="202", floor=2, room_type=second_type)
    client.force_authenticate(users["manager"])
    response = client.get(f"/api/v1/rooms/?room_type={second_type.pk}&floor=2&status=ready&search=202")
    assert response.status_code == 200
    assert [row["number"] for row in response.data["results"]] == ["202"]
    assert client.get(f"/api/v1/rooms/?room_type={room.room_type_id}&floor=2").data["count"] == 0


@pytest.mark.parametrize("value", ["abc", "0", "-1", "", "9223372036854775808"])
def test_invalid_room_type_filter_is_rejected(client, users, value):
    client.force_authenticate(users["admin"])
    assert client.get("/api/v1/rooms/", {"room_type": value}).status_code == 400


def test_service_details_photo_replace_remove_and_delete(client, users, settings, tmp_path, django_capture_on_commit_callbacks):
    settings.MEDIA_ROOT = tmp_path
    client.force_authenticate(users["admin"])
    result = client.post("/api/v1/services/", {
        "name": "Giặt áo", "unit": "cái", "unit_price": "45000", "category": "laundry",
        "description": "Giặt theo từng món", "notes": "Giao ca chiều", "image": image(),
    }, format="multipart")
    assert result.status_code == 201, result.data
    service = ServiceItem.objects.get(pk=result.data["id"])
    assert result.data["category_label"] == "Giặt ủi"
    assert result.data["description"] == "Giặt theo từng món"
    assert result.data["usage_count"] == 0 and result.data["can_delete"] is True
    old_name = service.image.name
    assert service.image.storage.exists(old_name)
    with django_capture_on_commit_callbacks(execute=True):
        replaced = client.patch(f"/api/v1/services/{service.pk}/", {"image": image()}, format="multipart")
    assert replaced.status_code == 200 and replaced.data["image_url"]
    assert not service.image.storage.exists(old_name)
    assert replaced.data["notes"] == "Giao ca chiều"
    with django_capture_on_commit_callbacks(execute=True):
        removed = client.patch(f"/api/v1/services/{service.pk}/", {"remove_image": True}, format="json")
    assert removed.status_code == 200 and removed.data["image_url"] is None
    assert not [p for p in tmp_path.rglob("*") if p.is_file()]
    assert client.delete(f"/api/v1/services/{service.pk}/").status_code == 204
    assert not ServiceItem.objects.filter(pk=service.pk).exists()
    assert AuditLog.objects.filter(entity="serviceitem", action="delete").exists()


@pytest.mark.parametrize("role", ["receptionist", "manager"])
def test_service_delete_is_admin_only(client, users, role):
    service = ServiceItem.objects.create(name="Dịch vụ mới", unit="gói", unit_price=1000)
    client.force_authenticate(users[role])
    assert client.get(f"/api/v1/services/{service.pk}/").status_code == 200
    assert client.delete(f"/api/v1/services/{service.pk}/").status_code == 403


def make_booking(room, user, start, end, status="checked_in", rate=400000):
    guest = Customer.objects.create(full_name="Khách báo cáo", phone="0901234567")
    return Booking.objects.create(room=room, customer=guest, created_by=user, start_date=start, end_date=end,
        status=status, nightly_rate=rate, guests=1, request_fingerprint="report-test")


def make_usage(stay, service, user, day, quantity=2):
    usage = ServiceUsage.objects.create(stay=stay, service=service, name=service.name, unit=service.unit,
        unit_price=15000, quantity=quantity, created_by=user, request_key=uuid4(), request_fingerprint="report-test")
    timestamp = timezone.make_aware(datetime.combine(day, time(0, 30)))
    ServiceUsage.objects.filter(pk=usage.pk).update(created_at=timestamp)
    return usage


def test_used_service_cannot_be_deleted_and_history_is_preserved(client, users, room):
    day = timezone.localdate()
    booking = make_booking(room, users["admin"], day, day + timedelta(days=1))
    stay = Stay.objects.create(booking=booking, checked_in_by=users["admin"], checked_in_at=timezone.now())
    service = ServiceItem.objects.create(name="Nước", unit="chai", unit_price=15000)
    usage = make_usage(stay, service, users["admin"], day)
    client.force_authenticate(users["admin"])
    details = client.get(f"/api/v1/services/{service.pk}/").data
    assert details["usage_count"] == 1 and details["can_delete"] is False
    assert client.delete(f"/api/v1/services/{service.pk}/").status_code == 409
    assert client.patch(f"/api/v1/services/{service.pk}/", {"is_active": False}, format="json").status_code == 200
    usage.refresh_from_db()
    assert usage.name == "Nước" and usage.unit_price == 15000


def test_revenue_uses_overlap_snapshot_prices_and_local_usage_day(client, users, room):
    start, end = date(2026, 10, 31), date(2026, 11, 2)
    booking = make_booking(room, users["admin"], start - timedelta(days=1), end + timedelta(days=1))
    make_booking(room, users["admin"], start, start + timedelta(days=1), status="confirmed", rate=300000)
    make_booking(room, users["admin"], start, end, status="cancelled", rate=999999)
    make_booking(room, users["admin"], end, end + timedelta(days=1), status="confirmed")
    stay = Stay.objects.create(booking=booking, checked_in_by=users["admin"], checked_in_at=timezone.now())
    service = ServiceItem.objects.create(name="Nước", unit="chai", unit_price=999999)
    make_usage(stay, service, users["admin"], start + timedelta(days=1))
    make_usage(stay, service, users["admin"], end)
    cancelled = make_usage(stay, service, users["admin"], start)
    ServiceUsage.objects.filter(pk=cancelled.pk).update(status="cancelled", cancelled_by=users["admin"],
        cancelled_at=timezone.make_aware(datetime.combine(start, time(1))), cancel_reason="Ghi nhầm")
    client.force_authenticate(users["manager"])
    response = client.get("/api/v1/reports/revenue-estimate/", {"start_date": str(start), "end_date": str(end)})
    assert response.status_code == 200, response.data
    result = response.data
    assert result["room_total"] == "1100000"
    assert result["service_total"] == "30000"
    assert result["estimated_total"] == "1130000"
    assert result["confirmed_room_total"] == "300000" and result["stay_room_total"] == "800000"
    assert result["booking_count"] == 2 and result["room_nights"] == 3 and result["service_count"] == 1
    assert [row["total"] for row in result["daily"]] == ["700000", "430000"]
    assert result["by_room_type"][0]["total"] == result["estimated_total"]
    assert result["collected_total"] == "0" and result["is_estimate"] is True


def test_revenue_empty_period_and_permissions(client, users):
    endpoint = "/api/v1/reports/revenue-estimate/"
    assert client.get(endpoint).status_code == 401
    client.force_authenticate(users["receptionist"])
    assert client.get(endpoint).status_code == 403
    client.force_authenticate(users["admin"])
    result = client.get(endpoint, {"start_date": "2026-10-01", "end_date": "2026-11-01"})
    assert result.status_code == 200 and result.data["estimated_total"] == "0"
    assert len(result.data["daily"]) == 31
    assert result.data["collected_total"] == "0"
    for start, end in [("bad", "2026-11-01"), ("2026-11-01", "2026-11-01"), ("2026-11-02", "2026-11-01"), ("2024-01-01", "2026-01-01")]:
        assert client.get(endpoint, {"start_date": start, "end_date": end}).status_code == 400
