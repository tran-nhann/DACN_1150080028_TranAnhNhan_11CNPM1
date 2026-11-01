import 'package:flutter/material.dart';

import '../../core/models.dart';

class BookingTiming {
  const BookingTiming(this.color, this.background, {this.label});
  final Color color, background;
  final String? label;

  factory BookingTiming.forBooking(HotelBooking booking, DateTime today) {
    if (booking.status == 'cancelled') {
      return const BookingTiming(Color(0xFF9F1239), Color(0xFFFFF1F2));
    }
    if (booking.status == 'checked_out') {
      return const BookingTiming(Color(0xFF64748B), Color(0xFFF1F5F9));
    }
    if (booking.status == 'checked_in') {
      return const BookingTiming(Color(0xFF1D4ED8), Color(0xFFEFF6FF));
    }
    final days = DateTime.utc(
      booking.start.year,
      booking.start.month,
      booking.start.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    if (days < 0) {
      return const BookingTiming(
        Color(0xFFB91C1C),
        Color(0xFFFEF2F2),
        label: 'Trễ ngày nhận',
      );
    }
    if (days == 0) {
      return const BookingTiming(
        Color(0xFF9A3412),
        Color(0xFFFFF7ED),
        label: 'Đến hôm nay',
      );
    }
    if (days == 1) {
      return const BookingTiming(
        Color(0xFF1D4ED8),
        Color(0xFFEFF6FF),
        label: 'Đến ngày mai',
      );
    }
    return BookingTiming(
      const Color(0xFF6D28D9),
      const Color(0xFFF5F3FF),
      label: 'Còn $days ngày',
    );
  }
}

class BookingTimingBadge extends StatelessWidget {
  const BookingTimingBadge({super.key, required this.timing});
  final BookingTiming timing;

  @override
  Widget build(BuildContext context) {
    if (timing.label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: timing.background,
        border: Border.all(color: timing.color.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, color: timing.color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              timing.label!,
              style: TextStyle(
                color: timing.color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
