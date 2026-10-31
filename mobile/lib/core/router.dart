import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/bookings/bookings_screen.dart';
import '../features/bookings/booking_form.dart';
import '../features/customers/customers_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/rooms/rooms_screen.dart';
import '../features/services/services_screen.dart';
import '../features/shell/app_shell.dart';
import 'providers.dart';
import 'loading.dart';
import 'interaction.dart';

CustomTransitionPage<void> _page(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  bool fade = false,
}) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: motionDuration(context, fade ? 180 : 240),
  reverseTransitionDuration: motionDuration(context, fade ? 180 : 240),
  transitionsBuilder: (context, animation, secondary, child) {
    final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(fade ? 0 : 24 / MediaQuery.sizeOf(context).width, 0),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  },
);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, next) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.matchedLocation;
      if (auth.restoring) return path == '/startup' ? null : '/startup';
      if (auth.user == null) return path == '/login' ? null : '/login';
      if (path == '/login' || path == '/startup') return '/dashboard';
      if (['/customers', '/profile/customers'].contains(path) &&
          !auth.user!.canAccessCustomers) {
        return '/dashboard';
      }
      if (path == '/bookings/new' && !auth.user!.canEditRooms) {
        return '/bookings';
      }
      if (path == '/customers') return '/profile/customers';
      if (path == '/services') return '/profile/services';
      return null;
    },
    routes: [
      GoRoute(
        path: '/startup',
        pageBuilder: (context, state) =>
            _page(context, state, const StartupScreen(), fade: true),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _page(context, state, const LoginScreen(), fade: true),
      ),
      GoRoute(
        path: '/bookings/new',
        pageBuilder: (context, state) =>
            _page(context, state, const BookingForm()),
      ),
      GoRoute(path: '/customers', redirect: (_, _) => '/profile/customers'),
      GoRoute(path: '/services', redirect: (_, _) => '/profile/services'),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            BranchContainer(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const DashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rooms',
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: RoomsScreen(
                    initialFloor: int.tryParse(
                      state.uri.queryParameters['floor'] ?? '',
                    ),
                    initialStatus: state.uri.queryParameters['status'] ?? '',
                    filterRevision: state.extra is int
                        ? state.extra as int
                        : null,
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookings',
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: BookingsScreen(
                    initialStatus: state.uri.queryParameters['status'] ?? '',
                    createdId: int.tryParse(
                      state.uri.queryParameters['created'] ?? '',
                    ),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const ProfileScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'customers',
                    pageBuilder: (context, state) =>
                        _page(context, state, const CustomersScreen()),
                  ),
                  GoRoute(
                    path: 'services',
                    pageBuilder: (context, state) =>
                        _page(context, state, const ServicesScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
