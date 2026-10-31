import pytest
from django.core.cache import cache
from rest_framework.test import APIClient

from hotel.models import Room, RoomType, User

TEST_PASSWORD = "TestingOnly!2026"


@pytest.fixture(autouse=True)
def clean_throttle_cache():
    cache.clear()


@pytest.fixture
def client():
    return APIClient()


@pytest.fixture
def users(db):
    return {
        role: User.objects.create_user(
            username=role, display_name=f"Nhân viên {role}", role=role, password=TEST_PASSWORD
        )
        for role in User.Role.values
    }


@pytest.fixture
def room(db):
    room_type = RoomType.objects.create(name="Deluxe", capacity=2, base_rate=950000)
    return Room.objects.create(number="101", floor=1, room_type=room_type)
