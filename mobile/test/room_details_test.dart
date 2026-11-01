import 'dart:typed_data';

import 'package:aster_hotel/core/api.dart';
import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/core/widgets.dart';
import 'package:aster_hotel/features/rooms/room_form.dart';
import 'package:aster_hotel/features/rooms/rooms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

const detailedRoom = HotelRoom(
  id: 1,
  number: '101',
  floor: 1,
  type: sampleType,
  condition: 'ready',
  notes: 'Kiểm tra minibar',
  description: 'Phòng có ban công riêng',
  area: 32.5,
  bedType: 'queen',
  bedCount: 1,
  view: 'Vườn',
  amenities: ['Wi-Fi', 'Điều hòa'],
);

class RoomApi extends StubApi {
  final saved = <Map<String, dynamic>>[];
  int? savedId;
  @override
  Future<List<RoomType>> roomTypes() async => [sampleType];
  @override
  Future<HotelRoom> saveRoom(
    Map<String, dynamic> data, {
    int? id,
    List<Uint8List> images = const [],
  }) async {
    if (failure != null) {
      throw ApiFailure(failure!, fields: {'number': failure!});
    }
    saved.add(Map.of(data));
    savedId = id;
    return HotelRoom.fromJson({
      ...data,
      'id': id ?? 12,
      'condition': 'ready',
      'is_active': true,
      'images': [],
      'room_type': {
        'id': sampleType.id,
        'name': sampleType.name,
        'description': sampleType.description,
        'capacity': sampleType.capacity,
        'base_rate': sampleType.rate.toString(),
      },
    });
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));
  Future<RoomApi> open(
    WidgetTester tester,
    Widget child, {
    StaffUser user = admin,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = RoomApi();
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
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Admin edits complete room details and returns to updated profile',
    (tester) async {
      final api = await open(tester, const RoomDetail(room: detailedRoom));
      await press(tester, find.byTooltip('Sửa phòng'));
      expect(find.text('Sửa phòng'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('room_area')))
            .controller!
            .text,
        '32.5',
      );
      await tester.ensureVisible(find.byKey(const Key('room_description')));
      await tester.enterText(
        find.byKey(const Key('room_description')),
        'Mô tả đã cập nhật',
      );
      await tester.ensureVisible(find.byKey(const Key('room_area')));
      await tester.enterText(find.byKey(const Key('room_area')), '40,25');
      await tester.ensureVisible(find.byKey(const Key('room_amenities')));
      await tester.enterText(
        find.byKey(const Key('room_amenities')),
        'Wi-Fi, TV, Wi-Fi',
      );
      await press(tester, find.byKey(const Key('room_save')));
      expect(api.savedId, 1);
      expect(api.saved.single['area'], '40.25');
      expect(api.saved.single['amenities'], ['Wi-Fi', 'TV']);
      expect(api.saved.single['bed_type'], 'queen');
      expect(api.saved.single['bed_count'], 1);
      expect(find.text('Sửa phòng'), findsNothing);
      expect(find.text('Mô tả đã cập nhật'), findsOneWidget);
      expect(
        find.text('Diện tích: 40.25 m²', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Invalid input and server errors retain entered data', (
    tester,
  ) async {
    final api = await open(tester, const RoomForm(room: detailedRoom));
    await tester.ensureVisible(find.byKey(const Key('room_area')));
    await tester.enterText(find.byKey(const Key('room_area')), '0');
    await press(tester, find.byKey(const Key('room_save')));
    expect(find.text('Nhập diện tích từ 1 đến 9999,99 m².'), findsOneWidget);
    expect(api.saved, isEmpty);
    await tester.enterText(find.byKey(const Key('room_area')), '45');
    api.failure = 'Số phòng đã tồn tại';
    await press(tester, find.byKey(const Key('room_save')));
    expect(find.text('Số phòng đã tồn tại'), findsWidgets);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('room_area')))
          .controller!
          .text,
      '45',
    );
    api.failure = null;
    await press(tester, find.byKey(const Key('room_save')));
    expect(api.saved.single['area'], '45');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back from editing returns to room in the same sheet', (
    tester,
  ) async {
    await open(tester, const RoomDetail(room: detailedRoom));
    await press(tester, find.byTooltip('Sửa phòng'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sửa phòng'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manager cannot open room editor', (tester) async {
    await open(tester, const RoomDetail(room: detailedRoom), user: manager);
    expect(find.byTooltip('Sửa phòng'), findsNothing);
  });

  testWidgets('Editor fits a narrow screen with double text size', (
    tester,
  ) async {
    await open(tester, const RoomForm(room: detailedRoom), scale: 2);
    for (final key in [
      'room_description',
      'room_bed_type',
      'room_notes',
      'room_save',
    ]) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: key);
    }
  });
}
