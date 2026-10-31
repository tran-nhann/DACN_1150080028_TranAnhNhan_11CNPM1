import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    const destinations = [
      (
        path: '/dashboard',
        label: 'Hôm nay',
        icon: Icons.space_dashboard_outlined,
      ),
      (path: '/rooms', label: 'Phòng', icon: Icons.bed_outlined),
      (
        path: '/bookings',
        label: 'Đặt phòng',
        icon: Icons.calendar_month_outlined,
      ),
      (path: '/profile', label: 'Thêm', icon: Icons.grid_view_rounded),
    ];
    final selected = navigationShell.currentIndex;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AsterColors.border)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Brand(),
                    ),
                  ),
                  Semantics(
                    label: 'Tài khoản',
                    button: true,
                    child: InkWell(
                      onTap: () => context.go('/profile'),
                      borderRadius: BorderRadius.circular(30),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFEBF3EF),
                            child: Text(
                              user.name.isEmpty
                                  ? 'A'
                                  : user.name.substring(0, 1),
                              style: const TextStyle(
                                color: AsterColors.teal,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: navigationShell),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == 3 && selected == 3,
        ),
        destinations: destinations
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon, size: 22),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class MoreBackButton extends StatelessWidget {
  const MoreBackButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Quay lại Thêm',
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    },
    icon: const Icon(Icons.arrow_back_rounded),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.onRefresh,
    this.scrollController,
  });
  final Widget child;
  final Future<void> Function()? onRefresh;
  final ScrollController? scrollController;
  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(
      controller: scrollController,
      key: PageStorageKey(
        ModalRoute.of(context)?.settings.name ?? child.runtimeType.toString(),
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
    return onRefresh == null
        ? scroll
        : RefreshIndicator(onRefresh: onRefresh!, child: scroll);
  }
}

class BranchContainer extends StatefulWidget {
  const BranchContainer({
    super.key,
    required this.index,
    required this.children,
  });
  final int index;
  final List<Widget> children;
  @override
  State<BranchContainer> createState() => _BranchContainerState();
}

class _BranchContainerState extends State<BranchContainer>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, value: 1);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _fade.stop();
      _fade.value = 1;
    }
  }

  @override
  void didUpdateWidget(BranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _fade.duration = motionDuration(context, 160);
      if (reducedMotion(context)) {
        _fade.value = 1;
      } else {
        _fade.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: widget.index,
    children: [
      for (var i = 0; i < widget.children.length; i++)
        TickerMode(
          enabled: i == widget.index,
          child: FadeTransition(
            opacity: _fade.drive(CurveTween(curve: Curves.easeOutCubic)),
            child: widget.children[i],
          ),
        ),
    ],
  );
}
