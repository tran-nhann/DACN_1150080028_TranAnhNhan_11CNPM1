from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal
from threading import Event

import pytest
from django.core.management import call_command
from django.db import IntegrityError, connections, transaction
from rest_framework_simplejwt.tokens import RefreshToken

from hotel.models import AuditLog, Customer, Room, RoomType, User
from hotel.services import room_transaction

from .conftest import TEST_PASSWORD

pytestmark = pytest.mark.django_db


def login(client, user):
    response = client.post(
        "/api/v1/auth/login/", {"username": user.username, "password": TEST_PASSWORD}
    )
    assert response.status_code == 200
    client.credentials(HTTP_AUTHORIZATION="Bearer " + response.data["access"])
    return response.data


def test_sql_server_is_the_actual_test_database():
    assert connections["default"].vendor == "microsoft"
    assert connections["default"].settings_dict["NAME"] == "HotelManagementTest"


def test_login_me_and_no_password_leak(client, users):
    data = login(client, users["receptionist"])
    assert data["user"]["role"] == "receptionist"
    assert "password" not in data["user"]
    response = client.get("/api/v1/me/")
    assert response.status_code == 200
    assert response.data["display_name"] == "Nhân viên receptionist"


def test_unauthenticated_access_is_rejected(client):
    response = client.get("/api/v1/rooms/")
    assert response.status_code == 401
    assert response.data["error"]["code"] == "unauthenticated"
    assert response["X-Request-ID"] == response.data["error"]["request_id"]


def test_wrong_password_and_inactive_user_cannot_login(client, users):
    assert (
        client.post("/api/v1/auth/login/", {"username": "admin", "password": "wrong"}).status_code
        == 401
    )
    users["admin"].is_active = False
    users["admin"].save()
    assert (
        client.post(
            "/api/v1/auth/login/", {"username": "admin", "password": TEST_PASSWORD}
        ).status_code
        == 401
    )


def test_refresh_rotation_and_logout(client, users):
    tokens = login(client, users["admin"])
    refreshed = client.post("/api/v1/auth/refresh/", {"refresh": tokens["refresh"]})
    assert refreshed.status_code == 200
    assert client.post("/api/v1/auth/refresh/", {"refresh": tokens["refresh"]}).status_code == 401
    assert (
        client.post("/api/v1/auth/logout/", {"refresh": refreshed.data["refresh"]}).status_code
        == 204
    )
    assert (
        client.post("/api/v1/auth/refresh/", {"refresh": refreshed.data["refresh"]}).status_code
        == 401
    )


def test_logout_cannot_revoke_someone_elses_refresh(client, users):
    login(client, users["admin"])
    other_refresh = str(RefreshToken.for_user(users["manager"]))
    assert client.post("/api/v1/auth/logout/", {"refresh": other_refresh}).status_code == 400
    assert client.post("/api/v1/auth/refresh/", {"refresh": other_refresh}).status_code == 200


def test_disabled_account_cannot_refresh_or_use_existing_access(client, users):
    tokens = login(client, users["admin"])
    users["admin"].is_active = False
    users["admin"].save()
    assert client.get("/api/v1/me/").status_code == 401
    assert client.post("/api/v1/auth/refresh/", {"refresh": tokens["refresh"]}).status_code == 400


@pytest.mark.parametrize("role", ["receptionist", "manager"])
def test_only_admin_can_edit_catalog(client, users, room, role):
    login(client, users[role])
    assert client.get("/api/v1/rooms/").status_code == 200
    assert client.patch(f"/api/v1/rooms/{room.pk}/", {"number": "999"}).status_code == 403
    assert (
        client.post(
            "/api/v1/room-types/", {"name": "X", "capacity": 1, "base_rate": "1"}
        ).status_code
        == 403
    )
    room.refresh_from_db()
    assert room.number == "101"


def test_admin_creation_validates_fields_and_audits(client, users, room):
    login(client, users["admin"])
    data = {"number": "102", "floor": 1, "room_type_id": room.room_type_id}
    response = client.post("/api/v1/rooms/", data)
    assert response.status_code == 201
    assert AuditLog.objects.filter(
        action="create", entity="room", entity_id=str(response.data["id"])
    ).exists()
    assert client.post("/api/v1/rooms/", data).status_code == 400
    assert (
        client.post(
            "/api/v1/room-types/", {"name": "Invalid", "capacity": 0, "base_rate": "-1"}
        ).status_code
        == 400
    )


def test_condition_change_is_audited_and_manager_cannot_write(client, users, room):
    login(client, users["receptionist"])
    response = client.post(f"/api/v1/rooms/{room.pk}/condition/", {"condition": "cleaning"})
    assert response.status_code == 200
    assert response.data["condition"] == "cleaning"
    assert AuditLog.objects.filter(action="change_condition").count() == 1
    assert (
        client.post(f"/api/v1/rooms/{room.pk}/condition/", {"condition": "occupied"}).status_code
        == 400
    )
    login(client, users["manager"])
    assert (
        client.post(f"/api/v1/rooms/{room.pk}/condition/", {"condition": "ready"}).status_code
        == 403
    )


def test_room_search_filter_and_invalid_query(client, users, room):
    login(client, users["manager"])
    assert client.get("/api/v1/rooms/?search=101&floor=1&condition=ready").data["count"] == 1
    assert client.get("/api/v1/rooms/?floor=2").data["count"] == 0
    assert client.get("/api/v1/rooms/?floor=abc").status_code == 400
    assert client.get("/api/v1/rooms/?condition=bogus").status_code == 400


def test_customer_unicode_and_permissions(client, users):
    login(client, users["receptionist"])
    response = client.post(
        "/api/v1/customers/", {"full_name": "Nguyễn Thị Ánh", "phone": "0901234567"}
    )
    assert response.status_code == 201
    assert Customer.objects.get(pk=response.data["id"]).full_name == "Nguyễn Thị Ánh"
    assert client.get("/api/v1/customers/?search=Ánh").data["count"] == 1
    assert client.post("/api/v1/customers/", {"full_name": "X", "phone": "abc"}).status_code == 400
    login(client, users["manager"])
    assert client.get("/api/v1/customers/").status_code == 403


def test_dashboard_counts_are_real_and_exclude_inactive_rooms(client, users, room):
    Room.objects.create(number="102", floor=1, room_type=room.room_type, condition="cleaning")
    Room.objects.create(number="103", floor=1, room_type=room.room_type, is_active=False)
    login(client, users["manager"])
    response = client.get("/api/v1/dashboard/")
    assert response.data["rooms"] == {
        "total": 2,
        "ready": 1,
        "occupied": 0,
        "reserved": 0,
        "cleaning": 1,
        "maintenance": 0,
    }
    assert response.data["floors"] == [{"floor": 1, "total": 2, "ready": 1}]
    assert "revenue" not in response.data
    assert not response.data["capabilities"]["customer_access"]


def test_database_constraints_and_decimal_are_enforced(room):
    assert room.room_type.base_rate == Decimal("950000")
    with pytest.raises(IntegrityError), transaction.atomic():
        RoomType.objects.create(name="Invalid", capacity=1, base_rate=-1)
    with pytest.raises(IntegrityError), transaction.atomic():
        Room.objects.create(number="999", floor=1, room_type=room.room_type, condition="bogus")


def test_schema_is_admin_only_and_supports_admin_session(client, users):
    assert client.get("/api/v1/schema/").status_code == 401
    login(client, users["manager"])
    assert client.get("/api/v1/schema/").status_code == 403
    login(client, users["admin"])
    assert client.get("/api/v1/schema/", HTTP_ACCEPT="application/json").status_code == 200
    client.credentials()
    client.force_login(users["admin"])
    assert client.get("/api/v1/docs/").status_code == 200


def test_superuser_has_admin_business_role_and_role_constraint():
    user = User.objects.create_superuser("owner", password=TEST_PASSWORD)
    assert user.role == "admin"
    assert user.display_name == "owner"
    with pytest.raises(IntegrityError), transaction.atomic():
        User.objects.filter(pk=user.pk).update(role="unknown")


def test_seed_is_repeatable_without_overwriting_edits(settings, monkeypatch):
    settings.DEBUG = True
    monkeypatch.setenv("DEMO_PASSWORD", TEST_PASSWORD)
    call_command("seed_demo")
    Room.objects.filter(number="101").update(notes="Giữ thay đổi này")
    call_command("seed_demo")
    assert Room.objects.count() == 30
    assert RoomType.objects.count() == 4
    assert Room.objects.get(number="101").notes == "Giữ thay đổi này"


@pytest.mark.django_db(transaction=True)
def test_room_lock_serializes_two_independent_connections():
    locked = Event()
    release = Event()
    second_attempt = Event()
    second_entered = Event()

    def first_writer():
        try:
            with room_transaction(99123):
                locked.set()
                assert release.wait(4)
        finally:
            connections.close_all()

    def second_writer():
        try:
            assert locked.wait(4)
            second_attempt.set()
            with room_transaction("099123"):
                second_entered.set()
        finally:
            connections.close_all()

    with ThreadPoolExecutor(max_workers=2) as pool:
        first = pool.submit(first_writer)
        second = pool.submit(second_writer)
        try:
            assert second_attempt.wait(4)
            assert not second_entered.wait(0.15)
        finally:
            release.set()
        first.result(timeout=5)
        second.result(timeout=5)
    assert second_entered.is_set()
