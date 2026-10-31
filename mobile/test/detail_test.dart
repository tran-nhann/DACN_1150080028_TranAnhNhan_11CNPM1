import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/core/widgets.dart';
import 'package:aster_hotel/features/bookings/booking_history.dart';
import 'package:aster_hotel/features/bookings/bookings_screen.dart';
import 'package:aster_hotel/features/customers/customers_screen.dart';
import 'package:aster_hotel/features/rooms/rooms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi'));
  Future<StubApi> open(
    WidgetTester tester,
    Widget child, {
    StaffUser user = admin,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = StubApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          authProvider.overrideWith(() => StubAuth(user)),
        ],
        child: MaterialApp(
          theme: asterTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showAsterSheet<void>(
                  context: context,
                  builder: (_) => child,
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Booking shows identity, historical rate and dates with primary action visible',
    (tester) async {
      final booking = HotelBooking(
        id: 7,
        code: 'BK-QUOTE',
        room: sampleRoom,
        customerId: 1,
        customerName: sampleGuest.name,
        start: DateTime(2026, 10, 14),
        end: DateTime(2026, 10, 17),
        guests: 2,
        nightlyRate: 450000,
        total: 1350000,
        status: 'confirmed',
        statusLabel: 'Đã đặt',
        createdAt: DateTime.utc(2026, 10, 1, 8),
      );
      await open(tester, BookingDetail(booking: booking));
      expect(find.text('BK-QUOTE'), findsOneWidget);
      expect(find.text('${money(450000)} × 3 đêm'), findsOneWidget);
      expect(find.text(money(1350000)), findsOneWidget);
      expect(find.text('14/10/2026'), findsOneWidget);
      expect(find.text('17/10/2026'), findsOneWidget);
      expect(
        tester.getBottomRight(find.byKey(const Key('booking_primary'))).dy,
        lessThan(700),
      );
      await press(tester, find.byKey(const Key('booking_guest_profile')));
      expect(find.text('Hồ sơ khách'), findsOneWidget);
      expect(find.text(sampleGuest.phone), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      await press(tester, find.byTooltip('Sửa khách hàng'));
      await tester.enterText(
        find.byKey(const Key('guest_name')),
        'Tên đã cập nhật',
      );
      await press(tester, find.byKey(const Key('guest_save')));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('BK-QUOTE'), findsOneWidget);
      expect(find.text('Tên đã cập nhật'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Guest history and editor return to same profile in one sheet', (
    tester,
  ) async {
    final api = await open(tester, const GuestDetail(guest: sampleGuest));
    expect(api.lookups.last.customerId, sampleGuest.id);
    expect(find.text(sampleGuest.phone), findsOneWidget);
    await press(tester, find.byType(BookingCard));
    expect(find.text('BK-TEST'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ khách'), findsOneWidget);
    await press(tester, find.byTooltip('Sửa khách hàng'));
    await tester.enterText(find.byKey(const Key('guest_name')), 'Khách đã sửa');
    await press(tester, find.byKey(const Key('guest_save')));
    expect(find.text('Khách đã sửa'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    await press(tester, find.byTooltip('Đóng'));
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Room history is scoped and Back returns to the room', (
    tester,
  ) async {
    final api = await open(tester, const RoomDetail(room: sampleRoom));
    expect(api.lookups.last.roomId, sampleRoom.id);
    await press(tester, find.byType(BookingCard));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Vận hành'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Daily list passes exact day and kind instead of generic status',
    (tester) async {
      final api = await open(
        tester,
        DailyBookings(kind: 'departures', day: DateTime(2026, 10, 15)),
      );
      expect(api.lookups.last.kind, 'departures');
      expect(api.lookups.last.day, '2026-10-15');
      await press(tester, find.byType(BookingCard));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Khách đi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Manager sees booking without customer profile or operations', (
    tester,
  ) async {
    await open(tester, BookingDetail(booking: sampleBooking()), user: manager);
    expect(find.byKey(const Key('booking_guest_profile')), findsNothing);
    expect(find.byKey(const Key('booking_primary')), findsNothing);
    expect(find.byTooltip('Thao tác khác'), findsNothing);
    expect(find.text('BK-TEST'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Entity details fit narrow width with large text', (
    tester,
  ) async {
    for (final child in [
      const GuestDetail(guest: sampleGuest),
      const RoomDetail(room: sampleRoom),
      BookingDetail(booking: sampleBooking()),
    ]) {
      await open(tester, child, scale: 2);
      expect(
        tester.takeException(),
        isNull,
        reason: child.runtimeType.toString(),
      );
      await tester.pumpWidget(const SizedBox());
    }
  });
}
