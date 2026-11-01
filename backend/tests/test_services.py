from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier
from uuid import uuid4

import pytest
from django.db import IntegrityError, connections, transaction
from django.utils import timezone
from rest_framework.test import APIClient

from hotel.models import AuditLog, Booking, Customer, ServiceItem, ServiceUsage, Stay

pytestmark = pytest.mark.django_db


def test_service_units_are_named_choices_and_require_login(client, users):
    assert client.get("/api/v1/service-units/").status_code == 401
    client.force_authenticate(users["receptionist"])
    units = client.get("/api/v1/service-units/").data["units"]
    assert {unit["value"] for unit in units} == set(ServiceItem.Unit.values)
    assert next(unit for unit in units if unit["value"] == "kg")["example"] == "Giặt ủi theo cân"
    assert all(unit["label"] and unit["example"] for unit in units)


@pytest.mark.parametrize("unit", ["20.000", "random", ""])
def test_random_unit_cannot_be_created_or_written(client, users, service, unit):
    client.force_authenticate(users["admin"])
    result = client.post(
        "/api/v1/services/", {"name": "Mục mới", "unit": unit, "unit_price": "20000"}
    )
    assert result.status_code == 400 and "unit" in result.data["error"]["fields"]
    result = client.patch(f"/api/v1/services/{service.pk}/", {"unit": unit})
    assert result.status_code == 400 and "unit" in result.data["error"]["fields"]
    service.refresh_from_db()
    assert service.unit == "kg"


def test_legacy_unit_is_flagged_and_cannot_create_new_usage(client, users, stay, service):
    client.force_authenticate(users["admin"])
    previous = add(client, stay, service).data
    ServiceUsage.objects.filter(pk=previous["id"]).update(unit="20.000")
    ServiceItem.objects.filter(pk=service.pk).update(unit="20.000")
    assert client.get(f"/api/v1/services/{service.pk}/").data["unit_valid"] is False
    assert add(client, stay, service).status_code == 409
    assert client.patch(f"/api/v1/services/{service.pk}/", {"unit": "chai"}).status_code == 200
    assert add(client, stay, service).status_code == 201
    assert ServiceUsage.objects.get(pk=previous["id"]).unit == "20.000"


@pytest.fixture
def service():
    return ServiceItem.objects.create(name="Giặt ủi", unit="kg", unit_price=30000)


@pytest.fixture
def stay(room, users):
    guest = Customer.objects.create(full_name="Khách dịch vụ", phone="0901234567")
    booking = Booking.objects.create(
        room=room,
        customer=guest,
        start_date=timezone.localdate(),
        end_date=timezone.localdate() + timedelta(days=2),
        guests=1,
        nightly_rate=950000,
        status="checked_in",
        created_by=users["receptionist"],
        request_fingerprint="test",
    )
    return Stay.objects.create(
        booking=booking, checked_in_by=users["receptionist"], checked_in_at=timezone.now()
    )


def add(client, stay, service, key=None, **extra):
    return client.post(
        f"/api/v1/bookings/{stay.booking_id}/services/",
        {
            "service_id": service.pk,
            "quantity": 2,
            "expected_unit_price": str(service.unit_price),
            **extra,
        },
        format="json",
        HTTP_IDEMPOTENCY_KEY=str(key or uuid4()),
    )


def test_usage_snapshot_replay_and_summary(client, users, stay, service):
    client.force_authenticate(users["receptionist"])
    key = uuid4()
    first = add(client, stay, service, key, unit_price="1", status="cancelled")
    assert first.status_code == 201
    assert first.data["total"] == "60000"
    assert first.data["unit_price"] == "30000"
    assert first.data["status"] == "active"
    service.name, service.unit, service.unit_price, service.is_active = (
        "Đã đổi",
        "lượt",
        99999,
        False,
    )
    service.save()
    replay = add(client, stay, service, key, expected_unit_price="30000")
    assert replay.status_code == 200 and replay.data["id"] == first.data["id"]
    assert replay.data["name"] == "Giặt ủi" and replay.data["unit"] == "kg"
    assert (
        add(client, stay, service, key, quantity=3, expected_unit_price="30000").status_code == 409
    )
    summary = client.get(f"/api/v1/bookings/{stay.booking_id}/services/")
    assert summary.status_code == 200
    assert summary.data["room_total"] == "1900000"
    assert summary.data["service_total"] == "60000"
    assert summary.data["estimated_total"] == "1960000"
    assert summary.data["can_edit"]
    assert ServiceUsage.objects.count() == 1
    assert AuditLog.objects.filter(action="service_add").count() == 1


def test_cancel_retains_history_and_excludes_amount(client, users, stay, service):
    client.force_authenticate(users["receptionist"])
    usage = add(client, stay, service).data
    endpoint = f"/api/v1/bookings/{stay.booking_id}/services/{usage['id']}/cancel/"
    cancelled = client.post(endpoint, {"reason": "Nhập nhầm số lượng"})
    assert cancelled.status_code == 200
    assert cancelled.data["cancelled_by"] == users["receptionist"].display_name
    assert cancelled.data["cancelled_at"] is not None
    assert client.post(endpoint, {"reason": "Nhập nhầm số lượng"}).status_code == 200
    assert client.post(endpoint, {"reason": "Lý do khác"}).status_code == 409
    summary = client.get(f"/api/v1/bookings/{stay.booking_id}/services/").data
    assert summary["service_total"] == "0" and summary["count"] == 1
    assert summary["results"][0]["status"] == "cancelled"
    assert AuditLog.objects.filter(action="service_cancel").count() == 1


@pytest.mark.parametrize(
    "change",
    ["inactive", "quote", "quantity_zero", "quantity_large", "missing_key", "missing_quote"],
)
def test_invalid_service_request_does_not_write(client, users, stay, service, change):
    client.force_authenticate(users["admin"])
    data = {"service_id": service.pk, "quantity": 1, "expected_unit_price": "30000"}
    if change == "inactive":
        service.is_active = False
        service.save()
    elif change == "quote":
        data["expected_unit_price"] = "1"
    elif change == "quantity_zero":
        data["quantity"] = 0
    elif change == "quantity_large":
        data["quantity"] = 1000
    elif change == "missing_quote":
        del data["expected_unit_price"]
    response = client.post(
        f"/api/v1/bookings/{stay.booking_id}/services/",
        data,
        format="json",
        **({} if change == "missing_key" else {"HTTP_IDEMPOTENCY_KEY": str(uuid4())}),
    )
    assert response.status_code == (409 if change in {"inactive", "quote"} else 400)
    assert ServiceUsage.objects.count() == 0


@pytest.mark.parametrize("booking_status", ["confirmed", "cancelled", "checked_out"])
def test_non_open_booking_cannot_add_or_cancel(client, users, stay, service, booking_status):
    client.force_authenticate(users["receptionist"])
    usage = add(client, stay, service).data
    Booking.objects.filter(pk=stay.booking_id).update(status=booking_status)
    assert add(client, stay, service).status_code == 409
    assert (
        client.post(
            f"/api/v1/bookings/{stay.booking_id}/services/{usage['id']}/cancel/", {"reason": "Nhầm"}
        ).status_code
        == 409
    )
    summary = client.get(f"/api/v1/bookings/{stay.booking_id}/services/").data
    assert not summary["can_edit"] and summary["service_total"] == "60000"


def test_catalog_permissions_and_manager_read_only(client, users, stay, service):
    for role in ["receptionist", "manager"]:
        client.force_authenticate(users[role])
        assert client.get("/api/v1/services/").status_code == 200
        assert (
            client.post(
                "/api/v1/services/", {"name": "Khác", "unit": "lượt", "unit_price": "100"}
            ).status_code
            == 403
        )
        assert (
            client.patch(f"/api/v1/services/{service.pk}/", {"unit_price": "1"}).status_code == 403
        )
    client.force_authenticate(users["receptionist"])
    usage = add(client, stay, service).data
    client.force_authenticate(users["manager"])
    data = client.get(f"/api/v1/bookings/{stay.booking_id}/services/").data
    assert data["count"] == 1 and not data["can_edit"]
    assert add(client, stay, service).status_code == 403
    assert (
        client.post(
            f"/api/v1/bookings/{stay.booking_id}/services/{usage['id']}/cancel/", {"reason": "Nhầm"}
        ).status_code
        == 403
    )
    client.force_authenticate(users["admin"])
    assert client.patch(f"/api/v1/services/{service.pk}/", {"is_active": False}).status_code == 200
    assert client.get("/api/v1/services/?active=true").data["count"] == 0
    assert client.get("/api/v1/services/?active=false").data["count"] == 1
    assert client.delete(f"/api/v1/services/{service.pk}/").status_code == 409


def test_scoping_reason_validation_and_closed_stay(client, users, stay, service):
    client.force_authenticate(users["admin"])
    usage = add(client, stay, service).data
    assert (
        client.post(
            f"/api/v1/bookings/{stay.booking_id}/services/{usage['id']}/cancel/", {"reason": "  "}
        ).status_code
        == 400
    )
    assert (
        client.post(
            f"/api/v1/bookings/999999/services/{usage['id']}/cancel/", {"reason": "Nhầm"}
        ).status_code
        == 404
    )
    stay.checked_out_at = timezone.now()
    stay.save()
    assert add(client, stay, service).status_code == 409
    assert not client.get(f"/api/v1/bookings/{stay.booking_id}/services/").data["can_edit"]


def test_admin_catalog_lifecycle_preserves_usage_and_other_stay_cannot_cancel(client, users, stay):
    client.force_authenticate(users["admin"])
    created = client.post(
        "/api/v1/services/",
        {"name": "Nước suối", "unit": "chai", "unit_price": "15000"},
        format="json",
    )
    assert created.status_code == 201
    service = ServiceItem.objects.get(pk=created.data["id"])
    key = uuid4()
    usage = add(client, stay, service, key).data
    assert (
        client.patch(
            f"/api/v1/services/{service.pk}/",
            {"name": "Nước", "unit": "bình", "unit_price": "20000", "is_active": False},
        ).status_code
        == 200
    )
    replay = add(client, stay, service, key)
    assert (
        replay.status_code == 200
        and replay.data["name"] == "Nước suối"
        and replay.data["unit_price"] == "15000"
    )
    assert add(client, stay, service).status_code == 409
    other = Booking.objects.create(
        room=stay.booking.room,
        customer=stay.booking.customer,
        start_date=timezone.localdate() + timedelta(days=2),
        end_date=timezone.localdate() + timedelta(days=3),
        guests=1,
        nightly_rate=950000,
        created_by=users["admin"],
        request_fingerprint="other",
    )
    assert (
        client.post(
            f"/api/v1/bookings/{other.pk}/services/{usage['id']}/cancel/", {"reason": "Nhầm"}
        ).status_code
        == 404
    )
    assert (
        client.post(
            "/api/v1/services/", {"name": "Nước", "unit": "chai", "unit_price": "1"}
        ).status_code
        == 400
    )
    assert client.patch(f"/api/v1/services/{service.pk}/", {"unit_price": "-1"}).status_code == 400
    assert client.get("/api/v1/services/?active=wrong").status_code == 400
    assert (
        client.post(
            f"/api/v1/bookings/{stay.booking_id}/services/",
            {"service_id": service.pk, "quantity": 1, "expected_unit_price": "15000"},
            format="json",
            HTTP_IDEMPOTENCY_KEY="bad",
        ).status_code
        == 400
    )
    client.force_authenticate(user=None)
    assert client.get("/api/v1/services/").status_code == 401
    assert client.get(f"/api/v1/bookings/{stay.booking_id}/services/").status_code == 401


def test_database_constraints_and_pagination_totals(client, users, stay, service):
    client.force_authenticate(users["admin"])
    for _ in range(31):
        assert add(client, stay, service).status_code == 201
    data = client.get(f"/api/v1/bookings/{stay.booking_id}/services/").data
    assert data["count"] == 31 and data["next"]
    assert data["service_total"] == "1860000"
    second = client.get(f"/api/v1/bookings/{stay.booking_id}/services/?page=2").data
    assert second["service_total"] == data["service_total"]
    with pytest.raises(IntegrityError), transaction.atomic():
        ServiceUsage.objects.all().update(quantity=0)
    with pytest.raises(IntegrityError), transaction.atomic():
        ServiceUsage.objects.all().update(status="cancelled")


@pytest.mark.django_db(transaction=True)
def test_two_connections_with_same_service_key_write_once(users, stay, service):
    barrier, key = Barrier(2), uuid4()

    def worker(_):
        try:
            api = APIClient()
            api.force_authenticate(users["receptionist"])
            barrier.wait(timeout=5)
            return add(api, stay, service, key).status_code
        finally:
            connections.close_all()

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(worker, [0, 1]))
    assert sorted(results) == [200, 201]
    assert ServiceUsage.objects.count() == 1


@pytest.mark.django_db(transaction=True)
@pytest.mark.parametrize("scenario", ["partial_update", "same_name"])
def test_two_catalog_writers_keep_partial_changes_and_report_duplicate_name(
    users, service, monkeypatch, scenario
):
    from hotel.service_views import ServiceItemViewSet

    barrier = Barrier(2)
    if scenario == "partial_update":
        original = ServiceItemViewSet.get_object

        def load(self):
            instance = original(self)
            barrier.wait(timeout=5)
            return instance

        monkeypatch.setattr(ServiceItemViewSet, "get_object", load)
    else:
        original = ServiceItemViewSet.perform_create

        def create(self, serializer):
            barrier.wait(timeout=5)
            return original(self, serializer)

        monkeypatch.setattr(ServiceItemViewSet, "perform_create", create)

    def worker(index):
        try:
            api = APIClient()
            api.force_authenticate(users["admin"])
            if scenario == "partial_update":
                return api.patch(
                    f"/api/v1/services/{service.pk}/",
                    {"unit_price": "45000"} if index == 0 else {"unit": "lượt"},
                ).status_code
            return api.post(
                "/api/v1/services/", {"name": "Đưa đón", "unit": "lượt", "unit_price": "200000"}
            ).status_code
        finally:
            connections.close_all()

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(worker, [0, 1]))
    if scenario == "partial_update":
        assert results == [200, 200]
        service.refresh_from_db()
        assert service.unit_price == 45000 and service.unit == "lượt"
    else:
        assert sorted(results) == [201, 400]
        assert ServiceItem.objects.filter(name="Đưa đón").count() == 1
