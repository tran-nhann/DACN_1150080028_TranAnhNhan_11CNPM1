from rest_framework import serializers

from .models import RoomMove
from .serializers import BookingSerializer, RoomSerializer


class RoomMoveInputSerializer(serializers.Serializer):
    room_id = serializers.IntegerField(min_value=1, max_value=9223372036854775807)
    price_mode = serializers.ChoiceField(choices=RoomMove.PriceMode.choices)
    old_room_condition = serializers.ChoiceField(choices=RoomMove.OldRoomCondition.choices)
    reason = serializers.CharField(max_length=300, allow_blank=False)


class RoomMoveCommitSerializer(RoomMoveInputSerializer):
    quote_token = serializers.RegexField(r"^[a-f0-9]{64}$")


class RoomMoveOptionsSerializer(serializers.Serializer):
    effective_date = serializers.DateField()
    policy = serializers.CharField()
    rooms = RoomSerializer(many=True)


class RoomMoveQuoteSerializer(serializers.Serializer):
    quote_token = serializers.CharField()
    effective_date = serializers.DateField()
    from_number = serializers.CharField()
    to_number = serializers.CharField()
    old_rate = serializers.DecimalField(max_digits=12, decimal_places=0)
    new_rate = serializers.DecimalField(max_digits=12, decimal_places=0)
    remaining_nights = serializers.IntegerField()
    current_room_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    new_room_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    difference = serializers.DecimalField(max_digits=18, decimal_places=0)
    service_total = serializers.DecimalField(max_digits=18, decimal_places=0)
    total = serializers.DecimalField(max_digits=18, decimal_places=0)
    policy = serializers.CharField()


class RoomMoveResponseSerializer(serializers.Serializer):
    move_id = serializers.IntegerField()
    booking = BookingSerializer()
