import datetime
from collections import Counter

from django.db import DatabaseError, connection, transaction
from django.db.models import Q, Sum
from django.utils import timezone
from django.utils.dateparse import parse_date
from drf_spectacular.utils import OpenApiParameter, OpenApiTypes, extend_schema, extend_schema_view
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .billing_serializers import CleanRoomSerializer
from .billing_services import confirm_cleaned
from .booking_services import guard_room_edit, validate_interval
from .models import Booking, Customer, Room, RoomType
from .permissions import CatalogPermission, CustomerPermission, RoomConditionPermission
from .room_charges import room_segments
from .selectors import available_rooms, booking_queryset, room_display_status, room_queryset
from .serializers import (
    ActiveUserRefreshSerializer,
    AvailabilitySerializer,
    BookingSerializer,
    CustomerSerializer,
    LoginResponseSerializer,
    LoginSerializer,
    LogoutSerializer,
    RefreshResponseSerializer,
    RoomConditionSerializer,
    RoomSerializer,
    RoomTypeSerializer,
    UserSerializer,
)
from .services import application_transaction, record_audit, room_transaction


@extend_schema(responses={200: LoginResponseSerializer})
class LoginView(TokenObtainPairView):
    serializer_class = LoginSerializer
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "login"


@extend_schema(responses={200: RefreshResponseSerializer})
class RefreshView(TokenRefreshView):
    serializer_class = ActiveUserRefreshSerializer
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "refresh"


class MeView(APIView):
    @extend_schema(responses=UserSerializer)
    def get(self, request):
        return Response(UserSerializer(request.user).data)


class LogoutView(APIView):
    @extend_schema(request=LogoutSerializer, responses={204: None})
    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            token = RefreshToken(serializer.validated_data["refresh"])
            if str(token.get("user_id")) != str(request.user.pk):
                raise ValidationError("Phiên đăng nhập không thuộc tài khoản này.")
            token.blacklist()
        except TokenError as exc:
            raise ValidationError("Phiên đăng nhập không còn hợp lệ.") from exc
        return Response(status=status.HTTP_204_NO_CONTENT)


class HealthView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
        except DatabaseError:
            return Response({"status": "unavailable"}, status=503)
        return Response({"status": "ok"})


class AuditedCatalogViewSet(viewsets.ModelViewSet):
    permission_classes = [CatalogPermission]
    http_method_names = ["get", "post", "put", "patch", "head", "options"]

    @transaction.atomic
    def perform_create(self, serializer):
        with application_transaction("hotel:catalog"):
            instance = serializer.save()
            record_audit(self.request.user, "create", instance)

    @transaction.atomic
    def perform_update(self, serializer):
        with application_transaction("hotel:catalog"):
            instance = serializer.save()
            record_audit(self.request.user, "update", instance)


class RoomTypeViewSet(AuditedCatalogViewSet):
    queryset = RoomType.objects.all()
    serializer_class = RoomTypeSerializer
    search_fields = ["name"]
    ordering_fields = ["base_rate", "name"]

    def perform_update(self, serializer):
        with application_transaction("hotel:catalog"):
            serializer.instance = RoomType.objects.get(pk=serializer.instance.pk)
            capacity = serializer.validated_data.get("capacity", serializer.instance.capacity)
            if (
                Booking.objects.filter(
                    room__room_type=serializer.instance,
                    status__in=["confirmed", "checked_in"],
                    guests__gt=capacity,
                )
                .filter(Q(end_date__gt=timezone.localdate()) | Q(status="checked_in"))
                .exists()
            ):
                raise ValidationError({"capacity": "Sức chứa mới không đủ cho lịch đặt hiện có."})
            super().perform_update(serializer)


ROOM_WRITE_REQUEST = {
    "application/json": RoomSerializer,
    "multipart/form-data": {
        "type": "object",
        "required": ["data"],
        "properties": {
            "data": {
                "type": "string",
                "description": "JSON room fields; image_ids retains/reorders existing images. "
                "cover_upload_index selects a new upload as cover (zero-based).",
            },
            "upload_images": {
                "type": "array", "maxItems": 10,
                "items": {"type": "string", "format": "binary"},
                "description": "JPG, PNG or WebP, at most 5 MB and 25 megapixels per image.",
            },
        },
    },
}


@extend_schema_view(
    list=extend_schema(parameters=[
        OpenApiParameter("room_type", int, description="ID hạng phòng; kết hợp với tầng và trạng thái."),
        OpenApiParameter("floor", int, description="Tầng phòng (số nguyên dương)."),
        OpenApiParameter("status", str, enum=["ready", "occupied", "reserved", "cleaning", "maintenance"]),
    ]),
    create=extend_schema(request=ROOM_WRITE_REQUEST),
    update=extend_schema(request=ROOM_WRITE_REQUEST),
    partial_update=extend_schema(request=ROOM_WRITE_REQUEST),
)
class RoomViewSet(AuditedCatalogViewSet):
    queryset = room_queryset()
    serializer_class = RoomSerializer
    search_fields = ["number", "room_type__name"]
    ordering_fields = ["floor", "number"]

    def perform_create(self, serializer):
        try:
            with application_transaction("hotel:catalog"):
                room = serializer.save()
                record_audit(self.request.user, "create", room)
        except Exception:
            serializer.cleanup_uploads()
            raise

    def get_queryset(self):
        queryset = room_queryset().filter(is_active=True)
        condition = self.request.query_params.get("condition")
        floor = self.request.query_params.get("floor")
        room_type = self.request.query_params.get("room_type")
        display_status = self.request.query_params.get("status")
        if display_status:
            if display_status == "occupied":
                queryset = queryset.filter(_occupied=True)
            elif display_status == "reserved":
                queryset = queryset.filter(_occupied=False, _reserved=True, condition="ready")
            elif display_status == "ready":
                queryset = queryset.filter(_occupied=False, _reserved=False, condition="ready")
            elif display_status in {"cleaning", "maintenance"}:
                queryset = queryset.filter(condition=display_status)
            else:
                raise ValidationError({"status": "Trạng thái phòng không hợp lệ."})
        if condition:
            if condition not in Room.Condition.values:
                raise ValidationError({"condition": "Trạng thái phòng không hợp lệ."})
            queryset = queryset.filter(condition=condition)
        if floor:
            try:
                floor_number = int(floor)
                if floor_number < 1 or floor_number > 32767:
                    raise ValueError
            except ValueError as exc:
                raise ValidationError({"floor": "Tầng phải là số nguyên dương hợp lệ."}) from exc
            queryset = queryset.filter(floor=floor_number)
        if room_type is not None:
            try:
                type_id = int(room_type)
                if type_id < 1 or type_id > 9223372036854775807:
                    raise ValueError
            except ValueError as exc:
                raise ValidationError({"room_type": "Hạng phòng không hợp lệ."}) from exc
            queryset = queryset.filter(room_type_id=type_id)
        return queryset

    def perform_update(self, serializer):
        try:
            with application_transaction("hotel:catalog"), room_transaction(serializer.instance.pk):
                serializer.instance = Room.objects.get(pk=serializer.instance.pk)
                guard_room_edit(serializer.instance, serializer.validated_data)
                room = serializer.save()
                record_audit(self.request.user, "update", room)
        except Exception:
            serializer.cleanup_uploads()
            raise

    @extend_schema(request=RoomConditionSerializer, responses=RoomSerializer)
    @action(
        detail=True,
        methods=["post"],
        permission_classes=[RoomConditionPermission],
        url_path="condition",
    )
    def change_condition(self, request, pk=None):
        data = RoomConditionSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        with room_transaction(pk):
            room = self.get_object()
            guard_room_edit(room, data.validated_data)
            room.condition = data.validated_data["condition"]
            room.save(update_fields=["condition", "updated_at"])
            record_audit(request.user, "change_condition", room)
        return Response(RoomSerializer(room).data)

    @extend_schema(request=CleanRoomSerializer, responses=RoomSerializer)
    @action(detail=True, methods=["post"], permission_classes=[RoomConditionPermission], url_path="confirm-cleaned")
    def confirm_cleaned(self, request, pk=None):
        data = CleanRoomSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        room = confirm_cleaned(request.user, pk, data.validated_data["expected_updated_at"])
        return Response(RoomSerializer(room).data)

    @extend_schema(parameters=[AvailabilitySerializer], responses=RoomSerializer(many=True))
    @action(detail=False, methods=["get"], url_path="timeline")
    def timeline(self, request):
        start_str = request.query_params.get("start_date")
        days_str = request.query_params.get("days", "7")
        floor_str = request.query_params.get("floor")

        try:
            start_date = parse_date(start_str) if start_str else timezone.localdate()
            if start_date is None:
                start_date = timezone.localdate()
        except (ValueError, TypeError):
            start_date = timezone.localdate()

        try:
            days = int(days_str)
            days = max(1, min(14, days))
        except (ValueError, TypeError):
            days = 7

        end_date = start_date + datetime.timedelta(days=days)
        dates = [start_date + datetime.timedelta(days=i) for i in range(days)]

        rooms_qs = Room.objects.filter(is_active=True).select_related("room_type").order_by("floor", "number")
        if floor_str:
            try:
                floor = int(floor_str)
                if floor > 0:
                    rooms_qs = rooms_qs.filter(floor=floor)
            except (ValueError, TypeError):
                pass

        rooms = list(rooms_qs)
        room_ids = [r.id for r in rooms]

        bookings = (
            booking_queryset()
            .filter(
                status__in=[Booking.Status.CONFIRMED, Booking.Status.CHECKED_IN],
                start_date__lt=end_date,
                end_date__gt=start_date,
            )
            .select_related("room", "customer")
        )

        from collections import defaultdict
        room_bookings = defaultdict(list)
        for b in bookings:
            for segment in room_segments(b):
                if segment["room_id"] in room_ids:
                    room_bookings[segment["room_id"]].append((b, segment))

        today = timezone.localdate()
        result_rooms = []
        for r in rooms:
            b_list = room_bookings.get(r.id, [])
            schedule = []
            for d in dates:
                cell = {
                    "date": d.isoformat(),
                    "status": "ready",
                    "booking": None,
                }
                if r.condition == Room.Condition.MAINTENANCE and d >= today:
                    cell["status"] = "maintenance"
                elif r.condition == Room.Condition.CLEANING and d == today:
                    cell["status"] = "cleaning"
                else:
                    allocation = next(((b, segment) for b, segment in b_list if segment["start_date"] <= d < segment["end_date"]), None)
                    if allocation:
                        matched, segment = allocation
                        cell["status"] = matched.status
                        cell["booking"] = {
                            "id": matched.id,
                            "code": matched.code,
                            "customer_name": matched.customer.full_name,
                            "customer_id": matched.customer.id,
                            "status": matched.status,
                            "status_label": matched.get_status_display(),
                            "start_date": matched.start_date.isoformat(),
                            "end_date": matched.end_date.isoformat(),
                            "guests": matched.guests,
                            "is_start": d == segment["start_date"],
                            "is_end": d == (segment["end_date"] - datetime.timedelta(days=1)),
                        }
                schedule.append(cell)

            result_rooms.append({
                "id": r.id,
                "number": r.number,
                "floor": r.floor,
                "type_name": r.room_type.name,
                "rate": int(r.room_type.base_rate),
                "condition": r.condition,
                "schedule": schedule,
            })

        return Response({
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "days": days,
            "dates": [d.isoformat() for d in dates],
            "rooms": result_rooms,
        })

    @action(detail=False, methods=["get"], url_path="availability")
    def availability(self, request):
        serializer = AvailabilitySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        validate_interval(data["start_date"], data["end_date"])
        rooms = available_rooms(
            data["start_date"], data["end_date"], data["guests"], data.get("exclude_booking")
        )
        page = self.paginate_queryset(rooms)
        return self.get_paginated_response(RoomSerializer(page, many=True).data)


class CustomerViewSet(viewsets.ModelViewSet):
    queryset = Customer.objects.all()
    serializer_class = CustomerSerializer
    permission_classes = [CustomerPermission]
    http_method_names = ["get", "post", "put", "patch", "head", "options"]
    search_fields = ["full_name", "phone"]
    ordering_fields = ["full_name", "created_at"]

    @transaction.atomic
    def perform_create(self, serializer):
        instance = serializer.save()
        record_audit(self.request.user, "create", instance)

    @transaction.atomic
    def perform_update(self, serializer):
        instance = serializer.save()
        record_audit(self.request.user, "update", instance)


class DashboardView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        today = timezone.localdate()
        rooms = list(room_queryset().filter(is_active=True))
        counts = Counter(room_display_status(room) for room in rooms)
        totals = {
            "total": len(rooms),
            **{
                key: counts[key]
                for key in ["ready", "occupied", "reserved", "cleaning", "maintenance"]
            },
        }
        floors = []
        for floor in sorted({room.floor for room in rooms}):
            rows = [room for room in rooms if room.floor == floor]
            floors.append(
                {
                    "floor": floor,
                    "total": len(rows),
                    "ready": sum(room_display_status(room) == "ready" for room in rows),
                }
            )
        attention = [room for room in rooms if room.condition != Room.Condition.READY][:6]
        arrivals = Booking.objects.filter(start_date=today, status=Booking.Status.CONFIRMED).count()
        departures = Booking.objects.filter(
            end_date=today, status=Booking.Status.CHECKED_IN
        ).count()
        guests = (
            Booking.objects.filter(status=Booking.Status.CHECKED_IN).aggregate(total=Sum("guests"))[
                "total"
            ]
            or 0
        )
        today_bookings = (
            booking_queryset()
            .filter(start_date=today, status=Booking.Status.CONFIRMED)
            .order_by("room__number")[:4]
        )
        return Response(
            {
                "hotel_name": "Aster Hotel",
                "date": timezone.localdate().isoformat(),
                "rooms": totals,
                "floors": floors,
                "attention_rooms": RoomSerializer(attention, many=True).data,
                "arrivals": arrivals,
                "departures": departures,
                "guests": guests,
                "today_bookings": BookingSerializer(today_bookings, many=True).data,
                "capabilities": {
                    "bookings": True,
                    "billing": False,
                    "revenue_estimate": request.user.role in {"admin", "manager"},
                    "customer_access": request.user.role in {"admin", "receptionist"},
                },
            }
        )
