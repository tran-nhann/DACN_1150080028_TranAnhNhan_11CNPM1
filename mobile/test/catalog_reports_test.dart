import 'dart:typed_data';

import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/revenue_models.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/core/widgets.dart';
import 'package:aster_hotel/features/dashboard/revenue_report.dart';
import 'package:aster_hotel/features/rooms/rooms_screen.dart';
import 'package:aster_hotel/features/services/service_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

const suite = RoomType(
  id: 2,
  name: 'Suite',
  description: '',
  capacity: 4,
  rate: 1850000,
);
const service = HotelService(
  id: 7,
  name: 'Giặt ủi',
  unit: 'kg',
  price: 30000,
  category: 'laundry',
  description: 'Giặt theo cân',
  notes: 'Nhận trước 18 giờ',
);

class CatalogApi extends StubApi {
  final roomQueries = <RoomQuery>[];
  final revenueQueries = <RevenueQuery>[];
  final serviceWrites = <Map<String, dynamic>>[];
  final deleted = <int>[];
  @override
  Future<List<RoomType>> roomTypes() async => [sampleType, suite];
  @override
  Future<DashboardData> dashboard() async => DashboardData(
    date: DateTime(2026, 10, 31),
    total: 2,
    ready: 2,
    cleaning: 0,
    maintenance: 0,
    floors: const [
      FloorSummary(floor: 1, total: 1, ready: 1),
      FloorSummary(floor: 2, total: 1, ready: 1),
    ],
    attention: const [],
  );
  @override
  Future<PagedResult<HotelRoom>> rooms(RoomQuery query) async {
    roomQueries.add(query);
    return const PagedResult(items: [sampleRoom], count: 1, hasNext: false);
  }

  @override
  Future<HotelService> saveService(
    Map<String, dynamic> data, {
    int? id,
    Uint8List? image,
  }) async {
    serviceWrites.add(Map.of(data));
    return HotelService(
      id: id!,
      name: data['name'] as String,
      unit: data['unit'] as String,
      price: int.parse(data['unit_price'] as String),
      category: data['category'] as String,
      description: data['description'] as String,
      notes: data['notes'] as String,
      active: data['is_active'] as bool,
    );
  }

  @override
  Future<void> deleteService(int id) async => deleted.add(id);
  @override
  Future<RevenueEstimate> revenueEstimate(RevenueQuery query) async {
    revenueQueries.add(query);
    final start = DateTime.parse(query.start), end = DateTime.parse(query.end);
    return RevenueEstimate(
      start: start,
      end: end,
      roomTotal: 1100000,
      serviceTotal: 30000,
      total: 1130000,
      confirmedTotal: 300000,
      stayTotal: 800000,
      bookingCount: 2,
      roomNights: 3,
      serviceCount: 1,
      types: const [RevenueType(name: 'Suite', total: 1130000)],
      daily: List.generate(
        end.difference(start).inDays,
        (index) => RevenueDay(
          date: start.add(Duration(days: index)),
          total: index == 0 ? 1130000 : 0,
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));
  Future<CatalogApi> mount(
    WidgetTester tester,
    Widget child, {
    bool sheet = true,
    StaffUser user = admin,
    Size size = const Size(480, 1000),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = CatalogApi();
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
            body: sheet
                ? Builder(
                    builder: (context) => FilledButton(
                      onPressed: () => showAsterSheet<void>(
                        context: context,
                        form: true,
                        builder: (_) => child,
                      ),
                      child: const Text('Mở'),
                    ),
                  )
                : child,
          ),
        ),
      ),
    );
    if (sheet) await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    return api;
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
    'Room filters combine type, floor and status, then clear together',
    (tester) async {
      final api = await mount(tester, const RoomsScreen(), sheet: false);
      await press(tester, find.byKey(const ValueKey('filter_type_null')));
      await press(tester, find.text('Suite').last);
      await press(tester, find.byKey(const ValueKey('filter_floor_null')));
      await press(tester, find.text('Tầng 2').last);
      await press(tester, find.widgetWithText(ChoiceChip, 'Sẵn sàng'));
      expect(api.roomQueries.last.roomType, 2);
      expect(api.roomQueries.last.floor, 2);
      expect(api.roomQueries.last.condition, 'ready');
      expect(api.roomQueries.last.page, 1);
      await press(tester, find.text('Xóa bộ lọc'));
      expect(api.roomQueries.last.roomType, isNull);
      expect(api.roomQueries.last.floor, isNull);
      expect(api.roomQueries.last.condition, '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Service profile edits metadata and returns to updated detail', (
    tester,
  ) async {
    final api = await mount(tester, const ServiceDetail(service: service));
    await press(tester, find.byKey(const Key('service_edit')));
    await tester.ensureVisible(find.byKey(const Key('catalog_description')));
    await tester.enterText(
      find.byKey(const Key('catalog_description')),
      'Mô tả mới',
    );
    await tester.ensureVisible(find.byKey(const Key('catalog_notes')));
    await tester.enterText(
      find.byKey(const Key('catalog_notes')),
      'Giao buổi chiều',
    );
    await press(tester, find.byKey(const Key('catalog_save')));
    expect(api.serviceWrites.single['category'], 'laundry');
    expect(api.serviceWrites.single['description'], 'Mô tả mới');
    expect(api.serviceWrites.single['notes'], 'Giao buổi chiều');
    expect(find.text('Chi tiết dịch vụ'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unused service requires confirmation before deleting', (
    tester,
  ) async {
    final api = await mount(tester, const ServiceDetail(service: service));
    await press(tester, find.byKey(const Key('service_delete')));
    expect(api.deleted, isEmpty);
    await press(tester, find.widgetWithText(FilledButton, 'Xóa dịch vụ'));
    expect(api.deleted, [7]);
    expect(find.byType(ServiceDetail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Used service keeps edit but blocks delete; manager has read-only profile',
    (tester) async {
      await mount(
        tester,
        const ServiceDetail(
          service: HotelService(
            id: 7,
            name: 'Giặt ủi',
            unit: 'kg',
            price: 30000,
            usageCount: 2,
          ),
        ),
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('service_delete')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('service_edit')))
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      await mount(tester, const ServiceDetail(service: service), user: manager);
      expect(find.byKey(const Key('service_edit')), findsNothing);
      expect(find.byKey(const Key('service_delete')), findsNothing);
    },
  );

  testWidgets(
    'Revenue presets use exclusive end dates and show estimate breakdown',
    (tester) async {
      final api = await mount(
        tester,
        RevenueReport(initialDate: DateTime(2026, 10, 31)),
      );
      expect(api.revenueQueries.last, (start: '2026-10-01', end: '2026-11-01'));
      expect(find.text('1.130.000 ₫'), findsWidgets);
      await press(tester, find.text('7 ngày'));
      expect(api.revenueQueries.last, (start: '2026-10-25', end: '2026-11-01'));
      await press(tester, find.text('Hôm nay'));
      expect(api.revenueQueries.last, (start: '2026-10-31', end: '2026-11-01'));
      await tester.ensureVisible(find.byType(RevenueBars));
      expect(find.byType(RevenueBars), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(480, 320)]) {
    testWidgets(
      'Catalog profile and revenue chart fit $size with double text',
      (tester) async {
        await mount(
          tester,
          const ServiceDetail(service: service),
          size: size,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        await press(tester, find.byKey(const Key('service_edit')));
        await tester.ensureVisible(find.byKey(const Key('catalog_notes')));
        expect(tester.takeException(), isNull);
        expect(
          tester.getBottomLeft(find.byKey(const Key('catalog_save'))).dy,
          lessThanOrEqualTo(size.height),
        );
        await tester.pumpWidget(const SizedBox());
        await mount(
          tester,
          RevenueReport(initialDate: DateTime(2026, 10, 31)),
          size: size,
          scale: 2,
        );
        await tester.ensureVisible(find.byType(RevenueBars));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
