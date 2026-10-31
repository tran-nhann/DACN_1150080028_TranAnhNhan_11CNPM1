import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/features/auth/login_screen.dart';
import 'package:aster_hotel/features/bookings/booking_form.dart';
import 'package:aster_hotel/features/bookings/bookings_screen.dart';
import 'package:aster_hotel/features/customers/customers_screen.dart';
import 'package:aster_hotel/features/dashboard/dashboard_screen.dart';
import 'package:aster_hotel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
    final fonts = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await fonts.load();
  });

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    StubAuth? auth,
    StubApi? api,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => auth ?? StubAuth(admin)),
          apiProvider.overrideWithValue(api ?? StubApi()),
        ],
        child: MaterialApp(
          theme: asterTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: tester.view.physicalSize / tester.view.devicePixelRatio,
              textScaler: TextScaler.linear(scale),
            ),
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Login validates empty fields and submits trimmed username', (
    tester,
  ) async {
    final auth = StubAuth(null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, const LoginScreen(), auth: auth);
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tài khoản.'), findsOneWidget);
    expect(auth.submittedUsername, isNull);
    await tester.enterText(find.byKey(const Key('login_username')), ' admin ');
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'Password!123456',
    );
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(auth.submittedUsername, 'admin');
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('Dashboard fits width $width with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, const DashboardScreen(), scale: 1.3);
      expect(find.byKey(const Key('ready_count')), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('/ 30 phòng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Booking preserves quote and idempotency key after failed submission',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = StubApi()..failure = 'Phòng đã được đặt. Chọn phòng khác.';
      await mount(tester, const BookingForm(), api: api);
      await tester.tap(find.byKey(const Key('booking_next')));
      await tester.pumpAndSettle();
      expect(find.text('Chọn khách hàng.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('booking_guest')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sampleGuest.name));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('booking_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('select_room_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('booking_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('booking_next')));
      await tester.pumpAndSettle();
      expect(find.text(api.failure!), findsOneWidget);
      expect(find.text(sampleGuest.name), findsOneWidget);
      await tester.tap(find.byKey(const Key('booking_next')));
      await tester.pumpAndSettle();
      expect(api.bookingKeys, hasLength(2));
      expect(api.bookingKeys[0], api.bookingKeys[1]);
      expect(api.bookingBodies[0], api.bookingBodies[1]);
      expect(api.bookingBodies[0]['expected_nightly_rate'], sampleType.rate);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('New booking clears the previous status filter and search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = StubApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => StubAuth(admin)),
          apiProvider.overrideWithValue(api),
        ],
        child: const AsterApp(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(DashboardScreen)))
        .go('/bookings?status=checked_in');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Không liên quan');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(api.bookingQueries.last.status, 'checked_in');
    expect(api.bookingQueries.last.search, 'Không liên quan');
    await tester.tap(find.byTooltip('Đặt phòng mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking_guest')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(sampleGuest.name));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('select_room_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking_next')));
    await tester.pumpAndSettle();
    expect(find.byType(BookingsScreen), findsOneWidget);
    expect(api.bookingQueries.last.status, 'confirmed');
    expect(api.bookingQueries.last.search, '');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.text(sampleGuest.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manager can read bookings but has no action buttons', (
    tester,
  ) async {
    await mount(
      tester,
      Scaffold(body: BookingDetail(booking: sampleBooking())),
      auth: StubAuth(manager),
    );
    expect(find.text(sampleGuest.name), findsOneWidget);
    expect(find.byKey(const Key('booking_primary')), findsNothing);
    expect(find.text('Hủy đặt phòng'), findsNothing);
    expect(find.text('Gia hạn'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Check-in asks confirmation and updates booking state', (
    tester,
  ) async {
    final api = StubApi();
    await mount(
      tester,
      Scaffold(body: BookingDetail(booking: sampleBooking())),
      api: api,
    );
    await tester.ensureVisible(find.byKey(const Key('booking_primary')));
    await tester.tap(find.byKey(const Key('booking_primary')));
    await tester.pumpAndSettle();
    expect(api.actions, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Nhận phòng').last);
    await tester.pumpAndSettle();
    expect(api.actions, ['check-in']);
    expect(find.text('Đang ở'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Nhận phòng'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Guest form validates phone and preserves input after server failure',
    (tester) async {
      final api = StubApi()..failure = 'Máy chủ tạm thời không phản hồi.';
      await mount(
        tester,
        const Scaffold(body: SingleChildScrollView(child: GuestForm())),
        api: api,
      );
      await tester.enterText(
        find.byKey(const Key('guest_name')),
        'Nguyễn Minh An',
      );
      await tester.enterText(find.byKey(const Key('guest_phone')), 'abc');
      await tester.ensureVisible(find.byKey(const Key('guest_save')));
      await tester.tap(find.byKey(const Key('guest_save')));
      await tester.pumpAndSettle();
      expect(find.text('Nhập số điện thoại gồm 9–15 chữ số.'), findsOneWidget);
      expect(api.savedGuests, 0);
      await tester.enterText(
        find.byKey(const Key('guest_phone')),
        '0901234567',
      );
      await tester.ensureVisible(find.byKey(const Key('guest_save')));
      await tester.tap(find.byKey(const Key('guest_save')));
      await tester.pumpAndSettle();
      expect(find.text('Máy chủ tạm thời không phản hồi.'), findsOneWidget);
      expect(find.text('Nguyễn Minh An'), findsOneWidget);
      expect(api.savedGuests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Manager cannot navigate to customers or see customer navigation',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => StubAuth(manager)),
            apiProvider.overrideWithValue(StubApi()),
          ],
          child: const AsterApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Khách hàng'), findsNothing);
      final context = tester.element(find.byType(DashboardScreen));
      GoRouter.of(context).go('/customers');
      await tester.pumpAndSettle();
      expect(find.byType(CustomersScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
