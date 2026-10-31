from django.db.models import Exists, OuterRef, Prefetch
from django.utils import timezone

from .models import Booking, Room

ACTIVE_BOOKING_STATUSES = [Booking.Status.CONFIRMED, Booking.Status.CHECKED_IN]


def room_queryset():
    today = timezone.localdate()
    return Room.objects.select_related("room_type").annotate(
        _occupied=Exists(
            Booking.objects.filter(room_id=OuterRef("pk"), status=Booking.Status.CHECKED_IN)
        ),
        _reserved=Exists(
            Booking.objects.filter(
                room_id=OuterRef("pk"),
                status=Booking.Status.CONFIRMED,
                start_date__lte=today,
                end_date__gt=today,
            )
        ),
    )


def room_display_status(room):
    if not hasattr(room, "_occupied"):
        today = timezone.localdate()
        room._occupied = Booking.objects.filter(
            room=room, status=Booking.Status.CHECKED_IN
        ).exists()
        room._reserved = Booking.objects.filter(
            room=room, status=Booking.Status.CONFIRMED, start_date__lte=today, end_date__gt=today
        ).exists()
    if room._occupied:
        return "occupied"
    if room.condition != Room.Condition.READY:
        return room.condition
    return "reserved" if room._reserved else "ready"


def booking_queryset():
    return Booking.objects.select_related("customer", "stay").prefetch_related(
        Prefetch("room", queryset=room_queryset())
    )


def available_rooms(start, end, guests=1, exclude_booking=None):
    overlaps = Booking.objects.filter(
        room_id=OuterRef("pk"),
        status__in=ACTIVE_BOOKING_STATUSES,
        start_date__lt=end,
        end_date__gt=start,
    )
    if exclude_booking:
        overlaps = overlaps.exclude(pk=exclude_booking)
    queryset = (
        room_queryset()
        .filter(is_active=True, room_type__capacity__gte=guests)
        .exclude(condition=Room.Condition.MAINTENANCE)
    )
    if start == timezone.localdate():
        overdue = Booking.objects.filter(
            room_id=OuterRef("pk"), status=Booking.Status.CHECKED_IN, end_date__lte=start
        )
        if exclude_booking:
            overdue = overdue.exclude(pk=exclude_booking)
        queryset = queryset.annotate(_overdue=Exists(overdue)).filter(_overdue=False)
    return (
        queryset.annotate(_overlap=Exists(overlaps))
        .filter(_overlap=False)
        .order_by("room_type__base_rate", "floor", "number")
    )
