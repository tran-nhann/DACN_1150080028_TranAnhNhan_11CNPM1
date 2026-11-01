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

const roomBedTypes = {
  'single': 'Giường đơn',
  'double': 'Giường đôi',
  'queen': 'Giường Queen',
  'king': 'Giường King',
  'twin': 'Hai giường đơn',
  'mixed': 'Kết hợp nhiều loại giường',
};

class RoomPhoto {
  const RoomPhoto({required this.id, required this.url});
  final int id;
  final String url;
  factory RoomPhoto.fromJson(Map<String, dynamic> json) =>
      RoomPhoto(id: json['id'] as int, url: json['url'] as String);
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
    this.description = '',
    this.area,
    this.bedType = '',
    this.bedCount,
    this.view = '',
    this.amenities = const [],
    this.images = const [],
    this.createdAt,
  });
  final int id, floor;
  final String number, condition, notes;
  final String displayStatus;
  final RoomType type;
  final DateTime? updatedAt;
  final bool active;
  final String description, bedType, view;
  final double? area;
  final int? bedCount;
  final List<String> amenities;
  final List<RoomPhoto> images;
  final DateTime? createdAt;
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
    description: json['description'] as String? ?? '',
    area: double.tryParse(json['area']?.toString() ?? ''),
    bedType: json['bed_type'] as String? ?? '',
    bedCount: json['bed_count'] as int?,
    view: json['view'] as String? ?? '',
    amenities: (json['amenities'] as List? ?? []).cast<String>(),
    images: (json['images'] as List? ?? [])
        .map((item) => RoomPhoto.fromJson(item as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
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
    this.category = 'other',
    this.description = '',
    this.notes = '',
    this.imageUrl,
    this.usageCount = 0,
    this.createdAt,
    this.updatedAt,
  });
  final int id, price;
  final String name, unit;
  final bool active, unitValid;
  final String category, description, notes;
  final String? imageUrl;
  final int usageCount;
  final DateTime? createdAt, updatedAt;
  bool get canDelete => usageCount == 0;
  factory HotelService.fromJson(Map<String, dynamic> json) => HotelService(
    id: json['id'] as int,
    name: json['name'] as String,
    unit: json['unit'] as String,
    price: int.parse(json['unit_price'].toString().split('.').first),
    active: json['is_active'] as bool,
    unitValid: json['unit_valid'] as bool? ?? true,
    category: json['category'] as String? ?? 'other',
    description: json['description'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    imageUrl: json['image_url'] as String?,
    usageCount: json['usage_count'] as int? ?? 0,
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
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
    this.planned = false,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason = '',
  });
  final int id, serviceId, price, quantity, total;
  final String name, unit, status, createdBy, cancelReason;
  final bool planned;
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
    planned: json['planned'] as bool? ?? false,
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
    this.bookingStatus,
    this.blockedReason = '',
  });
  final List<ServiceUsage> items;
  final int count, roomTotal, serviceTotal, estimatedTotal;
  final bool hasNext, canEdit;
  final String? bookingStatus;
  final String blockedReason;
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
    bookingStatus: json['booking_status'] as String?,
    blockedReason: json['blocked_reason'] as String? ?? '',
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
    this.canViewRevenue = false,
  });
  final DateTime date;
  final int total, ready, cleaning, maintenance;
  final int occupied, reserved, arrivals, departures, guests;
  final List<HotelBooking> todayBookings;
  final bool canViewRevenue;
  final List<FloorSummary> floors;
  final List<HotelRoom> attention;
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final counts = json['rooms'] as Map<String, dynamic>;
    return DashboardData(
      date: DateTime.parse(json['date'] as String),
      canViewRevenue:
          (json['capabilities'] as Map?)?['revenue_estimate'] == true,
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

typedef RoomQuery = ({
  String search,
  String condition,
  int? floor,
  int? roomType,
  int page,
});
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
    this.checkedOutAt,
    this.estimatedTotal,
    this.checkInRecordRecovered = false,
    this.roomSegments = const [],
    this.roomMoves = const [],
    this.createdAt,
  });
  final int id, customerId, guests, nightlyRate, total;
  final String code, customerName, status, statusLabel;
  final HotelRoom room;
  final DateTime start, end;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final int? estimatedTotal;
  final bool checkInRecordRecovered;
  final List<RoomAllocation> roomSegments;
  final List<RoomMoveHistory> roomMoves;
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
      estimatedTotal: int.tryParse(
        json['estimated_total']?.toString().split('.').first ?? '',
      ),
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      checkedInAt: json['checked_in_at'] == null
          ? null
          : DateTime.parse(json['checked_in_at'] as String),
      checkInRecordRecovered:
          json['check_in_record_recovered'] as bool? ?? false,
      roomSegments: (json['room_segments'] as List? ?? [])
          .map((row) => RoomAllocation.fromJson(row as Map<String, dynamic>))
          .toList(),
      roomMoves: (json['room_moves'] as List? ?? [])
          .map((row) => RoomMoveHistory.fromJson(row as Map<String, dynamic>))
          .toList(),
      checkedOutAt: DateTime.tryParse(json['checked_out_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class RoomAllocation {
  const RoomAllocation({
    required this.number,
    required this.type,
    required this.start,
    required this.end,
    required this.nights,
    required this.rate,
    required this.total,
  });
  final String number, type;
  final DateTime start, end;
  final int nights, rate, total;
  factory RoomAllocation.fromJson(Map<String, dynamic> json) => RoomAllocation(
    number: json['room_number'] as String,
    type: json['room_type'] as String,
    start: DateTime.parse(json['start_date'] as String),
    end: DateTime.parse(json['end_date'] as String),
    nights: json['nights'] as int,
    rate: int.parse(json['nightly_rate'].toString()),
    total: int.parse(json['total'].toString()),
  );
}

class RoomMoveHistory {
  const RoomMoveHistory({
    required this.from,
    required this.to,
    required this.oldRate,
    required this.newRate,
    required this.reason,
    required this.actor,
    required this.condition,
    required this.priceMode,
    required this.effectiveDate,
    required this.createdAt,
  });
  final String from, to, reason, actor, condition, priceMode;
  final int oldRate, newRate;
  final DateTime effectiveDate, createdAt;
  factory RoomMoveHistory.fromJson(Map<String, dynamic> json) =>
      RoomMoveHistory(
        from: json['from_number'] as String,
        to: json['to_number'] as String,
        oldRate: int.parse(json['old_rate'].toString()),
        newRate: int.parse(json['new_rate'].toString()),
        reason: json['reason'] as String,
        actor: json['created_by'] as String,
        condition: json['old_room_condition'] as String,
        priceMode: json['price_mode'] as String,
        effectiveDate: DateTime.parse(json['effective_date'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class TimelineBooking {
  const TimelineBooking({
    required this.id,
    required this.code,
    required this.customerName,
    required this.customerId,
    required this.status,
    required this.statusLabel,
    required this.startDate,
    required this.endDate,
    required this.guests,
    required this.isStart,
    required this.isEnd,
  });
  final int id, customerId, guests;
  final String code, customerName, status, statusLabel, startDate, endDate;
  final bool isStart, isEnd;

  factory TimelineBooking.fromJson(Map<String, dynamic> json) =>
      TimelineBooking(
        id: json['id'] as int,
        code: json['code'] as String,
        customerName: json['customer_name'] as String,
        customerId: json['customer_id'] as int,
        status: json['status'] as String,
        statusLabel: json['status_label'] as String,
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String,
        guests: json['guests'] as int,
        isStart: json['is_start'] as bool? ?? false,
        isEnd: json['is_end'] as bool? ?? false,
      );
}

class TimelineCell {
  const TimelineCell({required this.date, required this.status, this.booking});
  final String date;
  final String status;
  final TimelineBooking? booking;

  factory TimelineCell.fromJson(Map<String, dynamic> json) => TimelineCell(
    date: json['date'] as String,
    status: json['status'] as String,
    booking: json['booking'] == null
        ? null
        : TimelineBooking.fromJson(json['booking'] as Map<String, dynamic>),
  );
}

class RoomTimeline {
  const RoomTimeline({
    required this.id,
    required this.number,
    required this.floor,
    required this.typeName,
    required this.rate,
    required this.condition,
    required this.schedule,
  });
  final int id, floor, rate;
  final String number, typeName, condition;
  final List<TimelineCell> schedule;

  factory RoomTimeline.fromJson(Map<String, dynamic> json) => RoomTimeline(
    id: json['id'] as int,
    number: json['number'] as String,
    floor: json['floor'] as int,
    typeName: json['type_name'] as String,
    rate: json['rate'] as int,
    condition: json['condition'] as String,
    schedule: (json['schedule'] as List)
        .map((c) => TimelineCell.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

class TimelineData {
  const TimelineData({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.dates,
    required this.rooms,
  });
  final String startDate, endDate;
  final int days;
  final List<String> dates;
  final List<RoomTimeline> rooms;

  factory TimelineData.fromJson(Map<String, dynamic> json) => TimelineData(
    startDate: json['start_date'] as String,
    endDate: json['end_date'] as String,
    days: json['days'] as int,
    dates: (json['dates'] as List).map((d) => d as String).toList(),
    rooms: (json['rooms'] as List)
        .map((r) => RoomTimeline.fromJson(r as Map<String, dynamic>))
        .toList(),
  );
}
