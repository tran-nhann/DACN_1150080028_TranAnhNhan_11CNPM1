from django.db import transaction
from rest_framework import serializers

from .models import BookingServicePlan, ServiceItem, ServiceUsage


class ServiceItemSerializer(serializers.ModelSerializer):
    unit_valid = serializers.SerializerMethodField()
    category_label = serializers.CharField(source="get_category_display", read_only=True)
    image_url = serializers.SerializerMethodField()
    image = serializers.ImageField(write_only=True, required=False)
    remove_image = serializers.BooleanField(write_only=True, required=False, default=False)
    usage_count = serializers.SerializerMethodField()
    can_delete = serializers.SerializerMethodField()

    def get_image_url(self, obj) -> str | None:
        return obj.image.url if obj.image else None

    def get_usage_count(self, obj) -> int:
        count = getattr(obj, "usage_count", None)
        return count if count is not None else obj.usages.count() + obj.booking_plans.filter(usage__isnull=True).count()

    def get_can_delete(self, obj) -> bool:
        return self.get_usage_count(obj) == 0

    def validate_image(self, image):
        extensions = {"JPEG": "jpg", "PNG": "png", "WEBP": "webp"}
        if image.size > 5 * 1024 * 1024:
            raise serializers.ValidationError("Ảnh tối đa 5 MB.")
        if image.image.format not in extensions or image.image.width * image.image.height > 25_000_000:
            raise serializers.ValidationError("Chọn ảnh JPG/PNG/WebP, tối đa 25 triệu điểm ảnh.")
        image.name = "service." + extensions[image.image.format]
        return image

    def validate(self, attrs):
        if attrs.get("image") and attrs.get("remove_image"):
            raise serializers.ValidationError({"image": "Chọn ảnh mới hoặc xóa ảnh cũ."})
        return attrs

    def cleanup_uploads(self):
        for storage, name in getattr(self, "_new_files", []):
            storage.delete(name)

    def _save_item(self, instance, data):
        image = data.pop("image", None)
        remove = data.pop("remove_image", False)
        old = (instance.image.storage, instance.image.name) if instance and instance.image else None
        self._new_files = []
        item = super().update(instance, data) if instance else super().create(data)
        if image:
            item.image.save(image.name, image, save=False)
            self._new_files.append((item.image.storage, item.image.name))
        elif remove:
            item.image = ""
        if image or remove:
            item.save(update_fields=["image", "updated_at"])
            if old:
                storage, name = old
                transaction.on_commit(lambda: storage.delete(name), robust=True)
        return item

    def create(self, validated_data):
        return self._save_item(None, validated_data)

    def update(self, instance, validated_data):
        return self._save_item(instance, validated_data)

    def get_unit_valid(self, obj) -> bool:
        return obj.unit in ServiceItem.Unit.values

    class Meta:
        model = ServiceItem
        fields = ["id", "name", "category", "category_label", "description", "notes", "image", "image_url", "remove_image", "unit", "unit_valid", "unit_price", "is_active", "usage_count", "can_delete", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class ServiceUnitSerializer(serializers.Serializer):
    value = serializers.CharField()
    label = serializers.CharField()
    example = serializers.CharField()


class ServiceUnitsSerializer(serializers.Serializer):
    units = ServiceUnitSerializer(many=True)


class ServiceUsageSerializer(serializers.ModelSerializer):
    status = serializers.CharField(read_only=True, help_text="active/cancelled cho phát sinh; reserved/posted/cancelled cho đặt kèm.")
    planned = serializers.BooleanField(read_only=True, default=False)
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
            "planned",
        ]
        read_only_fields = fields


class BookingServicePlanSerializer(ServiceUsageSerializer):
    planned = serializers.BooleanField(read_only=True, default=True)

    class Meta(ServiceUsageSerializer.Meta):
        model = BookingServicePlan


class AddServiceSerializer(serializers.Serializer):
    service_id = serializers.IntegerField(min_value=1, max_value=9223372036854775807)
    quantity = serializers.IntegerField(min_value=1, max_value=999)
    expected_unit_price = serializers.DecimalField(max_digits=12, decimal_places=0, min_value=0)


class CancelServiceSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=200, allow_blank=False, trim_whitespace=True)


class UsagePageSerializer(serializers.Serializer):
    blocked_reason = serializers.CharField()
    booking_status = serializers.CharField()
    count = serializers.IntegerField()
    next = serializers.URLField(allow_null=True)
    previous = serializers.URLField(allow_null=True)
    results = ServiceUsageSerializer(many=True)
    room_total = serializers.DecimalField(max_digits=15, decimal_places=0)
    service_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    estimated_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    can_edit = serializers.BooleanField()
