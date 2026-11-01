import hashlib
import json
from contextlib import ExitStack, contextmanager

from django.utils import timezone

from .booking_services import (
    BookingConflict,
    assert_available,
    ensure_operator,
    get_booking,
    get_room,
)
from .models import Booking, Room, RoomMove
from .selectors import available_rooms
from .service_operations import ensure_open_stay
from .services import application_transaction, normalize_id, record_audit, room_transaction

POLICY = "Giá mới tính từ đêm của ngày chuyển theo giờ khách sạn; giữ nguyên các đêm trước. Dịch vụ theo cùng lượt lưu trú."


def validate_stay(booking):
    if booking.status != Booking.Status.CHECKED_IN:
        raise BookingConflict("Chỉ chuyển phòng khi khách đang ở và chưa chốt hóa đơn.")
    ensure_open_stay(booking)
    if hasattr(booking.stay, "invoice"):
        raise BookingConflict("Lưu trú đã có hóa đơn, không thể chuyển phòng.")
    today = timezone.localdate()
    if not booking.start_date <= today < booking.end_date:
        raise BookingConflict("Cần gia hạn lưu trú trước khi chuyển phòng vào hoặc sau ngày trả.")
    if booking.stay.checked_in_at > timezone.now():
        raise BookingConflict("Mốc nhận phòng không hợp lệ.")
    if Booking.objects.filter(room_id=booking.room_id, status="checked_in").exclude(pk=booking.pk).exists():
        raise BookingConflict("Phòng cũ có nhiều booking đang ở. Cần đối chiếu hồ sơ trước khi chuyển.")
    if any(move.effective_date > today for move in booking.room_moves.all()):
        raise BookingConflict("Lịch sử chuyển phòng có ngày sau hiện tại. Cần đối chiếu hồ sơ.")
    return today


def transfer_options(actor, booking_id):
    ensure_operator(actor)
    booking = get_booking(booking_id)
    today = validate_stay(booking)
    rooms = available_rooms(today, booking.end_date, booking.guests, booking.pk).filter(condition="ready", _occupied=False).exclude(pk=booking.room_id)
    return {"effective_date": today, "policy": POLICY, "rooms": rooms}


@contextmanager
def locked_rooms(booking, room_id):
    with ExitStack() as locks:
        for identifier in sorted({booking.room_id, normalize_id(room_id)}):
            locks.enter_context(room_transaction(identifier))
        yield


def quote_for(booking, data):
    today = validate_stay(booking)
    target = get_room(data["room_id"])
    if target.pk == booking.room_id:
        raise BookingConflict("Chọn phòng mới khác phòng hiện tại.")
    if target.condition != Room.Condition.READY:
        raise BookingConflict("Phòng mới chưa được dọn hoặc đang bảo trì.")
    if Booking.objects.filter(room=target, status="checked_in").exclude(pk=booking.pk).exists():
        raise BookingConflict("Phòng mới đang có khách lưu trú.")
    assert_available(target, today, booking.end_date, booking.guests, exclude=booking.pk)
    if data["old_room_condition"] == "maintenance" and Booking.objects.filter(
        room_id=booking.room_id, status="confirmed", end_date__gt=today,
    ).exclude(pk=booking.pk).exists():
        raise BookingConflict("Phòng cũ còn lịch đặt. Chuyển/hủy các lịch đó trước khi đưa phòng vào bảo trì, hoặc chọn Cần dọn.")
    old_rate = booking.nightly_rate
    new_rate = target.room_type.base_rate if data["price_mode"] == "target" else old_rate
    remaining = (booking.end_date - today).days
    difference = remaining * (new_rate - old_rate)
    old_total = booking.room_total
    service_total = sum((row.total for row in booking.stay.service_usages.filter(status="active")), 0)
    quote = {"effective_date": today.isoformat(), "from_number": booking.room.number, "to_number": target.number,
        "old_rate": str(old_rate), "new_rate": str(new_rate), "remaining_nights": remaining,
        "current_room_total": str(old_total), "new_room_total": str(old_total + difference), "difference": str(difference),
        "service_total": str(service_total), "total": str(old_total + difference + service_total), "policy": POLICY}
    version = {"booking": booking.pk, "updated_at": booking.updated_at.isoformat(), "from_room": booking.room_id,
        "target_updated_at": target.updated_at.isoformat(), "target_rate": str(target.room_type.base_rate),
        "stay": booking.stay.pk, "moves": list(booking.room_moves.values_list("pk", flat=True)), "input": data, "quote": quote}
    quote["quote_token"] = hashlib.sha256(json.dumps(version, sort_keys=True).encode()).hexdigest()
    return quote, target


def transfer_quote(actor, booking_id, data):
    ensure_operator(actor)
    with application_transaction(f"hotel:booking:{normalize_id(booking_id)}"), application_transaction("hotel:catalog", "Shared"):
        booking = get_booking(booking_id)
        with locked_rooms(booking, data["room_id"]):
            return quote_for(booking, data)[0]


def transfer_room(actor, booking_id, key, data):
    ensure_operator(actor)
    booking_id = normalize_id(booking_id)
    fingerprint = hashlib.sha256(json.dumps({"booking": booking_id, **data}, sort_keys=True).encode()).hexdigest()
    with application_transaction(f"hotel:move-request:{actor.pk}:{key}"), application_transaction(f"hotel:booking:{booking_id}"), application_transaction("hotel:catalog", "Shared"):
        existing = RoomMove.objects.filter(created_by=actor, request_key=key).first()
        if existing:
            if existing.request_fingerprint != fingerprint:
                raise BookingConflict("Mã yêu cầu chuyển phòng đã dùng với nội dung khác.")
            return get_booking(booking_id), existing, False
        booking = get_booking(booking_id)
        with locked_rooms(booking, data["room_id"]):
            expected = data["quote_token"]
            inputs = {name: value for name, value in data.items() if name != "quote_token"}
            quote, target = quote_for(booking, inputs)
            if quote["quote_token"] != expected:
                raise BookingConflict("Thông tin hoặc giá chuyển phòng đã thay đổi. Xem lại chênh lệch trước khi xác nhận.")
            old = get_room(booking.room_id)
            move = RoomMove.objects.create(booking=booking, from_room=old, to_room=target,
                from_number=old.number, to_number=target.number, from_type=old.room_type, to_type=target.room_type,
                from_type_name=old.room_type.name, to_type_name=target.room_type.name,
                old_rate=booking.nightly_rate, new_rate=quote["new_rate"], effective_date=quote["effective_date"],
                price_mode=data["price_mode"], old_room_condition=data["old_room_condition"], reason=data["reason"],
                created_by=actor, request_key=key, request_fingerprint=fingerprint)
            booking.room = target
            booking.nightly_rate = quote["new_rate"]
            booking.save(update_fields=["room", "nightly_rate", "updated_at"])
            old.condition = data["old_room_condition"]
            old.save(update_fields=["condition", "updated_at"])
            record_audit(actor, "room_move", move)
            record_audit(actor, "room_move_out", old)
            record_audit(actor, "room_move_in", target)
            return get_booking(booking_id), move, True
