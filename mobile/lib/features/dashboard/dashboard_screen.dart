import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../bookings/booking_history.dart';
import '../bookings/bookings_screen.dart';
import '../rooms/rooms_screen.dart';
import '../shell/app_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _rooms(BuildContext context, {String status = '', int? floor}) =>
      context.go(
        '/rooms?status=$status${floor == null ? '' : '&floor=$floor'}',
        extra: DateTime.now().microsecondsSinceEpoch,
      );
  void _daily(BuildContext context, DashboardData data, String kind) =>
      showAsterSheet<void>(
        context: context,
        builder: (_) => DailyBookings(kind: kind, day: data.date),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    onRefresh: () async {
      await ref.refresh(dashboardProvider.future).then((_) {});
    },
    child: AsyncContent(
      value: ref.watch(dashboardProvider),
      onRetry: () => ref.invalidate(dashboardProvider),
      builder: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(
            title: 'Tổng quan',
            subtitle: DateFormat('dd/MM/yyyy').format(data.date),
            action: IconButton(
              tooltip: 'Làm mới',
              onPressed: () => ref.invalidate(dashboardProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Material(
            color: AsterColors.dark,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _rooms(context, status: 'ready'),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AsterColors.dark, Color(0xFF1E6B5E)],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phòng sẵn sàng',
                            style: TextStyle(
                              color: Color(0xFFC2DECF),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${data.ready}',
                            key: const Key('ready_count'),
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '/ ${data.total} phòng',
                            style: const TextStyle(
                              color: Color(0xFFB3D2C8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: ExcludeSemantics(
                              child: CircularProgressIndicator(
                                value: data.total == 0
                                    ? 0
                                    : data.ready / data.total,
                                strokeWidth: 6,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.white.withValues(
                                  alpha: .12,
                                ),
                                color: const Color(0xFFB9EBD6),
                              ),
                            ),
                          ),
                          Text(
                            '${data.total == 0 ? 0 : (100 * data.ready / data.total).round()}%',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, box) {
              final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
              final width = large ? box.maxWidth : (box.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    [
                          (
                            label: 'Đến',
                            value: data.arrivals,
                            icon: Icons.login_rounded,
                            kind: 'arrivals',
                          ),
                          (
                            label: 'Đi',
                            value: data.departures,
                            icon: Icons.logout_rounded,
                            kind: 'departures',
                          ),
                          (
                            label: 'Khách',
                            value: data.guests,
                            icon: Icons.people_outline,
                            kind: 'guests',
                          ),
                        ]
                        .map(
                          (item) => SizedBox(
                            width: width,
                            child: _Metric(
                              label: item.label,
                              value: item.value,
                              icon: item.icon,
                              onTap: () => _daily(context, data, item.kind),
                            ),
                          ),
                        )
                        .toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  [
                        (
                          label: 'Đang ở',
                          value: data.occupied,
                          status: 'occupied',
                          color: const Color(0xFF3F6685),
                          icon: Icons.hotel_outlined,
                        ),
                        (
                          label: 'Đã đặt',
                          value: data.reserved,
                          status: 'reserved',
                          color: const Color(0xFF7661A7),
                          icon: Icons.event_available_outlined,
                        ),
                        (
                          label: 'Cần dọn',
                          value: data.cleaning,
                          status: 'cleaning',
                          color: AsterColors.amber,
                          icon: Icons.cleaning_services_outlined,
                        ),
                        (
                          label: 'Bảo trì',
                          value: data.maintenance,
                          status: 'maintenance',
                          color: AsterColors.red,
                          icon: Icons.build_outlined,
                        ),
                      ]
                      .map(
                        (item) => SizedBox(
                          width: MediaQuery.textScalerOf(context).scale(1) > 1.4
                              ? box.maxWidth
                              : (box.maxWidth - 10) / 2,
                          child: _Metric(
                            label: item.label,
                            value: item.value,
                            icon: item.icon,
                            color: item.color,
                            onTap: () => _rooms(context, status: item.status),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          if (data.floors.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionTitle('Theo tầng', icon: Icons.layers_outlined),
            const SizedBox(height: 10),
            Surface(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: data.floors
                    .map(
                      (floor) => ListTile(
                        key: Key('floor_${floor.floor}'),
                        minVerticalPadding: 12,
                        title: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              'Tầng ${floor.floor}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${floor.ready}/${floor.total} trống',
                              style: const TextStyle(
                                color: AsterColors.teal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ExcludeSemantics(
                              child: LinearProgressIndicator(
                                minHeight: 5,
                                value: floor.total == 0
                                    ? 0
                                    : floor.ready / floor.total,
                                backgroundColor: AsterColors.background,
                                color: AsterColors.teal,
                              ),
                            ),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _rooms(context, floor: floor.floor),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionTitle(
            'Khách đến',
            icon: Icons.event_available_outlined,
            action: IconButton(
              tooltip: 'Xem khách đến',
              onPressed: () => _daily(context, data, 'arrivals'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          if (data.todayBookings.isEmpty)
            const Surface(
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    color: AsterColors.muted,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chưa có lượt đến',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            ...data.todayBookings.map(
              (booking) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BookingCard(
                  booking: booking,
                  onTap: () => showAsterSheet<void>(
                    context: context,
                    builder: (_) => BookingDetail(booking: booking),
                  ),
                ),
              ),
            ),
          if (data.attention.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionTitle('Cần xử lý', icon: Icons.handyman_outlined),
            const SizedBox(height: 10),
            ...data.attention.map(
              (room) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AsterColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        room.number,
                        style: const TextStyle(
                          fontSize: 19,
                          color: AsterColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      room.type.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConditionBadge(room.condition),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => showAsterSheet<void>(
                      context: context,
                      builder: (_) => RoomDetail(room: room),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (ref.watch(authProvider).user?.canEditRooms == true) ...[
            const SizedBox(height: 24),
            PressScale(
              child: FilledButton.icon(
                onPressed: () => context.push('/bookings/new'),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Đặt phòng'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {required this.icon, this.action});
  final String title;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AsterColors.teal, size: 20),
      const SizedBox(width: 9),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      ?action,
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.color = AsterColors.teal,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const Spacer(),
                const Icon(
                  Icons.north_east_rounded,
                  size: 13,
                  color: AsterColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 25,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: AsterColors.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}
