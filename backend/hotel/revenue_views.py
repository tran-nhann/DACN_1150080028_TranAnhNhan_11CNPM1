from calendar import monthrange
from datetime import datetime, time, timedelta
from decimal import Decimal

from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.permissions import BasePermission
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Booking, BookingServicePlan, Payment, ServiceUsage
from .room_charges import room_segments, room_type_at


class RevenuePermission(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role in {"admin", "manager"}


class RevenuePeriodSerializer(serializers.Serializer):
    start_date = serializers.DateField()
    end_date = serializers.DateField(help_text="Ngày kết thúc không bao gồm trong kỳ.")

    def validate(self, attrs):
        days = (attrs["end_date"] - attrs["start_date"]).days
        if days < 1 or days > 366:
            raise serializers.ValidationError("Chọn kỳ từ 1 đến 366 ngày.")
        return attrs


class RevenueDaySerializer(serializers.Serializer):
    date = serializers.DateField()
    room_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    service_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    total = serializers.DecimalField(max_digits=18, decimal_places=0)


class RevenueTypeSerializer(serializers.Serializer):
    room_type_id = serializers.IntegerField()
    name = serializers.CharField()
    room_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    service_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    total = serializers.DecimalField(max_digits=18, decimal_places=0)


class RevenueEstimateSerializer(serializers.Serializer):
    start_date = serializers.DateField()
    end_date = serializers.DateField()
    room_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    service_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    estimated_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    confirmed_room_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    stay_room_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    booking_count = serializers.IntegerField()
    room_nights = serializers.IntegerField()
    service_count = serializers.IntegerField()
    currency = serializers.CharField()
    is_estimate = serializers.BooleanField()
    collected_total = serializers.DecimalField(max_digits=18, decimal_places=0, allow_null=True)
    cash_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    bank_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    payment_count = serializers.IntegerField()
    planned_service_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    daily = RevenueDaySerializer(many=True)
    by_room_type = RevenueTypeSerializer(many=True)


def revenue_estimate(start, end):
    daily = {}
    day = start
    while day < end:
        daily[day] = {"date": day.isoformat(), "room_total": Decimal(0), "service_total": Decimal(0)}
        day += timedelta(days=1)
    by_type = {}

    def group(type_id, name):
        return by_type.setdefault(type_id, {
            "room_type_id": type_id, "name": name,
            "room_total": Decimal(0), "service_total": Decimal(0),
        })

    bookings = Booking.objects.filter(
        status__in=["confirmed", "checked_in", "checked_out"],
        start_date__lt=end, end_date__gt=start,
    ).select_related("room__room_type").prefetch_related("room_moves")
    confirmed = stay_total = Decimal(0)
    nights = booking_count = 0
    for booking in bookings:
        booking_count += 1
        for segment in room_segments(booking):
            first, last = max(start, segment["start_date"]), min(end, segment["end_date"])
            count = max(0, (last - first).days)
            if not count:
                continue
            amount = count * segment["nightly_rate"]
            if booking.status == "confirmed":
                confirmed += amount
            else:
                stay_total += amount
            nights += count
            group(segment["room_type_id"], segment["room_type"])["room_total"] += amount
            while first < last:
                daily[first]["room_total"] += segment["nightly_rate"]
                first += timedelta(days=1)

    usages = ServiceUsage.objects.filter(
        status="active", stay__booking__status__in=["checked_in", "checked_out"],
        created_at__gte=timezone.make_aware(datetime.combine(start, time.min)),
        created_at__lt=timezone.make_aware(datetime.combine(end, time.min)),
    ).select_related("stay__booking__room__room_type").prefetch_related("stay__booking__room_moves")
    service_total = Decimal(0)
    service_count = 0
    for usage in usages:
        amount = usage.total
        day = timezone.localtime(usage.created_at).date()
        daily[day]["service_total"] += amount
        group(*room_type_at(usage.stay.booking, usage.created_at))["service_total"] += amount
        service_total += amount
        service_count += 1

    planned_total = Decimal(0)
    for plan in BookingServicePlan.objects.filter(status="reserved", booking__status="confirmed",
        booking__start_date__gte=start, booking__start_date__lt=end).select_related("booking__room__room_type"):
        planned_total += plan.total
        daily[plan.booking.start_date]["service_total"] += plan.total
        group(plan.booking.room.room_type_id, plan.booking.room.room_type.name)["service_total"] += plan.total

    def totals(row):
        return {**row, "room_total": str(row["room_total"]), "service_total": str(row["service_total"]), "total": str(row["room_total"] + row["service_total"])}

    received = list(Payment.objects.filter(
        received_at__gte=timezone.make_aware(datetime.combine(start, time.min)),
        received_at__lt=timezone.make_aware(datetime.combine(end, time.min)),
    ).values("amount", "method"))
    cash = sum((row["amount"] for row in received if row["method"] == "cash"), Decimal(0))
    bank = sum((row["amount"] for row in received if row["method"] == "bank_transfer"), Decimal(0))
    return {
        "start_date": start.isoformat(), "end_date": end.isoformat(),
        "room_total": str(confirmed + stay_total), "service_total": str(service_total),
        "estimated_total": str(confirmed + stay_total + service_total + planned_total),
        "planned_service_total": str(planned_total),
        "confirmed_room_total": str(confirmed), "stay_room_total": str(stay_total),
        "booking_count": booking_count, "room_nights": nights, "service_count": service_count,
        "currency": "VND", "is_estimate": True, "collected_total": str(cash + bank),
        "cash_total": str(cash), "bank_total": str(bank), "payment_count": len(received),
        "daily": [totals(row) for row in daily.values()],
        "by_room_type": [totals(row) for row in sorted(by_type.values(), key=lambda row: -(row["room_total"] + row["service_total"]))],
    }


class RevenueEstimateView(APIView):
    permission_classes = [RevenuePermission]

    @extend_schema(parameters=[RevenuePeriodSerializer], responses=RevenueEstimateSerializer)
    def get(self, request):
        today = timezone.localdate()
        first = today.replace(day=1)
        last = first + timedelta(days=monthrange(first.year, first.month)[1])
        period = RevenuePeriodSerializer(data={
            "start_date": request.query_params.get("start_date", first.isoformat()),
            "end_date": request.query_params.get("end_date", last.isoformat()),
        })
        period.is_valid(raise_exception=True)
        return Response(revenue_estimate(period.validated_data["start_date"], period.validated_data["end_date"]))
