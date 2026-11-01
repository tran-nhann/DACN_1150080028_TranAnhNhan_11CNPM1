import hashlib
import json
from decimal import Decimal

from django.utils import timezone

from .booking_services import BookingConflict, ensure_operator, get_booking, get_room
from .models import Booking, Invoice, InvoiceLine, Payment, Room
from .room_charges import room_segments
from .service_operations import ensure_open_stay
from .services import application_transaction, normalize_id, record_audit, room_transaction


def invoice_queryset():
    return Invoice.objects.select_related("stay__booking", "issued_by", "payment__received_by").prefetch_related("lines")


def folio_for(booking):
    stay = ensure_open_stay(booking)
    usages = list(stay.service_usages.filter(status="active").order_by("created_at", "pk"))
    segments = room_segments(booking)
    moved = bool(list(booking.room_moves.all()))
    lines = [{
        "kind": "room", "source_usage_id": None,
        "name": f"Phòng {row['room_number']}" + (f" · {row['start_date']:%d/%m/%Y} → {row['end_date']:%d/%m/%Y}" if moved else ""),
        "unit": "đêm", "quantity": row["nights"], "unit_price": str(row["nightly_rate"]),
        "total": str(row["total"]),
    } for row in segments] + [{
        "kind": "service", "source_usage_id": usage.pk, "name": usage.name,
        "unit": usage.unit, "quantity": usage.quantity, "unit_price": str(usage.unit_price),
        "total": str(usage.total),
    } for usage in usages]
    service_total = sum((usage.total for usage in usages), Decimal(0))
    reason = ""
    if booking.end_date < timezone.localdate():
        reason = "Lưu trú đã quá ngày trả. Cập nhật gia hạn trước khi chốt hóa đơn."
    result = {
        "booking_id": booking.pk, "booking_code": booking.code,
        "guest_name": booking.customer.full_name, "guest_phone": booking.customer.phone,
        "room_number": booking.room.number, "room_type": booking.room.room_type.name,
        "start_date": booking.start_date.isoformat(), "end_date": booking.end_date.isoformat(),
        "nights": booking.nights, "room_total": str(booking.room_total), "service_total": str(service_total),
        "total": str(booking.room_total + service_total), "lines": lines,
        "currency": "VND", "can_checkout": not reason, "blocked_reason": reason,
        "billing_policy": "Tính đủ số đêm đã đặt/gia hạn, kể cả trả sớm. Chưa áp dụng phụ thu, giảm giá hoặc cọc.",
    }
    result["quote_token"] = hashlib.sha256(json.dumps(result, sort_keys=True).encode()).hexdigest()
    return result


def checkout(actor, booking_id, key, data):
    ensure_operator(actor)
    booking_id = normalize_id(booking_id)
    fingerprint = hashlib.sha256(json.dumps({
        "booking": booking_id, "quote": data["quote_token"], "total": str(data["expected_total"]),
        "method": data["method"], "reference": data.get("reference", ""), "notes": data.get("notes", ""),
    }, sort_keys=True).encode()).hexdigest()
    with (
        application_transaction(f"hotel:checkout-request:{actor.pk}:{key}"),
        application_transaction(f"hotel:booking:{booking_id}"),
    ):
        existing = Invoice.objects.filter(issued_by=actor, request_key=key).first()
        if existing:
            if existing.request_fingerprint != fingerprint:
                raise BookingConflict("Mã yêu cầu đã dùng để chốt hóa đơn với thông tin khác.")
            return invoice_queryset().get(pk=existing.pk), False
        booking = get_booking(booking_id)
        if Invoice.objects.filter(stay__booking=booking).exists():
            raise BookingConflict("Lưu trú đã chốt hóa đơn. Mở hóa đơn để xem, không thu tiền lần nữa.")
        stay = ensure_open_stay(booking)
        with room_transaction(booking.room_id):
            room = get_room(booking.room_id)
            folio = folio_for(booking)
            if not folio["can_checkout"]:
                raise BookingConflict(folio["blocked_reason"])
            if folio["quote_token"] != data["quote_token"] or Decimal(folio["total"]) != data["expected_total"]:
                raise BookingConflict("Bảng kê đã thay đổi. Làm mới, kiểm tra lại và xác nhận thanh toán.")
            invoice = Invoice.objects.create(
                stay=stay, issued_by=actor, request_key=key, request_fingerprint=fingerprint,
                **{field: folio[field] for field in [
                    "booking_code", "guest_name", "guest_phone", "room_number", "room_type",
                    "start_date", "end_date", "room_total", "service_total", "total",
                ]},
            )
            InvoiceLine.objects.bulk_create([
                InvoiceLine(invoice=invoice, position=position, **line)
                for position, line in enumerate(folio["lines"], start=1)
            ])
            payment = Payment.objects.create(
                invoice=invoice, amount=invoice.total, method=data["method"],
                reference=data.get("reference", ""), notes=data.get("notes", ""), received_by=actor,
            )
            stay.checked_out_at = timezone.now()
            stay.save(update_fields=["checked_out_at"])
            booking.status = Booking.Status.CHECKED_OUT
            booking.save(update_fields=["status", "updated_at"])
            room.condition = Room.Condition.CLEANING
            room.save(update_fields=["condition", "updated_at"])
            record_audit(actor, "invoice_issue", invoice)
            record_audit(actor, "payment_receive", payment)
            record_audit(actor, "booking_check_out", booking)
            record_audit(actor, "checkout_cleaning", room)
            return invoice_queryset().get(pk=invoice.pk), True


def confirm_cleaned(actor, room_id, expected_updated_at):
    ensure_operator(actor)
    with room_transaction(room_id):
        room = get_room(room_id)
        if Booking.objects.filter(room=room, status=Booking.Status.CHECKED_IN).exists():
            raise BookingConflict("Phòng đang có khách, không thể xác nhận đã dọn.")
        if room.condition == Room.Condition.READY:
            return room
        if room.condition != Room.Condition.CLEANING:
            raise BookingConflict("Chỉ xác nhận đã dọn cho phòng đang Cần dọn.")
        if room.updated_at != expected_updated_at:
            raise BookingConflict("Thông tin phòng đã thay đổi. Mở lại phòng trước khi xác nhận đã dọn.")
        room.condition = Room.Condition.READY
        room.save(update_fields=["condition", "updated_at"])
        record_audit(actor, "room_cleaned", room)
        return room
