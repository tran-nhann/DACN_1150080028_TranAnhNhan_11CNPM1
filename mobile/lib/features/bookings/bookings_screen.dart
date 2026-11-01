import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/detail_widgets.dart';
import '../../core/form_layout.dart';
import '../../core/models.dart';
import '../customers/customers_screen.dart';
import '../services/stay_services.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../shell/app_shell.dart';
import 'booking_form.dart';
import 'booking_timing.dart';
import 'billing_panel.dart';
import 'room_move_panel.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key, this.initialStatus = '', this.createdId});
  final String initialStatus;
  final int? createdId;
  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  String _search = '';
  late String _status = widget.initialStatus;
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  int _page = 1;
  Timer? _debounce;
  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus ||
        oldWidget.createdId != widget.createdId) {
      _debounce?.cancel();
      _searchController.clear();
      _search = '';
      _status = widget.initialStatus;
      _page = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  BookingQuery get _query => (search: _search, status: _status, page: _page);
  @override
  Widget build(BuildContext context) => PageBody(
    scrollController: _scroll,
    onRefresh: () async {
      await ref.refresh(bookingsProvider(_query).future).then((_) {});
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeading(
          title: 'Đặt phòng',
          action: ref.watch(authProvider).user?.canEditRooms == true
              ? IconButton.filled(
                  tooltip: 'Đặt phòng mới',
                  onPressed: () => context.push('/bookings/new'),
                  icon: const Icon(Icons.add),
                )
              : null,
        ),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Khách, phòng hoặc mã',
            prefixIcon: Icon(Icons.search, size: 20),
          ),
          onChanged: (value) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () {
              if (mounted) {
                setState(() {
                  _search = value.trim();
                  _page = 1;
                });
              }
            });
          },
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                [
                      ('', 'Tất cả'),
                      ('confirmed', 'Đã đặt'),
                      ('checked_in', 'Đang ở'),
                      ('checked_out', 'Đã trả'),
                      ('cancelled', 'Đã hủy'),
                    ]
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            item.$2,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: _status == item.$1,
                          showCheckmark: false,
                          onSelected: (_) => setState(() {
                            _status = item.$1;
                            _page = 1;
                          }),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        const SizedBox(height: 20),
        AsyncContent(
          value: ref.watch(bookingsProvider(_query)),
          onRetry: () => ref.invalidate(bookingsProvider(_query)),
          builder: (data) => Column(
            children: [
              if (data.items.isEmpty)
                const EmptyState(
                  icon: Icons.event_outlined,
                  title: 'Chưa có đặt phòng',
                  message: '',
                ),
              ...data.items.map(
                (booking) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookingCard(
                    booking: booking,
                    onTap: () => showAsterSheet<void>(
                      context: context,
                      builder: (_) => BookingDetail(booking: booking),
                    ),
                  ),
                ),
              ),
              Pager(
                page: _page,
                hasNext: data.hasNext,
                onPage: (page) => setState(() => _page = page),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class BookingCard extends ConsumerWidget {
  const BookingCard({super.key, required this.booking, required this.onTap});
  final HotelBooking booking;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(dashboardProvider).value?.date ?? DateTime.now();
    final timing = BookingTiming.forBooking(booking, today);
    return Material(
      color: timing.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: timing.color.withValues(alpha: .3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: timing.color, width: 4)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: timing.color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      booking.room.number,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: timing.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AsterColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(booking.start)} → ${DateFormat('dd/MM/yyyy').format(booking.end)} · ${booking.nights} đêm',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking.code,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AsterColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AsterColors.muted,
                    size: 18,
                  ),
                ],
              ),
              if (timing.label != null) ...[
                const SizedBox(height: 12),
                BookingTimingBadge(timing: timing),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Flexible(child: BookingBadge(booking)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      money(booking.estimatedTotal ?? booking.total),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AsterColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingBadge extends StatelessWidget {
  const BookingBadge(this.booking, {super.key});
  final HotelBooking booking;
  @override
  Widget build(BuildContext context) {
    final color = switch (booking.status) {
      'checked_in' => const Color(0xFF3977A8),
      'cancelled' => AsterColors.red,
      'checked_out' => AsterColors.muted,
      _ => const Color(0xFF6D28D9),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (booking.status) {
              'checked_in' => Icons.login_rounded,
              'checked_out' => Icons.logout_rounded,
              'cancelled' => Icons.event_busy_outlined,
              _ => Icons.event_available_outlined,
            },
            color: color,
            size: 13,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              booking.statusLabel,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingDetail extends ConsumerStatefulWidget {
  const BookingDetail({
    super.key,
    required this.booking,
    this.onBack,
    this.onGuest,
    this.onUpdated,
  });
  final VoidCallback? onBack, onGuest;
  final ValueChanged<HotelBooking>? onUpdated;
  final HotelBooking booking;
  @override
  ConsumerState<BookingDetail> createState() => _BookingDetailState();
}

class _BookingDetailState extends ConsumerState<BookingDetail> {
  late HotelBooking _booking = widget.booking;
  late String _customerName = widget.booking.customerName;
  bool _busy = false, _rescheduleOpened = false;
  int _view = 0, _rescheduleVersion = 0;
  String? _error;
  String _pendingAction = '',
      _confirmTitle = '',
      _confirmLabel = '',
      _confirmDetails = '';
  Map<String, dynamic>? _payload;

  void _back() {
    if (_busy) return;
    setState(() {
      _view = 0;
      _error = null;
    });
    setSheetHeight(context, .85);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _action(String action, [Map<String, dynamic>? data]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    setSheetBusy(context, true);
    try {
      final updated = await ref
          .read(apiProvider)
          .bookingAction(_booking.id, action, data);
      if (!mounted) return;
      refreshBookings(ref);
      setSheetBusy(context, false);
      setState(() {
        _booking = updated;
        _customerName = updated.customerName;
        _busy = false;
        _view = 0;
        _rescheduleVersion++;
      });
      setSheetHeight(context, .85);
      showMessage(context, 'Đã cập nhật');
      widget.onUpdated?.call(updated);
    } catch (error) {
      if (mounted) {
        setSheetBusy(context, false);
        setState(() {
          _busy = false;
          _error = error.toString();
        });
        revealField(
          context,
          Key(_view == 1 ? 'reschedule_error' : 'confirm_error'),
        );
      }
    }
  }

  void _confirm(
    String action,
    String title,
    String label, {
    Map<String, dynamic>? data,
    String? details,
  }) {
    setState(() {
      _pendingAction = action;
      _confirmTitle = title;
      _confirmLabel = label;
      _payload = data;
      _confirmDetails =
          details ?? 'Phòng ${_booking.room.number} · $_customerName';
      _view = 2;
      _error = null;
    });
    setSheetHeight(context, .85);
  }

  Future<void> _extend() async {
    final newEnd = await showDatePicker(
      context: context,
      initialDate: _booking.end.add(const Duration(days: 1)),
      firstDate: _booking.end.add(const Duration(days: 1)),
      lastDate: _booking.start.add(const Duration(days: 90)),
      helpText: 'Ngày trả mới',
    );
    if (!mounted || newEnd == null) return;
    _confirm(
      'extend',
      'Gia hạn?',
      'Gia hạn',
      data: {'end_date': dateOnly(newEnd)},
      details:
          'Phòng ${_booking.room.number} · $_customerName\nĐến ${DateFormat('dd/MM/yyyy').format(newEnd)}\n${money(_booking.total + _booking.nightlyRate * newEnd.difference(_booking.end).inDays)}',
    );
  }

  void _reschedule() {
    setState(() {
      _rescheduleOpened = true;
      _view = 1;
      _error = null;
    });
    setSheetHeight(context, .95);
  }

  Widget _serviceEntry() {
    final query = (bookingId: _booking.id, page: 1);
    final value = ref.watch(stayServicesProvider(query));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Surface(
        color: AsterColors.background,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              key: const Key('booking_services'),
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(
                Icons.room_service_outlined,
                color: AsterColors.teal,
              ),
              title: Text(
                _booking.status == 'confirmed' ? 'Dịch vụ đặt kèm' : 'Dịch vụ',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: value.when(
                skipLoadingOnRefresh: true,
                data: (data) =>
                    Text('${data.count} khoản · ${money(data.serviceTotal)}'),
                loading: () => const Align(
                  alignment: Alignment.centerLeft,
                  child: AsterLoader(size: 20),
                ),
                error: (error, _) =>
                    const Text('Không tải được · Mở để thử lại'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => _view = 4),
            ),
            if (value.hasValue)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: DetailField(
                  label: 'Tạm tính',
                  value: money(value.value!.estimatedTotal),
                  emphasize: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _details() {
    final editable = ref.watch(authProvider).user?.canEditRooms == true;
    final today = ref.watch(dashboardProvider).value?.date ?? DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final canCheckIn =
        !day.isBefore(_booking.start) && day.isBefore(_booking.end);
    final confirmed = _booking.status == 'confirmed';
    final canExtend =
        ['confirmed', 'checked_in'].contains(_booking.status) &&
        _booking.nights < 90;
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const PageStorageKey('booking_detail'),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeading(
                  title: 'Phòng ${_booking.room.number}',
                  subtitle:
                      '${_booking.room.type.name} · Tầng ${_booking.room.floor}',
                  action: IconButton(
                    tooltip: 'Đóng',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
                if (widget.onBack != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy ? null : widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Quay lại'),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BookingBadge(_booking),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BookingTimingBadge(
                    timing: BookingTiming.forBooking(_booking, day),
                  ),
                ),
                DetailField(
                  label: 'Mã đặt phòng',
                  value: _booking.code,
                  copyable: true,
                ),
                const SizedBox(height: 20),
                Surface(
                  color: AsterColors.background,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE1EEE8),
                        child: Icon(
                          Icons.person_outline,
                          color: AsterColors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _customerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AsterColors.ink,
                              ),
                            ),
                            Text(
                              '${_booking.guests} khách',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (ref.watch(authProvider).user?.canAccessCustomers ==
                          true)
                        IconButton(
                          key: const Key('booking_guest_profile'),
                          tooltip: 'Hồ sơ khách',
                          onPressed:
                              widget.onGuest ?? () => setState(() => _view = 3),
                          icon: const Icon(Icons.chevron_right),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DetailSection(
                  title: 'Lịch ở',
                  icon: Icons.calendar_month_outlined,
                  children: [
                    LayoutBuilder(
                      builder: (context, box) {
                        final start = DetailField(
                          label: 'Nhận phòng',
                          value: DateFormat('dd/MM/yyyy')
                              .format(_booking.start),
                        );
                        final end = DetailField(
                          label: 'Trả phòng',
                          value: DateFormat('dd/MM/yyyy').format(_booking.end),
                        );
                        return MediaQuery.textScalerOf(context).scale(1) > 1.4
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  start,
                                  const SizedBox(height: 12),
                                  end,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: start),
                                  const SizedBox(width: 12),
                                  Expanded(child: end),
                                ],
                              );
                      },
                    ),
                    Text(
                      '${_booking.nights} đêm',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                DetailSection(
                  title: 'Tiền phòng',
                  icon: Icons.receipt_long_outlined,
                  children: [
                    DetailField(
                      label: _booking.roomMoves.isEmpty
                          ? '${money(_booking.nightlyRate)} × ${_booking.nights} đêm'
                          : 'Tổng theo từng phòng đã ở',
                      value: money(_booking.total),
                      emphasize: true,
                    ),
                    if (_booking.roomMoves.isNotEmpty)
                      for (final segment in _booking.roomSegments)
                        DetailField(
                          label:
                              'Phòng ${segment.number} · ${shortDate(segment.start)} → ${shortDate(segment.end)}',
                          value:
                              '${segment.nights} đêm × ${money(segment.rate)} = ${money(segment.total)}',
                        ),
                  ],
                ),
                if (_booking.roomMoves.isNotEmpty)
                  DetailSection(
                    title: 'Lịch sử chuyển phòng',
                    icon: Icons.move_up_rounded,
                    children: [
                      for (final move in _booking.roomMoves)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${move.from} → ${move.to} · ${dateStamp(move.createdAt)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text('${move.actor} · ${move.reason}'),
                              Text(
                                '${money(move.oldRate)} → ${money(move.newRate)} / đêm · ${move.priceMode == 'keep' ? 'Giữ giá hiện tại' : 'Giá phòng mới'}',
                              ),
                              Text(
                                'Phòng cũ: ${move.condition == 'maintenance' ? 'Bảo trì' : 'Cần dọn'}',
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                if ([
                  'confirmed',
                  'checked_in',
                  'checked_out',
                ].contains(_booking.status))
                  _serviceEntry(),
                if (['checked_in', 'checked_out'].contains(_booking.status))
                  Material(
                    color: Colors.white,
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                        _booking.status == 'checked_out'
                            ? 'Xem hóa đơn / phiếu thu'
                            : 'Bảng quyết toán lưu trú',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => setState(() => _view = 5),
                    ),
                  ),
                if (_booking.createdAt != null || _booking.checkedInAt != null)
                  DetailSection(
                    title: 'Mốc thời gian',
                    icon: Icons.history_rounded,
                    children: [
                      if (_booking.createdAt != null)
                        DetailField(
                          label: 'Tạo đặt phòng',
                          value: dateStamp(_booking.createdAt!),
                        ),
                      if (_booking.checkedInAt != null)
                        DetailField(
                          label: _booking.checkInRecordRecovered
                              ? 'Khôi phục hồ sơ lưu trú'
                              : 'Đã nhận phòng',
                          value: dateStamp(_booking.checkedInAt!),
                        ),
                      if (_booking.checkedOutAt != null)
                        DetailField(
                          label: 'Đã trả phòng',
                          value: dateStamp(_booking.checkedOutAt!),
                        ),
                    ],
                  ),
                if (_error != null) InlineError(_error!),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (editable &&
                  (confirmed || _booking.status == 'checked_in')) ...[
                const SizedBox(height: 12),
                if (_booking.status == 'checked_in') ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          key: const Key('booking_add_service'),
                          onPressed: _busy
                              ? null
                              : () => setState(() => _view = 7),
                          icon: const Icon(Icons.add_shopping_cart_outlined),
                          label: const Text('Thêm dịch vụ'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('booking_move_room'),
                          onPressed: _busy
                              ? null
                              : () {
                                  setState(() => _view = 8);
                                  setSheetHeight(context, .95);
                                },
                          child: const Text('Chuyển phòng'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (editable && confirmed && !canCheckIn)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      day.isBefore(_booking.start)
                          ? 'Nhận phòng từ ${DateFormat('dd/MM').format(_booking.start)}'
                          : 'Đã quá lịch nhận phòng',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AsterColors.amber,
                      ),
                    ),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: PressScale(
                        child: FilledButton.icon(
                          key: const Key('booking_primary'),
                          onPressed: _busy
                              ? null
                              : confirmed
                              ? (canCheckIn
                                    ? () => setState(() => _view = 6)
                                    : null)
                              : () => setState(() => _view = 5),
                          icon: Icon(
                            confirmed
                                ? Icons.login_rounded
                                : Icons.logout_rounded,
                            size: 20,
                          ),
                          label: Text(confirmed ? 'Nhận phòng' : 'Trả phòng'),
                        ),
                      ),
                    ),
                    if (!confirmed && canExtend) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _busy ? null : _extend,
                        child: const Text('Gia hạn'),
                      ),
                    ],
                    if (confirmed) ...[
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        tooltip: 'Thao tác khác',
                        enabled: !_busy,
                        onSelected: (action) {
                          if (action == 'reschedule') _reschedule();
                          if (action == 'extend') _extend();
                          if (action == 'cancel') {
                            _confirm(
                              'cancel',
                              'Hủy đặt phòng?',
                              'Hủy đặt phòng',
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'reschedule',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_calendar_outlined),
                              title: Text('Đổi lịch / phòng'),
                            ),
                          ),
                          if (canExtend)
                            const PopupMenuItem(
                              value: 'extend',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.more_time_rounded),
                                title: Text('Gia hạn'),
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'cancel',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.event_busy_outlined,
                                color: AsterColors.red,
                              ),
                              title: Text(
                                'Hủy đặt phòng',
                                style: TextStyle(color: AsterColors.red),
                              ),
                            ),
                          ),
                        ],
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && _view == 0 && widget.onBack == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop &&
          !_busy &&
          _view != 3 &&
          _view != 4 &&
          _view != 5 &&
          _view != 6 &&
          _view != 7 &&
          _view != 8) {
        if (_view != 0) {
          _back();
        } else {
          widget.onBack?.call();
        }
      }
    },
    child: SheetPages(
      index: _view,
      confirmationIndex: 2,
      children: [
        _details(),
        if (_rescheduleOpened && _booking.status == 'confirmed')
          _RescheduleForm(
            key: ValueKey(_rescheduleVersion),
            booking: _booking,
            busy: _busy,
            error: _error,
            onBack: _back,
            onSave: (data) => _action('reschedule', data),
          )
        else
          const SizedBox.shrink(),
        ConfirmPanel(
          pinned: true,
          title: _confirmTitle,
          details: _confirmDetails,
          label: _confirmLabel,
          busy: _busy,
          error: _error,
          destructive: _pendingAction == 'cancel',
          onBack: _back,
          onClose: () => Navigator.pop(context),
          onConfirm: () => _action(_pendingAction, _payload),
        ),
        if (_view == 3)
          GuestDetail(
            guestId: _booking.customerId,
            onBack: _back,
            onUpdated: (guest) => setState(() => _customerName = guest.name),
          )
        else
          const SizedBox.shrink(),
        if (_view == 4)
          StayServicesPanel(booking: _booking, onBack: _back)
        else
          const SizedBox.shrink(),
        if (_view == 5)
          BillingPanel(
            booking: _booking,
            onBack: _back,
            onUpdated: (updated) {
              setState(() {
                _booking = updated;
                _customerName = updated.customerName;
              });
              widget.onUpdated?.call(updated);
            },
          )
        else
          const SizedBox.shrink(),
        if (_view == 6)
          StayServicesPanel(
            booking: _booking,
            onBack: _back,
            onCheckedIn: (updated) {
              setState(() {
                _booking = updated;
                _customerName = updated.customerName;
                _view = 0;
              });
              widget.onUpdated?.call(updated);
              showMessage(context, 'Đã nhận phòng và chuyển dịch vụ đặt kèm');
            },
          )
        else
          const SizedBox.shrink(),
        if (_view == 7)
          StayServicesPanel(booking: _booking, onBack: _back, initialAdd: true)
        else
          const SizedBox.shrink(),
        if (_view == 8)
          RoomMovePanel(
            booking: _booking,
            onBack: _back,
            onMoved: (updated) {
              setState(() {
                _booking = updated;
                _customerName = updated.customerName;
                _view = 0;
              });
              setSheetHeight(context, .85);
              widget.onUpdated?.call(updated);
            },
          )
        else
          const SizedBox.shrink(),
      ],
    ),
  );
}

class _RescheduleForm extends ConsumerStatefulWidget {
  const _RescheduleForm({
    super.key,
    required this.booking,
    required this.onSave,
    required this.onBack,
    required this.busy,
    this.error,
  });
  final HotelBooking booking;
  final ValueChanged<Map<String, dynamic>> onSave;
  final VoidCallback onBack;
  final bool busy;
  final String? error;
  @override
  ConsumerState<_RescheduleForm> createState() => _RescheduleFormState();
}

class _RescheduleFormState extends ConsumerState<_RescheduleForm> {
  late DateTime _start = widget.booking.start, _end = widget.booking.end;
  HotelRoom? _room;
  String? _dateError;
  Future<void> _dates() async {
    final today = ref.read(dashboardProvider).value?.date ?? DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: first.add(const Duration(days: 455)),
      initialDateRange: _start.isBefore(first)
          ? null
          : DateTimeRange(start: _start, end: _end),
      helpText: 'Lịch mới',
    );
    if (!mounted || range == null) return;
    if (range.duration.inDays < 1 ||
        range.duration.inDays > 90 ||
        range.start.difference(first).inDays > 365) {
      setState(
        () => _dateError = 'Chọn 1–90 đêm, nhận phòng trong 365 ngày tới.',
      );
      revealField(context, const Key('reschedule_error'));
      return;
    }
    setState(() {
      _start = range.start;
      _end = range.end;
      _room = null;
      _dateError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      start: dateOnly(_start),
      end: dateOnly(_end),
      guests: widget.booking.guests,
      exclude: widget.booking.id,
    );
    final rooms = ref.watch(availabilityProvider(query));
    final available = rooms.value?.items ?? [];
    final selectionValid =
        !rooms.isLoading &&
        !rooms.hasError &&
        _room != null &&
        available.any((room) => room.id == _room!.id);
    final rate = _room?.id == widget.booking.room.id
        ? widget.booking.nightlyRate
        : _room?.type.rate;
    return PinnedFormLayout(
      header: ScreenHeading(
        title: 'Lịch & phòng',
        action: IconButton(
          tooltip: 'Quay lại',
          onPressed: widget.busy ? null : widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PressScale(
            child: OutlinedButton.icon(
              key: const Key('reschedule_dates'),
              onPressed: widget.busy ? null : _dates,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('${shortDate(_start)} → ${shortDate(_end)}'),
            ),
          ),
          const SizedBox(height: 12),
          AsyncContent(
            value: rooms,
            onRetry: () => ref.invalidate(availabilityProvider(query)),
            builder: (data) => Column(
              children: [
                if (data.items.isEmpty)
                  const EmptyState(
                    icon: Icons.bed_outlined,
                    title: 'Hết phòng phù hợp',
                    message: '',
                  ),
                ...data.items.map(
                  (room) => RoomChoice(
                    key: Key('reschedule_room_${room.id}'),
                    room: room,
                    selected: _room?.id == room.id,
                    nightlyRate: room.id == widget.booking.room.id
                        ? widget.booking.nightlyRate
                        : room.type.rate,
                    onTap: widget.busy
                        ? null
                        : () => setState(() => _room = room),
                  ),
                ),
              ],
            ),
          ),
          if (rate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                money(rate * _end.difference(_start).inDays),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AsterColors.ink,
                ),
              ),
            ),
          if (widget.error != null || _dateError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InlineError(
                widget.error ?? _dateError!,
                key: const Key('reschedule_error'),
              ),
            ),
        ],
      ),
      footer: PressScale(
        child: FilledButton(
          key: const Key('reschedule_save'),
          onPressed: selectionValid && !widget.busy
              ? () => widget.onSave({
                  'room_id': _room!.id,
                  'start_date': dateOnly(_start),
                  'end_date': dateOnly(_end),
                  'guests': widget.booking.guests,
                  if (_room!.id != widget.booking.room.id)
                    'expected_nightly_rate': _room!.type.rate,
                })
              : null,
          child: widget.busy ? const AsterLoader(size: 24) : const Text('Lưu'),
        ),
      ),
    );
  }
}
