from django.utils import timezone

from .booking_services import BookingConflict, ensure_operator, get_booking
from .models import AuditLog, Booking, Stay
from .planned_services import post_plans
from .services import application_transaction, normalize_id, record_audit, room_transaction


def recover_open_stay(actor, booking_id):
    """Repair a legacy checked-in row without inventing an historical arrival time."""
    ensure_operator(actor)
    with application_transaction(f"hotel:booking:{normalize_id(booking_id)}"):
        booking = get_booking(booking_id)
        with room_transaction(booking.room_id):
            if booking.status != Booking.Status.CHECKED_IN:
                raise BookingConflict("Chỉ khôi phục booking đang ở và thiếu hồ sơ nhận phòng.")
            old = getattr(booking, "stay", None)
            if old is not None:
                return old, False
            if Booking.objects.filter(room_id=booking.room_id, status="checked_in").exclude(pk=booking.pk).exists():
                raise BookingConflict("Phòng có nhiều booking đang ở. Cần đối chiếu dữ liệu trước khi khôi phục.")
            check_in = AuditLog.objects.filter(entity="booking", entity_id=str(booking.pk), action="booking_check_in").order_by("created_at", "pk").first()
            timestamp = check_in.created_at if check_in else timezone.now()
            if timestamp > timezone.now():
                raise BookingConflict("Mốc nhận phòng trong nhật ký không hợp lệ.")
            stay = Stay.objects.create(booking=booking, checked_in_at=timestamp,
                checked_in_by=check_in.actor if check_in and check_in.actor else actor)
            post_plans(actor, booking, stay)
            record_audit(actor, "stay_recovered" if check_in else "stay_recovered_now", stay)
            return stay, True
