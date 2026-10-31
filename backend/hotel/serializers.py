from django.contrib.auth import get_user_model
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer, TokenRefreshSerializer
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Booking, Customer, Room, RoomType
from .selectors import room_display_status


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


class RoomSerializer(serializers.ModelSerializer):
    room_type = RoomTypeSerializer(read_only=True)
    room_type_id = serializers.PrimaryKeyRelatedField(
        source="room_type", queryset=RoomType.objects.all(), write_only=True
    )
    condition_label = serializers.CharField(source="get_condition_display", read_only=True)
    display_status = serializers.SerializerMethodField()

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
            "is_active",
            "updated_at",
        ]
        read_only_fields = ["id", "updated_at"]


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


class BookingSerializer(serializers.ModelSerializer):
    room = RoomSerializer(read_only=True)
    customer = BookingCustomerSerializer(read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    nights = serializers.IntegerField(read_only=True)
    room_total = serializers.DecimalField(max_digits=15, decimal_places=0, read_only=True)
    checked_in_at = serializers.SerializerMethodField()

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
            "nights",
            "status",
            "status_label",
            "checked_in_at",
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
