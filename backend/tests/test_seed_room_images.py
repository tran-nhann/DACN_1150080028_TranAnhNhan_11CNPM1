import json
from io import StringIO

import pytest
from django.core.files.base import ContentFile
from django.core.management import call_command
from django.core.management.base import CommandError
from PIL import Image

from hotel.management.commands import seed_room_images
from hotel.models import AuditLog, RoomImage

pytestmark = pytest.mark.django_db


@pytest.fixture
def image_assets(settings, tmp_path, monkeypatch):
    settings.DEBUG = True
    settings.MEDIA_ROOT = tmp_path / "media"
    assets = tmp_path / "assets"
    assets.mkdir()
    names = [f"deluxe-{i}.jpg" for i in range(3)]
    for name in names:
        Image.new("RGB", (40, 30), "green").save(assets / name)
    (assets / "manifest.json").write_text(json.dumps({"types": {"deluxe": names}}))
    monkeypatch.setattr(seed_room_images, "ASSET_DIR", assets)
    return assets


def test_images_are_seeded_once_without_changing_room_fields(room, image_assets):
    original_updated = room.updated_at
    call_command("seed_room_images", stdout=StringIO())
    ids = list(room.images.values_list("id", flat=True))
    assert len(ids) == 3
    assert list(room.images.values_list("position", flat=True)) == [0, 1, 2]
    assert all(photo.image.storage.exists(photo.image.name) for photo in room.images.all())
    call_command("seed_room_images", stdout=StringIO())
    assert list(room.images.values_list("id", flat=True)) == ids
    room.refresh_from_db()
    assert room.updated_at == original_updated
    assert room.description == ""
    assert AuditLog.objects.filter(action="seed_images", entity_id=str(room.pk)).count() == 1


def test_existing_gallery_is_preserved(room, image_assets):
    original = RoomImage.objects.create(room=room, image=ContentFile(b"existing photo", name="own.jpg"))
    call_command("seed_room_images", stdout=StringIO())
    assert list(room.images.values_list("id", flat=True)) == [original.pk]
    assert original.image.read() == b"existing photo"


def test_missing_source_fails_without_partial_gallery(room, image_assets):
    (image_assets / "deluxe-2.jpg").unlink()
    with pytest.raises(CommandError, match="Không đọc được bộ ảnh mẫu"):
        call_command("seed_room_images")
    assert room.images.count() == 0


def test_failed_seed_removes_copied_files_and_rolls_back(room, image_assets, settings, monkeypatch):
    def fail(*args):
        raise RuntimeError("Simulated audit failure")

    monkeypatch.setattr(seed_room_images, "record_audit", fail)
    with pytest.raises(RuntimeError, match="Simulated audit failure"):
        call_command("seed_room_images")
    assert room.images.count() == 0
    assert not [path for path in settings.MEDIA_ROOT.rglob("*") if path.is_file()]


def test_production_rejects_sample_images(room, image_assets, settings):
    settings.DEBUG = False
    with pytest.raises(CommandError, match="DJANGO_DEBUG=True"):
        call_command("seed_room_images")
    assert room.images.count() == 0
