import 'package:aster_hotel/core/billing_models.dart';
import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/core/widgets.dart';
import 'package:aster_hotel/features/bookings/billing_panel.dart';
import 'package:aster_hotel/features/bookings/bookings_screen.dart';
import 'package:aster_hotel/features/dashboard/dashboard_screen.dart';
import 'package:aster_hotel/features/services/stay_services.dart';
import 'package:aster_hotel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

const water = HotelService(
  id: 1,
  name: 'Nước suối',
  unit: 'chai',
  price: 15000,
);

class LifecycleApi extends StubApi {
  String status = 'confirmed';
  final plans = <ServiceUsage>[], usages = <ServiceUsage>[];
  int converted = 0, cancelledPlans = 0;
  HotelBooking current() => HotelBooking(
    id: 1,
    code: 'BK-LIFECYCLE',
    room: sampleRoom,
    customerId: 1,
    customerName: sampleGuest.name,
    start: DateTime(2026, 10, 14),
    end: DateTime(2026, 10, 15),
    guests: 1,
    nightlyRate: 950000,
    total: 950000,
    status: status,
    statusLabel: status == 'confirmed' ? 'Đã đặt' : 'Đang ở',
    estimatedTotal: 950000 + total(status == 'confirmed' ? plans : usages),
  );
  int total(List<ServiceUsage> rows) => rows
      .where((row) => !row.cancelled)
      .fold(0, (sum, row) => sum + row.total);
  ServiceUsage row(
    int id,
    int quantity, {
    bool planned = false,
    bool cancelled = false,
  }) => ServiceUsage(
    id: id,
    serviceId: 1,
    name: water.name,
    unit: 'chai',
    price: 15000,
    quantity: quantity,
    total: 15000 * quantity,
    status: cancelled
        ? 'cancelled'
        : planned
        ? 'reserved'
        : 'active',
    planned: planned,
    createdAt: DateTime(2026, 10, 14),
    createdBy: admin.name,
    cancelReason: cancelled ? 'Không dùng' : '',
  );
  @override
  Future<PagedResult<HotelService>> services(ServiceQuery query) async =>
      const PagedResult(items: [water], count: 1, hasNext: false);
  @override
  Future<PagedResult<HotelBooking>> bookings(BookingQuery query) async =>
      PagedResult(items: [current()], count: 1, hasNext: false);
  @override
  Future<HotelBooking> createBooking(
    Map<String, dynamic> data,
    String key,
  ) async {
    bookingBodies.add(Map.of(data));
    bookingKeys.add(key);
    plans.clear();
    for (final line in data['services'] as List? ?? []) {
      plans.add(row(plans.length + 1, line['quantity'] as int, planned: true));
    }
    return current();
  }

  @override
  Future<ServiceUsage> addPlannedService(
    int bookingId,
    Map<String, dynamic> data,
    String key,
  ) async {
    final item = row(plans.length + 1, data['quantity'] as int, planned: true);
    plans.add(item);
    return item;
  }

  @override
  Future<ServiceUsage> addServiceUsage(
    int bookingId,
    Map<String, dynamic> data,
    String key,
  ) async {
    final item = row(usages.length + 11, data['quantity'] as int);
    usages.add(item);
    return item;
  }

  @override
  Future<ServiceUsage> cancelPlannedService(
    int bookingId,
    int planId,
    String reason,
  ) async {
    cancelledPlans++;
    final index = plans.indexWhere((line) => line.id == planId);
    return plans[index] = row(
      planId,
      plans[index].quantity,
      planned: true,
      cancelled: true,
    );
  }

  @override
  Future<StayServices> stayServices(StayServiceQuery query) async {
    final rows = status == 'confirmed' ? plans : usages;
    return StayServices(
      items: List.of(rows),
      count: rows.length,
      hasNext: false,
      roomTotal: 950000,
      serviceTotal: total(rows),
      estimatedTotal: 950000 + total(rows),
      canEdit: true,
      bookingStatus: status,
    );
  }

  @override
  Future<HotelBooking> bookingAction(
    int id,
    String action, [
    Map<String, dynamic>? data,
  ]) async {
    actions.add(action);
    if (action == 'check-in' && status == 'confirmed') {
      usages.addAll(
        plans
            .where((line) => !line.cancelled)
            .map((line) => row(line.id + 10, line.quantity)),
      );
      converted++;
      status = 'checked_in';
    }
    return current();
  }

  @override
  Future<BillingState> folio(int id) async => BillingState(
    folio: StayFolio(
      quote: '${usages.length}'.padLeft(64, 'a'),
      guest: sampleGuest.name,
      roomNumber: '101',
      start: current().start,
      end: current().end,
      roomTotal: 950000,
      serviceTotal: total(usages),
      total: 950000 + total(usages),
      canCheckout: true,
      blockedReason: '',
      policy: '',
      lines: [
        const BillLine(
          kind: 'room',
          name: 'Phòng 101',
          unit: 'đêm',
          quantity: 1,
          price: 950000,
          total: 950000,
        ),
        ...usages
            .where((line) => !line.cancelled)
            .map(
              (line) => BillLine(
                kind: 'service',
                name: line.name,
                unit: line.unit,
                quantity: line.quantity,
                price: line.price,
                total: line.total,
              ),
            ),
      ],
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));
  Future<LifecycleApi> mount(
    WidgetTester tester, {
    Widget? child,
    LifecycleApi? api,
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = api ?? LifecycleApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(client),
          authProvider.overrideWith(() => StubAuth(admin)),
        ],
        child: child == null
            ? const AsterApp()
            : MaterialApp(
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
    await tester.pumpAndSettle();
    if (child != null) {
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
    }
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

  testWidgets(
    'Choose service while choosing room, preserve on Back, submit cart and combined total',
    (tester) async {
      final api = await mount(tester);
      GoRouter.of(tester.element(find.byType(DashboardScreen)))
          .go('/bookings/new');
      await tester.pumpAndSettle();
      await press(tester, find.byKey(const Key('booking_guest')));
      await press(tester, find.text(sampleGuest.name));
      await press(tester, find.byKey(const Key('booking_next')));
      await press(tester, find.byKey(const Key('select_room_1')));
      await press(tester, find.byKey(const Key('booking_add_service')));
      await press(tester, find.byKey(const Key('service_1')));
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking_service_quantity_1')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('booking_service_quantity_1')),
        '2',
      );
      await press(tester, find.byKey(const Key('booking_next')));
      expect(find.text('980.000 ₫'), findsWidgets);
      await press(tester, find.byKey(const Key('review_edit_services')));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('booking_service_quantity_1')),
            )
            .initialValue,
        '2',
      );
      await press(tester, find.byKey(const Key('booking_next')));
      await press(tester, find.byKey(const Key('booking_next')));
      expect(api.bookingBodies.single['services'], [
        {'service_id': 1, 'quantity': 2, 'expected_unit_price': 15000},
      ]);
      expect(api.plans.single.quantity, 2);
      expect(api.usages, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Check-in reviews prebooked services, adds more and converts once',
    (tester) async {
      final api = LifecycleApi();
      api.plans.add(api.row(1, 2, planned: true));
      await mount(
        tester,
        child: BookingDetail(booking: api.current()),
        api: api,
      );
      await press(tester, find.byKey(const Key('booking_primary')));
      expect(find.text('Nhận phòng & dịch vụ'), findsOneWidget);
      expect(api.converted, 0);
      await press(tester, find.byKey(const Key('add_stay_service')));
      await press(tester, find.byKey(const Key('service_1')));
      await press(tester, find.byKey(const Key('usage_save')));
      expect(api.plans, hasLength(2));
      expect(api.usages, isEmpty);
      await press(tester, find.byKey(const Key('check_in_submit')));
      expect(api.converted, 1);
      expect(api.usages, hasLength(2));
      expect(api.total(api.usages), 45000);
      expect(find.widgetWithText(FilledButton, 'Trả phòng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancel a reserved item before arrival uses planned cancellation',
    (tester) async {
      final api = LifecycleApi();
      api.plans.add(api.row(1, 2, planned: true));
      await mount(
        tester,
        child: StayServicesPanel(booking: api.current(), onBack: () {}),
        api: api,
      );
      await press(tester, find.byKey(const Key('cancel_usage_1')));
      await tester.ensureVisible(find.byKey(const Key('usage_reason')));
      await tester.enterText(
        find.byKey(const Key('usage_reason')),
        'Không dùng',
      );
      await press(tester, find.byKey(const Key('usage_cancel_confirm')));
      expect(api.cancelledPlans, 1);
      expect(api.total(api.plans), 0);
      expect(api.usages, isEmpty);
    },
  );

  testWidgets(
    'Checkout edits services in place and clears old payment confirmation',
    (tester) async {
      final api = LifecycleApi()..status = 'checked_in';
      await mount(
        tester,
        child: BillingPanel(
          booking: api.current(),
          onBack: () {},
          onUpdated: (_) {},
        ),
        api: api,
      );
      await press(tester, find.byKey(const Key('checkout_method')));
      await press(tester, find.text('Tiền mặt').last);
      await press(tester, find.byKey(const Key('checkout_received')));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('checkout_received')),
            )
            .value,
        true,
      );
      await press(tester, find.byKey(const Key('folio_services_edit')));
      await press(tester, find.byKey(const Key('add_stay_service')));
      await press(tester, find.byKey(const Key('service_1')));
      await press(tester, find.byKey(const Key('usage_save')));
      await press(tester, find.widgetWithText(TextButton, 'Quay lại'));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('checkout_received')),
            )
            .value,
        false,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout_submit')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('965.000', findRichText: true), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(480, 320)]) {
    testWidgets('Check-in service review fits $size at double text', (
      tester,
    ) async {
      final api = LifecycleApi();
      api.plans.add(api.row(1, 2, planned: true));
      await mount(
        tester,
        child: StayServicesPanel(
          booking: api.current(),
          onBack: () {},
          onCheckedIn: (_) {},
        ),
        api: api,
        size: size,
        scale: 2,
      );
      expect(
        tester.getBottomLeft(find.byKey(const Key('check_in_submit'))).dy,
        lessThanOrEqualTo(size.height),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
