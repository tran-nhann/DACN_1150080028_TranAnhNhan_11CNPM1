import hashlib
import json
from contextlib import ExitStack
from datetime import timedelta

from django.db.models import Q
from django.utils import timezone
from rest_framework.exceptions import APIException, NotFound, PermissionDenied, ValidationError

from .models import Booking, Room, Stay
from .selectors import ACTIVE_BOOKING_STATUSES
from .services import application_transaction, normalize_id, record_audit, room_transaction


class BookingConflict(APIException):
    status_code = 409
    default_detail = "Phòng đã có lịch đặt trong thời gian này."
    default_code = "booking_conflict"


def ensure_operator(actor):
    if not actor.is_active or actor.role not in {"admin", "receptionist"}:
        raise PermissionDenied("Bạn không có quyền thay đổi đặt phòng.")


def validate_interval(start, end, allow_past=False):
    today = timezone.localdate()
    if end <= start or (end - start).days > 90:
        raise ValidationError("Thời gian lưu trú phải từ 1 đến 90 đêm.")
    if not allow_past and start < today:
        raise ValidationError("Ngày nhận phòng không được ở quá khứ.")
    if start > today + timedelta(days=365):
        raise ValidationError("Chỉ nhận đặt phòng trong 365 ngày tới.")


def get_room(room_id):
    try:
        return Room.objects.select_related("room_type").get(
            pk=normalize_id(room_id), is_active=True
        )
    except Room.DoesNotExist as exc:
        raise NotFound("Không tìm thấy phòng.") from exc


def get_booking(booking_id):
    try:
        return Booking.objects.select_related("room__room_type", "customer", "stay").get(
            pk=normalize_id(booking_id)
        )
    except Booking.DoesNotExist as exc:
        raise NotFound("Không tìm thấy đặt phòng.") from exc


def assert_available(room, start, end, guests, exclude=None):
    if room.condition == Room.Condition.MAINTENANCE:
        raise BookingConflict("Phòng đang bảo trì.")
    if guests > room.room_type.capacity:
        raise ValidationError("Số khách vượt sức chứa của phòng.")
    conflicts = Booking.objects.filter(room=room, status__in=ACTIVE_BOOKING_STATUSES).exclude(
        pk=exclude
    )
    if conflicts.filter(start_date__lt=end, end_date__gt=start).exists():
        raise BookingConflict()
    if (
        start == timezone.localdate()
        and conflicts.filter(status=Booking.Status.CHECKED_IN, end_date__lte=start).exists()
    ):
        raise BookingConflict("Khách hiện tại chưa trả phòng.")


def assert_quote(room, expected_rate):
    if expected_rate is not None and expected_rate != room.room_type.base_rate:
        raise BookingConflict("Giá phòng đã thay đổi. Vui lòng chọn lại phòng.")


def create_booking(actor, key, data):
    ensure_operator(actor)
    fingerprint = hashlib.sha256(
        json.dumps(
            {
                "room": data["room_id"].pk,
                "customer": data["customer_id"].pk,
                "start": data["start_date"].isoformat(),
                "end": data["end_date"].isoformat(),
                "guests": data["guests"],
                "quote": str(data.get("expected_nightly_rate"))
                if data.get("expected_nightly_rate") is not None
                else None,
            },
            sort_keys=True,
        ).encode()
    ).hexdigest()
    # Key lock first: requests with the same key but different room IDs also serialize.
    with (
        application_transaction(f"hotel:request:{actor.pk}:{key}"),
        application_transaction("hotel:catalog", "Shared"),
    ):
        existing = Booking.objects.filter(created_by=actor, request_key=key).first()
        if existing:
            if existing.request_fingerprint != fingerprint:
                raise BookingConflict("Mã yêu cầu đã dùng với thông tin khác.")
            return existing, False
        with room_transaction(data["room_id"].pk):
            room = get_room(data["room_id"].pk)
            validate_interval(data["start_date"], data["end_date"])
            assert_available(room, data["start_date"], data["end_date"], data["guests"])
            assert_quote(room, data.get("expected_nightly_rate"))
            booking = Booking.objects.create(
                room=room,
                customer=data["customer_id"],
                start_date=data["start_date"],
                end_date=data["end_date"],
                guests=data["guests"],
                nightly_rate=room.room_type.base_rate,
                created_by=actor,
                request_key=key,
                request_fingerprint=fingerprint,
            )
            record_audit(actor, "booking_create", booking)
            return booking, True


def cancel_booking(actor, booking_id):
    ensure_operator(actor)
    with application_transaction(f"hotel:booking:{normalize_id(booking_id)}"):
        booking = get_booking(booking_id)
        with room_transaction(booking.room_id):
            if booking.status == Booking.Status.CANCELLED:
                return booking
            if booking.status != Booking.Status.CONFIRMED:
                raise BookingConflict("Chỉ hủy được đặt phòng chưa nhận.")
            booking.status = Booking.Status.CANCELLED
            booking.save(update_fields=["status", "updated_at"])
            record_audit(actor, "booking_cancel", booking)
            return booking


def check_in(actor, booking_id):
    ensure_operator(actor)
    with application_transaction(f"hotel:booking:{normalize_id(booking_id)}"):
        booking = get_booking(booking_id)
        with room_transaction(booking.room_id):
            if booking.status == Booking.Status.CHECKED_IN:
                return booking
            if booking.status != Booking.Status.CONFIRMED:
                raise BookingConflict("Đặt phòng không thể nhận phòng.")
            today = timezone.localdate()
            if not booking.start_date <= today < booking.end_date:
                raise ValidationError("Chưa đến ngày nhận phòng hoặc lịch đã hết hạn.")
            room = get_room(booking.room_id)
            if room.condition != Room.Condition.READY:
                raise BookingConflict("Phòng chưa sẵn sàng để nhận khách.")
            if (
                Booking.objects.filter(room=room, status=Booking.Status.CHECKED_IN)
                .exclude(pk=booking.pk)
                .exists()
            ):
                raise BookingConflict("Phòng đang có khách lưu trú.")
            Stay.objects.create(booking=booking, checked_in_at=timezone.now(), checked_in_by=actor)
            booking.status = Booking.Status.CHECKED_IN
            booking.save(update_fields=["status", "updated_at"])
            record_audit(actor, "booking_check_in", booking)
            return get_booking(booking.pk)


def reschedule_booking(actor, booking_id, data):
    ensure_operator(actor)
    with (
        application_transaction(f"hotel:booking:{normalize_id(booking_id)}"),
        application_transaction("hotel:catalog", "Shared"),
    ):
        booking = get_booking(booking_id)
        room_id = data.get("room_id", booking.room).pk
        with ExitStack() as locks:
            for identifier in sorted({booking.room_id, room_id}):
                locks.enter_context(room_transaction(identifier))
            if booking.status != Booking.Status.CONFIRMED:
                raise BookingConflict("Chỉ đổi lịch được đặt phòng chưa nhận.")
            start, end = data["start_date"], data["end_date"]
            if (booking.room_id, booking.start_date, booking.end_date) == (room_id, start, end):
                return booking
            validate_interval(start, end)
            room = get_room(room_id)
            assert_available(room, start, end, booking.guests, exclude=booking.pk)
            if booking.room_id != room_id:
                assert_quote(room, data.get("expected_nightly_rate"))
                booking.nightly_rate = room.room_type.base_rate
            booking.room, booking.start_date, booking.end_date = room, start, end
            booking.save(
                update_fields=["room", "start_date", "end_date", "nightly_rate", "updated_at"]
            )
            record_audit(actor, "booking_reschedule", booking)
            return booking


def extend_booking(actor, booking_id, end):
    ensure_operator(actor)
    with application_transaction(f"hotel:booking:{normalize_id(booking_id)}"):
        booking = get_booking(booking_id)
        with room_transaction(booking.room_id):
            if booking.status not in ACTIVE_BOOKING_STATUSES:
                raise BookingConflict("Đặt phòng không thể gia hạn.")
            if end == booking.end_date:
                return booking
            if end < booking.end_date:
                raise ValidationError("Ngày trả mới phải sau ngày trả hiện tại.")
            validate_interval(
                booking.start_date, end, allow_past=booking.status == Booking.Status.CHECKED_IN
            )
            room = get_room(booking.room_id)
            assert_available(room, booking.start_date, end, booking.guests, exclude=booking.pk)
            booking.end_date = end
            booking.save(update_fields=["end_date", "updated_at"])
            record_audit(actor, "booking_extend", booking)
            return booking


def guard_room_edit(room, changes):
    active = Booking.objects.filter(room=room, status__in=ACTIVE_BOOKING_STATUSES).filter(
        Q(end_date__gt=timezone.localdate()) | Q(status=Booking.Status.CHECKED_IN)
    )
    occupied = active.filter(status=Booking.Status.CHECKED_IN).exists()
    next_condition = changes.get("condition", room.condition)
    if occupied and next_condition != Room.Condition.READY:
        raise BookingConflict("Phòng đang có khách lưu trú.")
    if active.exists() and (
        not changes.get("is_active", room.is_active)
        or (next_condition == Room.Condition.MAINTENANCE and room.condition != next_condition)
        or ("room_type" in changes and changes["room_type"].pk != room.room_type_id)
    ):
        raise BookingConflict("Phòng có lịch đặt. Hủy hoặc đổi phòng trước.")
