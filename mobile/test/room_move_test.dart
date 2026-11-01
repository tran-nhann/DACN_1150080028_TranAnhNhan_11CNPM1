import 'dart:async';

import 'package:aster_hotel/core/api.dart';
import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/room_move_models.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/core/widgets.dart';
import 'package:aster_hotel/features/bookings/bookings_screen.dart';
import 'package:aster_hotel/features/bookings/room_move_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

const targetRoom = HotelRoom(
  id: 2,
  number: '202',
  floor: 2,
  type: RoomType(
    id: 2,
    name: 'Suite',
    description: '',
    capacity: 4,
    rate: 1250000,
  ),
  condition: 'ready',
  notes: '',
);

class MoveApi extends StubApi {
  int availabilityReads = 0;
  @override
  Future<PagedResult<HotelRoom>> availability(AvailabilityQuery query) {
    availabilityReads++;
    return super.availability(query);
  }

  final payloads = <Map<String, dynamic>>[], keys = <String>[];
  final previews = <Map<String, dynamic>>[];
  bool failOptions = false, empty = false, failCommit = false;
  Completer<HotelBooking>? pending;
  HotelBooking current({bool moved = false}) => HotelBooking(
    id: 1,
    code: 'BK-MOVE',
    room: moved ? targetRoom : sampleRoom,
    customerId: 1,
    customerName: sampleGuest.name,
    start: DateTime(2026, 10, 30),
    end: DateTime(2026, 11, 2),
    guests: 2,
    nightlyRate: moved ? 1250000 : 950000,
    total: moved ? 3450000 : 2850000,
    status: 'checked_in',
    statusLabel: 'Đang ở',
  );
  @override
  Future<RoomMoveOptions> roomMoveOptions(int id) async {
    if (failOptions) throw const ApiFailure('Không tải được phòng trống.');
    return RoomMoveOptions(
      date: DateTime(2026, 10, 31),
      policy: 'Giá mới tính từ đêm của ngày chuyển.',
      rooms: empty ? [] : [targetRoom],
    );
  }

  @override
  Future<RoomMoveQuote> roomMoveQuote(int id, Map<String, dynamic> data) async {
    previews.add(Map.of(data));
    final rate = data['price_mode'] == 'keep' ? 950000 : 1250000;
    return RoomMoveQuote(
      token: 'quote-${previews.length}',
      date: DateTime(2026, 10, 31),
      from: '101',
      to: '202',
      oldRate: 950000,
      newRate: rate,
      nights: 2,
      oldTotal: 2850000,
      newTotal: 950000 + rate * 2,
      difference: (rate - 950000) * 2,
      services: 30000,
      total: 980000 + rate * 2,
      policy: 'Giá mới tính từ đêm của ngày chuyển.',
    );
  }

  @override
  Future<HotelBooking> moveRoom(
    int id,
    Map<String, dynamic> data,
    String key,
  ) async {
    payloads.add(Map.of(data));
    keys.add(key);
    if (pending != null) return pending!.future;
    if (failCommit) throw const ApiFailure('Mất kết nối.');
    return current(moved: true);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));
  Future<void> mount(
    WidgetTester tester,
    MoveApi api,
    Widget child, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          authProvider.overrideWith(() => StubAuth(admin)),
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
                  form: true,
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
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester) async {
    await press(tester, find.byKey(const Key('move_room_2')));
    await tester.ensureVisible(find.byKey(const Key('move_reason')));
    await tester.enterText(
      find.byKey(const Key('move_reason')),
      'Máy lạnh hỏng',
    );
    await press(tester, find.byKey(const Key('move_preview')));
  }

  testWidgets(
    'Occupied detail exposes fixed Room move and returns the new room after confirmation',
    (tester) async {
      final api = MoveApi();
      HotelBooking? updated;
      await mount(
        tester,
        api,
        BookingDetail(
          booking: api.current(),
          onUpdated: (value) => updated = value,
        ),
      );
      expect(
        api.availabilityReads,
        0,
        reason: 'Hidden rescheduling must not query past booking dates.',
      );
      await press(tester, find.byKey(const Key('booking_move_room')));
      expect(find.byType(RoomMovePanel), findsOneWidget);
      await choose(tester);
      expect(find.text('Xác nhận chuyển phòng'), findsNWidgets(2));
      expect(
        find.textContaining('600.000', findRichText: true),
        findsOneWidget,
      );
      expect(api.payloads, isEmpty);
      await press(tester, find.byKey(const Key('move_confirm')));
      expect(api.payloads.single['reason'], 'Máy lạnh hỏng');
      expect(api.payloads.single['quote_token'], 'quote-1');
      expect(updated?.room.number, '202');
      expect(find.text('Phòng 202'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Keep price and maintenance choices are included and a reason is required',
    (tester) async {
      final api = MoveApi();
      await mount(
        tester,
        api,
        RoomMovePanel(booking: api.current(), onBack: () {}, onMoved: (_) {}),
      );
      await press(tester, find.byKey(const Key('move_room_2')));
      await press(tester, find.byKey(const Key('move_preview')));
      expect(find.text('Nhập lý do chuyển phòng.'), findsOneWidget);
      expect(api.previews, isEmpty);
      await press(tester, find.byKey(const Key('move_price_mode')));
      await press(tester, find.text('Giữ giá hiện tại').last);
      await press(tester, find.byKey(const Key('move_old_condition')));
      await press(tester, find.text('Bảo trì').last);
      await choose(tester);
      expect(api.previews.single['price_mode'], 'keep');
      expect(api.previews.single['old_room_condition'], 'maintenance');
      await press(tester, find.byKey(const Key('move_confirm')));
      expect(api.payloads.single['price_mode'], 'keep');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Network retry keeps exact key and quote; changing selection requires a new preview',
    (tester) async {
      final api = MoveApi()..failCommit = true;
      await mount(
        tester,
        api,
        RoomMovePanel(booking: api.current(), onBack: () {}, onMoved: (_) {}),
      );
      await choose(tester);
      await press(tester, find.byKey(const Key('move_confirm')));
      expect(find.text('Mất kết nối.'), findsOneWidget);
      await press(tester, find.byKey(const Key('move_confirm')));
      expect(api.keys[0], api.keys[1]);
      expect(api.payloads[0], api.payloads[1]);
      await press(tester, find.byKey(const Key('move_edit')));
      expect(find.byKey(const Key('move_confirm')), findsNothing);
      await choose(tester);
      await press(tester, find.byKey(const Key('move_confirm')));
      expect(api.keys.last, isNot(api.keys.first));
      expect(api.payloads.last['quote_token'], 'quote-2');
    },
  );

  testWidgets('In-flight transfer locks form, Back and duplicate submissions', (
    tester,
  ) async {
    final api = MoveApi()..pending = Completer<HotelBooking>();
    int backs = 0;
    await mount(
      tester,
      api,
      RoomMovePanel(
        booking: api.current(),
        onBack: () => backs++,
        onMoved: (_) {},
      ),
    );
    await choose(tester);
    await tester.tap(find.byKey(const Key('move_confirm')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('move_confirm')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('move_edit')))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(backs, 0);
    expect(api.payloads.length, 1);
    api.pending!.complete(api.current(moved: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Options failure shows manual retry and empty catalog cannot continue',
    (tester) async {
      final api = MoveApi()..failOptions = true;
      await mount(
        tester,
        api,
        RoomMovePanel(booking: api.current(), onBack: () {}, onMoved: (_) {}),
      );
      expect(find.text('Không tải được phòng trống.'), findsOneWidget);
      api.failOptions = false;
      api.empty = true;
      await press(tester, find.widgetWithText(OutlinedButton, 'Thử lại'));
      expect(find.text('Chưa có phòng phù hợp'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('move_preview')))
            .onPressed,
        isNull,
      );
    },
  );

  for (final size in [const Size(320, 568), const Size(480, 320)]) {
    testWidgets('Room move preview and confirmation fit $size at double text', (
      tester,
    ) async {
      final api = MoveApi();
      await mount(
        tester,
        api,
        RoomMovePanel(booking: api.current(), onBack: () {}, onMoved: (_) {}),
        size: size,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      await choose(tester);
      expect(
        tester.getBottomLeft(find.byKey(const Key('move_confirm'))).dy,
        lessThanOrEqualTo(size.height),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
