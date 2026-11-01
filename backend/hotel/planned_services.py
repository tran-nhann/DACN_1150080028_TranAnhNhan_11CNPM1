import hashlib
import json
from uuid import NAMESPACE_URL, uuid5

from django.utils import timezone
from rest_framework.exceptions import NotFound

from .booking_services import BookingConflict, ensure_operator, get_booking
from .models import Booking, BookingServicePlan, ServiceItem, ServiceUsage
from .services import application_transaction, normalize_id, record_audit


def make_plan(actor, booking, key, data, fingerprint=""):
    try:
        service = ServiceItem.objects.get(pk=data["service_id"])
    except ServiceItem.DoesNotExist as exc:
        raise NotFound("Không tìm thấy dịch vụ đặt kèm.") from exc
    if not service.is_active or service.unit not in ServiceItem.Unit.values:
        raise BookingConflict("Dịch vụ đặt kèm đã ngừng bán hoặc chưa có đơn vị hợp lệ.")
    if service.unit_price != data["expected_unit_price"]:
        raise BookingConflict(f"Giá {service.name} đã thay đổi. Chọn lại dịch vụ để xác nhận giá mới.")
    plan = BookingServicePlan.objects.create(booking=booking, service=service, name=service.name,
        unit=service.unit, unit_price=service.unit_price, quantity=data["quantity"], created_by=actor,
        request_key=key, request_fingerprint=fingerprint)
    record_audit(actor, "service_plan_add", plan)
    return plan


def add_plan(actor, booking_id, key, data):
    ensure_operator(actor)
    booking_id = normalize_id(booking_id)
    fingerprint = hashlib.sha256(json.dumps({"booking": booking_id, "service": data["service_id"],
        "quantity": data["quantity"], "quote": str(data["expected_unit_price"])}, sort_keys=True).encode()).hexdigest()
    with application_transaction(f"hotel:plan-request:{actor.pk}:{key}"), application_transaction(f"hotel:booking:{booking_id}"):
        old = BookingServicePlan.objects.filter(created_by=actor, request_key=key).first()
        if old:
            if old.request_fingerprint != fingerprint:
                raise BookingConflict("Mã yêu cầu đã dùng với dịch vụ đặt kèm khác.")
            return old, False
        booking = get_booking(booking_id)
        if booking.status != Booking.Status.CONFIRMED or getattr(booking, "stay", None) is not None:
            raise BookingConflict("Chỉ thêm dịch vụ đặt trước khi booking chưa nhận phòng. Tải lại trạng thái lưu trú.")
        with application_transaction("hotel:catalog", "Shared"):
            return make_plan(actor, booking, key, data, fingerprint), True


def cancel_plan(actor, booking_id, plan_id, reason):
    ensure_operator(actor)
    with application_transaction(f"hotel:booking:{normalize_id(booking_id)}"):
        booking = get_booking(booking_id)
        try:
            plan = BookingServicePlan.objects.get(pk=normalize_id(plan_id), booking=booking)
        except BookingServicePlan.DoesNotExist as exc:
            raise NotFound("Không tìm thấy dịch vụ đặt kèm trong booking này.") from exc
        if plan.status == "cancelled":
            if plan.cancel_reason != reason:
                raise BookingConflict("Khoản đã hủy, không thể đổi lý do.")
            return plan
        if booking.status != "confirmed" or plan.status != "reserved":
            raise BookingConflict("Khoản đã chuyển vào lưu trú. Tải lại bảng dịch vụ để xử lý khoản hiện tại.")
        plan.status, plan.cancelled_at, plan.cancelled_by, plan.cancel_reason = "cancelled", timezone.now(), actor, reason
        plan.save(update_fields=["status", "cancelled_at", "cancelled_by", "cancel_reason"])
        record_audit(actor, "service_plan_cancel", plan)
        return plan


def post_plans(actor, booking, stay):
    # Caller holds the booking lock. Each reserved row is linked to exactly one usage.
    for plan in booking.service_plans.filter(status="reserved").order_by("pk"):
        usage = ServiceUsage.objects.create(stay=stay, service_id=plan.service_id, name=plan.name, unit=plan.unit,
            unit_price=plan.unit_price, quantity=plan.quantity, created_by=plan.created_by,
            request_key=uuid5(NAMESPACE_URL, f"hotel:plan:{plan.pk}"), request_fingerprint=f"plan:{plan.pk}")
        plan.status, plan.usage = "posted", usage
        plan.save(update_fields=["status", "usage"])
        record_audit(actor, "service_plan_post", plan)
