from rest_framework import serializers

from .models import ServiceItem, ServiceUsage


class ServiceItemSerializer(serializers.ModelSerializer):
    unit_valid = serializers.SerializerMethodField()

    def get_unit_valid(self, obj) -> bool:
        return obj.unit in ServiceItem.Unit.values

    class Meta:
        model = ServiceItem
        fields = ["id", "name", "unit", "unit_valid", "unit_price", "is_active", "updated_at"]
        read_only_fields = ["id", "updated_at"]


class ServiceUnitSerializer(serializers.Serializer):
    value = serializers.CharField()
    label = serializers.CharField()
    example = serializers.CharField()


class ServiceUnitsSerializer(serializers.Serializer):
    units = ServiceUnitSerializer(many=True)


class ServiceUsageSerializer(serializers.ModelSerializer):
    service_id = serializers.IntegerField(read_only=True)
    total = serializers.DecimalField(max_digits=15, decimal_places=0, read_only=True)
    created_by = serializers.CharField(source="created_by.display_name", read_only=True)
    cancelled_by = serializers.CharField(
        source="cancelled_by.display_name", read_only=True, allow_null=True
    )

    class Meta:
        model = ServiceUsage
        fields = [
            "id",
            "service_id",
            "name",
            "unit",
            "unit_price",
            "quantity",
            "total",
            "status",
            "created_at",
            "created_by",
            "cancelled_at",
            "cancelled_by",
            "cancel_reason",
        ]
        read_only_fields = fields


class AddServiceSerializer(serializers.Serializer):
    service_id = serializers.IntegerField(min_value=1, max_value=9223372036854775807)
    quantity = serializers.IntegerField(min_value=1, max_value=999)
    expected_unit_price = serializers.DecimalField(max_digits=12, decimal_places=0, min_value=0)


class CancelServiceSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=200, allow_blank=False, trim_whitespace=True)


class UsagePageSerializer(serializers.Serializer):
    count = serializers.IntegerField()
    next = serializers.URLField(allow_null=True)
    previous = serializers.URLField(allow_null=True)
    results = ServiceUsageSerializer(many=True)
    room_total = serializers.DecimalField(max_digits=15, decimal_places=0)
    service_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    estimated_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    can_edit = serializers.BooleanField()
