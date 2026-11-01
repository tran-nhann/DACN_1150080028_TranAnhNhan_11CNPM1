import 'dart:async';

import 'package:aster_hotel/core/api.dart';
import 'package:aster_hotel/core/billing_models.dart';
import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/core/widgets.dart';
import 'package:aster_hotel/features/bookings/billing_panel.dart';
import 'package:aster_hotel/features/bookings/bookings_screen.dart';
import 'package:aster_hotel/features/bookings/invoices_panel.dart';
import 'package:aster_hotel/features/rooms/rooms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

final cleaningRoom = HotelRoom(
  id: 1,
  number: '101',
  floor: 1,
  type: sampleType,
  condition: 'cleaning',
  displayStatus: 'cleaning',
  notes: '',
  updatedAt: DateTime(2026, 10, 15, 12),
);
const lines = [
  BillLine(
    kind: 'room',
    name: 'Phòng 101',
    unit: 'đêm',
    quantity: 1,
    price: 950000,
    total: 950000,
  ),
  BillLine(
    kind: 'service',
    name: 'Nước',
    unit: 'chai',
    quantity: 2,
    price: 15000,
    total: 30000,
  ),
];
final invoice = HotelInvoice(
  id: 1,
  code: 'HD-TEST',
  bookingId: 1,
  bookingCode: 'BK-TEST',
  guest: sampleGuest.name,
  phone: sampleGuest.phone,
  roomNumber: '101',
  roomType: sampleType.name,
  start: DateTime(2026, 10, 14),
  end: DateTime(2026, 10, 15),
  roomTotal: 950000,
  serviceTotal: 30000,
  total: 980000,
  issuedAt: DateTime(2026, 10, 15, 12),
  issuedBy: admin.name,
  lines: lines,
  payment: BillPayment(
    code: 'PT-TEST',
    method: 'bank_transfer',
    methodLabel: 'Chuyển khoản',
    amount: 980000,
    date: DateTime(2026, 10, 15, 12),
    cashier: admin.name,
    reference: 'BANK-TEST',
  ),
);
HotelBooking closedBooking() => HotelBooking(
  id: 1,
  code: 'BK-TEST',
  room: cleaningRoom,
  customerId: sampleGuest.id,
  customerName: sampleGuest.name,
  start: DateTime(2026, 10, 14),
  end: DateTime(2026, 10, 15),
  guests: 1,
  nightlyRate: 950000,
  total: 950000,
  status: 'checked_out',
  statusLabel: 'Đã trả',
  checkedOutAt: DateTime(2026, 10, 15, 12),
);

class BillingApi extends StubApi {
  final keys = <String>[];
  final bodies = <Map<String, dynamic>>[];
  bool paid = false, failFirst = false;
  int cleaned = 0;
  Completer<CheckoutResult>? pending;
  @override
  Future<BillingState> folio(int id) async => paid
      ? BillingState(invoice: invoice)
      : BillingState(
          folio: StayFolio(
            quote: 'a' * 64,
            guest: sampleGuest.name,
            roomNumber: '101',
            start: invoice.start,
            end: invoice.end,
            roomTotal: 950000,
            serviceTotal: 30000,
            total: 980000,
            lines: lines,
            canCheckout: true,
            blockedReason: '',
            policy: 'Tính đủ số đêm đã đặt/gia hạn.',
          ),
        );
  @override
  Future<CheckoutResult> checkout(
    int id,
    Map<String, dynamic> data,
    String key,
  ) async {
    keys.add(key);
    bodies.add(Map.of(data));
    if (failFirst && keys.length == 1) {
      throw const ApiFailure('Mất phản hồi, thử lại.');
    }
    if (pending != null) return pending!.future;
    paid = true;
    return CheckoutResult(invoice: invoice, booking: closedBooking());
  }

  @override
  Future<HotelBooking> getBooking(int id) async =>
      paid ? closedBooking() : sampleBooking(status: 'checked_in');
  @override
  Future<HotelRoom> confirmCleaned(int id, DateTime version) async {
    expect(version, cleaningRoom.updatedAt);
    cleaned++;
    return sampleRoom;
  }

  @override
  Future<PagedResult<HotelInvoice>> invoices(InvoiceQuery query) async =>
      PagedResult(items: [invoice], count: 1, hasNext: false);
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));
  Future<BillingApi> mount(
    WidgetTester tester,
    Widget child, {
    BillingApi? api,
    StaffUser user = admin,
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = api ?? BillingApi();
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

  Future<void> choosePayment(WidgetTester tester) async {
    await press(tester, find.byKey(const Key('checkout_method')));
    await press(tester, find.text('Chuyển khoản').last);
    await tester.ensureVisible(find.byKey(const Key('checkout_reference')));
    await tester.enterText(
      find.byKey(const Key('checkout_reference')),
      'BANK-TEST',
    );
    await press(tester, find.byKey(const Key('checkout_received')));
  }

  testWidgets(
    'Check-out reviews folio, confirms payment and displays frozen invoice',
    (tester) async {
      final api = await mount(
        tester,
        BookingDetail(booking: sampleBooking(status: 'checked_in')),
      );
      await press(tester, find.widgetWithText(FilledButton, 'Trả phòng'));
      expect(find.byType(BillingPanel), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout_submit')))
            .onPressed,
        isNull,
      );
      await choosePayment(tester);
      await press(tester, find.byKey(const Key('checkout_submit')));
      expect(api.bodies.single['method'], 'bank_transfer');
      expect(api.bodies.single['expected_total'], '980000');
      expect(api.bodies.single['reference'], 'BANK-TEST');
      expect(api.bodies.single['payment_received'], true);
      expect(find.text('Hóa đơn đã thanh toán'), findsOneWidget);
      expect(find.text('HD-TEST'), findsOneWidget);
      expect(find.byKey(const Key('checkout_submit')), findsNothing);
      await press(tester, find.byTooltip('Quay lại'));
      expect(find.text('Đã trả'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Trả phòng'), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Retry after lost response retains the payment key and quote', (
    tester,
  ) async {
    final api = BillingApi()..failFirst = true;
    await mount(
      tester,
      BookingDetail(booking: sampleBooking(status: 'checked_in')),
      api: api,
    );
    await press(tester, find.widgetWithText(FilledButton, 'Trả phòng'));
    await choosePayment(tester);
    await press(tester, find.byKey(const Key('checkout_submit')));
    expect(find.byKey(const Key('checkout_error')), findsOneWidget);
    await press(tester, find.byKey(const Key('checkout_submit')));
    expect(api.keys, hasLength(2));
    expect(api.keys.first, api.keys.last);
    expect(api.bodies.first, api.bodies.last);
    expect(find.byType(InvoicePanel), findsOneWidget);
  });

  testWidgets('Pending payment blocks Back and duplicate payment', (
    tester,
  ) async {
    final api = BillingApi()..pending = Completer<CheckoutResult>();
    await mount(
      tester,
      BookingDetail(booking: sampleBooking(status: 'checked_in')),
      api: api,
    );
    await press(tester, find.widgetWithText(FilledButton, 'Trả phòng'));
    await choosePayment(tester);
    await tester.tap(find.byKey(const Key('checkout_submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('checkout_submit')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(BillingPanel), findsOneWidget);
    expect(api.keys, hasLength(1));
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('checkout_method')),
          )
          .onChanged,
      isNull,
    );
    api.paid = true;
    api.pending!.complete(
      CheckoutResult(invoice: invoice, booking: closedBooking()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InvoicePanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manager can review folio and invoice but cannot collect', (
    tester,
  ) async {
    await mount(
      tester,
      BillingPanel(
        booking: sampleBooking(status: 'checked_in'),
        onBack: () {},
        onUpdated: (_) {},
      ),
      user: manager,
    );
    expect(find.byKey(const Key('checkout_method')), findsNothing);
    expect(find.byKey(const Key('checkout_submit')), findsNothing);
    expect(find.textContaining('980.000', findRichText: true), findsWidgets);
  });

  testWidgets('Cleaning confirmation updates room and cannot submit twice', (
    tester,
  ) async {
    final api = await mount(tester, RoomDetail(room: cleaningRoom));
    await press(tester, find.byKey(const Key('room_confirm_cleaned')));
    expect(api.cleaned, 0);
    await press(
      tester,
      find.widgetWithText(FilledButton, 'Xác nhận đã dọn').last,
    );
    expect(api.cleaned, 1);
    expect(find.byKey(const Key('room_confirm_cleaned')), findsNothing);
    expect(find.text('Sẵn sàng'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(480, 320)]) {
    testWidgets(
      'Folio and invoice fit $size at double text and keep payment pinned',
      (tester) async {
        await mount(
          tester,
          BillingPanel(
            booking: sampleBooking(status: 'checked_in'),
            onBack: () {},
            onUpdated: (_) {},
          ),
          size: size,
          scale: 2,
        );
        await choosePayment(tester);
        expect(
          tester.getBottomLeft(find.byKey(const Key('checkout_submit'))).dy,
          lessThanOrEqualTo(size.height),
        );
        expect(tester.takeException(), isNull);
        await press(tester, find.byKey(const Key('checkout_submit')));
        await tester.ensureVisible(
          find.textContaining('Người thu', findRichText: true).first,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Invoice search opens a read-only receipt and returns to list', (
    tester,
  ) async {
    await mount(tester, const InvoicesPanel());
    await press(tester, find.text('HD-TEST · Phòng 101'));
    expect(find.byType(InvoicePanel), findsOneWidget);
    await press(tester, find.byTooltip('Quay lại'));
    expect(find.text('Hóa đơn & phiếu thu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
