from decimal import Decimal
from uuid import UUID

from django.db.models import DecimalField, ExpressionWrapper, F, Sum
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Booking, ServiceItem, ServiceUsage
from .permissions import BookingPermission
from .selectors import booking_queryset
from .service_operations import add_service, cancel_service
from .service_serializers import (
    AddServiceSerializer,
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
    queryset = ServiceItem.objects.all()
    serializer_class = ServiceItemSerializer
    search_fields = ["name", "unit"]
    ordering_fields = ["name", "unit_price"]

    def _check_name(self, name, exclude=None):
        if ServiceItem.objects.filter(name=name).exclude(pk=exclude).exists():
            raise ValidationError({"name": "Tên dịch vụ đã tồn tại."})

    def perform_create(self, serializer):
        with application_transaction("hotel:catalog"):
            self._check_name(serializer.validated_data["name"])
            record_audit(self.request.user, "create", serializer.save())

    def perform_update(self, serializer):
        with application_transaction("hotel:catalog"):
            serializer.instance = ServiceItem.objects.get(pk=serializer.instance.pk)
            if "name" in serializer.validated_data:
                self._check_name(serializer.validated_data["name"], serializer.instance.pk)
            record_audit(self.request.user, "update", serializer.save())

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
        usages = ServiceUsage.objects.filter(stay__booking=booking).select_related(
            "created_by", "cancelled_by"
        )
        service_total = usages.filter(status="active").aggregate(
            total=Sum(
                ExpressionWrapper(
                    F("unit_price") * F("quantity"),
                    output_field=DecimalField(max_digits=18, decimal_places=0),
                )
            )
        )["total"] or Decimal(0)
        page = self.paginate_queryset(usages)
        response = self.get_paginated_response(ServiceUsageSerializer(page, many=True).data)
        stay = getattr(booking, "stay", None)
        response.data.update(
            {
                "room_total": str(booking.room_total),
                "service_total": str(service_total),
                "estimated_total": str(booking.room_total + service_total),
                "can_edit": request.user.role in {"admin", "receptionist"}
                and booking.status == Booking.Status.CHECKED_IN
                and stay is not None
                and stay.checked_out_at is None,
            }
        )
        return response

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
