from decimal import Decimal
from uuid import UUID

from django.db import transaction
from django.db.models import Count, DecimalField, ExpressionWrapper, F, Q, Sum
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from .booking_services import BookingConflict
from .models import Booking, BookingServicePlan, ServiceItem, ServiceUsage
from .permissions import BookingPermission
from .planned_services import add_plan, cancel_plan
from .selectors import booking_queryset
from .service_operations import add_service, cancel_service
from .service_serializers import (
    AddServiceSerializer,
    BookingServicePlanSerializer,
    CancelServiceSerializer,
    ServiceItemSerializer,
    ServiceUnitsSerializer,
    ServiceUsageSerializer,
    UsagePageSerializer,
)
from .services import application_transaction, normalize_id, record_audit
from .views import AuditedCatalogViewSet


class ServiceUnitsView(APIView):
    @extend_schema(responses=ServiceUnitsSerializer)
    def get(self, request):
        examples = {
            "chai": "Nước suối",
            "lon": "Nước ngọt",
            "ly": "Đồ uống pha",
            "bình": "Nước uống",
            "suất": "Ăn sáng",
            "kg": "Giặt ủi theo cân",
            "cái": "Giặt từng món",
            "bộ": "Giặt theo bộ",
            "lượt": "Đưa đón",
            "giờ": "Thuê theo giờ",
            "ngày": "Thuê theo ngày",
            "đêm": "Theo đêm",
            "gói": "Trọn gói",
        }
        return Response(
            {
                "units": [
                    {"value": value, "label": label, "example": examples[value]}
                    for value, label in ServiceItem.Unit.choices
                ]
            }
        )


class ServiceItemViewSet(AuditedCatalogViewSet):
    queryset = ServiceItem.objects.annotate(usage_count=Count("usages", distinct=True) + Count("booking_plans", filter=Q(booking_plans__usage__isnull=True), distinct=True)).order_by("name", "pk")
    serializer_class = ServiceItemSerializer
    search_fields = ["name", "unit", "description"]
    ordering_fields = ["name", "unit_price"]
    http_method_names = ["get", "post", "put", "patch", "delete", "head", "options"]

    def _check_name(self, name, exclude=None):
        if ServiceItem.objects.filter(name=name).exclude(pk=exclude).exists():
            raise ValidationError({"name": "Tên dịch vụ đã tồn tại."})

    def perform_create(self, serializer):
        try:
            with application_transaction("hotel:catalog"):
                self._check_name(serializer.validated_data["name"])
                record_audit(self.request.user, "create", serializer.save())
        except Exception:
            serializer.cleanup_uploads()
            raise

    def perform_update(self, serializer):
        try:
            with application_transaction("hotel:catalog"):
                serializer.instance = ServiceItem.objects.get(pk=serializer.instance.pk)
                if "name" in serializer.validated_data:
                    self._check_name(serializer.validated_data["name"], serializer.instance.pk)
                record_audit(self.request.user, "update", serializer.save())
        except Exception:
            serializer.cleanup_uploads()
            raise

    def perform_destroy(self, instance):
        with application_transaction("hotel:catalog"):
            item = ServiceItem.objects.get(pk=instance.pk)
            if item.usages.exists() or item.booking_plans.exists():
                raise BookingConflict("Dịch vụ đã có lịch sử sử dụng. Hãy ngừng bán để giữ dữ liệu cũ.")
            old = (item.image.storage, item.image.name) if item.image else None
            record_audit(self.request.user, "delete", item)
            item.delete()
            if old:
                storage, name = old
                transaction.on_commit(lambda: storage.delete(name), robust=True)

    @extend_schema(
        parameters=[OpenApiParameter("active", bool, description="Lọc dịch vụ đang bán/ngừng bán.")]
    )
    def list(self, request, *args, **kwargs):
        return super().list(request, *args, **kwargs)

    def get_queryset(self):
        queryset = super().get_queryset()
        active = self.request.query_params.get("active")
        if active is not None:
            if active not in {"true", "false"}:
                raise ValidationError({"active": "Chọn true hoặc false."})
            queryset = queryset.filter(is_active=active == "true")
        return queryset


class BookingServiceViewSet(mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    queryset = booking_queryset()
    serializer_class = UsagePageSerializer
    permission_classes = [BookingPermission]
    http_method_names = ["get", "post", "head", "options"]

    @extend_schema(responses=UsagePageSerializer)
    @action(detail=True, methods=["get"], url_path="services")
    def services(self, request, pk=None):
        with application_transaction(f"hotel:booking:{normalize_id(pk)}", "Shared"):
            return self._summary(request)

    def _summary(self, request):
        booking = self.get_object()
        planned = booking.status in {"confirmed", "cancelled"} and getattr(booking, "stay", None) is None
        usages = (BookingServicePlan.objects.filter(booking=booking) if planned else ServiceUsage.objects.filter(stay__booking=booking)).select_related(
            "created_by", "cancelled_by"
        )
        service_total = usages.filter(status="reserved" if planned else "active").aggregate(
            total=Sum(
                ExpressionWrapper(
                    F("unit_price") * F("quantity"),
                    output_field=DecimalField(max_digits=18, decimal_places=0),
                )
            )
        )["total"] or Decimal(0)
        page = self.paginate_queryset(usages)
        item_serializer = BookingServicePlanSerializer if planned else ServiceUsageSerializer
        response = self.get_paginated_response(item_serializer(page, many=True).data)
        stay = getattr(booking, "stay", None)
        response.data.update(
            {
                "room_total": str(booking.room_total),
                "service_total": str(service_total),
                "estimated_total": str(booking.room_total + service_total),
                "booking_status": booking.status,
                "blocked_reason": "Booking đang ở nhưng thiếu hồ sơ nhận phòng. Cần khôi phục hồ sơ lưu trú." if booking.status == "checked_in" and stay is None else "",
                "can_edit": request.user.role in {"admin", "receptionist"}
                and ((booking.status == Booking.Status.CONFIRMED and stay is None) or (booking.status == Booking.Status.CHECKED_IN
                and stay is not None and stay.checked_out_at is None)),
            }
        )
        return response

    @extend_schema(request=AddServiceSerializer, responses={200: BookingServicePlanSerializer, 201: BookingServicePlanSerializer},
        parameters=[OpenApiParameter("Idempotency-Key", str, location=OpenApiParameter.HEADER, required=True)])
    @action(detail=True, methods=["post"], url_path="planned-services")
    def plan(self, request, pk=None):
        data = AddServiceSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        try:
            key = UUID(request.headers.get("Idempotency-Key", ""))
        except (ValueError, AttributeError) as exc:
            raise ValidationError("Thiếu Idempotency-Key hợp lệ.") from exc
        plan, created = add_plan(request.user, pk, key, data.validated_data)
        return Response(BookingServicePlanSerializer(plan).data, status=201 if created else 200)

    @extend_schema(request=CancelServiceSerializer, responses=BookingServicePlanSerializer)
    @action(detail=True, methods=["post"], url_path=r"planned-services/(?P<plan_id>[^/.]+)/cancel")
    def cancel_plan(self, request, pk=None, plan_id=None):
        data = CancelServiceSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        return Response(BookingServicePlanSerializer(cancel_plan(request.user, pk, plan_id, data.validated_data["reason"])).data)

    @extend_schema(
        request=AddServiceSerializer,
        responses={200: ServiceUsageSerializer, 201: ServiceUsageSerializer},
        parameters=[
            OpenApiParameter(
                "Idempotency-Key", str, location=OpenApiParameter.HEADER, required=True
            )
        ],
    )
    @services.mapping.post
    def add(self, request, pk=None):
        serializer = AddServiceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            key = UUID(request.headers.get("Idempotency-Key", ""))
        except (ValueError, AttributeError) as exc:
            raise ValidationError("Thiếu Idempotency-Key hợp lệ.") from exc
        usage, created = add_service(request.user, pk, key, serializer.validated_data)
        return Response(
            ServiceUsageSerializer(usage).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    @extend_schema(request=CancelServiceSerializer, responses=ServiceUsageSerializer)
    @action(detail=True, methods=["post"], url_path=r"services/(?P<usage_id>[^/.]+)/cancel")
    def cancel(self, request, pk=None, usage_id=None):
        serializer = CancelServiceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        usage = cancel_service(request.user, pk, usage_id, serializer.validated_data["reason"])
        return Response(ServiceUsageSerializer(usage).data)
