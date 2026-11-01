import json
from pathlib import Path

from django.conf import settings
from django.core.files import File
from django.core.management.base import BaseCommand, CommandError
from PIL import Image

from hotel.models import Room, RoomImage
from hotel.services import application_transaction, record_audit

ASSET_DIR = Path(__file__).resolve().parents[2] / "demo_assets" / "rooms"


class Command(BaseCommand):
    help = "Gắn bộ ảnh mẫu theo loại phòng cho phòng chưa có ảnh; không ghi đè ảnh đã nhập."

    def handle(self, *args, **options):
        if not settings.DEBUG:
            raise CommandError("Chỉ được thêm ảnh mẫu khi DJANGO_DEBUG=True.")
        try:
            catalog = json.loads((ASSET_DIR / "manifest.json").read_text(encoding="utf-8"))["types"]
            for filenames in catalog.values():
                if len(filenames) != 3:
                    raise ValueError("Mỗi loại phòng cần đủ 3 ảnh mẫu.")
                for filename in filenames:
                    if Path(filename).name != filename:
                        raise ValueError("Tên file ảnh không hợp lệ.")
                    source = ASSET_DIR / filename
                    if source.stat().st_size > 5 * 1024 * 1024:
                        raise ValueError(f"Ảnh vượt quá 5 MB: {filename}")
                    with Image.open(source) as image:
                        if image.format not in {"JPEG", "PNG", "WEBP"} or image.width * image.height > 25_000_000:
                            raise ValueError(f"Ảnh không hợp lệ: {filename}")
                        image.verify()
        except (OSError, ValueError, KeyError, TypeError) as exc:
            raise CommandError(f"Không đọc được bộ ảnh mẫu: {exc}") from exc

        created_files = []
        added_rooms = skipped_rooms = added_images = 0
        try:
            with application_transaction("hotel:catalog"):
                for room in Room.objects.select_related("room_type").prefetch_related("images"):
                    if room.images.exists():
                        skipped_rooms += 1
                        continue
                    filenames = catalog.get(room.room_type.name.casefold())
                    if not filenames:
                        raise CommandError(f"Chưa có bộ ảnh cho loại phòng {room.room_type.name}.")
                    for position, filename in enumerate(filenames):
                        photo = RoomImage(room=room, position=position)
                        with (ASSET_DIR / filename).open("rb") as stream:
                            photo.image.save(filename, File(stream), save=False)
                        created_files.append(photo.image)
                        photo.save()
                        added_images += 1
                    record_audit(None, "seed_images", room)
                    added_rooms += 1
        except Exception:
            for file in created_files:
                file.delete(save=False)
            raise
        self.stdout.write(self.style.SUCCESS(
            f"Đã thêm {added_images} ảnh mẫu cho {added_rooms} phòng; "
            f"giữ nguyên {skipped_rooms} phòng đã có ảnh."
        ))
