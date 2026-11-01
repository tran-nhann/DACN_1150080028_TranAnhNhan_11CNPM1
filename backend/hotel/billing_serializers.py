from rest_framework import serializers

from .models import Invoice, InvoiceLine, Payment
from .serializers import BookingSerializer


class CheckoutSerializer(serializers.Serializer):
    quote_token = serializers.RegexField(r"^[a-f0-9]{64}$")
    expected_total = serializers.DecimalField(max_digits=18, decimal_places=0, min_value=0)
    method = serializers.ChoiceField(choices=Payment.Method.choices)
    payment_received = serializers.BooleanField()
    reference = serializers.CharField(max_length=100, allow_blank=True, required=False, default="")
    notes = serializers.CharField(max_length=300, allow_blank=True, required=False, default="")

    def validate_payment_received(self, value):
        if not value:
            raise serializers.ValidationError("Xác nhận đã nhận đủ tiền trước khi chốt hóa đơn.")
        return value


class CleanRoomSerializer(serializers.Serializer):
    expected_updated_at = serializers.DateTimeField()


class InvoiceLineSerializer(serializers.ModelSerializer):
    class Meta:
        model = InvoiceLine
        fields = ["id", "position", "kind", "source_usage_id", "name", "unit", "quantity", "unit_price", "total"]
        read_only_fields = fields


class PaymentSerializer(serializers.ModelSerializer):
    method_label = serializers.CharField(source="get_method_display", read_only=True)
    received_by = serializers.CharField(source="received_by.display_name", read_only=True)

    class Meta:
        model = Payment
        fields = ["id", "code", "amount", "method", "method_label", "reference", "notes", "received_at", "received_by"]
        read_only_fields = fields


class InvoiceSerializer(serializers.ModelSerializer):
    booking_id = serializers.IntegerField(source="stay.booking_id", read_only=True)
    issued_by = serializers.CharField(source="issued_by.display_name", read_only=True)
    payment = PaymentSerializer(read_only=True)
    lines = InvoiceLineSerializer(many=True, read_only=True)
    checked_out_at = serializers.DateTimeField(source="stay.checked_out_at", read_only=True)

    class Meta:
        model = Invoice
        fields = [
            "id", "code", "booking_id", "booking_code", "guest_name", "guest_phone", "room_number", "room_type",
            "start_date", "end_date", "room_total", "service_total", "total", "issued_at", "issued_by",
            "checked_out_at", "lines", "payment",
        ]
        read_only_fields = fields


class FolioLineSerializer(serializers.Serializer):
    kind = serializers.CharField()
    source_usage_id = serializers.IntegerField(allow_null=True)
    name = serializers.CharField()
    unit = serializers.CharField()
    quantity = serializers.IntegerField()
    unit_price = serializers.DecimalField(max_digits=12, decimal_places=0)
    total = serializers.DecimalField(max_digits=18, decimal_places=0)


class FolioSerializer(serializers.Serializer):
    booking_id = serializers.IntegerField()
    booking_code = serializers.CharField()
    guest_name = serializers.CharField()
    guest_phone = serializers.CharField()
    room_number = serializers.CharField()
    room_type = serializers.CharField()
    start_date = serializers.DateField()
    end_date = serializers.DateField()
    nights = serializers.IntegerField()
    room_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    service_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    total = serializers.DecimalField(max_digits=18, decimal_places=0)
    currency = serializers.CharField()
    can_checkout = serializers.BooleanField()
    blocked_reason = serializers.CharField()
    billing_policy = serializers.CharField()
    quote_token = serializers.CharField()
    lines = FolioLineSerializer(many=True)


class FolioResponseSerializer(serializers.Serializer):
    state = serializers.ChoiceField(choices=["open", "closed"])
    folio = FolioSerializer(allow_null=True)
    invoice = InvoiceSerializer(allow_null=True)


class CheckoutResponseSerializer(serializers.Serializer):
    invoice = InvoiceSerializer()
    booking = BookingSerializer()
