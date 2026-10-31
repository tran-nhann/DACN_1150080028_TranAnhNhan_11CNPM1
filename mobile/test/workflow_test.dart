import 'dart:async';

import 'package:aster_hotel/core/api.dart';
import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/core/widgets.dart';
import 'package:aster_hotel/features/auth/login_screen.dart';
import 'package:aster_hotel/features/bookings/booking_form.dart';
import 'package:aster_hotel/features/bookings/bookings_screen.dart';
import 'package:aster_hotel/features/customers/customers_screen.dart';
import 'package:aster_hotel/features/dashboard/dashboard_screen.dart';
import 'package:aster_hotel/features/rooms/rooms_screen.dart';
import 'package:aster_hotel/features/profile/profile_screen.dart';
import 'package:aster_hotel/features/services/services_screen.dart';
import 'package:aster_hotel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';

import 'support.dart';

class FlowApi extends StubApi {
  final roomQueries = <RoomQuery>[];
  final actionData = <Map<String, dynamic>>[];
  int guestCalls = 0;
  Completer<Guest>? pendingGuest;
  Completer<HotelBooking>? pendingAction;
  Completer<HotelBooking>? pendingBooking;
  ApiFailure? guestError;
  bool manyBookings = false;
  bool actionFails = false;

  @override
  Future<PagedResult<HotelBooking>> bookings(BookingQuery query) async {
    bookingQueries.add(query);
    return PagedResult(
      items: List.generate(manyBookings ? 12 : 1, (i) => sampleBooking()),
      count: manyBookings ? 12 : 1,
      hasNext: false,
    );
  }

  @override
  Future<PagedResult<HotelRoom>> rooms(RoomQuery query) async {
    roomQueries.add(query);
    return const PagedResult(items: [sampleRoom], count: 1, hasNext: false);
  }

  @override
  Future<List<RoomType>> roomTypes() async => [sampleType];
  @override
  Future<Guest> saveGuest(Map<String, dynamic> data, {int? id}) async {
    guestCalls++;
    if (pendingGuest != null) return pendingGuest!.future;
    if (guestError != null) throw guestError!;
    return super.saveGuest(data, id: id);
  }

  @override
  Future<HotelBooking> bookingAction(
    int id,
    String action, [
    Map<String, dynamic>? data,
  ]) async {
    actions.add(action);
    actionData.add(data ?? {});
    if (pendingAction != null) return pendingAction!.future;
    if (actionFails) throw const ApiFailure('Phòng không còn trống.');
    return sampleBooking(
      status: action == 'cancel'
          ? 'cancelled'
          : action == 'check-in'
          ? 'checked_in'
          : 'confirmed',
    );
  }

  @override
  Future<HotelBooking> createBooking(
    Map<String, dynamic> data,
    String key,
  ) async {
    if (pendingBooking == null) return super.createBooking(data, key);
    bookingBodies.add(Map.of(data));
    bookingKeys.add(key);
    return pendingBooking!.future;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    FlowApi? api,
    bool app = false,
    double scale = 1,
    bool reduced = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => StubAuth(admin)),
          apiProvider.overrideWithValue(api ?? FlowApi()),
        ],
        child: app
            ? const AsterApp()
            : MaterialApp(
                theme: asterTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: reduced,
                  ),
                  child: child!,
                ),
                home:
                    child is Scaffold ||
                        child is BookingForm ||
                        child is LoginScreen
                    ? child
                    : Scaffold(body: child),
              ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openGuestPicker(WidgetTester tester) async =>
      press(tester, find.byKey(const Key('booking_guest')));

  Future<void> review(WidgetTester tester) async {
    await openGuestPicker(tester);
    await press(tester, find.text(sampleGuest.name));
    await press(tester, find.byKey(const Key('booking_next')));
    await press(tester, find.byKey(const Key('select_room_1')));
    await press(tester, find.byKey(const Key('booking_next')));
  }

  Future<void> openDetails(WidgetTester tester, {FlowApi? api}) async {
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAsterSheet<void>(
              context: context,
              builder: (_) => BookingDetail(booking: sampleBooking()),
            ),
            child: const Text('Mở'),
          ),
        ),
      ),
      api: api,
    );
    await press(tester, find.text('Mở'));
  }

  testWidgets(
    'More child screens return using visible Back, platform Back and tab reselect',
    (tester) async {
      await mount(tester, const SizedBox(), app: true);
      await press(tester, find.widgetWithText(NavigationDestination, 'Thêm'));
      await press(tester, find.text('Khách hàng'));
      expect(
        GoRouter.of(tester.element(find.byType(CustomersScreen))).canPop(),
        isTrue,
      );
      await press(tester, find.byTooltip('Thêm khách hàng'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CustomersScreen), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await press(tester, find.byTooltip('Quay lại Thêm'));
      expect(find.byType(ProfileScreen), findsOneWidget);
      await press(tester, find.text('Dịch vụ'));
      expect(find.byType(ServicesScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await press(tester, find.text('Khách hàng'));
      await tester.enterText(find.byType(TextField), 'Minh');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await press(tester, find.widgetWithText(NavigationDestination, 'Phòng'));
      await press(tester, find.widgetWithText(NavigationDestination, 'Thêm'));
      expect(find.byType(CustomersScreen), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Minh',
      );
      await press(tester, find.widgetWithText(NavigationDestination, 'Thêm'));
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Legacy More URLs have parent pages and hardware Back returns to More',
    (tester) async {
      await mount(tester, const SizedBox(), app: true);
      final router = GoRouter.of(tester.element(find.byType(DashboardScreen)));
      for (final path in ['/customers', '/services']) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.canPop(), isTrue, reason: path);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget, reason: path);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Switching tabs retains search, filters and scroll position', (
    tester,
  ) async {
    final api = FlowApi()..manyBookings = true;
    await mount(tester, const SizedBox(), api: api, app: true);
    await press(
      tester,
      find.widgetWithText(NavigationDestination, 'Đặt phòng'),
    );
    await tester.enterText(find.byType(TextField), 'An');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await press(tester, find.widgetWithText(ChoiceChip, 'Đang ở'));
    final scrollFinder = find
        .descendant(
          of: find.byType(BookingsScreen),
          matching: find.byType(Scrollable),
        )
        .last;
    await tester.drag(scrollFinder, const Offset(0, -360));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(scrollFinder)
        .position
        .pixels;
    expect(position, greaterThan(0));
    await press(tester, find.widgetWithText(NavigationDestination, 'Phòng'));
    await press(
      tester,
      find.widgetWithText(NavigationDestination, 'Đặt phòng'),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'An',
    );
    expect(api.bookingQueries.last.status, 'checked_in');
    expect(
      tester.state<ScrollableState>(scrollFinder).position.pixels,
      closeTo(position, .1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard applies filter and Customers stays under More', (
    tester,
  ) async {
    final api = FlowApi();
    await mount(tester, const SizedBox(), api: api, app: true);
    await press(tester, find.text('Cần dọn'));
    expect(api.roomQueries.last.condition, 'cleaning');
    await tester.enterText(find.byType(TextField), '101');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await press(tester, find.widgetWithText(ChoiceChip, 'Sẵn sàng'));
    await press(tester, find.widgetWithText(NavigationDestination, 'Hôm nay'));
    await press(tester, find.text('Cần dọn'));
    expect(api.roomQueries.last.condition, 'cleaning');
    expect(api.roomQueries.last.search, '');
    await press(tester, find.widgetWithText(NavigationDestination, 'Thêm'));
    await press(tester, find.text('Khách hàng'));
    expect(find.byType(CustomersScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    await press(tester, find.widgetWithText(NavigationDestination, 'Hôm nay'));
    await press(tester, find.widgetWithText(NavigationDestination, 'Thêm'));
    expect(find.byType(CustomersScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Review edits and platform Back preserve booking choices', (
    tester,
  ) async {
    await mount(tester, const BookingForm());
    await review(tester);
    await press(tester, find.byKey(const Key('review_edit_details')));
    expect(find.text(sampleGuest.name), findsOneWidget);
    await press(tester, find.byKey(const Key('booking_next')));
    expect(
      tester
          .widget<Icon>(
            find
                .descendant(
                  of: find.byKey(const Key('select_room_1')),
                  matching: find.byType(Icon),
                )
                .last,
          )
          .icon,
      Icons.check_circle,
    );
    await press(tester, find.byKey(const Key('booking_next')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('select_room_1')), findsOneWidget);
    await press(tester, find.byTooltip('Quay lại').last);
    expect(find.text(sampleGuest.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Adding a guest uses one sheet and preserves draft/search', (
    tester,
  ) async {
    final api = FlowApi();
    await mount(tester, const BookingForm(), api: api);
    await openGuestPicker(tester);
    await tester.enterText(find.byType(TextField), 'An');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await press(tester, find.byTooltip('Thêm khách hàng'));
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.enterText(find.byKey(const Key('guest_name')), 'Khách mới');
    await tester.enterText(find.byKey(const Key('guest_phone')), '0901234999');
    await press(tester, find.byTooltip('Quay lại').last);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'An',
    );
    await press(tester, find.byTooltip('Thêm khách hàng'));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('guest_name')))
          .controller!
          .text,
      'Khách mới',
    );
    await press(tester, find.byKey(const Key('guest_save')));
    expect(find.byType(BottomSheet), findsOneWidget);
    await press(tester, find.byKey(const Key('pick_guest_100')));
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Khách mới'), findsOneWidget);
    expect(api.guestCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saving guest blocks barrier, swipe, Back and duplicate submit', (
    tester,
  ) async {
    final api = FlowApi()..pendingGuest = Completer<Guest>();
    await mount(tester, const BookingForm(), api: api);
    await openGuestPicker(tester);
    await press(tester, find.byTooltip('Thêm khách hàng'));
    await tester.enterText(find.byKey(const Key('guest_name')), 'Khách mới');
    await tester.enterText(find.byKey(const Key('guest_phone')), '0901234999');
    await tester.ensureVisible(find.byKey(const Key('guest_save')));
    await tester.tap(find.byKey(const Key('guest_save')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('guest_save')));
    await tester.tapAt(const Offset(5, 5));
    await tester.binding.handlePopRoute();
    await tester.dragFrom(
      tester.getTopLeft(find.byType(GuestForm)) + const Offset(50, 8),
      const Offset(0, 500),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GuestForm), findsOneWidget);
    expect(api.guestCalls, 1);
    api.pendingGuest!.complete(
      const Guest(
        id: 100,
        name: 'Khách mới',
        phone: '0901234999',
        email: '',
        notes: '',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick_guest_100')), findsOneWidget);
    await press(tester, find.byTooltip('Đóng'));
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Server field error appears at phone and preserves values', (
    tester,
  ) async {
    final api = FlowApi()
      ..guestError = const ApiFailure(
        'Điện thoại đã tồn tại.',
        fields: {'phone': 'Điện thoại đã tồn tại.'},
      );
    await mount(tester, const Scaffold(body: GuestForm()), api: api);
    await tester.enterText(find.byKey(const Key('guest_name')), 'Minh An');
    await tester.enterText(find.byKey(const Key('guest_phone')), '0901234567');
    await press(tester, find.byKey(const Key('guest_save')));
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('guest_phone')),
              matching: find.byType(TextField),
            ),
          )
          .decoration!
          .errorText,
      'Điện thoại đã tồn tại.',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('guest_name')))
          .controller!
          .text,
      'Minh An',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reschedule is inside detail sheet and survives failed save', (
    tester,
  ) async {
    final api = FlowApi()..actionFails = true;
    await openDetails(tester, api: api);
    await press(tester, find.byTooltip('Thao tác khác'));
    await press(tester, find.text('Đổi lịch / phòng'));
    expect(find.byType(BottomSheet), findsOneWidget);
    await press(tester, find.byKey(const Key('reschedule_room_1')));
    await press(tester, find.byKey(const Key('reschedule_save')));
    expect(find.text('Phòng không còn trống.'), findsOneWidget);
    expect(api.actionData.single.containsKey('expected_nightly_rate'), isFalse);
    await press(tester, find.byTooltip('Quay lại'));
    await press(tester, find.byTooltip('Thao tác khác'));
    await press(tester, find.text('Đổi lịch / phòng'));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('reschedule_save')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancellation confirmation stays in sheet and sends only once', (
    tester,
  ) async {
    final api = FlowApi()..pendingAction = Completer<HotelBooking>();
    await openDetails(tester, api: api);
    await press(tester, find.byTooltip('Thao tác khác'));
    await press(tester, find.text('Hủy đặt phòng'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('confirm_action')));
    await tester.tap(find.byKey(const Key('confirm_action')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm_action')));
    await tester.tapAt(const Offset(5, 5));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.actions, ['cancel']);
    expect(find.byType(BottomSheet), findsOneWidget);
    api.pendingAction!.complete(sampleBooking(status: 'cancelled'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking_primary')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Booking submission locks edit controls and preserves retry key',
    (tester) async {
      final api = FlowApi()..pendingBooking = Completer<HotelBooking>();
      await mount(tester, const BookingForm(), api: api);
      await review(tester);
      await tester.tap(find.byKey(const Key('booking_next')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('review_edit_details')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('booking_next')));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(api.bookingKeys, hasLength(1));
      api.pendingBooking!.completeError(const ApiFailure('Thử lại.'));
      await tester.pumpAndSettle();
      api.pendingBooking = Completer<HotelBooking>();
      await tester.tap(find.byKey(const Key('booking_next')));
      await tester.pump();
      expect(api.bookingKeys[0], api.bookingKeys[1]);
      expect(api.bookingBodies[0], api.bookingBodies[1]);
      api.pendingBooking!.completeError(const ApiFailure('Thử lại.'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reduced motion disables sheet and pressed-button animation', (
    tester,
  ) async {
    await mount(tester, const BookingForm(), reduced: true);
    await openGuestPicker(tester);
    final sheetContext = tester.element(find.byType(GuestPicker));
    expect(ModalRoute.of(sheetContext)!.transitionDuration, Duration.zero);
    await press(tester, find.byTooltip('Đóng'));
    final pointer = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('booking_next'))),
    );
    await tester.pump();
    expect(
      tester
          .widget<AnimatedScale>(
            find
                .ancestor(
                  of: find.byKey(const Key('booking_next')),
                  matching: find.byType(AnimatedScale),
                )
                .first,
          )
          .scale,
      1,
    );
    await pointer.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sheet form scrolls above keyboard in portrait and landscape', (
    tester,
  ) async {
    await mount(tester, const BookingForm(), scale: 2);
    await openGuestPicker(tester);
    await press(tester, find.byTooltip('Thêm khách hàng'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('guest_phone')));
    await tester.enterText(find.byKey(const Key('guest_phone')), '0901234567');
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(480, 320);
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('guest_save')));
    await tester.tap(find.byKey(const Key('guest_save')));
    await tester.pumpAndSettle();
    expect(find.text('Nhập họ tên.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Refresh retains content and shows loading/error feedback', (
    tester,
  ) async {
    var pending = Completer<int>()..complete(21);
    final provider = FutureProvider<int>((ref) => pending.future);
    late WidgetRef consumerRef;
    await mount(
      tester,
      Consumer(
        builder: (context, ref, _) {
          consumerRef = ref;
          return AsyncContent<int>(
            value: ref.watch(provider),
            builder: (data) => Text('$data phòng'),
            onRetry: () => ref.invalidate(provider),
          );
        },
      ),
    );
    pending = Completer<int>();
    consumerRef.invalidate(provider);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('21 phòng'), findsOneWidget);
    expect(find.byType(LoadingCards), findsNothing);
    expect(find.byType(AsterLoader), findsOneWidget);
    pending.complete(22);
    await tester.pumpAndSettle();
    expect(find.text('22 phòng'), findsOneWidget);
    pending = Completer<int>();
    consumerRef.invalidate(provider);
    await tester.pump();
    pending.completeError(const ApiFailure('Mất kết nối.'));
    await tester.pumpAndSettle();
    expect(find.text('22 phòng'), findsOneWidget);
    expect(find.text('Mất kết nối.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Room choices and booking review fit narrow width at double text',
    (tester) async {
      await mount(tester, const BookingForm(), scale: 2);
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      await review(tester);
      expect(tester.takeException(), isNull);
      await press(tester, find.byKey(const Key('review_edit_room')));
      expect(find.byKey(const Key('select_room_1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('App shell fits narrow width with system text scaling', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mount(tester, const SizedBox(), app: true);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    for (final label in ['Phòng', 'Đặt phòng', 'Thêm', 'Hôm nay']) {
      await press(tester, find.widgetWithText(NavigationDestination, label));
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 780),
    const Size(430, 900),
    const Size(480, 320),
  ]) {
    testWidgets('All screens and sheets fit $size at double text size', (
      tester,
    ) async {
      for (final child in <Widget>[
        const DashboardScreen(),
        const RoomsScreen(),
        const BookingsScreen(),
        const CustomersScreen(),
        const LoginScreen(),
        const BookingForm(),
        const Scaffold(body: GuestForm()),
        Scaffold(body: BookingDetail(booking: sampleBooking())),
      ]) {
        await mount(tester, child, scale: 2);
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: child.runtimeType.toString(),
        );
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
