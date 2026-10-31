from uuid import UUID

from django.utils.dateparse import parse_date
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from .booking_services import (
    cancel_booking,
    check_in,
    create_booking,
    extend_booking,
    reschedule_booking,
)
from .models import Booking
from .permissions import BookingPermission
from .selectors import booking_queryset
from .serializers import (
    BookingCreateSerializer,
    BookingSerializer,
    ExtendSerializer,
    RescheduleSerializer,
)


@extend_schema_view(list=extend_schema(parameters=[
    OpenApiParameter("room", int, description="Lịch đặt của một phòng."),
    OpenApiParameter("customer", int, description="Lịch đặt của một khách hàng."),
    OpenApiParameter("arrival_on", OpenApiTypes.DATE, description="Ngày nhận phòng chính xác."),
    OpenApiParameter("departure_on", OpenApiTypes.DATE, description="Ngày trả phòng chính xác."),
]))
class BookingViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    queryset = booking_queryset()
    serializer_class = BookingSerializer
    permission_classes = [BookingPermission]
    http_method_names = ["get", "post", "head", "options"]
    search_fields = ["code", "room__number", "customer__full_name"]
    ordering_fields = ["start_date", "created_at"]

    def get_queryset(self):
        queryset = booking_queryset()
        selected_status = self.request.query_params.get("status")
        selected_date = self.request.query_params.get("date")
        for parameter, field in (("room", "room_id"), ("customer", "customer_id")):
            value = self.request.query_params.get(parameter)
            if value is not None:
                try:
                    identifier = int(value)
                    if identifier < 1:
                        raise ValueError
                except (ValueError, TypeError) as exc:
                    raise ValidationError({parameter: "Mã phải là số nguyên dương."}) from exc
                queryset = queryset.filter(**{field: identifier})
        for parameter, field in (("arrival_on", "start_date"), ("departure_on", "end_date")):
            value = self.request.query_params.get(parameter)
            if value is not None:
                try:
                    day = parse_date(value)
                except ValueError as exc:
                    raise ValidationError({parameter: "Ngày không hợp lệ."}) from exc
                if day is None:
                    raise ValidationError({parameter: "Ngày không hợp lệ."})
                queryset = queryset.filter(**{field: day})
        if selected_status:
            if selected_status not in Booking.Status.values:
                raise ValidationError({"status": "Trạng thái không hợp lệ."})
            queryset = queryset.filter(status=selected_status)
        if selected_date:
            try:
                day = parse_date(selected_date)
            except ValueError as exc:
                raise ValidationError({"date": "Ngày không hợp lệ."}) from exc
            if day is None:
                raise ValidationError({"date": "Ngày không hợp lệ."})
            queryset = queryset.filter(start_date__lte=day, end_date__gt=day)
        return queryset

    @extend_schema(
        request=BookingCreateSerializer,
        responses={200: BookingSerializer, 201: BookingSerializer},
        parameters=[
            OpenApiParameter(
                "Idempotency-Key", str, location=OpenApiParameter.HEADER, required=True
            )
        ],
    )
    def create(self, request):
        serializer = BookingCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            key = UUID(request.headers.get("Idempotency-Key", ""))
        except (ValueError, AttributeError) as exc:
            raise ValidationError("Thiếu Idempotency-Key hợp lệ.") from exc
        booking, created = create_booking(request.user, key, serializer.validated_data)
        return Response(
            BookingSerializer(booking).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    @extend_schema(request=None, responses=BookingSerializer)
    @action(detail=True, methods=["post"])
    def cancel(self, request, pk=None):
        return Response(BookingSerializer(cancel_booking(request.user, pk)).data)

    @extend_schema(request=None, responses=BookingSerializer)
    @action(detail=True, methods=["post"], url_path="check-in")
    def check_in(self, request, pk=None):
        return Response(BookingSerializer(check_in(request.user, pk)).data)

    @extend_schema(request=RescheduleSerializer, responses=BookingSerializer)
    @action(detail=True, methods=["post"])
    def reschedule(self, request, pk=None):
        serializer = RescheduleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(
            BookingSerializer(reschedule_booking(request.user, pk, serializer.validated_data)).data
        )

    @extend_schema(request=ExtendSerializer, responses=BookingSerializer)
    @action(detail=True, methods=["post"])
    def extend(self, request, pk=None):
        serializer = ExtendSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(
            BookingSerializer(
                extend_booking(request.user, pk, serializer.validated_data["end_date"])
            ).data
        )
