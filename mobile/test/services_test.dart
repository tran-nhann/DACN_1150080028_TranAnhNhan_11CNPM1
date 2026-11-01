import 'dart:typed_data';
import 'dart:async';

import 'package:aster_hotel/core/api.dart';
import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/core/widgets.dart';
import 'package:aster_hotel/features/bookings/bookings_screen.dart';
import 'package:aster_hotel/features/services/services_screen.dart';
import 'package:aster_hotel/features/services/stay_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

const laundry = HotelService(id: 1, name: 'Giặt ủi', unit: 'kg', price: 30000);
ServiceUsage usage({bool cancelled = false}) => ServiceUsage(
  id: 1,
  serviceId: 1,
  name: 'Giặt ủi',
  unit: 'kg',
  price: 30000,
  quantity: 2,
  total: 60000,
  status: cancelled ? 'cancelled' : 'active',
  createdAt: DateTime(2026, 10, 24, 9),
  createdBy: 'Minh Anh',
  cancelledAt: cancelled ? DateTime(2026, 10, 24, 10) : null,
  cancelledBy: cancelled ? 'Anh Nhân' : null,
  cancelReason: cancelled ? 'Nhập nhầm' : '',
);

class ServiceApi extends StubApi {
  final keys = <String>[];
  final bodies = <Map<String, dynamic>>[];
  final reasons = <String>[];
  List<ServiceUsage> usages = [];
  bool editable = true;
  ApiFailure? addError, saveError, cancelError;
  Completer<ServiceUsage>? pending;
  Completer<HotelService>? pendingCatalog;
  int catalogWrites = 0;
  final catalogData = <Map<String, dynamic>>[];
  ApiFailure? unitsError;
  @override
  Future<List<ServiceUnit>> serviceUnits() async {
    if (unitsError != null) throw unitsError!;
    return super.serviceUnits();
  }

  @override
  Future<PagedResult<HotelService>> services(ServiceQuery query) async =>
      const PagedResult(items: [laundry], count: 1, hasNext: false);
  @override
  Future<StayServices> stayServices(StayServiceQuery query) async {
    final total = usages
        .where((item) => !item.cancelled)
        .fold(0, (sum, item) => sum + item.total);
    return StayServices(
      items: usages,
      count: usages.length,
      hasNext: false,
      roomTotal: 950000,
      serviceTotal: total,
      estimatedTotal: 950000 + total,
      canEdit: editable,
    );
  }

  @override
  Future<ServiceUsage> addServiceUsage(
    int bookingId,
    Map<String, dynamic> data,
    String key,
  ) async {
    keys.add(key);
    bodies.add(Map.of(data));
    if (pending != null) return pending!.future;
    if (addError != null) throw addError!;
    final item = usage();
    usages = [item];
    return item;
  }

  @override
  Future<ServiceUsage> cancelServiceUsage(
    int bookingId,
    int usageId,
    String reason,
  ) async {
    reasons.add(reason);
    if (cancelError != null) throw cancelError!;
    final item = usage(cancelled: true);
    usages = [item];
    return item;
  }

  @override
  Future<HotelService> saveService(
    Map<String, dynamic> data, {
    int? id,
    Uint8List? image,
  }) async {
    catalogWrites++;
    catalogData.add(Map.of(data));
    if (pendingCatalog != null) return pendingCatalog!.future;
    if (saveError != null) throw saveError!;
    return laundry;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));
  Future<void> open(
    WidgetTester tester,
    ServiceApi api, {
    Widget? child,
    StaffUser user = admin,
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
                  builder: (_) =>
                      child ??
                      StayServicesPanel(
                        booking: sampleBooking(status: 'checked_in'),
                        onBack: () => Navigator.pop(context),
                      ),
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
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester) async {
    await press(tester, find.byKey(const Key('add_stay_service')));
    await press(tester, find.byKey(const Key('service_1')));
    await tester.enterText(find.byKey(const Key('usage_quantity')), '2');
  }

  testWidgets(
    'Service retry keeps quantity and same request key, updates totals',
    (tester) async {
      final api = ServiceApi()..addError = const ApiFailure('Mất kết nối.');
      await open(tester, api);
      await choose(tester);
      await press(tester, find.byKey(const Key('usage_save')));
      expect(find.text('Mất kết nối.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('usage_quantity')))
            .controller!
            .text,
        '2',
      );
      api.addError = null;
      await press(tester, find.byKey(const Key('usage_save')));
      expect(api.keys[0], api.keys[1]);
      expect(api.bodies[0], api.bodies[1]);
      expect(api.bodies.first['expected_unit_price'], 30000);
      expect(find.text(money(1010000)), findsOneWidget);
      expect(find.text('2 kg × ${money(30000)}'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Posting blocks duplicate, barrier, close and platform Back', (
    tester,
  ) async {
    final api = ServiceApi()..pending = Completer<ServiceUsage>();
    await open(tester, api);
    await choose(tester);
    await tester.ensureVisible(find.byKey(const Key('usage_save')));
    await tester.tap(find.byKey(const Key('usage_save')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('usage_save')));
    await tester.tapAt(const Offset(3, 3));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.keys, hasLength(1));
    expect(find.byType(AddStayServiceForm), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Đóng',
            ),
          )
          .onPressed,
      isNull,
    );
    api.pending!.complete(usage());
    await tester.pumpAndSettle();
    await press(tester, find.byTooltip('Đóng'));
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Selection and quantity survive Back and invalid quantity is blocked',
    (tester) async {
      final api = ServiceApi();
      await open(tester, api);
      await choose(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await press(tester, find.byKey(const Key('add_stay_service')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('usage_quantity')))
            .controller!
            .text,
        '2',
      );
      await tester.enterText(find.byKey(const Key('usage_quantity')), '0');
      await press(tester, find.byKey(const Key('usage_save')));
      expect(api.keys, isEmpty);
      expect(find.text('Chọn 1–999.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancellation requires reason, keeps it on error, retains cancelled history',
    (tester) async {
      final api = ServiceApi()
        ..usages = [usage()]
        ..cancelError = const ApiFailure('Thử lại.');
      await open(tester, api);
      await press(tester, find.byKey(const Key('cancel_usage_1')));
      await press(tester, find.byKey(const Key('usage_cancel_confirm')));
      expect(api.reasons, isEmpty);
      expect(find.text('Nhập lý do.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('usage_reason')),
        'Nhập nhầm',
      );
      await press(tester, find.byKey(const Key('usage_cancel_confirm')));
      expect(find.text('Thử lại.'), findsOneWidget);
      api.cancelError = null;
      await press(tester, find.byKey(const Key('usage_cancel_confirm')));
      expect(api.reasons, ['Nhập nhầm', 'Nhập nhầm']);
      expect(find.text('Đã hủy'), findsOneWidget);
      expect(find.text('Nhập nhầm'), findsOneWidget);
      expect(find.byKey(const Key('cancel_usage_1')), findsNothing);
      expect(find.text(money(950000)), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Manager and closed stay have no add or cancel controls', (
    tester,
  ) async {
    final api = ServiceApi()..usages = [usage()];
    await open(tester, api, user: manager);
    expect(find.byKey(const Key('add_stay_service')), findsNothing);
    expect(find.byKey(const Key('cancel_usage_1')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.editable = false;
    await open(tester, api);
    expect(find.byKey(const Key('add_stay_service')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Booking opens services in the same sheet and Back returns to booking',
    (tester) async {
      await open(
        tester,
        ServiceApi(),
        child: BookingDetail(booking: sampleBooking(status: 'checked_in')),
      );
      await press(tester, find.byKey(const Key('booking_services')));
      await choose(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add_stay_service')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('BK-TEST'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Catalog displays server field error without losing entered values',
    (tester) async {
      final api = ServiceApi()
        ..saveError = const ApiFailure(
          'Tên đã có.',
          fields: {'name': 'Tên đã có.'},
        );
      await open(tester, api, child: const ServiceForm());
      await tester.enterText(find.byKey(const Key('catalog_name')), 'Giặt ủi');
      await press(tester, find.byKey(const Key('catalog_unit')));
      await press(tester, find.text('kg').last);
      await tester.enterText(
        find.byKey(const Key('catalog_unit_price')),
        '30000',
      );
      await press(tester, find.byKey(const Key('catalog_save')));
      expect(find.text('Tên đã có.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('catalog_unit_price')))
            .controller!
            .text,
        '30000',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Unit must be selected from named choices and legacy invalid unit is corrected explicitly',
    (tester) async {
      final api = ServiceApi();
      await open(
        tester,
        api,
        child: const ServiceForm(
          service: HotelService(
            id: 5,
            name: 'Mục cũ',
            unit: '20.000',
            price: 20000,
            unitValid: false,
          ),
        ),
      );
      expect(
        find.text('Đơn vị cũ “20.000” không hợp lệ. Chọn lại.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('catalog_unit')),
            )
            .initialValue,
        isNull,
      );
      await press(tester, find.byKey(const Key('catalog_save')));
      expect(api.catalogWrites, 0);
      await press(tester, find.byKey(const Key('catalog_unit')));
      expect(find.text('Nước suối'), findsOneWidget);
      await press(tester, find.text('Chai').last);
      await press(tester, find.byKey(const Key('catalog_save')));
      expect(api.catalogData.single['unit'], 'chai');
      expect(api.catalogData.single['unit_price'], '20000');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unit load failure blocks save, retry keeps other form input', (
    tester,
  ) async {
    final api = ServiceApi()..unitsError = const ApiFailure('Mất kết nối.');
    await open(tester, api, child: const ServiceForm());
    await tester.enterText(find.byKey(const Key('catalog_name')), 'Ăn sáng');
    await tester.enterText(
      find.byKey(const Key('catalog_unit_price')),
      '60000',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('catalog_save')))
          .onPressed,
      isNull,
    );
    api.unitsError = null;
    await press(tester, find.text('Thử lại'));
    await press(tester, find.byKey(const Key('catalog_unit')));
    await press(tester, find.text('Suất').last);
    await press(tester, find.byKey(const Key('catalog_save')));
    expect(api.catalogData.single['name'], 'Ăn sáng');
    expect(api.catalogData.single['unit'], 'suất');
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(480, 320)]) {
    testWidgets('Service screens fit $size with double text and keyboard', (
      tester,
    ) async {
      for (final child in [
        const ServicesScreen(),
        const ServiceForm(),
        CancelUsageForm(
          bookingId: 1,
          usage: usage(),
          onBack: () {},
          onSaved: () {},
        ),
      ]) {
        await open(
          tester,
          ServiceApi(),
          child: child is ServicesScreen
              ? SingleChildScrollView(child: child)
              : child,
          size: size,
          scale: 2,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: child.runtimeType.toString(),
        );
        await tester.pumpWidget(const SizedBox());
      }
      await open(tester, ServiceApi(), size: size, scale: 2);
      await choose(tester);
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height > 400 ? 240 : 120,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('usage_save')));
      expect(tester.takeException(), isNull);
    });
  }
}
