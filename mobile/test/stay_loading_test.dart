import 'dart:async';

import 'package:aster_hotel/core/api.dart';
import 'package:aster_hotel/core/billing_models.dart';
import 'package:aster_hotel/core/models.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/core/widgets.dart';
import 'package:aster_hotel/features/bookings/billing_panel.dart';
import 'package:aster_hotel/features/bookings/bookings_screen.dart';
import 'package:aster_hotel/features/services/stay_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'billing_test.dart' show BillingApi;
import 'services_test.dart' show ServiceApi;
import 'support.dart';

class LoadingApi extends ServiceApi {
  int folioReads = 0, serviceReads = 0;
  ApiFailure? folioError, serviceError;
  Completer<BillingState>? pendingFolio;
  @override
  Future<BillingState> folio(int id) async {
    folioReads++;
    if (folioError != null) throw folioError!;
    if (pendingFolio != null) return pendingFolio!.future;
    return BillingApi().folio(id);
  }

  @override
  Future<StayServices> stayServices(StayServiceQuery query) async {
    serviceReads++;
    if (serviceError != null) throw serviceError!;
    return super.stayServices(query);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));
  Future<void> mount(
    WidgetTester tester,
    LoadingApi api,
    Widget child, {
    bool settle = true,
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Widget folio() => BillingPanel(
    booking: sampleBooking(status: 'checked_in'),
    onBack: () {},
    onUpdated: (_) {},
  );

  testWidgets(
    '409 shows a real error without automatic infinite folio retries; manual retry succeeds',
    (tester) async {
      final api = LoadingApi()
        ..folioError = const ApiFailure(
          'Booking đang ở nhưng thiếu hồ sơ nhận phòng.',
        );
      await mount(tester, api, folio());
      expect(find.text('Không tải được'), findsOneWidget);
      expect(
        find.text('Booking đang ở nhưng thiếu hồ sơ nhận phòng.'),
        findsOneWidget,
      );
      expect(find.byType(LoadingCards), findsNothing);
      expect(find.byKey(const Key('folio_services_edit')), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(api.folioReads, 1);
      api.folioError = null;
      await press(tester, find.widgetWithText(OutlinedButton, 'Thử lại'));
      expect(api.folioReads, 2);
      expect(find.byType(BillTotals), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Hung folio times out and keeps service entry visible during initial load',
    (tester) async {
      final api = LoadingApi()..pendingFolio = Completer<BillingState>();
      await mount(tester, api, folio(), settle: false);
      expect(find.byType(LoadingCards), findsOneWidget);
      expect(find.byKey(const Key('folio_services_edit')), findsOneWidget);
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(find.text('Không tải được'), findsOneWidget);
      expect(find.textContaining('Tải bảng kê quá lâu'), findsOneWidget);
      expect(api.folioReads, 1);
      expect(find.byType(LoadingCards), findsNothing);
    },
  );

  testWidgets(
    'Services failure is shown immediately and is retried only by the user',
    (tester) async {
      final api = LoadingApi()
        ..serviceError = const ApiFailure('Không tải được dịch vụ.');
      await mount(
        tester,
        api,
        StayServicesPanel(
          booking: sampleBooking(status: 'checked_in'),
          onBack: () {},
        ),
      );
      expect(find.text('Không tải được dịch vụ.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(api.serviceReads, 1);
      api.serviceError = null;
      await press(tester, find.widgetWithText(OutlinedButton, 'Thử lại'));
      expect(api.serviceReads, 2);
      expect(find.byKey(const Key('add_stay_service')), findsOneWidget);
    },
  );

  testWidgets('Checked-in booking exposes a fixed direct Add service action', (
    tester,
  ) async {
    final api = LoadingApi();
    await mount(
      tester,
      api,
      BookingDetail(booking: sampleBooking(status: 'checked_in')),
    );
    await press(tester, find.byKey(const Key('booking_add_service')));
    expect(find.byType(AddStayServiceForm), findsOneWidget);
    await press(tester, find.byKey(const Key('service_1')));
    await tester.enterText(find.byKey(const Key('usage_quantity')), '2');
    await press(tester, find.byKey(const Key('usage_save')));
    expect(api.bodies.single['quantity'], 2);
    expect(find.byType(StayServicesPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(480, 320)]) {
    testWidgets(
      'Checked-in footer with Add service fits $size at double text',
      (tester) async {
        await mount(
          tester,
          LoadingApi(),
          BookingDetail(booking: sampleBooking(status: 'checked_in')),
          size: size,
          scale: 2,
        );
        expect(
          tester.getBottomLeft(find.byKey(const Key('booking_add_service'))).dy,
          lessThanOrEqualTo(size.height),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
