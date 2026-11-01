import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../bookings/bookings_screen.dart';
import 'rooms_screen.dart';

class RoomTimelineView extends ConsumerStatefulWidget {
  const RoomTimelineView({
    super.key,
    this.floor,
    required this.floors,
    required this.onFloorChanged,
  });

  final int? floor;
  final List<FloorSummary> floors;
  final ValueChanged<int?> onFloorChanged;

  @override
  ConsumerState<RoomTimelineView> createState() => _RoomTimelineViewState();
}

class _RoomTimelineViewState extends ConsumerState<RoomTimelineView> {
  late DateTime _startDate;
  final int _days = 7;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
  }

  void _previousWeek() {
    setState(() {
      _startDate = _startDate.subtract(Duration(days: _days));
    });
  }

  void _nextWeek() {
    setState(() {
      _startDate = _startDate.add(Duration(days: _days));
    });
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, now.day);
    });
  }

  Future<void> _openBooking(BuildContext context, int bookingId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final booking = await ref.read(apiProvider).getBooking(bookingId);
      if (!context.mounted) return;
      showAsterSheet<void>(
        context: context,
        builder: (_) => BookingDetail(booking: booking),
      );
    } catch (e) {
      if (context.mounted) {
        showMessage(context, 'Không tải được chi tiết đặt phòng: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRoom(BuildContext context, int id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final room = await ref.read(apiProvider).getRoom(id);
      if (!context.mounted) return;
      showAsterSheet<void>(
        context: context,
        builder: (_) => RoomDetail(room: room),
      );
    } catch (error) {
      if (context.mounted) showMessage(context, 'Không tải được phòng: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bookCell(
    BuildContext context,
    RoomTimeline room,
    String dateStr,
  ) async {
    if (room.condition == 'maintenance' ||
        (room.condition == 'cleaning' &&
            dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now()))) {
      await _openRoom(context, room.id);
      return;
    }
    final canBook = ref.read(authProvider).user?.canEditRooms == true;
    if (!canBook) {
      showMessage(context, 'Bạn không có quyền tạo đặt phòng.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final actual = await ref.read(apiProvider).getRoom(room.id);
      if (context.mounted) {
        context.push('/bookings/new?date=$dateStr', extra: actual);
      }
    } catch (error) {
      if (context.mounted) showMessage(context, 'Không tải được phòng: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatDayHeader(DateTime date) {
    const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    final weekday = days[date.weekday % 7];
    return weekday;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final timelineAsync = ref.watch(
      timelineProvider((start: dateStr, days: _days, floor: widget.floor)),
    );

    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- TOOLBAR: DATE NAVIGATION & MINIMAL LEGEND ---
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top line: Unified navigation pill on left, Date range on right
                Row(
                  children: [
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AsterColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: _previousWeek,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(7),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 6,
                              ),
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: 18,
                                color: AsterColors.navy,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: AsterColors.border,
                          ),
                          InkWell(
                            onTap: _goToday,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                'Hôm nay',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AsterColors.navy,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: AsterColors.border,
                          ),
                          InkWell(
                            onTap: _nextWeek,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(7),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 6,
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AsterColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${DateFormat('dd/MM').format(_startDate)} – ${DateFormat('dd/MM/yyyy').format(_startDate.add(Duration(days: _days - 1)))}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AsterColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Bottom line: Minimal dot legend (refined, airy, no heavy buttons)
                const SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _LegendDot(color: AsterColors.navy, label: 'Đang ở'),
                      SizedBox(width: 14),
                      _LegendDot(color: AsterColors.gold, label: 'Đã đặt'),
                      SizedBox(width: 14),
                      _LegendDot(
                        color: Colors.white,
                        borderColor: AsterColors.border,
                        label: 'Trống (+ Đặt)',
                      ),
                      SizedBox(width: 14),
                      _LegendDot(color: Color(0xFFD97706), label: 'Cần dọn'),
                      SizedBox(width: 14),
                      _LegendDot(color: Color(0xFFDC2626), label: 'Bảo trì'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // --- MATRIX GRID CONTENT ---
        AsyncContent(
          value: timelineAsync,
          onRetry: () => ref.invalidate(timelineProvider),
          builder: (data) {
            final dates = data.dates;
            const leftColWidth = 84.0;
            const cellWidth = 72.0;
            const rowHeight = 54.0;
            const headerHeight = 50.0;
            final totalWidth = leftColWidth + dates.length * cellWidth;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AsterColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- HEADER ROW (DATES) ---
                      Container(
                        height: headerHeight,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(
                            bottom: BorderSide(
                              color: AsterColors.border,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Left header cell: "Phòng"
                            Container(
                              width: leftColWidth,
                              height: headerHeight,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: AsterColors.border,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bed_outlined,
                                    size: 15,
                                    color: AsterColors.navy,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Phòng',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AsterColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 7 Date headers
                            for (final dStr in dates) ...[
                              Builder(
                                builder: (context) {
                                  final d =
                                      DateTime.tryParse(dStr) ?? DateTime.now();
                                  final isToday = dStr == todayStr;
                                  return Container(
                                    width: cellWidth,
                                    height: headerHeight,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isToday
                                          ? AsterColors.goldLight.withValues(
                                              alpha: 0.35,
                                            )
                                          : Colors.transparent,
                                      border: const Border(
                                        right: BorderSide(
                                          color: AsterColors.border,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _formatDayHeader(d),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isToday
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: isToday
                                                ? AsterColors.navy
                                                : AsterColors.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: isToday
                                              ? BoxDecoration(
                                                  color: AsterColors.navy,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                )
                                              : null,
                                          child: Text(
                                            DateFormat('dd/MM').format(d),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: isToday
                                                  ? FontWeight.w800
                                                  : FontWeight.w700,
                                              color: isToday
                                                  ? Colors.white
                                                  : AsterColors.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      // --- ROOM ROWS ---
                      if (data.rooms.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Không có phòng nào phù hợp.',
                              style: TextStyle(color: AsterColors.muted),
                            ),
                          ),
                        )
                      else
                        for (final room in data.rooms)
                          Container(
                            height: rowHeight,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AsterColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Left Room Column
                                Material(
                                  color: const Color(0xFFFAFAFA),
                                  child: InkWell(
                                    onTap: () => _openRoom(context, room.id),
                                    child: Container(
                                      width: leftColWidth,
                                      height: rowHeight,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: AsterColors.border,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'P.${room.number}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AsterColors.navy,
                                              height: 1.1,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            room.typeName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w500,
                                              color: AsterColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // 7 Day Cells
                                for (final cell in room.schedule)
                                  _TimelineGridCell(
                                    width: cellWidth,
                                    height: rowHeight,
                                    cell: cell,
                                    room: room,
                                    onTapBooking: (id) =>
                                        _openBooking(context, id),
                                    onTapEmpty: (date) =>
                                        _bookCell(context, room, date),
                                  ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.borderColor,
  });

  final Color color;
  final Color? borderColor;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1.5)
              : null,
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
    ],
  );
}

class _TimelineGridCell extends StatelessWidget {
  const _TimelineGridCell({
    required this.width,
    required this.height,
    required this.cell,
    required this.room,
    required this.onTapBooking,
    required this.onTapEmpty,
  });

  final double width;
  final double height;
  final TimelineCell cell;
  final RoomTimeline room;
  final ValueChanged<int> onTapBooking;
  final ValueChanged<String> onTapEmpty;

  @override
  Widget build(BuildContext context) {
    final status = cell.status;
    final booking = cell.booking;

    Widget content;
    Color bgColor = Colors.transparent;
    VoidCallback? onTap;

    if (status == 'checked_in' && booking != null) {
      bgColor = AsterColors.navy;
      onTap = () => onTapBooking(booking.id);
      content = Tooltip(
        message:
            '${booking.customerName} (${booking.code})\nNhận: ${booking.startDate} - Trả: ${booking.endDate}',
        child: Container(
          margin: EdgeInsets.fromLTRB(
            booking.isStart ? 3 : 0,
            4,
            booking.isEnd ? 3 : 0,
            4,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: AsterColors.navy,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(booking.isStart ? 6 : 0),
              right: Radius.circular(booking.isEnd ? 6 : 0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                booking.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                booking.isStart ? 'Nhận' : (booking.isEnd ? 'Trả' : 'Đang ở'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (status == 'confirmed' && booking != null) {
      onTap = () => onTapBooking(booking.id);
      content = Tooltip(
        message:
            'Đã đặt: ${booking.customerName} (${booking.code})\n${booking.startDate} — ${booking.endDate}',
        child: Container(
          margin: EdgeInsets.fromLTRB(
            booking.isStart ? 3 : 0,
            4,
            booking.isEnd ? 3 : 0,
            4,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: AsterColors.gold,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(booking.isStart ? 6 : 0),
              right: Radius.circular(booking.isEnd ? 6 : 0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                booking.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AsterColors.ink,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Đã đặt',
                style: TextStyle(
                  color: AsterColors.navy,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (status == 'cleaning') {
      onTap = () => onTapEmpty(cell.date);
      bgColor = const Color(0xFFFEF3C7);
      content = const Tooltip(
        message: 'Phòng cần dọn vệ sinh',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cleaning_services_outlined,
                size: 14,
                color: Color(0xFFB45309),
              ),
              SizedBox(height: 2),
              Text(
                'Cần dọn',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (status == 'maintenance') {
      onTap = () => onTapEmpty(cell.date);
      bgColor = const Color(0xFFFEE2E2);
      content = const Tooltip(
        message: 'Phòng đang bảo trì thiết bị',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.build_outlined, size: 14, color: Color(0xFFDC2626)),
              SizedBox(height: 2),
              Text(
                'Bảo trì',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // READY / EMPTY
      onTap = () => onTapEmpty(cell.date);
      content = Tooltip(
        message:
            'Phòng ${room.number} trống ngày ${cell.date}. Bấm để đặt phòng.',
        child: Center(
          child: Icon(
            Icons.add_rounded,
            size: 14,
            color: Colors.grey.withValues(alpha: 0.35),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(right: BorderSide(color: AsterColors.border)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
