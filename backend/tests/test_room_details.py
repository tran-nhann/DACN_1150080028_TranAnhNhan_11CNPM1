import json
from io import BytesIO

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image

from hotel.models import AuditLog, Room, RoomImage

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def media(settings, tmp_path):
    settings.MEDIA_ROOT = tmp_path
    return tmp_path


def photo(name="room.png", color="green"):
    stream = BytesIO()
    Image.new("RGB", (40, 30), color).save(stream, format="PNG")
    return SimpleUploadedFile(name, stream.getvalue(), content_type="image/png")


def test_create_room_with_details_and_photos(client, users, room):
    client.force_authenticate(users["admin"])
    payload = {
        "number": "102", "floor": 1, "room_type_id": room.room_type_id,
        "description": "Phòng có ban công", "area": "32.50",
        "bed_type": "queen", "bed_count": 1, "view": "Thành phố",
        "amenities": ["Wi-Fi", "Điều hòa", "Wi-Fi"], "notes": "Kiểm tra minibar",
    }
    response = client.post("/api/v1/rooms/", {
        "data": json.dumps(payload), "upload_images": [photo(), photo(color="blue")],
    }, format="multipart")
    assert response.status_code == 201, response.data
    assert response.data["area"] == "32.50"
    assert response.data["amenities"] == ["Wi-Fi", "Điều hòa"]
    assert response.data["description"] == payload["description"]
    assert response.data["bed_type"] == "queen"
    assert response.data["bed_count"] == 1
    assert response.data["view"] == "Thành phố"
    assert len(response.data["images"]) == 2
    assert response.data["images"][0]["url"].startswith("/media/rooms/")
    saved = Room.objects.get(pk=response.data["id"])
    assert all(image.image.storage.exists(image.image.name) for image in saved.images.all())
    assert AuditLog.objects.filter(entity="room", entity_id=str(saved.pk), action="create").exists()
    listed = client.get("/api/v1/rooms/").data["results"]
    assert next(row for row in listed if row["id"] == saved.pk)["images"] == response.data["images"]
    assert client.get(f"/api/v1/rooms/{saved.pk}/").data["images"] == response.data["images"]


def test_edit_reorders_deletes_and_appends_photos(client, users, room, django_capture_on_commit_callbacks):
    client.force_authenticate(users["admin"])
    originals = [RoomImage.objects.create(room=room, image=photo(), position=i) for i in range(3)]
    removed_file = originals[1].image
    with django_capture_on_commit_callbacks(execute=True):
        response = client.patch(f"/api/v1/rooms/{room.pk}/", {
            "data": json.dumps({"image_ids": [originals[2].pk, originals[0].pk], "notes": "Đã cập nhật"}),
            "upload_images": [photo()],
        }, format="multipart")
    assert response.status_code == 200, response.data
    images = response.data["images"]
    assert [row["id"] for row in images[:2]] == [originals[2].pk, originals[0].pk]
    assert [row["position"] for row in images] == [0, 1, 2]
    assert not removed_file.storage.exists(removed_file.name)
    assert response.data["notes"] == "Đã cập nhật"
    # A metadata-only PATCH must retain the gallery.
    response = client.patch(f"/api/v1/rooms/{room.pk}/", {"view": "Vườn"}, format="json")
    assert response.status_code == 200
    assert response.data["images"] == images


def test_new_upload_can_be_selected_as_cover(client, users, room):
    client.force_authenticate(users["admin"])
    old = RoomImage.objects.create(room=room, image=photo())
    response = client.patch(f"/api/v1/rooms/{room.pk}/", {
        "data": json.dumps({"cover_upload_index": 1}),
        "upload_images": [photo(), photo(color="blue")],
    }, format="multipart")
    assert response.status_code == 200, response.data
    assert response.data["images"][1]["id"] == old.pk
    assert [row["position"] for row in response.data["images"]] == [0, 1, 2]


@pytest.mark.parametrize("role", ["receptionist", "manager"])
def test_only_admin_can_edit_details_or_upload(client, users, room, role):
    client.force_authenticate(users[role])
    assert client.get(f"/api/v1/rooms/{room.pk}/").status_code == 200
    assert client.patch(f"/api/v1/rooms/{room.pk}/", {"description": "Sửa trái quyền"}, format="json").status_code == 403
    response = client.patch(f"/api/v1/rooms/{room.pk}/", {"data": "{}", "upload_images": [photo()]}, format="multipart")
    assert response.status_code == 403
    assert not RoomImage.objects.exists()


@pytest.mark.parametrize("changes", [
    {"area": "0"}, {"area": "10000"}, {"bed_count": 0}, {"bed_count": 21},
    {"bed_type": "invalid"}, {"amenities": "Wi-Fi"}, {"amenities": ["x" * 51]},
    {"amenities": ["Wi-Fi"] * 31}, {"description": "x" * 2001},
    {"image_ids": [99999]},
    {"cover_upload_index": 0},
])
def test_invalid_details_do_not_change_room(client, users, room, changes):
    client.force_authenticate(users["admin"])
    response = client.patch(f"/api/v1/rooms/{room.pk}/", {"notes": "Không lưu", **changes}, format="json")
    assert response.status_code == 400, response.data
    room.refresh_from_db()
    assert room.notes == ""


def test_foreign_duplicate_and_too_many_photos_rejected(client, users, room):
    client.force_authenticate(users["admin"])
    other = Room.objects.create(number="201", floor=2, room_type=room.room_type)
    foreign = RoomImage.objects.create(room=other, image=photo())
    own = RoomImage.objects.create(room=room, image=photo())
    for ids in [[foreign.pk], [own.pk, own.pk]]:
        assert client.patch(f"/api/v1/rooms/{room.pk}/", {"image_ids": ids}, format="json").status_code == 400
    response = client.patch(f"/api/v1/rooms/{room.pk}/", {
        "data": "{}", "upload_images": [photo() for _ in range(10)],
    }, format="multipart")
    assert response.status_code == 400
    assert room.images.count() == 1


def test_bad_image_and_oversized_image_rejected(client, users, room):
    client.force_authenticate(users["admin"])
    oversized = photo().read() + b"x" * (5 * 1024 * 1024)
    for upload in [
        SimpleUploadedFile("fake.png", b"not an image", content_type="image/png"),
        SimpleUploadedFile("large.png", oversized, content_type="image/png"),
    ]:
        response = client.patch(f"/api/v1/rooms/{room.pk}/", {
            "data": json.dumps({"notes": "Không lưu"}), "upload_images": [upload],
        }, format="multipart")
        assert response.status_code == 400, response.data
    room.refresh_from_db()
    assert room.notes == ""
    assert not room.images.exists()


def test_failed_audit_rolls_back_data_and_removes_new_files(client, users, room, media, monkeypatch):
    client.force_authenticate(users["admin"])

    def fail(*args):
        raise RuntimeError("Simulated audit failure")

    monkeypatch.setattr("hotel.views.record_audit", fail)
    with pytest.raises(RuntimeError, match="Simulated audit failure"):
        client.patch(f"/api/v1/rooms/{room.pk}/", {
            "data": json.dumps({"notes": "Không lưu"}), "upload_images": [photo()],
        }, format="multipart")
    room.refresh_from_db()
    assert room.notes == ""
    assert not room.images.exists()
    assert not [path for path in media.rglob("*") if path.is_file()]


@pytest.mark.parametrize("payload", ["{", "[]", "null"])
def test_malformed_multipart_data_is_a_validation_error(client, users, room, payload):
    client.force_authenticate(users["admin"])
    response = client.patch(f"/api/v1/rooms/{room.pk}/", {"data": payload}, format="multipart")
    assert response.status_code == 400
