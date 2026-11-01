import 'package:aster_hotel/core/api.dart';
import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/features/services/services_screen.dart';
import 'package:aster_hotel/features/services/stay_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

const water = HotelService(
  id: 1,
  name: 'Nước suối',
  unit: 'chai',
  price: 15000,
);
const invalid = HotelService(
  id: 2,
  name: 'Chưa chọn đơn vị',
  unit: '-',
  price: 20000,
  unitValid: false,
);
const inactive = HotelService(
  id: 3,
  name: 'Đã ngừng',
  unit: 'kg',
  price: 30000,
  active: false,
);
HotelBooking staying() => HotelBooking(
  id: 11,
  code: 'BK-ROOM-101',
  room: sampleRoom,
  customerId: 1,
  customerName: sampleGuest.name,
  start: DateTime(2026, 10, 30),
  end: DateTime(2026, 11, 1),
  guests: 1,
  nightlyRate: 950000,
  total: 1900000,
  status: 'checked_in',
  statusLabel: 'Đang ở',
);

class ApplyApi extends StubApi {
  final queries = <BookingQuery>[], keys = <String>[];
  final writes = <({int bookingId, Map<String, dynamic> data})>[];
  List<ServiceUsage> usages = [];
  bool noGuests = false, closed = false, failFirst = false;
  @override
  Future<PagedResult<HotelService>> services(ServiceQuery query) async {
    final items = [water, invalid, inactive]
        .where(
          (service) => query.active == null || service.active == query.active,
        )
        .toList();
    return PagedResult(items: items, count: items.length, hasNext: false);
  }

  @override
  Future<PagedResult<HotelBooking>> bookings(BookingQuery query) async {
    queries.add(query);
    expect(query.status, 'checked_in');
    final items =
        noGuests ||
            (query.search.isNotEmpty &&
                !'101 ${sampleGuest.name}'.contains(query.search))
        ? <HotelBooking>[]
        : [staying()];
    return PagedResult(items: items, count: items.length, hasNext: false);
  }

  @override
  Future<ServiceUsage> addServiceUsage(
    int bookingId,
    Map<String, dynamic> data,
    String key,
  ) async {
    keys.add(key);
    writes.add((bookingId: bookingId, data: Map.of(data)));
    if (closed) throw const ApiFailure('Lưu trú đã kết thúc.');
    if (failFirst && keys.length == 1) throw const ApiFailure('Mất phản hồi.');
    final usage = ServiceUsage(
      id: 8,
      serviceId: water.id,
      name: water.name,
      unit: water.unit,
      price: water.price,
      quantity: data['quantity'] as int,
      total: water.price * (data['quantity'] as int),
      status: 'active',
      createdAt: DateTime(2026, 10, 31),
      createdBy: admin.name,
    );
    usages = [usage];
    return usage;
  }

  @override
  Future<StayServices> stayServices(StayServiceQuery query) async =>
      StayServices(
        items: usages,
        count: usages.length,
        hasNext: false,
        roomTotal: 1900000,
        serviceTotal: usages.fold(0, (sum, usage) => sum + usage.total),
        estimatedTotal:
            1900000 + usages.fold(0, (sum, usage) => sum + usage.total),
        canEdit: !closed,
      );
  @override
  Future<HotelService> getService(int id) async => HotelService(
    id: water.id,
    name: water.name,
    unit: water.unit,
    price: water.price,
    usageCount: usages.length,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));
  Future<ApplyApi> mount(
    WidgetTester tester, {
    Widget? child,
    ApplyApi? api,
    StaffUser user = admin,
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = api ?? ApplyApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(client),
          authProvider.overrideWith(() => StubAuth(user)),
        ],
        child: MaterialApp(
          theme: asterTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: child ?? const ServicesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return client;
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> chooseRoom(WidgetTester tester) async {
    await press(tester, find.byKey(const Key('apply_service_1')));
    await press(tester, find.byKey(const Key('apply_booking_11')));
  }

  testWidgets(
    'Catalog applies selected service to the chosen stay and shows its charges',
    (tester) async {
      final api = await mount(tester);
      await chooseRoom(tester);
      expect(find.byType(AddStayServiceForm), findsOneWidget);
      expect(find.text('Phòng 101 · ${sampleGuest.name}'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('usage_quantity')), '2');
      await press(tester, find.byKey(const Key('usage_save')));
      expect(api.writes.single.bookingId, 11);
      expect(api.writes.single.data, {
        'service_id': 1,
        'quantity': 2,
        'expected_unit_price': 15000,
      });
      expect(find.byType(StayServicesPanel), findsOneWidget);
      expect(
        find.textContaining('1.930.000', findRichText: true),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Apply uses only occupied bookings, supports search and no-stay feedback',
    (tester) async {
      final api = await mount(tester);
      await press(tester, find.byKey(const Key('apply_service_1')));
      await tester.enterText(find.byKey(const Key('apply_room_search')), '999');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(api.queries.last, (search: '999', status: 'checked_in', page: 1));
      expect(find.text('Không có phòng đang ở phù hợp'), findsOneWidget);
      expect(find.byKey(const Key('usage_save')), findsNothing);
      await tester.enterText(find.byKey(const Key('apply_room_search')), '101');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await press(tester, find.byKey(const Key('apply_booking_11')));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('apply_room_search')), findsOneWidget);
      expect(api.writes, isEmpty);
    },
  );

  testWidgets(
    'Missing units and stopped services block apply, manager has no apply action',
    (tester) async {
      await mount(tester);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('apply_service_2')))
            .onPressed,
        isNull,
      );
      await press(tester, find.widgetWithText(ChoiceChip, 'Tất cả'));
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('apply_service_3')))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await mount(tester, user: manager);
      expect(find.byKey(const Key('apply_service_1')), findsNothing);
    },
  );

  testWidgets(
    'Retry retains the selected room, service, quantity and request key',
    (tester) async {
      final api = ApplyApi()..failFirst = true;
      await mount(tester, api: api);
      await chooseRoom(tester);
      await tester.enterText(find.byKey(const Key('usage_quantity')), '2');
      await press(tester, find.byKey(const Key('usage_save')));
      expect(find.byKey(const Key('usage_error')), findsOneWidget);
      await press(tester, find.byKey(const Key('usage_save')));
      expect(api.keys, hasLength(2));
      expect(api.keys.first, api.keys.last);
      expect(api.writes.first.bookingId, api.writes.last.bookingId);
      expect(api.writes.first.data, api.writes.last.data);
    },
  );

  testWidgets(
    'Guest checks out while choosing service: display error without a false success',
    (tester) async {
      final api = await mount(tester);
      await chooseRoom(tester);
      api.closed = true;
      await press(tester, find.byKey(const Key('usage_save')));
      expect(find.text('Lưu trú đã kết thúc.'), findsOneWidget);
      expect(find.byType(StayServicesPanel), findsNothing);
      expect(api.usages, isEmpty);
    },
  );

  testWidgets('Service detail also applies and refreshes its usage count', (
    tester,
  ) async {
    final api = await mount(tester);
    await press(tester, find.byKey(const Key('service_1')));
    await press(tester, find.byKey(const Key('service_apply')));
    await press(tester, find.byKey(const Key('apply_booking_11')));
    await press(tester, find.byKey(const Key('usage_save')));
    expect(api.usages, hasLength(1));
    await press(tester, find.widgetWithText(TextButton, 'Quay lại'));
    expect(find.text('Chi tiết dịch vụ'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('service_delete')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(480, 320)]) {
    testWidgets(
      'Apply fits $size with double text and fixed action above keyboard',
      (tester) async {
        await mount(tester, size: size, scale: 2);
        await chooseRoom(tester);
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height > 400 ? 230 : 100,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final action = find.byKey(const Key('usage_save'));
        final before = tester.getRect(action);
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(action), before);
        expect(
          before.bottom,
          lessThanOrEqualTo(size.height - tester.view.viewInsets.bottom),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
