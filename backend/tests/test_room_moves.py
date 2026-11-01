import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from pathlib import Path
from threading import Barrier
from uuid import uuid4

import pytest
from django.db import connections
from django.utils import timezone
from rest_framework.test import APIClient

from hotel.models import (
    AuditLog,
    Booking,
    Customer,
    Invoice,
    Payment,
    Room,
    RoomMove,
    RoomType,
    ServiceItem,
    ServiceUsage,
    Stay,
)

pytestmark = pytest.mark.django_db


@pytest.fixture
def occupied(users, room):
    day = timezone.localdate()
    booking = Booking.objects.create(room=room, customer=Customer.objects.create(full_name="Khách chuyển phòng", phone="0901234567"),
        start_date=day - timedelta(days=1), end_date=day + timedelta(days=2), guests=2,
        nightly_rate=650000, status="checked_in", created_by=users["admin"], request_fingerprint="move")
    Stay.objects.create(booking=booking, checked_in_at=timezone.now() - timedelta(days=1), checked_in_by=users["admin"])
    return booking


@pytest.fixture
def target():
    kind = RoomType.objects.create(name="Suite", capacity=4, base_rate=950000)
    return Room.objects.create(number="202", floor=2, room_type=kind)


def inputs(target, **changes):
    return {"room_id": target.pk, "price_mode": "target", "old_room_condition": "cleaning", "reason": "Khách nâng hạng", **changes}


def quote(client, booking, data):
    response = client.post(f"/api/v1/bookings/{booking.pk}/transfer-quote/", data, format="json")
    assert response.status_code == 200, response.data
    return {**data, "quote_token": response.data["quote_token"]}, response.data


def move(client, booking, data, key=None):
    return client.post(f"/api/v1/bookings/{booking.pk}/transfer/", data, format="json", HTTP_IDEMPOTENCY_KEY=str(key or uuid4()))


def water(booking, actor):
    item, _ = ServiceItem.objects.get_or_create(name="Nước", defaults={"unit": "chai", "unit_price": 15000})
    return ServiceUsage.objects.create(stay=booking.stay, service=item, name="Nước", unit="chai", unit_price=15000,
        quantity=2, created_by=actor, request_key=uuid4(), request_fingerprint="water")


def test_upgrade_preserves_stay_services_bills_segments_and_releases_room(client, users, occupied, target):
    client.force_authenticate(users["receptionist"])
    service = water(occupied, users["receptionist"])
    endpoint = f"/api/v1/bookings/{occupied.pk}/"
    options = client.get(endpoint + "transfer-options/")
    assert options.status_code == 200 and [row["id"] for row in options.data["rooms"]] == [target.pk]
    data, preview = quote(client, occupied, inputs(target))
    assert preview["current_room_total"] == "1950000" and preview["new_room_total"] == "2550000"
    assert preview["difference"] == "600000" and preview["total"] == "2580000"
    assert not RoomMove.objects.exists() and occupied.room_id != target.pk
    original_stay = occupied.stay.pk
    old_folio = client.get(endpoint + "folio/").data["folio"]
    key = uuid4()
    first = move(client, occupied, data, key)
    assert first.status_code == 201, first.data
    booking = first.data["booking"]
    assert booking["room"]["id"] == target.pk and booking["room"]["display_status"] == "occupied"
    assert booking["status"] == "checked_in" and booking["room_total"] == "2550000"
    assert [row["nights"] for row in booking["room_segments"]] == [1, 2]
    assert booking["room_moves"][0]["reason"] == "Khách nâng hạng"
    service.refresh_from_db()
    assert service.stay_id == original_stay and ServiceUsage.objects.count() == Stay.objects.count() == 1
    assert Room.objects.get(pk=occupied.room_id).condition == "cleaning"
    assert client.get(endpoint + "services/").data["service_total"] == "30000"
    assert client.get("/api/v1/bookings/", {"room": occupied.room_id}).data["count"] == 1
    today = timezone.localdate()
    rows = client.get("/api/v1/rooms/timeline/", {"start_date": today - timedelta(days=1), "days": 3}).data["rooms"]
    old = next(row for row in rows if row["id"] == occupied.room_id)["schedule"]
    new = next(row for row in rows if row["id"] == target.pk)["schedule"]
    assert old[0]["booking"]["id"] == occupied.pk and old[1]["status"] == "cleaning" and old[2]["booking"] is None
    assert new[0]["booking"] is None and new[1]["booking"]["id"] == occupied.pk
    again = move(client, occupied, data, key)
    assert again.status_code == 200 and again.data["move_id"] == first.data["move_id"]
    assert move(client, occupied, {**data, "reason": "Khác"}, key).status_code == 409
    assert RoomMove.objects.count() == 1 and AuditLog.objects.filter(action="room_move").count() == 1
    stale_checkout = client.post(endpoint + "check-out/", {"quote_token": old_folio["quote_token"], "expected_total": old_folio["total"],
        "method": "cash", "payment_received": True}, format="json", HTTP_IDEMPOTENCY_KEY=str(uuid4()))
    assert stale_checkout.status_code == 409 and not Invoice.objects.exists()
    folio = client.get(endpoint + "folio/").data["folio"]
    assert [line["total"] for line in folio["lines"]] == ["650000", "1900000", "30000"]
    receipt = client.post(endpoint + "check-out/", {"quote_token": folio["quote_token"], "expected_total": folio["total"],
        "method": "cash", "payment_received": True}, format="json", HTTP_IDEMPOTENCY_KEY=str(uuid4()))
    assert receipt.status_code == 201, receipt.data
    assert receipt.data["invoice"]["total"] == "2580000" and len(receipt.data["invoice"]["lines"]) == 3
    assert Invoice.objects.count() == Payment.objects.count() == 1
    assert Room.objects.get(pk=target.pk).condition == "cleaning"
    assert move(client, occupied, data, key).status_code == 200  # Retry cannot move the guest again after checkout.
    assert move(client, occupied, data).status_code == 409


@pytest.mark.parametrize("mode,rate,difference", [("keep", 650000, "0"), ("target", 400000, "-500000")])
def test_keep_price_and_downgrade_only_affect_remaining_nights(client, users, occupied, target, mode, rate, difference):
    client.force_authenticate(users["admin"])
    RoomType.objects.filter(pk=target.room_type_id).update(base_rate=rate)
    data, preview = quote(client, occupied, inputs(target, price_mode=mode, old_room_condition="maintenance", reason="Máy lạnh hỏng"))
    assert preview["new_rate"] == str(rate) and preview["difference"] == difference
    assert move(client, occupied, data).status_code == 201
    assert Room.objects.get(pk=occupied.room_id).condition == "maintenance"


@pytest.mark.parametrize("condition", ["cleaning", "maintenance", "inactive", "occupied", "reserved", "capacity", "same", "overdue", "no_stay", "cancelled"])
def test_invalid_target_or_stay_never_moves(client, users, occupied, target, condition):
    client.force_authenticate(users["admin"])
    if condition in {"cleaning", "maintenance"}:
        Room.objects.filter(pk=target.pk).update(condition=condition)
    elif condition == "inactive":
        Room.objects.filter(pk=target.pk).update(is_active=False)
    elif condition == "capacity":
        RoomType.objects.filter(pk=target.room_type_id).update(capacity=1)
    elif condition in {"occupied", "reserved"}:
        Booking.objects.create(room=target, customer=occupied.customer, start_date=occupied.start_date, end_date=occupied.end_date,
            guests=1, nightly_rate=1, status="checked_in" if condition == "occupied" else "confirmed", created_by=users["admin"], request_fingerprint="conflict")
    elif condition == "same":
        target = occupied.room
    elif condition == "overdue":
        Booking.objects.filter(pk=occupied.pk).update(end_date=timezone.localdate())
    elif condition == "no_stay":
        occupied.stay.delete()
    else:
        Booking.objects.filter(pk=occupied.pk).update(status="cancelled")
    response = client.post(f"/api/v1/bookings/{occupied.pk}/transfer-quote/", inputs(target), format="json")
    assert response.status_code in {400, 404, 409}, response.data
    assert not RoomMove.objects.exists() and Room.objects.get(pk=occupied.room_id).condition == "ready"


@pytest.mark.parametrize("change", ["price", "occupied", "service", "extension", "reason", "room_condition"])
def test_stale_quote_cannot_commit(client, users, occupied, target, change):
    client.force_authenticate(users["admin"])
    data, _ = quote(client, occupied, inputs(target))
    if change == "price":
        RoomType.objects.filter(pk=target.room_type_id).update(base_rate=1200000)
    elif change == "occupied":
        Booking.objects.create(room=target, customer=occupied.customer, start_date=occupied.start_date, end_date=occupied.end_date,
            guests=1, nightly_rate=1, created_by=users["admin"], request_fingerprint="reserved")
    elif change == "service":
        water(occupied, users["admin"])
    elif change == "extension":
        Booking.objects.filter(pk=occupied.pk).update(end_date=occupied.end_date + timedelta(days=1))
    elif change == "reason":
        data["reason"] = "Nội dung khác"
    else:
        Room.objects.filter(pk=target.pk).update(condition="cleaning")
    assert move(client, occupied, data).status_code == 409
    assert not RoomMove.objects.exists() and Room.objects.get(pk=occupied.room_id).condition == "ready"


def test_repeat_same_day_move_next_day_move_and_extension_keep_charges(client, users, occupied, target, monkeypatch):
    from hotel import room_moves
    client.force_authenticate(users["admin"])
    data, _ = quote(client, occupied, inputs(target))
    assert move(client, occupied, data).status_code == 201
    cheaper_type = RoomType.objects.create(name="Standard", base_rate=500000, capacity=2)
    other = Room.objects.create(number="303", floor=3, room_type=cheaper_type)
    data, _ = quote(client, occupied, inputs(other))
    same_day = move(client, occupied, data)
    assert same_day.status_code == 201 and same_day.data["booking"]["room_total"] == "1650000"
    assert [row["nights"] for row in same_day.data["booking"]["room_segments"]] == [1, 2]
    today = timezone.localdate()
    monkeypatch.setattr(room_moves.timezone, "localdate", lambda: today + timedelta(days=1))
    Room.objects.filter(pk=target.pk).update(condition="ready")
    data, _ = quote(client, occupied, inputs(target))
    next_day = move(client, occupied, data)
    assert next_day.status_code == 201 and next_day.data["booking"]["room_total"] == "2100000"
    assert [row["nights"] for row in next_day.data["booking"]["room_segments"]] == [1, 1, 1]
    extended = client.post(f"/api/v1/bookings/{occupied.pk}/extend/", {"end_date": occupied.end_date + timedelta(days=1)})
    assert extended.status_code == 200 and extended.data["room_total"] == "3050000"
    assert Stay.objects.count() == 1 and RoomMove.objects.count() == 3


def test_reports_keep_daily_type_allocation_and_services_at_original_type(client, users, occupied, target):
    client.force_authenticate(users["admin"])
    water(occupied, users["admin"])
    data, _ = quote(client, occupied, inputs(target))
    assert move(client, occupied, data).status_code == 201
    water(occupied, users["admin"])
    report = client.get("/api/v1/reports/revenue-estimate/", {"start_date": occupied.start_date, "end_date": occupied.end_date}).data
    assert report["room_total"] == "2550000" and report["service_total"] == "60000"
    assert [row["room_total"] for row in report["daily"]] == ["650000", "950000", "950000"]
    groups = {row["room_type_id"]: row for row in report["by_room_type"]}
    assert groups[occupied.room.room_type_id]["room_total"] == "650000"
    assert groups[target.room_type_id]["room_total"] == "1900000"
    assert groups[occupied.room.room_type_id]["service_total"] == groups[target.room_type_id]["service_total"] == "30000"
    assert report["booking_count"] == 1 and report["room_nights"] == 3 and report["collected_total"] == "0"


def test_roles_payload_and_protect_future_bookings_before_maintenance(client, users, occupied, target):
    endpoint = f"/api/v1/bookings/{occupied.pk}/"
    client.force_authenticate(users["manager"])
    assert client.get(endpoint + "transfer-options/").status_code == 403
    assert client.post(endpoint + "transfer-quote/", inputs(target)).status_code == 403
    assert client.post(endpoint + "transfer/", inputs(target)).status_code == 403
    client.force_authenticate(users["admin"])
    assert client.post(endpoint + "transfer-quote/", inputs(target, reason="   ")).status_code == 400
    data, _ = quote(client, occupied, inputs(target))
    assert client.post(endpoint + "transfer/", data, format="json").status_code == 400
    Booking.objects.create(room=occupied.room, customer=occupied.customer, start_date=occupied.end_date,
        end_date=occupied.end_date + timedelta(days=1), guests=1, nightly_rate=650000, created_by=users["admin"], request_fingerprint="later")
    assert client.post(endpoint + "transfer-quote/", inputs(target, old_room_condition="maintenance")).status_code == 409
    assert client.post(endpoint + "transfer-quote/", inputs(target)).status_code == 200


def test_persistence_failure_rolls_back_every_room_and_history(client, users, occupied, target, monkeypatch):
    from hotel import room_moves
    client.force_authenticate(users["admin"])
    data, _ = quote(client, occupied, inputs(target))
    def fail(*args):
        raise RuntimeError("Simulated history failure")
    monkeypatch.setattr(room_moves, "record_audit", fail)
    with pytest.raises(RuntimeError):
        move(client, occupied, data)
    occupied.refresh_from_db()
    assert occupied.room_id != target.pk and occupied.nightly_rate == 650000
    assert Room.objects.get(pk=occupied.room_id).condition == "ready"
    assert not RoomMove.objects.exists()


@pytest.mark.parametrize("broken", ["future_checkin", "duplicate_occupancy", "closed_stay", "future_move"])
def test_inconsistent_stay_is_blocked_before_transfer(client, users, occupied, target, broken):
    client.force_authenticate(users["admin"])
    if broken == "future_checkin":
        Stay.objects.filter(pk=occupied.stay.pk).update(checked_in_at=timezone.now() + timedelta(days=1))
    elif broken == "duplicate_occupancy":
        Booking.objects.create(room=occupied.room, customer=occupied.customer, start_date=occupied.start_date, end_date=occupied.end_date,
            guests=1, nightly_rate=1, status="checked_in", created_by=users["admin"], request_fingerprint="duplicate")
    elif broken == "closed_stay":
        Stay.objects.filter(pk=occupied.stay.pk).update(checked_out_at=timezone.now())
    else:
        data, _ = quote(client, occupied, inputs(target))
        assert move(client, occupied, data).status_code == 201
        RoomMove.objects.filter(booking=occupied).update(effective_date=timezone.localdate() + timedelta(days=1))
    count = RoomMove.objects.count()
    assert client.get(f"/api/v1/bookings/{occupied.pk}/transfer-options/").status_code == 409
    assert RoomMove.objects.count() == count


@pytest.mark.django_db(transaction=True)
def test_two_stays_cannot_move_into_the_same_room(client, users, occupied, target):
    client.force_authenticate(users["admin"])
    other_room = Room.objects.create(number="102", floor=1, room_type=occupied.room.room_type)
    other = Booking.objects.create(room=other_room, customer=occupied.customer, start_date=occupied.start_date, end_date=occupied.end_date,
        guests=1, nightly_rate=650000, status="checked_in", created_by=users["admin"], request_fingerprint="other")
    Stay.objects.create(booking=other, checked_in_at=timezone.now() - timedelta(days=1), checked_in_by=users["admin"])
    payloads = [quote(client, booking, inputs(target))[0] for booking in [occupied, other]]
    barrier = Barrier(2)
    def worker(index):
        try:
            api = APIClient()
            api.force_authenticate(users["admin"])
            barrier.wait(timeout=5)
            return move(api, [occupied, other][index], payloads[index]).status_code
        finally:
            connections.close_all()
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = sorted(pool.map(worker, [0, 1]))
    assert results == [201, 409]
    assert Booking.objects.filter(room=target, status="checked_in").count() == RoomMove.objects.count() == 1


@pytest.mark.skipif(os.getenv("RUN_BROWSER_E2E") != "1", reason="Opt-in Edge + local web build required")
@pytest.mark.django_db(transaction=True)
def test_edge_room_move_and_checkout_with_real_api_and_sql(live_server, users, occupied, target):
    from django.db import connection
    assert connection.settings_dict["NAME"] == "HotelManagementTest"
    recorded = water(occupied, users["admin"])
    root = Path(__file__).resolve().parents[2]
    result = subprocess.run(["node", str(root / "scripts/check-room-move-api-browser.cjs")], cwd=root,
        env={**os.environ, "ROOM_MOVE_API_URL": live_server.url + "/api/v1/", "ROOM_MOVE_BOOKING_ID": str(occupied.pk),
            "ROOM_MOVE_TARGET_ID": str(target.pk), "ROOM_MOVE_USAGE_ID": str(recorded.pk)},
        text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=180)
    assert result.returncode == 0, result.stdout + result.stderr
    occupied.refresh_from_db()
    assert occupied.room_id == target.pk and occupied.status == "checked_out"
    assert RoomMove.objects.count() == Stay.objects.count() == Invoice.objects.count() == Payment.objects.count() == 1
    assert recorded.stay_id == occupied.stay.pk and ServiceUsage.objects.count() == 1
    assert Invoice.objects.get(stay=occupied.stay).total == 2580000
    assert Room.objects.get(pk=target.pk).condition == Room.objects.get(pk=occupied.room_moves.first().from_room_id).condition == "cleaning"
