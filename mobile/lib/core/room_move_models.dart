import 'models.dart';

class RoomMoveOptions {
  const RoomMoveOptions({
    required this.date,
    required this.policy,
    required this.rooms,
  });
  final DateTime date;
  final String policy;
  final List<HotelRoom> rooms;
  factory RoomMoveOptions.fromJson(Map<String, dynamic> json) =>
      RoomMoveOptions(
        date: DateTime.parse(json['effective_date'] as String),
        policy: json['policy'] as String,
        rooms: (json['rooms'] as List)
            .map((row) => HotelRoom.fromJson(row as Map<String, dynamic>))
            .toList(),
      );
}

class RoomMoveQuote {
  const RoomMoveQuote({
    required this.token,
    required this.date,
    required this.from,
    required this.to,
    required this.oldRate,
    required this.newRate,
    required this.nights,
    required this.oldTotal,
    required this.newTotal,
    required this.difference,
    required this.services,
    required this.total,
    required this.policy,
  });
  final String token, from, to, policy;
  final DateTime date;
  final int oldRate,
      newRate,
      nights,
      oldTotal,
      newTotal,
      difference,
      services,
      total;
  factory RoomMoveQuote.fromJson(Map<String, dynamic> json) {
    int amount(String key) => int.parse(json[key].toString());
    return RoomMoveQuote(
      token: json['quote_token'] as String,
      date: DateTime.parse(json['effective_date'] as String),
      from: json['from_number'] as String,
      to: json['to_number'] as String,
      oldRate: amount('old_rate'),
      newRate: amount('new_rate'),
      nights: json['remaining_nights'] as int,
      oldTotal: amount('current_room_total'),
      newTotal: amount('new_room_total'),
      difference: amount('difference'),
      services: amount('service_total'),
      total: amount('total'),
      policy: json['policy'] as String,
    );
  }
}
