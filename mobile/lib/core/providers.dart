import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'models.dart';

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);
final apiProvider = Provider<ApiClient>((ref) {
  final api = ApiClient(store: ref.watch(sessionStoreProvider));
  api.onExpired = () => ref.read(authProvider.notifier).expire();
  return api;
});

class AuthState {
  const AuthState({
    this.user,
    this.restoring = false,
    this.busy = false,
    this.error,
  });
  final StaffUser? user;
  final bool restoring, busy;
  final String? error;
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(restore);
    return const AuthState(restoring: true);
  }

  Future<void> restore() async {
    final store = ref.read(sessionStoreProvider);
    try {
      if (await store.readRefresh() == null) {
        state = const AuthState();
        return;
      }
      final api = ref.read(apiProvider);
      await api.refresh();
      state = AuthState(user: await api.me());
    } catch (error) {
      if (error is! DioException || error.response != null) await store.clear();
      state = const AuthState(
        error: 'Không thể khôi phục phiên. Vui lòng đăng nhập lại.',
      );
    }
  }

  Future<void> login(String username, String password) async {
    if (state.busy) return;
    state = const AuthState(busy: true);
    try {
      state = AuthState(
        user: await ref.read(apiProvider).login(username, password),
      );
    } catch (error) {
      state = AuthState(error: error.toString());
    }
  }

  void expire() {
    _clearData();
    state = const AuthState(
      error: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    );
  }

  Future<bool> logout() async {
    final revoked = await ref.read(apiProvider).logout();
    _clearData();
    state = const AuthState();
    return revoked;
  }

  void _clearData() {
    ref.invalidate(servicesProvider);
    ref.invalidate(serviceUnitsProvider);
    ref.invalidate(stayServicesProvider);
    ref.invalidate(bookingLookupProvider);
    ref.invalidate(guestDetailProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(roomsProvider);
    ref.invalidate(guestsProvider);
    ref.invalidate(roomTypesProvider);
    ref.invalidate(bookingsProvider);
    ref.invalidate(availabilityProvider);
  }
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>(
  (ref) => ref.watch(apiProvider).dashboard(),
);
final roomsProvider = FutureProvider.autoDispose
    .family<PagedResult<HotelRoom>, RoomQuery>(
      (ref, query) => ref.watch(apiProvider).rooms(query),
    );
final guestsProvider = FutureProvider.autoDispose
    .family<PagedResult<Guest>, GuestQuery>(
      (ref, query) => ref.watch(apiProvider).guests(query),
    );
final roomTypesProvider = FutureProvider.autoDispose<List<RoomType>>(
  (ref) => ref.watch(apiProvider).roomTypes(),
);

final bookingsProvider = FutureProvider.autoDispose
    .family<PagedResult<HotelBooking>, BookingQuery>(
      (ref, query) => ref.watch(apiProvider).bookings(query),
    );
final availabilityProvider = FutureProvider.autoDispose
    .family<PagedResult<HotelRoom>, AvailabilityQuery>(
      (ref, query) => ref.watch(apiProvider).availability(query),
    );

void refreshBookings(WidgetRef ref) {
  ref.invalidate(stayServicesProvider);
  ref.invalidate(bookingLookupProvider);
  ref.invalidate(bookingsProvider);
  ref.invalidate(availabilityProvider);
  refreshRooms(ref);
}

final bookingLookupProvider = FutureProvider.autoDispose
    .family<PagedResult<HotelBooking>, BookingLookup>(
      (ref, query) => ref.watch(apiProvider).lookupBookings(query),
    );

final guestDetailProvider = FutureProvider.autoDispose.family<Guest, int>(
  (ref, id) => ref.watch(apiProvider).guest(id),
);

void refreshRooms(WidgetRef ref) {
  ref.invalidate(roomsProvider);
  ref.invalidate(dashboardProvider);
}

final servicesProvider = FutureProvider.autoDispose
    .family<PagedResult<HotelService>, ServiceQuery>(
      (ref, query) => ref.watch(apiProvider).services(query),
    );

final serviceUnitsProvider = FutureProvider.autoDispose<List<ServiceUnit>>(
  (ref) => ref.watch(apiProvider).serviceUnits(),
);
final stayServicesProvider = FutureProvider.autoDispose
    .family<StayServices, StayServiceQuery>(
      (ref, query) => ref.watch(apiProvider).stayServices(query),
    );
