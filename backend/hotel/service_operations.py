import hashlib
import json

from django.utils import timezone
from rest_framework.exceptions import NotFound

from .booking_services import BookingConflict, ensure_operator, get_booking
from .models import Booking, ServiceItem, ServiceUsage
from .services import application_transaction, normalize_id, record_audit


def ensure_open_stay(booking):
    stay = getattr(booking, "stay", None)
    if booking.status == Booking.Status.CHECKED_IN and stay is None:
        raise BookingConflict("Booking đang ở nhưng thiếu hồ sơ nhận phòng. Cần khôi phục hồ sơ lưu trú trước khi ghi dịch vụ hoặc quyết toán.")
    if (
        booking.status != Booking.Status.CHECKED_IN
        or stay is None
        or stay.checked_out_at is not None
    ):
        raise BookingConflict("Chỉ ghi hoặc hủy dịch vụ khi khách đang ở.")
    return stay


def add_service(actor, booking_id, key, data):
    ensure_operator(actor)
    booking_id = normalize_id(booking_id)
    fingerprint = hashlib.sha256(
        json.dumps(
            {
                "booking": booking_id,
                "service": data["service_id"],
                "quantity": data["quantity"],
                "quote": str(data["expected_unit_price"]),
            },
            sort_keys=True,
        ).encode()
    ).hexdigest()
    with (
        application_transaction(f"hotel:service-request:{actor.pk}:{key}"),
        application_transaction(f"hotel:booking:{booking_id}"),
    ):
        existing = ServiceUsage.objects.filter(created_by=actor, request_key=key).first()
        if existing:
            if existing.request_fingerprint != fingerprint:
                raise BookingConflict("Mã yêu cầu đã dùng với thông tin khác.")
            return existing, False
        booking = get_booking(booking_id)
        stay = ensure_open_stay(booking)
        with application_transaction("hotel:catalog", "Shared"):
            try:
                service = ServiceItem.objects.get(pk=data["service_id"])
            except ServiceItem.DoesNotExist as exc:
                raise NotFound("Không tìm thấy dịch vụ.") from exc
            if not service.is_active:
                raise BookingConflict("Dịch vụ đã ngừng bán. Chọn dịch vụ khác.")
            if service.unit not in ServiceItem.Unit.values:
                raise BookingConflict("Đơn vị dịch vụ chưa hợp lệ. Admin cần cập nhật danh mục.")
            if service.unit_price != data["expected_unit_price"]:
                raise BookingConflict("Giá dịch vụ đã thay đổi. Chọn lại để xem giá mới.")
            usage = ServiceUsage.objects.create(
                stay=stay,
                service=service,
                name=service.name,
                unit=service.unit,
                unit_price=service.unit_price,
                quantity=data["quantity"],
                created_by=actor,
                request_key=key,
                request_fingerprint=fingerprint,
            )
            record_audit(actor, "service_add", usage)
            return usage, True


def cancel_service(actor, booking_id, usage_id, reason):
    ensure_operator(actor)
    with application_transaction(f"hotel:booking:{normalize_id(booking_id)}"):
        booking = get_booking(booking_id)
        try:
            usage = ServiceUsage.objects.get(pk=normalize_id(usage_id), stay__booking=booking)
        except ServiceUsage.DoesNotExist as exc:
            raise NotFound("Không tìm thấy khoản dịch vụ trong lưu trú này.") from exc
        if usage.status == ServiceUsage.Status.CANCELLED:
            if usage.cancel_reason != reason:
                raise BookingConflict("Khoản này đã hủy; không thể thay đổi lý do.")
            return usage
        ensure_open_stay(booking)
        usage.status = ServiceUsage.Status.CANCELLED
        usage.cancelled_at = timezone.now()
        usage.cancelled_by = actor
        usage.cancel_reason = reason
        usage.save(update_fields=["status", "cancelled_at", "cancelled_by", "cancel_reason"])
        record_audit(actor, "service_cancel", usage)
        return usage
