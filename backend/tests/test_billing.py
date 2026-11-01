from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, time, timedelta
from threading import Barrier
from uuid import uuid4

import pytest
from django.db import IntegrityError, connections, transaction
from django.utils import timezone
from rest_framework.test import APIClient

from hotel.models import (
    AuditLog,
    Booking,
    Customer,
    Invoice,
    InvoiceLine,
    Payment,
    Room,
    ServiceItem,
    ServiceUsage,
    Stay,
)

pytestmark = pytest.mark.django_db


@pytest.fixture
def stay(users, room):
    guest = Customer.objects.create(full_name="Khách quyết toán", phone="0912345678")
    day = timezone.localdate()
    booking = Booking.objects.create(room=room, customer=guest, start_date=day - timedelta(days=2), end_date=day,
        guests=1, nightly_rate=650000, status="checked_in", created_by=users["admin"], request_fingerprint="billing")
    return Stay.objects.create(booking=booking, checked_in_at=timezone.now() - timedelta(days=2), checked_in_by=users["admin"])


def usage(stay, actor, amount=15000, quantity=2):
    service, _ = ServiceItem.objects.get_or_create(name="Nước", defaults={"unit": "chai", "unit_price": 99999})
    return ServiceUsage.objects.create(stay=stay, service=service, name="Nước lúc dùng", unit="chai", unit_price=amount,
        quantity=quantity, created_by=actor, request_key=uuid4(), request_fingerprint="billing")


def body(client, stay, **changes):
    response = client.get(f"/api/v1/bookings/{stay.booking_id}/folio/")
    assert response.status_code == 200, response.data
    folio = response.data["folio"]
    return {"quote_token": folio["quote_token"], "expected_total": folio["total"], "method": "cash", "payment_received": True, **changes}


def pay(client, stay, data, key=None):
    return client.post(f"/api/v1/bookings/{stay.booking_id}/check-out/", data, format="json", HTTP_IDEMPOTENCY_KEY=str(key or uuid4()))


@pytest.mark.parametrize("method", ["cash", "bank_transfer"])
def test_folio_checkout_and_cleaning_complete_flow(client, users, stay, method):
    client.force_authenticate(users["receptionist"])
    usage(stay, users["receptionist"])
    cancelled = usage(stay, users["admin"], amount=50000)
    cancelled.status, cancelled.cancelled_at, cancelled.cancelled_by, cancelled.cancel_reason = "cancelled", timezone.now(), users["admin"], "Nhầm"
    cancelled.save()
    data = body(client, stay, method=method, reference="BANK-123" if method == "bank_transfer" else "")
    assert data["expected_total"] == "1330000"
    result = pay(client, stay, data)
    assert result.status_code == 201, result.data
    invoice, booking = result.data["invoice"], result.data["booking"]
    assert invoice["total"] == "1330000" and invoice["service_total"] == "30000"
    assert len(invoice["lines"]) == 2
    assert invoice["lines"][0]["quantity"] == 2 and invoice["lines"][0]["unit_price"] == "650000"
    assert invoice["payment"]["amount"] == invoice["total"] and invoice["payment"]["method"] == method
    assert booking["status"] == "checked_out" and booking["checked_out_at"]
    assert booking["room"]["display_status"] == "cleaning"
    stay.refresh_from_db()
    assert stay.checked_out_at and Invoice.objects.count() == Payment.objects.count() == 1
    closed = client.get(f"/api/v1/bookings/{stay.booking_id}/folio/").data
    assert closed["state"] == "closed" and closed["invoice"]["code"] == invoice["code"]
    room = client.get(f"/api/v1/rooms/{stay.booking.room_id}/").data
    timeline = client.get("/api/v1/rooms/timeline/").data
    row = next(item for item in timeline["rooms"] if item["id"] == room["id"])
    assert row["schedule"][0]["status"] == "cleaning"
    cleaned = client.post(f"/api/v1/rooms/{room['id']}/confirm-cleaned/", {"expected_updated_at": room["updated_at"]})
    assert cleaned.status_code == 200 and cleaned.data["display_status"] == "ready"
    assert client.post(f"/api/v1/rooms/{room['id']}/confirm-cleaned/", {"expected_updated_at": room["updated_at"]}).status_code == 200
    assert AuditLog.objects.filter(action="room_cleaned").count() == 1
    row = next(item for item in client.get("/api/v1/rooms/timeline/").data["rooms"] if item["id"] == room["id"])
    assert row["schedule"][0]["status"] == "ready"


def test_idempotent_checkout_does_not_recharge_or_reset_clean_room(client, users, stay):
    client.force_authenticate(users["admin"])
    key, data = uuid4(), body(client, stay)
    first = pay(client, stay, data, key)
    Room.objects.filter(pk=stay.booking.room_id).update(condition="ready")
    second = pay(client, stay, data, key)
    assert first.status_code == 201 and second.status_code == 200
    assert first.data["invoice"] == second.data["invoice"]
    assert Room.objects.get(pk=stay.booking.room_id).condition == "ready"
    assert Invoice.objects.count() == Payment.objects.count() == 1
    assert AuditLog.objects.filter(action="payment_receive").count() == 1
    assert pay(client, stay, {**data, "method": "bank_transfer"}, key).status_code == 409
    assert pay(client, stay, data).status_code == 409


def test_stale_quote_same_total_and_late_service_edits_are_blocked(client, users, stay):
    client.force_authenticate(users["admin"])
    item = usage(stay, users["admin"])
    data = body(client, stay)
    ServiceUsage.objects.filter(pk=item.pk).update(name="Nội dung đã thay đổi")
    assert pay(client, stay, data).status_code == 409
    assert Invoice.objects.count() == Payment.objects.count() == 0
    data = body(client, stay)
    assert pay(client, stay, {**data, "expected_total": "1"}).status_code == 409
    assert pay(client, stay, data).status_code == 201
    assert client.post(f"/api/v1/bookings/{stay.booking_id}/services/", {
        "service_id": item.service_id, "quantity": 1, "expected_unit_price": "99999",
    }, HTTP_IDEMPOTENCY_KEY=str(uuid4())).status_code == 409
    assert client.post(f"/api/v1/bookings/{stay.booking_id}/services/{item.pk}/cancel/", {"reason": "Nhầm"}).status_code == 409
    assert client.post(f"/api/v1/bookings/{stay.booking_id}/extend/", {"end_date": str(timezone.localdate() + timedelta(days=1))}).status_code == 409


def test_invoice_snapshots_history_and_recorded_collection_period(client, users, stay):
    client.force_authenticate(users["admin"])
    item = usage(stay, users["admin"])
    first = pay(client, stay, body(client, stay, method="bank_transfer"))
    assert first.status_code == 201, first.data
    frozen = first.data["invoice"]
    Customer.objects.filter(pk=stay.booking.customer_id).update(full_name="Tên mới")
    ServiceItem.objects.filter(pk=item.service_id).update(name="Tên giá mới", unit_price=999999)
    Room.objects.filter(pk=stay.booking.room_id).update(number="999")
    again = client.get(f"/api/v1/invoices/{frozen['id']}/")
    assert again.status_code == 200 and again.data == frozen
    assert client.patch(f"/api/v1/invoices/{frozen['id']}/", {"total": "1"}).status_code == 405
    assert client.delete(f"/api/v1/invoices/{frozen['id']}/").status_code == 405
    assert client.get("/api/v1/invoices/", {"search": frozen["code"], "method": "bank_transfer"}).data["count"] == 1
    today = timezone.localdate()
    Payment.objects.all().update(received_at=timezone.make_aware(datetime.combine(today, time(0, 30))))
    assert client.get("/api/v1/invoices/", {"start_date": str(today), "end_date": str(today + timedelta(days=1))}).data["count"] == 1
    assert client.get("/api/v1/invoices/", {"start_date": str(today - timedelta(days=1)), "end_date": str(today)}).data["count"] == 0
    report = client.get("/api/v1/reports/revenue-estimate/", {"start_date": str(today), "end_date": str(today + timedelta(days=1))}).data
    assert report["collected_total"] == frozen["total"] and report["bank_total"] == frozen["total"]
    assert report["cash_total"] == "0" and report["payment_count"] == 1
    previous = client.get("/api/v1/reports/revenue-estimate/", {"start_date": str(today - timedelta(days=1)), "end_date": str(today)}).data
    assert previous["collected_total"] == "0"


@pytest.mark.parametrize("scenario", ["manager", "not_received", "wrong_method", "missing_key", "closed", "overdue"])
def test_invalid_checkout_never_partially_writes(client, users, stay, scenario):
    client.force_authenticate(users["admin"])
    data = body(client, stay)
    if scenario == "manager":
        client.force_authenticate(users["manager"])
    if scenario == "not_received":
        data["payment_received"] = False
    if scenario == "wrong_method":
        data["method"] = "card"
    if scenario == "closed":
        Stay.objects.filter(pk=stay.pk).update(checked_out_at=timezone.now())
    if scenario == "overdue":
        Booking.objects.filter(pk=stay.booking_id).update(end_date=timezone.localdate() - timedelta(days=1))
    if scenario == "missing_key":
        response = client.post(f"/api/v1/bookings/{stay.booking_id}/check-out/", data)
    else:
        response = pay(client, stay, data)
    assert response.status_code in {400, 403, 409}, response.data
    assert Invoice.objects.count() == Payment.objects.count() == InvoiceLine.objects.count() == 0
    assert Room.objects.get(pk=stay.booking.room_id).condition == "ready"


def test_failure_rolls_back_invoice_payment_booking_and_room(client, users, stay, monkeypatch):
    from hotel import billing_services
    client.force_authenticate(users["admin"])
    data = body(client, stay)
    original = billing_services.record_audit

    def fail(actor, action, instance):
        if action == "booking_check_out":
            raise RuntimeError("Simulated persistence failure")
        return original(actor, action, instance)

    monkeypatch.setattr(billing_services, "record_audit", fail)
    with pytest.raises(RuntimeError):
        pay(client, stay, data)
    assert Invoice.objects.count() == InvoiceLine.objects.count() == Payment.objects.count() == 0
    stay.refresh_from_db()
    assert stay.checked_out_at is None and stay.booking.status == "checked_in"
    assert Room.objects.get(pk=stay.booking.room_id).condition == "ready"
    assert not AuditLog.objects.filter(action__in=["invoice_issue", "payment_receive"]).exists()


def test_cleaning_requires_current_version_and_blocks_occupied_maintenance(client, users, stay):
    client.force_authenticate(users["admin"])
    room = client.get(f"/api/v1/rooms/{stay.booking.room_id}/").data
    endpoint = f"/api/v1/rooms/{room['id']}/confirm-cleaned/"
    assert client.post(endpoint, {"expected_updated_at": room["updated_at"]}).status_code == 409
    Booking.objects.filter(pk=stay.booking_id).update(status="checked_out")
    Room.objects.filter(pk=room["id"]).update(condition="maintenance")
    assert client.post(endpoint, {"expected_updated_at": room["updated_at"]}).status_code == 409
    Room.objects.filter(pk=room["id"]).update(condition="cleaning", updated_at=timezone.now())
    assert client.post(endpoint, {"expected_updated_at": room["updated_at"]}).status_code == 409
    assert client.post(endpoint, {}).status_code == 400
    client.force_authenticate(users["manager"])
    assert client.post(endpoint, {"expected_updated_at": room["updated_at"]}).status_code == 403


@pytest.mark.django_db(transaction=True)
@pytest.mark.parametrize("same_key", [True, False])
def test_two_cashiers_cannot_collect_twice(client, users, stay, same_key):
    client.force_authenticate(users["admin"])
    data, key, barrier = body(client, stay), uuid4(), Barrier(2)

    def worker(index):
        try:
            api = APIClient()
            api.force_authenticate(users["admin"] if same_key else users[["admin", "receptionist"][index]])
            barrier.wait(timeout=5)
            return pay(api, stay, data, key if same_key else uuid4()).status_code
        finally:
            connections.close_all()

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = sorted(pool.map(worker, [0, 1]))
    assert results == ([200, 201] if same_key else [201, 409])
    assert Invoice.objects.count() == Payment.objects.count() == 1


def test_database_constraints_and_multiple_invoices(client, users, stay):
    client.force_authenticate(users["admin"])
    first = pay(client, stay, body(client, stay))
    assert first.status_code == 201
    day = timezone.localdate()
    booking = Booking.objects.create(room=stay.booking.room, customer=stay.booking.customer, start_date=day,
        end_date=day + timedelta(days=1), guests=1, nightly_rate=0, status="checked_in",
        created_by=users["admin"], request_fingerprint="second")
    other = Stay.objects.create(booking=booking, checked_in_at=timezone.now(), checked_in_by=users["admin"])
    second = pay(client, other, body(client, other))
    assert second.status_code == 201, second.data
    assert Invoice.objects.count() == Payment.objects.count() == 2
    with pytest.raises(IntegrityError), transaction.atomic():
        Invoice.objects.all().update(total=1)
    with pytest.raises(IntegrityError), transaction.atomic():
        Payment.objects.all().update(method="invalid")
