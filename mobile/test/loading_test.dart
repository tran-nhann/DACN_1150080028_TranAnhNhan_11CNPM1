import 'package:aster_hotel/core/loading.dart';
import 'package:aster_hotel/core/providers.dart';
import 'package:aster_hotel/core/theme.dart';
import 'package:aster_hotel/core/widgets.dart';
import 'package:aster_hotel/features/auth/login_screen.dart';
import 'package:aster_hotel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RestoringAuth extends AuthController {
  @override
  AuthState build() => const AuthState(restoring: true);

  void finish() => state = const AuthState();
}

void main() {
  testWidgets('Startup fits narrow and landscape screens with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(320, 568), const Size(480, 320)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          theme: asterTheme(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: StartupScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Reduced motion stops all loaders and exposes status semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Column(children: [AsterLoader(), LoadingCards()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.bySemanticsLabel('Đang tải'), findsOneWidget);
    expect(find.bySemanticsLabel('Đang tải dữ liệu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Startup exits as soon as session restoration finishes', (
    tester,
  ) async {
    final auth = _RestoringAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => auth)],
        child: const AsterApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(StartupScreen), findsOneWidget);
    auth.finish();
    await tester.pumpAndSettle();
    expect(find.byType(StartupScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });
}
