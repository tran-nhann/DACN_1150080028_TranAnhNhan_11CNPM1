from datetime import datetime, time
from uuid import UUID

from django.utils import timezone
from django.utils.dateparse import parse_date
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from .billing_serializers import (
    CheckoutResponseSerializer,
    CheckoutSerializer,
    FolioResponseSerializer,
    InvoiceSerializer,
)
from .billing_services import checkout, folio_for, invoice_queryset
from .booking_services import get_booking
from .permissions import BookingPermission
from .selectors import booking_queryset
from .serializers import BookingSerializer
from .services import application_transaction, normalize_id


class BookingBillingViewSet(viewsets.GenericViewSet):
    permission_classes = [BookingPermission]
    serializer_class = FolioResponseSerializer
    http_method_names = ["get", "post", "head", "options"]

    @extend_schema(responses=FolioResponseSerializer)
    @action(detail=True, methods=["get"])
    def folio(self, request, pk=None):
        with application_transaction(f"hotel:booking:{normalize_id(pk)}", "Shared"):
            booking = get_booking(pk)
            invoice = invoice_queryset().filter(stay__booking=booking).first()
            if invoice:
                return Response({"state": "closed", "folio": None, "invoice": InvoiceSerializer(invoice).data})
            return Response({"state": "open", "folio": folio_for(booking), "invoice": None})

    @extend_schema(
        request=CheckoutSerializer, responses={200: CheckoutResponseSerializer, 201: CheckoutResponseSerializer},
        parameters=[OpenApiParameter("Idempotency-Key", str, location=OpenApiParameter.HEADER, required=True)],
    )
    @action(detail=True, methods=["post"], url_path="check-out")
    def check_out(self, request, pk=None):
        serializer = CheckoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            key = UUID(request.headers.get("Idempotency-Key", ""))
        except (ValueError, AttributeError) as exc:
            raise ValidationError("Thiếu Idempotency-Key hợp lệ.") from exc
        invoice, created = checkout(request.user, pk, key, serializer.validated_data)
        booking = booking_queryset().get(pk=invoice.stay.booking_id)
        return Response({"invoice": InvoiceSerializer(invoice).data, "booking": BookingSerializer(booking).data}, status=201 if created else 200)


@extend_schema_view(list=extend_schema(parameters=[
    OpenApiParameter("method", str, enum=["cash", "bank_transfer"]),
    OpenApiParameter("start_date", str, description="Ngày thu tiền từ, gồm ngày này."),
    OpenApiParameter("end_date", str, description="Ngày thu tiền đến, không gồm ngày này."),
]))
class InvoiceViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = invoice_queryset()
    serializer_class = InvoiceSerializer
    permission_classes = [BookingPermission]
    http_method_names = ["get", "head", "options"]
    search_fields = ["code", "booking_code", "guest_name", "guest_phone", "room_number", "payment__code", "payment__reference"]
    ordering_fields = ["issued_at", "total"]

    def get_queryset(self):
        queryset = super().get_queryset()
        method = self.request.query_params.get("method")
        if method is not None:
            if method not in {"cash", "bank_transfer"}:
                raise ValidationError({"method": "Chọn tiền mặt hoặc chuyển khoản."})
            queryset = queryset.filter(payment__method=method)
        for parameter, lookup in [("start_date", "payment__received_at__gte"), ("end_date", "payment__received_at__lt")]:
            value = self.request.query_params.get(parameter)
            if value is not None:
                try:
                    day = parse_date(value)
                except ValueError as exc:
                    raise ValidationError({parameter: "Ngày không hợp lệ."}) from exc
                if day is None:
                    raise ValidationError({parameter: "Ngày không hợp lệ."})
                queryset = queryset.filter(**{lookup: timezone.make_aware(datetime.combine(day, time.min))})
        return queryset
