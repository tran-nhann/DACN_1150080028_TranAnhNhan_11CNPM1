import 'package:aster_hotel/core/api.dart';
import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';

class MemorySessionStore implements SessionStore {
  String? token;
  @override
  Future<String?> readRefresh() async => token;
  @override
  Future<void> writeRefresh(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

const admin = StaffUser(
  id: 1,
  username: 'admin',
  name: 'Anh Nhân',
  role: 'admin',
  roleLabel: 'Quản trị viên',
);
const manager = StaffUser(
  id: 2,
  username: 'manager',
  name: 'Quản lý',
  role: 'manager',
  roleLabel: 'Quản lý',
);
const sampleType = RoomType(
  id: 1,
  name: 'Deluxe',
  description: 'Hướng thành phố',
  capacity: 2,
  rate: 950000,
);
const sampleRoom = HotelRoom(
  id: 1,
  number: '101',
  floor: 1,
  type: sampleType,
  condition: 'ready',
  notes: '',
);
const sampleGuest = Guest(
  id: 1,
  name: 'Nguyễn Minh An',
  phone: '0901234567',
  email: '',
  notes: '',
);

HotelBooking sampleBooking({String status = 'confirmed'}) => HotelBooking(
  id: 1,
  code: 'BK-TEST',
  room: sampleRoom,
  customerId: 1,
  customerName: sampleGuest.name,
  start: DateTime(2026, 10, 14),
  end: DateTime(2026, 10, 15),
  guests: 1,
  nightlyRate: sampleType.rate,
  total: sampleType.rate,
  status: status,
  statusLabel: status == 'checked_in' ? 'Đang ở' : 'Đã đặt',
);

class StubAuth extends AuthController {
  StubAuth(this.user);
  final StaffUser? user;
  String? submittedUsername;
  @override
  AuthState build() => AuthState(user: user);
  @override
  Future<void> login(String username, String password) async {
    submittedUsername = username;
  }
}

class StubApi extends ApiClient {
  StubApi() : super(store: MemorySessionStore());
  int savedGuests = 0;
  @override
  Future<List<ServiceUnit>> serviceUnits() async => const [
    ServiceUnit(value: 'chai', label: 'Chai', example: 'Nước suối'),
    ServiceUnit(value: 'suất', label: 'Suất', example: 'Ăn sáng'),
    ServiceUnit(value: 'kg', label: 'kg', example: 'Giặt ủi theo cân'),
    ServiceUnit(value: 'lượt', label: 'Lượt', example: 'Đưa đón'),
  ];
  @override
  Future<PagedResult<HotelService>> services(ServiceQuery query) async =>
      const PagedResult(items: [], count: 0, hasNext: false);
  @override
  Future<StayServices> stayServices(StayServiceQuery query) async =>
      StayServices(
        items: const [],
        count: 0,
        hasNext: false,
        roomTotal: sampleType.rate,
        serviceTotal: 0,
        estimatedTotal: sampleType.rate,
        canEdit: true,
      );
  final lookups = <BookingLookup>[];
  @override
  Future<Guest> guest(int id) async => sampleGuest;
  @override
  Future<PagedResult<HotelBooking>> lookupBookings(BookingLookup query) async {
    lookups.add(query);
    final items = query.customerId == 99 || query.roomId == 99
        ? <HotelBooking>[]
        : [sampleBooking()];
    return PagedResult(items: items, count: items.length, hasNext: false);
  }

  final bookingKeys = <String>[];
  final bookingBodies = <Map<String, dynamic>>[];
  final actions = <String>[];
  final bookingQueries = <BookingQuery>[];
  String? failure;
  @override
  Future<DashboardData> dashboard() async => DashboardData(
    date: DateTime(2026, 10, 14),
    total: 30,
    ready: 21,
    cleaning: 6,
    maintenance: 3,
    floors: const [FloorSummary(floor: 1, total: 10, ready: 7)],
    attention: const [],
  );
  @override
  Future<PagedResult<HotelRoom>> rooms(RoomQuery query) async =>
      const PagedResult(items: [sampleRoom], count: 1, hasNext: false);
  @override
  Future<PagedResult<Guest>> guests(GuestQuery query) async =>
      const PagedResult(items: [sampleGuest], count: 1, hasNext: false);
  @override
  Future<PagedResult<HotelRoom>> availability(AvailabilityQuery query) async =>
      const PagedResult(items: [sampleRoom], count: 1, hasNext: false);
  @override
  Future<PagedResult<HotelBooking>> bookings(BookingQuery query) async {
    bookingQueries.add(query);
    final items = query.status.isNotEmpty && query.status != 'confirmed'
        ? <HotelBooking>[]
        : [sampleBooking()];
    return PagedResult(items: items, count: items.length, hasNext: false);
  }

  @override
  Future<HotelBooking> createBooking(
    Map<String, dynamic> data,
    String key,
  ) async {
    bookingKeys.add(key);
    bookingBodies.add(Map.of(data));
    if (failure != null) throw ApiFailure(failure!);
    return sampleBooking();
  }

  @override
  Future<HotelBooking> bookingAction(
    int id,
    String action, [
    Map<String, dynamic>? data,
  ]) async {
    actions.add(action);
    if (failure != null) throw ApiFailure(failure!);
    return sampleBooking(
      status: action == 'check-in' ? 'checked_in' : 'confirmed',
    );
  }

  @override
  Future<Guest> saveGuest(Map<String, dynamic> guest, {int? id}) async {
    if (failure != null) throw ApiFailure(failure!);
    savedGuests++;
    return Guest(
      id: id ?? 100,
      name: guest['full_name'] as String,
      phone: guest['phone'] as String,
      email: guest['email'] as String,
      notes: guest['notes'] as String,
    );
  }
}
