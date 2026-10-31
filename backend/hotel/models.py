import uuid

from django.contrib.auth.models import AbstractUser, UserManager
from django.core.validators import MaxValueValidator, MinValueValidator, RegexValidator
from django.db import models


class StaffUserManager(UserManager):
    def create_superuser(self, username, email=None, password=None, **extra_fields):
        extra_fields["role"] = "admin"
        extra_fields.setdefault("display_name", username)
        return super().create_superuser(username, email, password, **extra_fields)


class User(AbstractUser):
    class Role(models.TextChoices):
        ADMIN = "admin", "Quản trị viên"
        RECEPTIONIST = "receptionist", "Lễ tân"
        MANAGER = "manager", "Quản lý"

    role = models.CharField(max_length=20, choices=Role.choices, default=Role.RECEPTIONIST)
    display_name = models.CharField(max_length=100)
    objects = StaffUserManager()
    REQUIRED_FIELDS = ["display_name"]

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=models.Q(role__in=["admin", "receptionist", "manager"]),
                name="staff_role_valid",
            )
        ]


class TimestampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class RoomType(TimestampedModel):
    name = models.CharField(max_length=80, unique=True)
    description = models.CharField(max_length=300, blank=True)
    capacity = models.PositiveSmallIntegerField(validators=[MinValueValidator(1)])
    base_rate = models.DecimalField(
        max_digits=12, decimal_places=0, validators=[MinValueValidator(0)]
    )

    class Meta:
        ordering = ["base_rate", "id"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(capacity__gt=0), name="room_type_capacity_positive"
            ),
            models.CheckConstraint(
                condition=models.Q(base_rate__gte=0), name="room_type_rate_nonnegative"
            ),
        ]

    def __str__(self):
        return self.name


class Room(TimestampedModel):
    class Condition(models.TextChoices):
        READY = "ready", "Sẵn sàng"
        CLEANING = "cleaning", "Cần dọn"
        MAINTENANCE = "maintenance", "Bảo trì"

    number = models.CharField(
        max_length=10, unique=True, validators=[RegexValidator(r"^[A-Za-z0-9-]+$")]
    )
    floor = models.PositiveSmallIntegerField(validators=[MinValueValidator(1)])
    room_type = models.ForeignKey(RoomType, on_delete=models.PROTECT, related_name="rooms")
    condition = models.CharField(max_length=20, choices=Condition.choices, default=Condition.READY)
    notes = models.CharField(max_length=300, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["floor", "number"]
        indexes = [
            models.Index(fields=["is_active", "condition", "floor"], name="room_status_floor_idx")
        ]
        constraints = [
            models.CheckConstraint(condition=models.Q(floor__gt=0), name="room_floor_positive"),
            models.CheckConstraint(
                condition=models.Q(condition__in=["ready", "cleaning", "maintenance"]),
                name="room_condition_valid",
            ),
        ]

    def __str__(self):
        return self.number


class Customer(TimestampedModel):
    full_name = models.CharField(max_length=100)
    phone = models.CharField(max_length=20, validators=[RegexValidator(r"^\+?[0-9]{9,15}$")])
    email = models.EmailField(blank=True)
    notes = models.CharField(max_length=300, blank=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        indexes = [models.Index(fields=["phone"], name="customer_phone_idx")]

    def __str__(self):
        return self.full_name


def new_booking_code():
    return "BK-" + uuid.uuid4().hex[:12].upper()


class Booking(TimestampedModel):
    class Status(models.TextChoices):
        CONFIRMED = "confirmed", "Đã đặt"
        CHECKED_IN = "checked_in", "Đang ở"
        CHECKED_OUT = "checked_out", "Đã trả"
        CANCELLED = "cancelled", "Đã hủy"

    code = models.CharField(max_length=20, unique=True, default=new_booking_code, editable=False)
    room = models.ForeignKey(Room, on_delete=models.PROTECT, related_name="bookings")
    customer = models.ForeignKey(Customer, on_delete=models.PROTECT, related_name="bookings")
    start_date = models.DateField()
    end_date = models.DateField()
    guests = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(20)]
    )
    nightly_rate = models.DecimalField(
        max_digits=12, decimal_places=0, validators=[MinValueValidator(0)]
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.CONFIRMED)
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="created_bookings")
    request_key = models.UUIDField(default=uuid.uuid4, editable=False)
    request_fingerprint = models.CharField(max_length=64, editable=False)

    class Meta:
        ordering = ["-created_at", "-id"]
        indexes = [
            models.Index(
                fields=["room", "status", "start_date", "end_date"], name="booking_room_dates_idx"
            ),
            models.Index(fields=["status", "start_date"], name="booking_arrival_idx"),
        ]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(end_date__gt=models.F("start_date")), name="booking_dates_valid"
            ),
            models.CheckConstraint(
                condition=models.Q(guests__gte=1, guests__lte=20), name="booking_guests_valid"
            ),
            models.CheckConstraint(
                condition=models.Q(nightly_rate__gte=0), name="booking_rate_nonnegative"
            ),
            models.CheckConstraint(
                condition=models.Q(
                    status__in=["confirmed", "checked_in", "checked_out", "cancelled"]
                ),
                name="booking_status_valid",
            ),
            models.UniqueConstraint(
                fields=["created_by", "request_key"], name="booking_request_once"
            ),
        ]

    @property
    def nights(self):
        return (self.end_date - self.start_date).days

    @property
    def room_total(self):
        return self.nightly_rate * self.nights


class Stay(models.Model):
    booking = models.OneToOneField(Booking, on_delete=models.PROTECT, related_name="stay")
    checked_in_at = models.DateTimeField()
    checked_in_by = models.ForeignKey(User, on_delete=models.PROTECT)
    checked_out_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=models.Q(checked_out_at__isnull=True)
                | models.Q(checked_out_at__gte=models.F("checked_in_at")),
                name="stay_times_valid",
            )
        ]


class ServiceItem(TimestampedModel):
    class Unit(models.TextChoices):
        BOTTLE = "chai", "Chai"
        CAN = "lon", "Lon"
        GLASS = "ly", "Ly"
        JUG = "bình", "Bình"
        SERVING = "suất", "Suất"
        KILOGRAM = "kg", "kg"
        ITEM = "cái", "Cái"
        SET = "bộ", "Bộ"
        TRIP = "lượt", "Lượt"
        HOUR = "giờ", "Giờ"
        DAY = "ngày", "Ngày"
        NIGHT = "đêm", "Đêm"
        PACKAGE = "gói", "Gói"

    name = models.CharField(max_length=100, unique=True)
    unit = models.CharField(max_length=30, choices=Unit.choices)
    unit_price = models.DecimalField(max_digits=12, decimal_places=0, validators=[MinValueValidator(0)])
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["name", "id"]
        constraints = [models.CheckConstraint(condition=models.Q(unit_price__gte=0), name="service_price_nonnegative")]


class ServiceUsage(models.Model):
    class Status(models.TextChoices):
        ACTIVE = "active", "Đã ghi"
        CANCELLED = "cancelled", "Đã hủy"

    stay = models.ForeignKey(Stay, on_delete=models.PROTECT, related_name="service_usages")
    service = models.ForeignKey(ServiceItem, on_delete=models.PROTECT, related_name="usages")
    name = models.CharField(max_length=100)
    unit = models.CharField(max_length=30)
    unit_price = models.DecimalField(max_digits=12, decimal_places=0)
    quantity = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(999)])
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="recorded_services")
    request_key = models.UUIDField(editable=False)
    request_fingerprint = models.CharField(max_length=64, editable=False)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    cancelled_by = models.ForeignKey(User, on_delete=models.PROTECT, null=True, blank=True, related_name="cancelled_services")
    cancel_reason = models.CharField(max_length=200, blank=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        indexes = [models.Index(fields=["stay", "status"], name="usage_stay_status_idx")]
        constraints = [
            models.UniqueConstraint(fields=["created_by", "request_key"], name="usage_request_once"),
            models.CheckConstraint(condition=models.Q(quantity__gte=1, quantity__lte=999), name="usage_quantity_valid"),
            models.CheckConstraint(condition=models.Q(unit_price__gte=0), name="usage_price_nonnegative"),
            models.CheckConstraint(condition=(
                models.Q(status="active", cancelled_at__isnull=True, cancelled_by__isnull=True, cancel_reason="")
                | (models.Q(status="cancelled", cancelled_at__isnull=False, cancelled_by__isnull=False) & ~models.Q(cancel_reason=""))
            ), name="usage_cancellation_valid"),
            models.CheckConstraint(condition=models.Q(cancelled_at__isnull=True) | models.Q(cancelled_at__gte=models.F("created_at")), name="usage_cancel_time_valid"),
        ]

    @property
    def total(self):
        return self.unit_price * self.quantity


class AuditLog(models.Model):
    actor = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    action = models.CharField(max_length=40)
    entity = models.CharField(max_length=40)
    entity_id = models.CharField(max_length=30)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at", "-id"]
