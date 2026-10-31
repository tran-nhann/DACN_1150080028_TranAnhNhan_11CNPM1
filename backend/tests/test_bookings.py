from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier
from uuid import uuid4

import pytest
from django.db import IntegrityError, connections, transaction
from django.utils import timezone
from rest_framework.test import APIClient

from hotel.models import Booking, Customer, Room, Stay

pytestmark = pytest.mark.django_db


@pytest.fixture
def customer(db):
    return Customer.objects.create(full_name="Khách kiểm thử", phone="0901234567")


@pytest.fixture
def operator(client, users):
    client.force_authenticate(users["receptionist"])
    return client


def body(room, customer, start=None, end=None, **extra):
    start = start or timezone.localdate()
    end = end or start + timedelta(days=2)
    return {
        "room_id": room.pk,
        "customer_id": customer.pk,
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "guests": 2,
        **extra,
    }


def book(client, data, key=None):
    return client.post(
        "/api/v1/bookings/", data, format="json", HTTP_IDEMPOTENCY_KEY=str(key or uuid4())
    )


def test_booking_price_is_server_snapshot_and_requests_are_idempotent(operator, room, customer):
    key = uuid4()
    payload = body(room, customer, nightly_rate="1", status="checked_in")
    first = book(operator, payload, key)
    assert first.status_code == 201
    assert first.data["nightly_rate"] == "950000"
    assert first.data["room_total"] == "1900000"
    assert first.data["status"] == "confirmed"
    replay = book(operator, payload, key)
    assert replay.status_code == 200
    assert replay.data["id"] == first.data["id"]
    assert Booking.objects.count() == 1
    conflict = book(operator, {**payload, "guests": 1}, key)
    assert conflict.status_code == 409


def test_booking_history_and_daily_filters_are_exact(operator, room, customer, users):
    today = timezone.localdate()
    other_room = Room.objects.create(number="102", floor=1, room_type=room.room_type)
    other_guest = Customer.objects.create(full_name="Khách khác", phone="0901234568")
    first = book(operator, body(room, customer))
    second = book(operator, body(other_room, other_guest, start=today + timedelta(days=1)))
    assert first.status_code == second.status_code == 201
    endpoint = "/api/v1/bookings/"
    def ids(**query):
        response = operator.get(endpoint, query)
        assert response.status_code == 200
        return [item["id"] for item in response.data["results"]]
    assert ids(room=room.pk) == [first.data["id"]]
    assert ids(customer=other_guest.pk) == [second.data["id"]]
    assert ids(room=room.pk, customer=other_guest.pk) == []
    assert ids(arrival_on=today.isoformat(), status="confirmed") == [first.data["id"]]
    assert ids(departure_on=(today + timedelta(days=2)).isoformat()) == [first.data["id"]]
    assert ids(departure_on=today.isoformat()) == []
    operator.force_authenticate(users["manager"])
    assert ids(room=room.pk) == [first.data["id"]]
    assert operator.get(f"/api/v1/customers/{customer.pk}/").status_code == 403
    payload = operator.get(endpoint, {"customer": customer.pk}).data["results"][0]
    assert "phone" not in payload["customer"]


@pytest.mark.parametrize("parameter,value", [
    ("room", "abc"), ("room", "0"), ("customer", "-1"), ("customer", ""),
    ("arrival_on", "2026-02-30"), ("arrival_on", "yesterday"),
    ("departure_on", "2026-13-01"), ("departure_on", ""),
])
def test_booking_lookup_rejects_invalid_filters(operator, parameter, value):
    response = operator.get("/api/v1/bookings/", {parameter: value})
    assert response.status_code == 400
    assert parameter in response.data["error"]["fields"]


def test_overlap_is_rejected_but_adjacent_nights_are_valid(operator, room, customer):
    first = book(operator, body(room, customer))
    assert first.status_code == 201
    assert book(operator, body(room, customer)).status_code == 409
    next_start = timezone.localdate() + timedelta(days=2)
    assert book(operator, body(room, customer, start=next_start)).status_code == 201
    assert Booking.objects.count() == 2


@pytest.mark.parametrize("change", ["past", "reverse", "long", "capacity", "missing_key"])
def test_invalid_booking_inputs(operator, room, customer, change):
    payload = body(room, customer)
    if change == "past":
        payload["start_date"] = (timezone.localdate() - timedelta(days=1)).isoformat()
    elif change == "reverse":
        payload["end_date"] = payload["start_date"]
    elif change == "long":
        payload["end_date"] = (timezone.localdate() + timedelta(days=91)).isoformat()
    elif change == "capacity":
        payload["guests"] = 3
    if change == "missing_key":
        response = operator.post("/api/v1/bookings/", payload)
    else:
        response = book(operator, payload)
    assert response.status_code == 400
    assert Booking.objects.count() == 0


def test_maintenance_unavailable_and_dirty_room_cannot_check_in(operator, room, customer):
    room.condition = "maintenance"
    room.save()
    assert book(operator, body(room, customer)).status_code == 409
    room.condition = "cleaning"
    room.save()
    created = book(operator, body(room, customer))
    assert created.status_code == 201
    assert operator.post(f"/api/v1/bookings/{created.data['id']}/check-in/").status_code == 409
    assert Stay.objects.count() == 0


def test_cancel_releases_dates_and_cannot_be_patched_around(operator, room, customer):
    created = book(operator, body(room, customer))
    endpoint = f"/api/v1/bookings/{created.data['id']}/"
    assert operator.patch(endpoint, {"status": "cancelled"}).status_code == 405
    assert operator.post(endpoint + "cancel/").status_code == 200
    assert operator.post(endpoint + "cancel/").status_code == 200
    assert book(operator, body(room, customer)).status_code == 201


def test_check_in_is_idempotent_and_updates_actual_room_status(operator, room, customer):
    created = book(operator, body(room, customer))
    endpoint = f"/api/v1/bookings/{created.data['id']}/check-in/"
    first = operator.post(endpoint)
    assert first.status_code == 200
    assert first.data["status"] == "checked_in"
    assert first.data["checked_in_at"] is not None
    assert operator.post(endpoint).status_code == 200
    assert Stay.objects.count() == 1
    assert operator.get(f"/api/v1/rooms/{room.pk}/").data["display_status"] == "occupied"
    assert (
        operator.post(f"/api/v1/rooms/{room.pk}/condition/", {"condition": "cleaning"}).status_code
        == 409
    )
    dashboard = operator.get("/api/v1/dashboard/").data
    assert dashboard["rooms"]["occupied"] == 1
    assert dashboard["rooms"]["ready"] == 0
    assert dashboard["guests"] == 2
    assert operator.post(f"/api/v1/bookings/{created.data['id']}/cancel/").status_code == 409


def test_future_check_in_rejected_and_reserved_today_is_distinct(operator, room, customer):
    future = book(operator, body(room, customer, start=timezone.localdate() + timedelta(days=3)))
    assert operator.post(f"/api/v1/bookings/{future.data['id']}/check-in/").status_code == 400
    assert operator.get(f"/api/v1/rooms/{room.pk}/").data["display_status"] == "ready"
    today = book(operator, body(room, customer))
    assert today.status_code == 201
    assert operator.get(f"/api/v1/rooms/{room.pk}/").data["display_status"] == "reserved"
    assert operator.get("/api/v1/rooms/?status=ready").data["count"] == 0


def test_availability_filter_and_cancellation(operator, room, customer):
    created = book(operator, body(room, customer))
    query = {
        "start_date": timezone.localdate().isoformat(),
        "end_date": (timezone.localdate() + timedelta(days=2)).isoformat(),
        "guests": 2,
    }
    assert operator.get("/api/v1/rooms/availability/", query).data["count"] == 0
    assert (
        operator.get(
            "/api/v1/rooms/availability/", {**query, "exclude_booking": created.data["id"]}
        ).data["count"]
        == 1
    )
    operator.post(f"/api/v1/bookings/{created.data['id']}/cancel/")
    assert operator.get("/api/v1/rooms/availability/", query).data["count"] == 1
    assert operator.get("/api/v1/rooms/availability/", {**query, "guests": 3}).data["count"] == 0


def test_extend_and_reschedule_validate_conflicts_without_partial_updates(operator, room, customer):
    first = book(operator, body(room, customer))
    second_start = timezone.localdate() + timedelta(days=2)
    second = book(operator, body(room, customer, start=second_start))
    first_id = first.data["id"]
    assert (
        operator.post(
            f"/api/v1/bookings/{first_id}/extend/",
            {"end_date": (second_start + timedelta(days=1)).isoformat()},
        ).status_code
        == 409
    )
    existing = Booking.objects.get(pk=first_id)
    assert existing.end_date == second_start
    assert (
        operator.post(
            f"/api/v1/bookings/{first_id}/reschedule/",
            {
                "start_date": second_start.isoformat(),
                "end_date": (second_start + timedelta(days=1)).isoformat(),
            },
        ).status_code
        == 409
    )
    operator.post(f"/api/v1/bookings/{second.data['id']}/cancel/")
    assert (
        operator.post(
            f"/api/v1/bookings/{first_id}/extend/",
            {"end_date": (second_start + timedelta(days=1)).isoformat()},
        ).status_code
        == 200
    )
    assert (
        operator.post(
            f"/api/v1/bookings/{first_id}/extend/",
            {"end_date": (second_start + timedelta(days=1)).isoformat()},
        ).status_code
        == 200
    )


def test_room_switch_reprices_but_catalog_change_does_not_change_old_booking(
    operator, client, users, room, customer
):
    created = book(operator, body(room, customer))
    room.room_type.base_rate = 1100000
    room.room_type.save()
    assert Booking.objects.get(pk=created.data["id"]).nightly_rate == 950000
    second_room = Room.objects.create(number="102", floor=1, room_type=room.room_type)
    response = operator.post(
        f"/api/v1/bookings/{created.data['id']}/reschedule/",
        {
            "room_id": second_room.pk,
            "start_date": timezone.localdate().isoformat(),
            "end_date": (timezone.localdate() + timedelta(days=2)).isoformat(),
        },
    )
    assert response.status_code == 200
    assert response.data["nightly_rate"] == "1100000"
    client.force_authenticate(users["admin"])
    assert (
        client.patch(f"/api/v1/room-types/{room.room_type_id}/", {"capacity": 1}).status_code == 400
    )


def test_stale_price_quote_rejected(operator, room, customer):
    response = book(operator, body(room, customer, expected_nightly_rate="900000"))
    assert response.status_code == 409
    assert Booking.objects.count() == 0


def test_room_cannot_be_disabled_or_maintained_with_active_bookings(
    operator, users, room, customer
):
    book(operator, body(room, customer))
    operator.force_authenticate(users["admin"])
    assert operator.patch(f"/api/v1/rooms/{room.pk}/", {"is_active": False}).status_code == 409
    assert (
        operator.post(
            f"/api/v1/rooms/{room.pk}/condition/", {"condition": "maintenance"}
        ).status_code
        == 409
    )
    room.refresh_from_db()
    assert room.is_active
    assert room.condition == "ready"


def test_manager_has_read_only_booking_access(operator, users, room, customer):
    created = book(operator, body(room, customer))
    operator.force_authenticate(users["manager"])
    assert operator.get("/api/v1/bookings/").status_code == 200
    assert book(operator, body(room, customer)).status_code == 403
    for action in ["check-in", "cancel", "extend", "reschedule"]:
        assert (
            operator.post(f"/api/v1/bookings/{created.data['id']}/{action}/", {}).status_code == 403
        )


def test_sql_constraints_reject_invalid_booking_dates(operator, room, customer):
    created = book(operator, body(room, customer))
    with pytest.raises(IntegrityError), transaction.atomic():
        Booking.objects.filter(pk=created.data["id"]).update(end_date=timezone.localdate())


def test_overdue_guest_blocks_today_and_next_check_in(operator, users, room, customer):
    next_booking = book(operator, body(room, customer))
    Booking.objects.create(
        room=room,
        customer=customer,
        start_date=timezone.localdate() - timedelta(days=1),
        end_date=timezone.localdate(),
        guests=1,
        nightly_rate=950000,
        status="checked_in",
        created_by=users["admin"],
        request_fingerprint="legacy",
    )
    assert operator.post(f"/api/v1/bookings/{next_booking.data['id']}/check-in/").status_code == 409
    assert book(operator, body(room, customer)).status_code == 409


@pytest.mark.django_db(transaction=True)
@pytest.mark.parametrize("scenario", ["same_room", "same_key", "key_different_rooms"])
def test_two_connections_cannot_double_book_or_duplicate_requests(users, room, customer, scenario):
    barrier = Barrier(2)
    second_room = Room.objects.create(number="102", floor=1, room_type=room.room_type)
    shared_key = uuid4()

    def worker(index):
        try:
            api = APIClient()
            api.force_authenticate(users["receptionist"])
            target = second_room if scenario == "key_different_rooms" and index == 1 else room
            key = shared_key if scenario != "same_room" else uuid4()
            barrier.wait(timeout=5)
            response = book(api, body(target, customer), key)
            return response.status_code
        finally:
            connections.close_all()

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(worker, [0, 1]))
    assert sorted(results) == ([200, 201] if scenario == "same_key" else [201, 409])
    assert Booking.objects.count() == 1
