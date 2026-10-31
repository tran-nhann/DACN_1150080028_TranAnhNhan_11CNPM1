class StaffUser {
  const StaffUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.roleLabel,
  });
  final int id;
  final String username, name, role, roleLabel;
  bool get isAdmin => role == 'admin';
  bool get canEditRooms => role == 'admin' || role == 'receptionist';
  bool get canAccessCustomers => role == 'admin' || role == 'receptionist';
  factory StaffUser.fromJson(Map<String, dynamic> json) => StaffUser(
    id: json['id'] as int,
    username: json['username'] as String,
    name: json['display_name'] as String,
    role: json['role'] as String,
    roleLabel: json['role_label'] as String,
  );
}

class RoomType {
  const RoomType({
    required this.id,
    required this.name,
    required this.description,
    required this.capacity,
    required this.rate,
  });
  final int id, capacity, rate;
  final String name, description;
  factory RoomType.fromJson(Map<String, dynamic> json) => RoomType(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String,
    capacity: json['capacity'] as int,
    rate: int.parse((json['base_rate'] as String).split('.').first),
  );
}

class HotelRoom {
  const HotelRoom({
    required this.id,
    required this.number,
    required this.floor,
    required this.type,
    required this.condition,
    required this.notes,
    this.displayStatus = 'ready',
    this.updatedAt,
    this.active = true,
  });
  final int id, floor;
  final String number, condition, notes;
  final String displayStatus;
  final RoomType type;
  final DateTime? updatedAt;
  final bool active;
  factory HotelRoom.fromJson(Map<String, dynamic> json) => HotelRoom(
    id: json['id'] as int,
    number: json['number'] as String,
    floor: json['floor'] as int,
    type: RoomType.fromJson(json['room_type'] as Map<String, dynamic>),
    condition: json['condition'] as String,
    notes: json['notes'] as String,
    displayStatus:
        json['display_status'] as String? ?? json['condition'] as String,
    updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    active: json['is_active'] as bool? ?? true,
  );
}

class Guest {
  const Guest({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.notes,
    this.createdAt,
  });
  final int id;
  final String name, phone, email, notes;
  final DateTime? createdAt;
  factory Guest.fromJson(Map<String, dynamic> json) => Guest(
    id: json['id'] as int,
    name: json['full_name'] as String,
    phone: json['phone'] as String,
    email: json['email'] as String,
    notes: json['notes'] as String,
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
  );
}

class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.count,
    required this.hasNext,
  });
  final List<T> items;
  final int count;
  final bool hasNext;
}

class HotelService {
  const HotelService({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    this.active = true,
    this.unitValid = true,
  });
  final int id, price;
  final String name, unit;
  final bool active, unitValid;
  factory HotelService.fromJson(Map<String, dynamic> json) => HotelService(
    id: json['id'] as int,
    name: json['name'] as String,
    unit: json['unit'] as String,
    price: int.parse(json['unit_price'].toString().split('.').first),
    active: json['is_active'] as bool,
    unitValid: json['unit_valid'] as bool? ?? true,
  );
}

class ServiceUnit {
  const ServiceUnit({
    required this.value,
    required this.label,
    required this.example,
  });
  final String value, label, example;
  factory ServiceUnit.fromJson(Map<String, dynamic> json) => ServiceUnit(
    value: json['value'] as String,
    label: json['label'] as String,
    example: json['example'] as String,
  );
}

class ServiceUsage {
  const ServiceUsage({
    required this.id,
    required this.serviceId,
    required this.name,
    required this.unit,
    required this.price,
    required this.quantity,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason = '',
  });
  final int id, serviceId, price, quantity, total;
  final String name, unit, status, createdBy, cancelReason;
  final String? cancelledBy;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  bool get cancelled => status == 'cancelled';
  factory ServiceUsage.fromJson(Map<String, dynamic> json) => ServiceUsage(
    id: json['id'] as int,
    serviceId: json['service_id'] as int,
    name: json['name'] as String,
    unit: json['unit'] as String,
    price: int.parse(json['unit_price'].toString().split('.').first),
    quantity: json['quantity'] as int,
    total: int.parse(json['total'].toString().split('.').first),
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    createdBy: json['created_by'] as String,
    cancelledAt: DateTime.tryParse(json['cancelled_at']?.toString() ?? ''),
    cancelledBy: json['cancelled_by'] as String?,
    cancelReason: json['cancel_reason'] as String? ?? '',
  );
}

class StayServices {
  const StayServices({
    required this.items,
    required this.count,
    required this.hasNext,
    required this.roomTotal,
    required this.serviceTotal,
    required this.estimatedTotal,
    required this.canEdit,
  });
  final List<ServiceUsage> items;
  final int count, roomTotal, serviceTotal, estimatedTotal;
  final bool hasNext, canEdit;
  factory StayServices.fromJson(Map<String, dynamic> json) => StayServices(
    items: (json['results'] as List)
        .map((item) => ServiceUsage.fromJson(item as Map<String, dynamic>))
        .toList(),
    count: json['count'] as int,
    hasNext: json['next'] != null,
    roomTotal: int.parse(json['room_total'].toString().split('.').first),
    serviceTotal: int.parse(json['service_total'].toString().split('.').first),
    estimatedTotal: int.parse(
      json['estimated_total'].toString().split('.').first,
    ),
    canEdit: json['can_edit'] as bool,
  );
}

typedef ServiceQuery = ({String search, bool? active, int page});
typedef StayServiceQuery = ({int bookingId, int page});

class DashboardData {
  const DashboardData({
    required this.date,
    required this.total,
    required this.ready,
    required this.cleaning,
    required this.maintenance,
    required this.floors,
    required this.attention,
    this.occupied = 0,
    this.reserved = 0,
    this.arrivals = 0,
    this.departures = 0,
    this.guests = 0,
    this.todayBookings = const [],
  });
  final DateTime date;
  final int total, ready, cleaning, maintenance;
  final int occupied, reserved, arrivals, departures, guests;
  final List<HotelBooking> todayBookings;
  final List<FloorSummary> floors;
  final List<HotelRoom> attention;
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final counts = json['rooms'] as Map<String, dynamic>;
    return DashboardData(
      date: DateTime.parse(json['date'] as String),
      total: counts['total'] as int,
      ready: counts['ready'] as int,
      cleaning: counts['cleaning'] as int,
      maintenance: counts['maintenance'] as int,
      occupied: counts['occupied'] as int? ?? 0,
      reserved: counts['reserved'] as int? ?? 0,
      arrivals: json['arrivals'] as int? ?? 0,
      departures: json['departures'] as int? ?? 0,
      guests: json['guests'] as int? ?? 0,
      todayBookings: (json['today_bookings'] as List? ?? [])
          .map((item) => HotelBooking.fromJson(item as Map<String, dynamic>))
          .toList(),
      floors: (json['floors'] as List)
          .map((item) => FloorSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      attention: (json['attention_rooms'] as List)
          .map((item) => HotelRoom.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FloorSummary {
  const FloorSummary({
    required this.floor,
    required this.total,
    required this.ready,
  });
  final int floor, total, ready;
  factory FloorSummary.fromJson(Map<String, dynamic> json) => FloorSummary(
    floor: json['floor'] as int,
    total: json['total'] as int,
    ready: json['ready'] as int,
  );
}

typedef RoomQuery = ({String search, String condition, int? floor, int page});
typedef GuestQuery = ({String search, int page});
typedef BookingQuery = ({String search, String status, int page});

class BookingLookup {
  const BookingLookup({
    this.roomId,
    this.customerId,
    this.day,
    this.kind,
    this.page = 1,
  });
  final int? roomId, customerId;
  final String? day, kind;
  final int page;
  @override
  bool operator ==(Object other) =>
      other is BookingLookup &&
      roomId == other.roomId &&
      customerId == other.customerId &&
      day == other.day &&
      kind == other.kind &&
      page == other.page;
  @override
  int get hashCode => Object.hash(roomId, customerId, day, kind, page);
}

typedef AvailabilityQuery = ({
  String start,
  String end,
  int guests,
  int? exclude,
});

class HotelBooking {
  const HotelBooking({
    required this.id,
    required this.code,
    required this.room,
    required this.customerId,
    required this.customerName,
    required this.start,
    required this.end,
    required this.guests,
    required this.nightlyRate,
    required this.total,
    required this.status,
    required this.statusLabel,
    this.checkedInAt,
    this.createdAt,
  });
  final int id, customerId, guests, nightlyRate, total;
  final String code, customerName, status, statusLabel;
  final HotelRoom room;
  final DateTime start, end;
  final DateTime? checkedInAt;
  final DateTime? createdAt;
  int get nights => end.difference(start).inDays;
  factory HotelBooking.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>;
    return HotelBooking(
      id: json['id'] as int,
      code: json['code'] as String,
      room: HotelRoom.fromJson(json['room'] as Map<String, dynamic>),
      customerId: customer['id'] as int,
      customerName: customer['full_name'] as String,
      start: DateTime.parse(json['start_date'] as String),
      end: DateTime.parse(json['end_date'] as String),
      guests: json['guests'] as int,
      nightlyRate: int.parse(json['nightly_rate'] as String),
      total: int.parse(json['room_total'] as String),
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      checkedInAt: json['checked_in_at'] == null
          ? null
          : DateTime.parse(json['checked_in_at'] as String),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
