import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/core/widgets.dart';
import 'package:aster_hotel/features/bookings/booking_form.dart';
import 'package:aster_hotel/features/bookings/booking_timing.dart';
import 'package:aster_hotel/features/bookings/bookings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

class ManyRoomsApi extends StubApi {
  @override
  Future<PagedResult<HotelRoom>> availability(AvailabilityQuery query) async =>
      PagedResult(
        items: List.generate(
          30,
          (index) => HotelRoom(
            id: index + 1,
            number: '${101 + index}',
            floor: 1,
            type: sampleType,
            condition: 'ready',
            notes: '',
          ),
        ),
        count: 30,
        hasNext: false,
      );
}

HotelBooking datedBooking(DateTime start, {String status = 'confirmed'}) =>
    HotelBooking(
      id: 1,
      code: 'BK-TIMING',
      room: sampleRoom,
      customerId: 1,
      customerName: sampleGuest.name,
      start: start,
      end: start.add(const Duration(days: 1)),
      guests: 2,
      nightlyRate: 950000,
      total: 950000,
      status: status,
      statusLabel: status,
    );

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  test(
    'Arrival timing respects calendar boundaries and terminal booking states',
    () {
      final today = DateTime(2026, 12, 31, 23, 55);
      final now = BookingTiming.forBooking(
        datedBooking(DateTime(2026, 12, 31)),
        today,
      );
      final tomorrow = BookingTiming.forBooking(
        datedBooking(DateTime(2027, 1, 1)),
        today,
      );
      final future = BookingTiming.forBooking(
        datedBooking(DateTime(2027, 1, 3)),
        today,
      );
      final late = BookingTiming.forBooking(
        datedBooking(DateTime(2026, 12, 30)),
        today,
      );
      expect(now.label, 'Đến hôm nay');
      expect(tomorrow.label, 'Đến ngày mai');
      expect(future.label, 'Còn 3 ngày');
      expect(late.label, 'Trễ ngày nhận');
      expect({
        now.color,
        tomorrow.color,
        future.color,
        late.color,
      }, hasLength(4));
      for (final state in ['cancelled', 'checked_out', 'checked_in']) {
        expect(
          BookingTiming.forBooking(
            datedBooking(today, status: state),
            today,
          ).label,
          isNull,
        );
      }
    },
  );

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(ManyRoomsApi()),
          authProvider.overrideWith(() => StubAuth(admin)),
        ],
        child: MaterialApp(
          theme: asterTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> details(
    WidgetTester tester, {
    double scale = 1,
    String status = 'confirmed',
  }) async {
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            child: const Text('Mở'),
            onPressed: () => showAsterSheet<void>(
              context: context,
              builder: (_) =>
                  BookingDetail(booking: sampleBooking(status: status)),
            ),
          ),
        ),
      ),
      scale: scale,
    );
    await press(tester, find.text('Mở'));
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Reschedule save stays visible through a long list and keyboard at scale $scale',
      (tester) async {
        await details(tester, scale: scale);
        await press(tester, find.byTooltip('Thao tác khác'));
        await press(tester, find.text('Đổi lịch / phòng'));
        await press(tester, find.byKey(const Key('reschedule_room_1')));
        final save = find.byKey(const Key('reschedule_save'));
        final before = tester.getRect(save);
        expect(before.bottom, lessThan(700));
        final scroll = find
            .ancestor(
              of: find.byKey(const Key('reschedule_room_1')),
              matching: find.byType(SingleChildScrollView),
            )
            .first;
        await tester.drag(scroll, const Offset(0, -1000));
        await tester.pumpAndSettle();
        expect(tester.getRect(save), before);
        tester.view.physicalSize = const Size(480, 320);
        tester.view.viewInsets = const FakeViewPadding(bottom: 100);
        await tester.pumpAndSettle();
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(220));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'New booking keeps primary action fixed at each step and above keyboard',
    (tester) async {
      await mount(tester, const BookingForm());
      final next = find.byKey(const Key('booking_next'));
      final before = tester.getRect(next);
      await press(tester, find.byKey(const Key('booking_guest')));
      await press(tester, find.text(sampleGuest.name));
      await press(tester, next);
      await press(tester, find.byKey(const Key('select_room_1')));
      final scroll = find
          .ancestor(
            of: find.byKey(const Key('select_room_1')),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      await tester.drag(scroll, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(tester.getRect(next), before);
      await press(tester, next);
      expect(tester.getRect(next), before);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(tester.getRect(next).bottom, lessThanOrEqualTo(440));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Extension confirmation keeps action pinned while details scroll',
    (tester) async {
      await details(tester, status: 'checked_in', scale: 2);
      await press(tester, find.widgetWithText(OutlinedButton, 'Gia hạn'));
      await press(tester, find.text('OK'));
      final confirm = find.byKey(const Key('confirm_action'));
      final before = tester.getRect(confirm);
      expect(before.bottom, lessThan(700));
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(confirm), before);
      expect(tester.takeException(), isNull);
    },
  );
}
