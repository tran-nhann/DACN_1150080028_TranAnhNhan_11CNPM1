from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier
from uuid import uuid4

import pytest
from django.db import connections
from django.utils import timezone
from rest_framework.test import APIClient

from hotel.models import (
    Booking,
    BookingServicePlan,
    Customer,
    Invoice,
    ServiceItem,
    ServiceUsage,
    Stay,
)

pytestmark = pytest.mark.django_db


@pytest.fixture
def cart(client, users, room):
    client.force_authenticate(users["admin"])
    guest = Customer.objects.create(full_name="Khách đặt kèm", phone="0901234567")
    service = ServiceItem.objects.create(name="Ăn sáng", unit="suất", unit_price=60000)
    day = timezone.localdate()
    payload = {"room_id": room.pk, "customer_id": guest.pk, "start_date": str(day), "end_date": str(day + timedelta(days=1)),
        "guests": 1, "expected_nightly_rate": "950000", "services": [{"service_id": service.pk, "quantity": 2, "expected_unit_price": "60000"}]}
    return payload, service


def create(client, payload, key=None):
    return client.post("/api/v1/bookings/", payload, format="json", HTTP_IDEMPOTENCY_KEY=str(key or uuid4()))


def add_plan(client, booking_id, service, key=None, quantity=1):
    return client.post(f"/api/v1/bookings/{booking_id}/planned-services/", {"service_id": service.pk,
        "quantity": quantity, "expected_unit_price": str(service.unit_price)}, format="json", HTTP_IDEMPOTENCY_KEY=str(key or uuid4()))


def test_four_stages_keep_one_ledger_and_snapshot_prices(client, users, cart):
    payload, service = cart
    result = create(client, payload)
    assert result.status_code == 201, result.data
    pk = result.data["id"]
    assert result.data["planned_service_total"] == "120000" and result.data["estimated_total"] == "1070000"
    assert Stay.objects.count() == ServiceUsage.objects.count() == 0
    report = client.get("/api/v1/reports/revenue-estimate/", {"start_date": payload["start_date"], "end_date": payload["end_date"]}).data
    assert report["planned_service_total"] == "120000" and report["estimated_total"] == "1070000"
    assert report["collected_total"] == "0"
    summary = client.get(f"/api/v1/bookings/{pk}/services/").data
    assert summary["can_edit"] and summary["results"][0]["planned"] is True
    added = add_plan(client, pk, service)
    assert added.status_code == 201, added.data
    assert client.get(f"/api/v1/bookings/{pk}/services/").data["service_total"] == "180000"
    assert client.get(f"/api/v1/services/{service.pk}/").data["usage_count"] == 2
    ServiceItem.objects.filter(pk=service.pk).update(unit_price=99000, is_active=False)
    assert client.post(f"/api/v1/bookings/{pk}/check-in/").status_code == 200
    assert client.post(f"/api/v1/bookings/{pk}/check-in/").status_code == 200
    assert ServiceUsage.objects.count() == 2 and BookingServicePlan.objects.filter(status="posted").count() == 2
    assert all(row.unit_price == 60000 for row in ServiceUsage.objects.all())
    assert client.get(f"/api/v1/bookings/{pk}/services/").data["service_total"] == "180000"
    current = ServiceItem.objects.create(name="Nước", unit="chai", unit_price=15000)
    usage = client.post(f"/api/v1/bookings/{pk}/services/", {"service_id": current.pk, "quantity": 2,
        "expected_unit_price": "15000"}, HTTP_IDEMPOTENCY_KEY=str(uuid4()))
    assert usage.status_code == 201
    old_folio = client.get(f"/api/v1/bookings/{pk}/folio/").data["folio"]
    assert old_folio["total"] == "1160000"
    original = ServiceUsage.objects.filter(service=service).first()
    assert client.post(f"/api/v1/bookings/{pk}/services/{original.pk}/cancel/", {"reason": "Khách không dùng"}).status_code == 200
    stale = client.post(f"/api/v1/bookings/{pk}/check-out/", {"quote_token": old_folio["quote_token"],
        "expected_total": old_folio["total"], "method": "cash", "payment_received": True}, HTTP_IDEMPOTENCY_KEY=str(uuid4()))
    assert stale.status_code == 409 and Invoice.objects.count() == 0
    fresh = client.get(f"/api/v1/bookings/{pk}/folio/").data["folio"]
    paid = client.post(f"/api/v1/bookings/{pk}/check-out/", {"quote_token": fresh["quote_token"], "expected_total": fresh["total"],
        "method": "cash", "payment_received": True}, HTTP_IDEMPOTENCY_KEY=str(uuid4()))
    assert paid.status_code == 201, paid.data
    assert paid.data["invoice"]["service_total"] == fresh["service_total"]
    assert add_plan(client, pk, service).status_code == 409


def test_cart_replay_and_different_cart_same_key_conflict(client, cart):
    payload, service = cart
    key = uuid4()
    first = create(client, payload, key)
    assert first.status_code == 201
    assert create(client, payload, key).status_code == 200
    changed = {**payload, "services": [{"service_id": service.pk, "quantity": 3, "expected_unit_price": "60000"}]}
    assert create(client, changed, key).status_code == 409
    assert Booking.objects.count() == BookingServicePlan.objects.count() == 1


@pytest.mark.parametrize("scenario", ["price", "inactive", "unit", "duplicate", "quantity", "missing"])
def test_invalid_cart_rolls_back_booking_and_plans(client, cart, scenario):
    payload, service = cart
    if scenario == "price":
        payload["services"][0]["expected_unit_price"] = "1"
    if scenario == "inactive":
        ServiceItem.objects.filter(pk=service.pk).update(is_active=False)
    if scenario == "unit":
        ServiceItem.objects.filter(pk=service.pk).update(unit="invalid")
    if scenario == "duplicate":
        payload["services"] *= 2
    if scenario == "quantity":
        payload["services"][0]["quantity"] = 0
    if scenario == "missing":
        payload["services"][0]["service_id"] = 999999
    assert create(client, payload).status_code in {400, 404, 409}
    assert Booking.objects.count() == BookingServicePlan.objects.count() == 0


def test_cancel_plan_booking_and_catalog_history(client, users, cart):
    payload, service = cart
    pk = create(client, payload).data["id"]
    plan = BookingServicePlan.objects.get()
    assert client.delete(f"/api/v1/services/{service.pk}/").status_code == 409
    key = uuid4()
    created = add_plan(client, pk, service, key)
    assert created.status_code == 201 and add_plan(client, pk, service, key).status_code == 200
    client.force_authenticate(users["manager"])
    assert add_plan(client, pk, service).status_code == 403
    assert not client.get(f"/api/v1/bookings/{pk}/services/").data["can_edit"]
    client.force_authenticate(users["admin"])
    endpoint = f"/api/v1/bookings/{pk}/planned-services/{plan.pk}/cancel/"
    assert client.post(endpoint, {"reason": "Không dùng"}).status_code == 200
    assert client.post(endpoint, {"reason": "Không dùng"}).status_code == 200
    assert client.post(endpoint, {"reason": "Khác"}).status_code == 409
    assert client.post(f"/api/v1/bookings/{pk}/cancel/").status_code == 200
    assert not BookingServicePlan.objects.exclude(status="cancelled").exists()
    assert client.get(f"/api/v1/bookings/{pk}/services/").data["service_total"] == "0"
    assert ServiceUsage.objects.count() == Stay.objects.count() == 0


def test_checkin_failure_rolls_back_conversion(client, cart, monkeypatch):
    from hotel import planned_services
    payload, _ = cart
    pk = create(client, payload).data["id"]
    original = planned_services.record_audit
    def broken(actor, action, obj):
        if action == "service_plan_post":
            raise RuntimeError("Simulated conversion error")
        original(actor, action, obj)
    monkeypatch.setattr(planned_services, "record_audit", broken)
    with pytest.raises(RuntimeError):
        client.post(f"/api/v1/bookings/{pk}/check-in/")
    assert Stay.objects.count() == ServiceUsage.objects.count() == 0
    assert BookingServicePlan.objects.get().status == "reserved"
    assert Booking.objects.get().status == "confirmed"


@pytest.mark.django_db(transaction=True)
def test_two_checkins_convert_cart_once(client, users, cart):
    payload, _ = cart
    pk = create(client, payload).data["id"]
    barrier = Barrier(2)
    def worker(index):
        try:
            api = APIClient()
            api.force_authenticate(users["admin"])
            barrier.wait(timeout=5)
            return api.post(f"/api/v1/bookings/{pk}/check-in/").status_code
        finally:
            connections.close_all()
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert list(pool.map(worker, [0, 1])) == [200, 200]
    assert Stay.objects.count() == ServiceUsage.objects.count() == 1
