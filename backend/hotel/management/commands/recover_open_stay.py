from django.core.management.base import BaseCommand, CommandError

from hotel.models import Booking, User
from hotel.stay_recovery import recover_open_stay


class Command(BaseCommand):
    help = "Kiểm tra/khôi phục một booking Đang ở bị thiếu Stay; mặc định chỉ xem."

    def add_arguments(self, parser):
        parser.add_argument("--booking", type=int, required=True)
        parser.add_argument("--actor", required=True)
        parser.add_argument("--apply", action="store_true")

    def handle(self, *args, **options):
        try:
            booking = Booking.objects.select_related("room", "stay").get(pk=options["booking"])
            actor = User.objects.get(username=options["actor"], is_active=True, role__in=["admin", "receptionist"])
        except (Booking.DoesNotExist, User.DoesNotExist) as exc:
            raise CommandError("Không tìm thấy booking hoặc tài khoản có quyền.") from exc
        missing = booking.status == "checked_in" and getattr(booking, "stay", None) is None
        self.stdout.write(f"Booking {booking.pk}, phòng {booking.room.number}, trạng thái {booking.status}, thiếu Stay: {missing}")
        if options["apply"]:
            stay, created = recover_open_stay(actor, booking.pk)
            self.stdout.write(self.style.SUCCESS(f"Hồ sơ {stay.pk}; đã khôi phục: {created}. Không lập hóa đơn hoặc ghi nhận thu tiền."))
