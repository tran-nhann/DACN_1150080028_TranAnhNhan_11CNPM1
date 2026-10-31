import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'bookings_screen.dart';

class BookingHistory extends ConsumerStatefulWidget {
  const BookingHistory({
    super.key,
    this.roomId,
    this.customerId,
    this.day,
    this.kind,
    this.title = 'Lịch đặt',
    required this.onSelected,
  });
  final int? roomId, customerId;
  final String? day, kind;
  final String title;
  final ValueChanged<HotelBooking> onSelected;
  @override
  ConsumerState<BookingHistory> createState() => _BookingHistoryState();
}

class _BookingHistoryState extends ConsumerState<BookingHistory> {
  int _page = 1;
  @override
  void didUpdateWidget(BookingHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId ||
        oldWidget.customerId != widget.customerId ||
        oldWidget.day != widget.day ||
        oldWidget.kind != widget.kind) {
      _page = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = BookingLookup(
      roomId: widget.roomId,
      customerId: widget.customerId,
      day: widget.day,
      kind: widget.kind,
      page: _page,
    );
    final value = ref.watch(bookingLookupProvider(query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (value.hasValue)
              Text(
                '${value.value!.count}',
                style: const TextStyle(
                  color: AsterColors.teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            IconButton(
              tooltip: 'Làm mới lịch đặt',
              onPressed: () => ref.invalidate(bookingLookupProvider(query)),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AsyncContent(
          value: value,
          onRetry: () => ref.invalidate(bookingLookupProvider(query)),
          builder: (data) => Column(
            children: [
              if (data.items.isEmpty)
                const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Chưa có lượt đặt',
                  message: '',
                ),
              ...data.items.map(
                (booking) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookingCard(
                    booking: booking,
                    onTap: () => widget.onSelected(booking),
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
    );
  }
}

class DailyBookings extends StatefulWidget {
  const DailyBookings({super.key, required this.kind, required this.day});
  final String kind;
  final DateTime day;
  @override
  State<DailyBookings> createState() => _DailyBookingsState();
}

class _DailyBookingsState extends State<DailyBookings> {
  HotelBooking? _selected;
  void _back() {
    setState(() => _selected = null);
    setSheetHeight(context, .85);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _selected == null,
    child: SheetPages(
      index: _selected == null ? 0 : 1,
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            children: [
              ScreenHeading(
                title: switch (widget.kind) {
                  'arrivals' => 'Khách đến',
                  'departures' => 'Khách đi',
                  _ => 'Đang ở',
                },
                subtitle: DateFormat('dd/MM/yyyy').format(widget.day),
                action: IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              BookingHistory(
                kind: widget.kind,
                day: DateFormat('yyyy-MM-dd').format(widget.day),
                title: 'Đặt phòng',
                onSelected: (booking) => setState(() => _selected = booking),
              ),
            ],
          ),
        ),
        if (_selected != null)
          BookingDetail(
            key: ValueKey(_selected!.id),
            booking: _selected!,
            onBack: _back,
          )
        else
          const SizedBox.shrink(),
      ],
    ),
  );
}
