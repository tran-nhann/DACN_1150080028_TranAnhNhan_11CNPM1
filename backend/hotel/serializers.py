import json

from django.contrib.auth import get_user_model
from django.db import transaction
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer, TokenRefreshSerializer
from rest_framework_simplejwt.tokens import RefreshToken

from .models import AuditLog, Booking, Customer, Room, RoomImage, RoomMove, RoomType
from .selectors import room_display_status
from .service_serializers import AddServiceSerializer


class UserSerializer(serializers.ModelSerializer):
    role_label = serializers.CharField(source="get_role_display", read_only=True)

    class Meta:
        model = get_user_model()
        fields = ["id", "username", "display_name", "role", "role_label"]
        read_only_fields = fields


class LoginResponseSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()
    user = UserSerializer()


class RefreshResponseSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()


class LoginSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        data = super().validate(attrs)
        data["user"] = UserSerializer(self.user).data
        return data


class ActiveUserRefreshSerializer(TokenRefreshSerializer):
    def validate(self, attrs):
        token = RefreshToken(attrs["refresh"])
        user_id = token.get("user_id")
        if not get_user_model().objects.filter(id=user_id, is_active=True).exists():
            raise serializers.ValidationError("Tài khoản đã bị khóa.")
        return super().validate(attrs)


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()


class RoomTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = RoomType
        fields = ["id", "name", "description", "capacity", "base_rate"]


class RoomImageSerializer(serializers.ModelSerializer):
    url = serializers.CharField(source="image.url", read_only=True)

    class Meta:
        model = RoomImage
        fields = ["id", "url", "position"]


class RoomSerializer(serializers.ModelSerializer):
    room_type = RoomTypeSerializer(read_only=True)
    room_type_id = serializers.PrimaryKeyRelatedField(
        source="room_type", queryset=RoomType.objects.all(), write_only=True
    )
    condition_label = serializers.CharField(source="get_condition_display", read_only=True)
    display_status = serializers.SerializerMethodField()
    images = RoomImageSerializer(many=True, read_only=True)
    amenities = serializers.ListField(
        child=serializers.CharField(max_length=50, allow_blank=False),
        max_length=30, required=False,
    )
    image_ids = serializers.ListField(
        child=serializers.IntegerField(min_value=1), max_length=10,
        write_only=True, required=False,
    )
    upload_images = serializers.ListField(
        child=serializers.ImageField(), max_length=10, write_only=True, required=False,
    )
    cover_upload_index = serializers.IntegerField(min_value=0, write_only=True, required=False, allow_null=True)

    def to_internal_value(self, data):
        # Multipart carries the same JSON contract plus repeated binary files.
        if hasattr(data, "getlist") and "data" in data:
            try:
                payload = json.loads(data["data"])
            except (ValueError, TypeError) as exc:
                raise serializers.ValidationError({"data": "Dữ liệu phòng không hợp lệ."}) from exc
            if not isinstance(payload, dict):
                raise serializers.ValidationError({"data": "Dữ liệu phòng phải là một object."})
            payload["upload_images"] = data.getlist("upload_images")
            data = payload
        return super().to_internal_value(data)

    def validate_upload_images(self, images):
        extensions = {"JPEG": "jpg", "PNG": "png", "WEBP": "webp"}
        for image in images:
            if image.size > 5 * 1024 * 1024:
                raise serializers.ValidationError("Mỗi ảnh tối đa 5 MB.")
            image_format = image.image.format
            if image_format not in extensions:
                raise serializers.ValidationError("Chỉ nhận ảnh JPG, PNG hoặc WebP.")
            if image.image.width * image.image.height > 25_000_000:
                raise serializers.ValidationError("Ảnh tối đa 25 triệu điểm ảnh.")
            image.name = "photo." + extensions[image_format]
        return images

    def validate_amenities(self, values):
        return list(dict.fromkeys(values))

    def validate(self, attrs):
        existing = list(self.instance.images.all()) if self.instance else []
        ids = attrs.get("image_ids", [image.pk for image in existing])
        if len(ids) != len(set(ids)) or not set(ids).issubset({image.pk for image in existing}):
            raise serializers.ValidationError({"image_ids": "Ảnh không thuộc phòng hoặc bị lặp."})
        if len(ids) + len(attrs.get("upload_images", [])) > 10:
            raise serializers.ValidationError({"upload_images": "Mỗi phòng tối đa 10 ảnh."})
        cover = attrs.get("cover_upload_index")
        if cover is not None and cover >= len(attrs.get("upload_images", [])):
            raise serializers.ValidationError({"cover_upload_index": "Ảnh bìa không hợp lệ."})
        return attrs

    def cleanup_uploads(self):
        for image in getattr(self, "_created_images", []):
            image.delete(save=False)

    def _save_room(self, instance, validated_data):
        uploads = validated_data.pop("upload_images", [])
        image_ids = validated_data.pop("image_ids", None)
        cover = validated_data.pop("cover_upload_index", None)
        existing = {image.pk: image for image in instance.images.all()} if instance else {}
        ids = list(existing) if image_ids is None else image_ids
        # Recheck after the view acquires the catalog and room locks.
        if not set(ids).issubset(existing) or len(ids) + len(uploads) > 10:
            raise serializers.ValidationError({"image_ids": "Ảnh phòng đã thay đổi. Mở lại phòng rồi thử lại."})
        room = super().update(instance, validated_data) if instance else super().create(validated_data)
        self._created_images = []
        for position, image_id in enumerate(ids):
            image = existing[image_id]
            image.position = position
            image.save(update_fields=["position"])
        for image_id in set(existing) - set(ids):
            image = existing[image_id]
            file = image.image
            image.delete()
            transaction.on_commit(lambda file=file: file.delete(save=False), robust=True)
        for position, upload in enumerate(uploads, start=len(ids)):
            image = RoomImage(room=room, position=position)
            image.image.save(upload.name, upload, save=False)
            self._created_images.append(image.image)
            image.save()
        if cover is not None:
            ordered = list(room.images.all())
            ordered.insert(0, ordered.pop(len(ids) + cover))
            for position, image in enumerate(ordered):
                image.position = position
                image.save(update_fields=["position"])
        room._prefetched_objects_cache = {}
        return room

    def create(self, validated_data):
        return self._save_room(None, validated_data)

    def update(self, instance, validated_data):
        return self._save_room(instance, validated_data)

    def get_display_status(self, obj) -> str:
        return room_display_status(obj)

    class Meta:
        model = Room
        fields = [
            "id",
            "number",
            "floor",
            "room_type",
            "room_type_id",
            "condition",
            "condition_label",
            "display_status",
            "notes",
            "description",
            "area",
            "bed_type",
            "bed_count",
            "view",
            "amenities",
            "images",
            "image_ids",
            "upload_images",
            "cover_upload_index",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


class RoomConditionSerializer(serializers.Serializer):
    condition = serializers.ChoiceField(choices=Room.Condition.choices)


class CustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = ["id", "full_name", "phone", "email", "notes", "created_at"]
        read_only_fields = ["id", "created_at"]


class BookingCustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = ["id", "full_name"]


class RoomSegmentSerializer(serializers.Serializer):
    room_id = serializers.IntegerField()
    room_number = serializers.CharField()
    room_type = serializers.CharField()
    start_date = serializers.DateField()
    end_date = serializers.DateField()
    nightly_rate = serializers.DecimalField(max_digits=12, decimal_places=0)
    nights = serializers.IntegerField()
    total = serializers.DecimalField(max_digits=18, decimal_places=0)


class RoomMoveHistorySerializer(serializers.ModelSerializer):
    created_by = serializers.CharField(source="created_by.display_name", read_only=True)

    class Meta:
        model = RoomMove
        fields = ["id", "from_room_id", "to_room_id", "from_number", "to_number", "from_type_name", "to_type_name",
            "old_rate", "new_rate", "effective_date", "price_mode", "old_room_condition", "reason", "created_at", "created_by"]
        read_only_fields = fields


class BookingSerializer(serializers.ModelSerializer):
    room_moves = RoomMoveHistorySerializer(many=True, read_only=True)
    room_segments = serializers.SerializerMethodField()

    @extend_schema_field(RoomSegmentSerializer(many=True))
    def get_room_segments(self, obj):
        from .room_charges import room_segments
        return RoomSegmentSerializer(room_segments(obj), many=True).data

    check_in_record_recovered = serializers.SerializerMethodField()

    def get_check_in_record_recovered(self, obj) -> bool:
        stay = getattr(obj, "stay", None)
        return bool(stay and AuditLog.objects.filter(entity="stay", entity_id=str(stay.pk), action="stay_recovered_now").exists())
    planned_service_total = serializers.SerializerMethodField()
    service_total = serializers.SerializerMethodField()
    estimated_total = serializers.SerializerMethodField()

    def _charges(self, obj):
        if not hasattr(obj, "_charge_totals"):
            planned = sum((row.total for row in obj.service_plans.all() if row.status == "reserved"), 0)
            stay = getattr(obj, "stay", None)
            used = sum((row.total for row in stay.service_usages.all() if row.status == "active"), 0) if stay else 0
            obj._charge_totals = planned, used
        return obj._charge_totals

    def get_planned_service_total(self, obj) -> str:
        return str(self._charges(obj)[0])

    def get_service_total(self, obj) -> str:
        return str(self._charges(obj)[1])

    def get_estimated_total(self, obj) -> str:
        return str(obj.room_total + sum(self._charges(obj)))
    room = RoomSerializer(read_only=True)
    customer = BookingCustomerSerializer(read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    nights = serializers.IntegerField(read_only=True)
    room_total = serializers.DecimalField(max_digits=15, decimal_places=0, read_only=True)
    checked_in_at = serializers.SerializerMethodField()
    checked_out_at = serializers.DateTimeField(source="stay.checked_out_at", read_only=True, allow_null=True)

    @extend_schema_field(serializers.DateTimeField(allow_null=True))
    def get_checked_in_at(self, obj):
        stay = getattr(obj, "stay", None)
        return serializers.DateTimeField().to_representation(stay.checked_in_at) if stay else None

    class Meta:
        model = Booking
        fields = [
            "id",
            "code",
            "room",
            "customer",
            "start_date",
            "end_date",
            "guests",
            "nightly_rate",
            "room_total",
            "planned_service_total", "service_total", "estimated_total",
            "nights",
            "status",
            "status_label",
            "checked_in_at",
            "check_in_record_recovered",
            "checked_out_at",
            "room_segments", "room_moves",
            "created_at",
        ]
        read_only_fields = fields


class IntervalSerializer(serializers.Serializer):
    start_date = serializers.DateField()
    end_date = serializers.DateField()

    def validate(self, attrs):
        if attrs["end_date"] <= attrs["start_date"]:
            raise serializers.ValidationError("Ngày trả phải sau ngày nhận.")
        if (attrs["end_date"] - attrs["start_date"]).days > 90:
            raise serializers.ValidationError("Tối đa 90 đêm mỗi lượt đặt.")
        return attrs


class AvailabilitySerializer(IntervalSerializer):
    guests = serializers.IntegerField(min_value=1, max_value=20, default=1)
    exclude_booking = serializers.IntegerField(min_value=1, required=False)


class BookingCreateSerializer(IntervalSerializer):
    services = AddServiceSerializer(many=True, required=False, default=list, max_length=50)

    def validate_services(self, value):
        ids = [row["service_id"] for row in value]
        if len(ids) != len(set(ids)):
            raise serializers.ValidationError("Mỗi dịch vụ chỉ chọn một dòng; điều chỉnh số lượng trên dòng đó.")
        return value

    room_id = serializers.PrimaryKeyRelatedField(queryset=Room.objects.filter(is_active=True))
    customer_id = serializers.PrimaryKeyRelatedField(queryset=Customer.objects.all())
    guests = serializers.IntegerField(min_value=1, max_value=20)
    expected_nightly_rate = serializers.DecimalField(
        max_digits=12, decimal_places=0, min_value=0, required=False
    )


class RescheduleSerializer(IntervalSerializer):
    room_id = serializers.PrimaryKeyRelatedField(
        queryset=Room.objects.filter(is_active=True), required=False
    )
    expected_nightly_rate = serializers.DecimalField(
        max_digits=12, decimal_places=0, min_value=0, required=False
    )


class ExtendSerializer(serializers.Serializer):
    end_date = serializers.DateField()
