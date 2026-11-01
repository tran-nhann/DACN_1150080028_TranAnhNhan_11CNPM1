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
    class BedType(models.TextChoices):
        SINGLE = "single", "Giường đơn"
        DOUBLE = "double", "Giường đôi"
        QUEEN = "queen", "Giường Queen"
        KING = "king", "Giường King"
        TWIN = "twin", "Hai giường đơn"
        MIXED = "mixed", "Kết hợp nhiều loại giường"

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
    description = models.TextField(max_length=2000, blank=True)
    area = models.DecimalField(
        max_digits=6, decimal_places=2, null=True, blank=True,
        validators=[MinValueValidator(1)],
    )
    bed_type = models.CharField(max_length=20, choices=BedType.choices, blank=True)
    bed_count = models.PositiveSmallIntegerField(
        null=True, blank=True, validators=[MinValueValidator(1), MaxValueValidator(20)]
    )
    view = models.CharField(max_length=100, blank=True)
    amenities = models.JSONField(default=list, blank=True)
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
            models.CheckConstraint(
                condition=models.Q(area__isnull=True) | models.Q(area__gte=1),
                name="room_area_positive",
            ),
            models.CheckConstraint(
                condition=models.Q(bed_count__isnull=True) | models.Q(bed_count__gte=1, bed_count__lte=20),
                name="room_bed_count_valid",
            ),
        ]

    def __str__(self):
        return self.number


def room_image_path(instance, filename):
    # Never use a client filename as a storage path.
    extension = filename.rsplit(".", 1)[-1].lower()
    return f"rooms/{instance.room_id}/{uuid.uuid4().hex}.{extension}"


class RoomImage(models.Model):
    room = models.ForeignKey(Room, on_delete=models.CASCADE, related_name="images")
    image = models.ImageField(upload_to=room_image_path, max_length=255)
    position = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["position", "id"]


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
        from .room_charges import room_segments
        return sum((row["total"] for row in room_segments(self)), 0)


class RoomMove(models.Model):
    class OldRoomCondition(models.TextChoices):
        CLEANING = "cleaning", "Cần dọn"
        MAINTENANCE = "maintenance", "Bảo trì"

    class PriceMode(models.TextChoices):
        TARGET = "target", "Giá phòng mới"
        KEEP = "keep", "Giữ giá hiện tại"

    booking = models.ForeignKey(Booking, on_delete=models.PROTECT, related_name="room_moves")
    from_room = models.ForeignKey(Room, on_delete=models.PROTECT, related_name="moves_out")
    to_room = models.ForeignKey(Room, on_delete=models.PROTECT, related_name="moves_in")
    from_number = models.CharField(max_length=10)
    to_number = models.CharField(max_length=10)
    from_type = models.ForeignKey(RoomType, on_delete=models.PROTECT, related_name="moves_out")
    to_type = models.ForeignKey(RoomType, on_delete=models.PROTECT, related_name="moves_in")
    from_type_name = models.CharField(max_length=80)
    to_type_name = models.CharField(max_length=80)
    old_rate = models.DecimalField(max_digits=12, decimal_places=0)
    new_rate = models.DecimalField(max_digits=12, decimal_places=0)
    effective_date = models.DateField()
    price_mode = models.CharField(max_length=10, choices=PriceMode.choices)
    old_room_condition = models.CharField(max_length=20, choices=OldRoomCondition.choices)
    reason = models.CharField(max_length=300)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="room_moves")
    request_key = models.UUIDField(editable=False)
    request_fingerprint = models.CharField(max_length=64, editable=False)

    class Meta:
        ordering = ["created_at", "id"]
        constraints = [
            models.UniqueConstraint(fields=["created_by", "request_key"], name="room_move_request_once"),
            models.CheckConstraint(condition=~models.Q(from_room=models.F("to_room")), name="room_move_different_rooms"),
            models.CheckConstraint(condition=models.Q(old_rate__gte=0, new_rate__gte=0), name="room_move_rates_valid"),
            models.CheckConstraint(condition=models.Q(price_mode__in=["target", "keep"]), name="room_move_price_mode_valid"),
            models.CheckConstraint(condition=models.Q(old_room_condition__in=["cleaning", "maintenance"]), name="room_move_condition_valid"),
            models.CheckConstraint(condition=~models.Q(reason=""), name="room_move_reason_required"),
        ]


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


def service_image_path(instance, filename):
    extension = filename.rsplit(".", 1)[-1].lower()
    return f"services/{uuid.uuid4().hex}.{extension}"


class ServiceItem(TimestampedModel):
    class Category(models.TextChoices):
        FOOD = "food", "Ăn uống"
        LAUNDRY = "laundry", "Giặt ủi"
        TRANSPORT = "transport", "Đưa đón"
        MINIBAR = "minibar", "Minibar"
        WELLNESS = "wellness", "Thư giãn"
        OTHER = "other", "Khác"

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
    category = models.CharField(max_length=20, choices=Category.choices, default=Category.OTHER)
    description = models.TextField(max_length=2000, blank=True)
    notes = models.CharField(max_length=300, blank=True)
    image = models.ImageField(upload_to=service_image_path, max_length=255, blank=True)
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


class BookingServicePlan(models.Model):
    class Status(models.TextChoices):
        RESERVED = "reserved", "Đặt trước"
        POSTED = "posted", "Đã chuyển vào lưu trú"
        CANCELLED = "cancelled", "Đã hủy"

    booking = models.ForeignKey(Booking, on_delete=models.PROTECT, related_name="service_plans")
    service = models.ForeignKey(ServiceItem, on_delete=models.PROTECT, related_name="booking_plans")
    usage = models.OneToOneField(ServiceUsage, on_delete=models.PROTECT, null=True, blank=True, related_name="booking_plan")
    name = models.CharField(max_length=100)
    unit = models.CharField(max_length=30)
    unit_price = models.DecimalField(max_digits=12, decimal_places=0)
    quantity = models.PositiveSmallIntegerField()
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.RESERVED)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="planned_services")
    request_key = models.UUIDField(editable=False)
    request_fingerprint = models.CharField(max_length=64, editable=False)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    cancelled_by = models.ForeignKey(User, on_delete=models.PROTECT, null=True, blank=True, related_name="cancelled_service_plans")
    cancel_reason = models.CharField(max_length=200, blank=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        constraints = [
            models.UniqueConstraint(fields=["created_by", "request_key"], name="plan_request_once"),
            models.CheckConstraint(condition=models.Q(quantity__gte=1, quantity__lte=999, unit_price__gte=0), name="plan_values_valid"),
            models.CheckConstraint(condition=(
                models.Q(status="reserved", usage__isnull=True, cancelled_at__isnull=True, cancelled_by__isnull=True, cancel_reason="")
                | models.Q(status="posted", usage__isnull=False, cancelled_at__isnull=True, cancelled_by__isnull=True, cancel_reason="")
                | (models.Q(status="cancelled", usage__isnull=True, cancelled_at__isnull=False, cancelled_by__isnull=False) & ~models.Q(cancel_reason=""))
            ), name="plan_state_valid"),
        ]

    @property
    def total(self):
        return self.quantity * self.unit_price


def new_invoice_code():
    return "HD-" + uuid.uuid4().hex[:12].upper()


def new_receipt_code():
    return "PT-" + uuid.uuid4().hex[:12].upper()


class Invoice(models.Model):
    stay = models.OneToOneField(Stay, on_delete=models.PROTECT, related_name="invoice")
    code = models.CharField(max_length=20, unique=True, default=new_invoice_code, editable=False)
    booking_code = models.CharField(max_length=20)
    guest_name = models.CharField(max_length=150)
    guest_phone = models.CharField(max_length=20)
    room_number = models.CharField(max_length=10)
    room_type = models.CharField(max_length=80)
    start_date = models.DateField()
    end_date = models.DateField()
    room_total = models.DecimalField(max_digits=18, decimal_places=0)
    service_total = models.DecimalField(max_digits=18, decimal_places=0)
    total = models.DecimalField(max_digits=18, decimal_places=0)
    issued_at = models.DateTimeField(auto_now_add=True)
    issued_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="issued_invoices")
    request_key = models.UUIDField(editable=False)
    request_fingerprint = models.CharField(max_length=64, editable=False)

    class Meta:
        ordering = ["-issued_at", "-id"]
        constraints = [
            models.UniqueConstraint(fields=["issued_by", "request_key"], name="invoice_request_once"),
            models.CheckConstraint(condition=models.Q(end_date__gt=models.F("start_date")), name="invoice_dates_valid"),
            models.CheckConstraint(condition=models.Q(room_total__gte=0, service_total__gte=0, total__gte=0), name="invoice_totals_positive"),
            models.CheckConstraint(condition=models.Q(total=models.F("room_total") + models.F("service_total")), name="invoice_totals_match"),
        ]


class InvoiceLine(models.Model):
    class Kind(models.TextChoices):
        ROOM = "room", "Tiền phòng"
        SERVICE = "service", "Dịch vụ"

    invoice = models.ForeignKey(Invoice, on_delete=models.PROTECT, related_name="lines")
    position = models.PositiveIntegerField()
    kind = models.CharField(max_length=10, choices=Kind.choices)
    source_usage = models.OneToOneField(ServiceUsage, on_delete=models.PROTECT, null=True, blank=True)
    name = models.CharField(max_length=200)
    unit = models.CharField(max_length=30)
    quantity = models.PositiveSmallIntegerField()
    unit_price = models.DecimalField(max_digits=12, decimal_places=0)
    total = models.DecimalField(max_digits=18, decimal_places=0)

    class Meta:
        ordering = ["position", "id"]
        constraints = [
            models.UniqueConstraint(fields=["invoice", "position"], name="invoice_line_position_once"),
            models.CheckConstraint(condition=models.Q(quantity__gte=1, unit_price__gte=0, total__gte=0), name="invoice_line_values_valid"),
            models.CheckConstraint(condition=models.Q(total=models.F("quantity") * models.F("unit_price")), name="invoice_line_total_matches"),
            models.CheckConstraint(condition=models.Q(kind="room", source_usage__isnull=True) | models.Q(kind="service", source_usage__isnull=False), name="invoice_line_source_valid"),
        ]


class Payment(models.Model):
    class Method(models.TextChoices):
        CASH = "cash", "Tiền mặt"
        BANK_TRANSFER = "bank_transfer", "Chuyển khoản"

    invoice = models.OneToOneField(Invoice, on_delete=models.PROTECT, related_name="payment")
    code = models.CharField(max_length=20, unique=True, default=new_receipt_code, editable=False)
    amount = models.DecimalField(max_digits=18, decimal_places=0)
    method = models.CharField(max_length=20, choices=Method.choices)
    reference = models.CharField(max_length=100, blank=True)
    notes = models.CharField(max_length=300, blank=True)
    received_at = models.DateTimeField(auto_now_add=True)
    received_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="received_payments")

    class Meta:
        ordering = ["-received_at", "-id"]
        constraints = [
            models.CheckConstraint(condition=models.Q(amount__gte=0), name="payment_amount_nonnegative"),
            models.CheckConstraint(condition=models.Q(method__in=["cash", "bank_transfer"]), name="payment_method_valid"),
        ]


class AuditLog(models.Model):
    actor = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    action = models.CharField(max_length=40)
    entity = models.CharField(max_length=40)
    entity_id = models.CharField(max_length=30)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at", "-id"]
