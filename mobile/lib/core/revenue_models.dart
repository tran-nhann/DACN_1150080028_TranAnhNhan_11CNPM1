int _amount(dynamic value) =>
    int.tryParse(value?.toString().split('.').first ?? '') ?? 0;

typedef RevenueQuery = ({String start, String end});

class RevenueDay {
  const RevenueDay({required this.date, required this.total});
  final DateTime date;
  final int total;
  factory RevenueDay.fromJson(Map<String, dynamic> json) => RevenueDay(
    date: DateTime.parse(json['date'] as String),
    total: _amount(json['total']),
  );
}

class RevenueType {
  const RevenueType({required this.name, required this.total});
  final String name;
  final int total;
  factory RevenueType.fromJson(Map<String, dynamic> json) =>
      RevenueType(name: json['name'] as String, total: _amount(json['total']));
}

class RevenueEstimate {
  const RevenueEstimate({
    required this.start,
    required this.end,
    required this.roomTotal,
    required this.serviceTotal,
    required this.total,
    required this.confirmedTotal,
    required this.stayTotal,
    required this.bookingCount,
    required this.roomNights,
    required this.serviceCount,
    this.daily = const [],
    this.types = const [],
    this.collectedTotal,
    this.cashTotal = 0,
    this.bankTotal = 0,
    this.paymentCount = 0,
    this.plannedServiceTotal = 0,
  });
  final DateTime start, end;
  final int roomTotal,
      serviceTotal,
      total,
      confirmedTotal,
      stayTotal,
      bookingCount,
      roomNights,
      serviceCount;
  final List<RevenueDay> daily;
  final List<RevenueType> types;
  final int? collectedTotal;
  final int cashTotal, bankTotal, paymentCount;
  final int plannedServiceTotal;
  factory RevenueEstimate.fromJson(Map<String, dynamic> json) =>
      RevenueEstimate(
        start: DateTime.parse(json['start_date'] as String),
        end: DateTime.parse(json['end_date'] as String),
        roomTotal: _amount(json['room_total']),
        serviceTotal: _amount(json['service_total']),
        total: _amount(json['estimated_total']),
        confirmedTotal: _amount(json['confirmed_room_total']),
        stayTotal: _amount(json['stay_room_total']),
        bookingCount: _amount(json['booking_count']),
        roomNights: _amount(json['room_nights']),
        serviceCount: _amount(json['service_count']),
        plannedServiceTotal: _amount(json['planned_service_total']),
        collectedTotal: json['collected_total'] == null
            ? null
            : _amount(json['collected_total']),
        cashTotal: _amount(json['cash_total']),
        bankTotal: _amount(json['bank_total']),
        paymentCount: _amount(json['payment_count']),
        daily: (json['daily'] as List? ?? [])
            .map((row) => RevenueDay.fromJson(row as Map<String, dynamic>))
            .toList(),
        types: (json['by_room_type'] as List? ?? [])
            .map((row) => RevenueType.fromJson(row as Map<String, dynamic>))
            .toList(),
      );
}
