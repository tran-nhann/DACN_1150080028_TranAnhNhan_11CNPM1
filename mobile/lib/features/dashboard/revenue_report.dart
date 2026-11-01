import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/detail_widgets.dart';
import '../../core/providers.dart';
import '../../core/revenue_models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
String _period(DateTime start, DateTime end) =>
    '${DateFormat('dd/MM/yyyy').format(start)} → ${DateFormat('dd/MM/yyyy').format(end.subtract(const Duration(days: 1)))}';

class RevenueSummary extends ConsumerWidget {
  const RevenueSummary({super.key, required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (
      start: _date(DateTime(date.year, date.month)),
      end: _date(DateTime(date.year, date.month + 1)),
    );
    return AsyncContent(
      value: ref.watch(revenueProvider(query)),
      onRetry: () => ref.invalidate(revenueProvider(query)),
      builder: (data) => Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_rounded, color: AsterColors.navy),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Doanh thu ước tính',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Xem báo cáo doanh thu',
                  onPressed: () => showAsterSheet<void>(
                    context: context,
                    form: true,
                    builder: (_) => RevenueReport(initialDate: date),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
            Text(
              'Tháng ${date.month}/${date.year}',
              style: const TextStyle(fontSize: 12, color: AsterColors.muted),
            ),
            const SizedBox(height: 8),
            Text(
              money(data.total),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AsterColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            DetailField(
              inline: true,
              label: 'Tiền phòng',
              value: money(data.roomTotal),
            ),
            const SizedBox(height: 6),
            DetailField(
              inline: true,
              label: 'Dịch vụ đã ghi',
              value: money(data.serviceTotal),
            ),
            if (data.plannedServiceTotal > 0)
              DetailField(
                inline: true,
                label: 'Dịch vụ đặt trước',
                value: money(data.plannedServiceTotal),
              ),
            const SizedBox(height: 12),
            if (data.collectedTotal != null) ...[
              DetailField(
                inline: true,
                label: 'Đã thu trong tháng',
                value: money(data.collectedTotal!),
                emphasize: true,
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Theo lịch đặt và dịch vụ đã ghi; chưa phải tiền đã thu.',
              style: TextStyle(fontSize: 11, color: AsterColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class RevenueReport extends ConsumerStatefulWidget {
  const RevenueReport({super.key, this.initialDate});
  final DateTime? initialDate;
  @override
  ConsumerState<RevenueReport> createState() => _RevenueReportState();
}

class _RevenueReportState extends ConsumerState<RevenueReport> {
  late final DateTime _today;
  late DateTime _start, _end;
  String? _error;
  @override
  void initState() {
    super.initState();
    final date =
        widget.initialDate ??
        ref.read(dashboardProvider).value?.date ??
        DateTime.now();
    _today = DateTime(date.year, date.month, date.day);
    _start = DateTime(date.year, date.month);
    _end = DateTime(date.year, date.month + 1);
  }

  void _select(DateTime start, DateTime end) => setState(() {
    _start = start;
    _end = end;
    _error = null;
  });
  Future<void> _pick() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_today.year - 5),
      lastDate: _today.add(const Duration(days: 731)),
      initialDateRange: DateTimeRange(
        start: _start,
        end: _end.subtract(const Duration(days: 1)),
      ),
      helpText: 'Kỳ thống kê',
      saveText: 'Chọn',
    );
    if (!mounted || range == null) return;
    if (range.duration.inDays >= 366) {
      setState(() => _error = 'Chọn tối đa 366 ngày.');
      return;
    }
    _select(range.start, range.end.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final query = (start: _date(_start), end: _date(_end));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ScreenHeading(
            title: 'Doanh thu ước tính',
            action: IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          _select(_today, _today.add(const Duration(days: 1))),
                      child: const Text('Hôm nay'),
                    ),
                    OutlinedButton(
                      onPressed: () => _select(
                        _today.subtract(const Duration(days: 6)),
                        _today.add(const Duration(days: 1)),
                      ),
                      child: const Text('7 ngày'),
                    ),
                    OutlinedButton(
                      onPressed: () => _select(
                        DateTime(_today.year, _today.month),
                        DateTime(_today.year, _today.month + 1),
                      ),
                      child: const Text('Tháng này'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pick,
                      icon: const Icon(Icons.date_range_outlined),
                      label: const Text('Chọn kỳ'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _period(_start, _end),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Làm mới báo cáo',
                      onPressed: () => ref.invalidate(revenueProvider(query)),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                if (_error != null) InlineError(_error!),
                AsyncContent(
                  value: ref.watch(revenueProvider(query)),
                  onRetry: () => ref.invalidate(revenueProvider(query)),
                  builder: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.collectedTotal != null) ...[
                        DetailSection(
                          title: 'Đã thu trong kỳ',
                          icon: Icons.payments_outlined,
                          children: [
                            DetailField(
                              inline: true,
                              label: 'Thực thu',
                              value: money(data.collectedTotal!),
                              emphasize: true,
                            ),
                            DetailField(
                              inline: true,
                              label: 'Tiền mặt',
                              value: money(data.cashTotal),
                            ),
                            DetailField(
                              inline: true,
                              label: 'Chuyển khoản',
                              value: money(data.bankTotal),
                            ),
                            Text(
                              '${data.paymentCount} phiếu thu · Theo ngày nhận tiền, độc lập với ngày lưu trú.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AsterColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Tổng giá trị dự kiến',
                              style: TextStyle(
                                fontSize: 12,
                                color: AsterColors.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              money(data.total),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AsterColors.navy,
                              ),
                            ),
                            const SizedBox(height: 18),
                            DetailField(
                              inline: true,
                              label: 'Tiền phòng',
                              value: money(data.roomTotal),
                            ),
                            const SizedBox(height: 10),
                            DetailField(
                              inline: true,
                              label: 'Dịch vụ đã ghi',
                              value: money(data.serviceTotal),
                            ),
                            if (data.plannedServiceTotal > 0)
                              DetailField(
                                inline: true,
                                label: 'Dịch vụ đặt trước',
                                value: money(data.plannedServiceTotal),
                              ),
                            const Divider(height: 28),
                            DetailField(
                              inline: true,
                              label: 'Lịch đã xác nhận',
                              value: money(data.confirmedTotal),
                            ),
                            const SizedBox(height: 10),
                            DetailField(
                              inline: true,
                              label: 'Phòng đã nhận / đã trả',
                              value: money(data.stayTotal),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      DetailSection(
                        title: 'Diễn biến trong kỳ',
                        icon: Icons.bar_chart_rounded,
                        children: [RevenueBars(days: data.daily)],
                      ),
                      DetailSection(
                        title: 'Theo hạng phòng hiện tại',
                        icon: Icons.hotel_outlined,
                        children: [
                          if (data.types.isEmpty)
                            const Text('Chưa có giá trị trong kỳ.'),
                          ...data.types.map(
                            (type) => DetailField(
                              inline: true,
                              label: type.name,
                              value: money(type.total),
                            ),
                          ),
                        ],
                      ),
                      DetailSection(
                        title: 'Số liệu trong kỳ',
                        icon: Icons.analytics_outlined,
                        children: [
                          DetailField(
                            inline: true,
                            label: 'Lịch đặt liên quan',
                            value: '${data.bookingCount}',
                          ),
                          DetailField(
                            inline: true,
                            label: 'Số đêm phòng',
                            value: '${data.roomNights}',
                          ),
                          DetailField(
                            inline: true,
                            label: 'Khoản dịch vụ',
                            value: '${data.serviceCount}',
                          ),
                        ],
                      ),
                      const Text(
                        'Ước tính dùng giá đã chốt, phân bổ phòng theo đêm, dịch vụ phát sinh theo ngày ghi và dịch vụ đặt trước theo ngày nhận dự kiến. Bỏ lịch/khoản đã hủy; chưa gồm phụ thu, giảm giá. Tiền đã thu được trình bày riêng theo phiếu thu.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AsterColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RevenueBars extends StatelessWidget {
  const RevenueBars({super.key, required this.days});
  final List<RevenueDay> days;
  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const Text('Chưa có dữ liệu.');
    final maxBars = MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 4 : 7;
    final groupSize = (days.length / maxBars).ceil();
    final groups = <({DateTime date, int amount})>[];
    for (var i = 0; i < days.length; i += groupSize) {
      groups.add((
        date: days[i].date,
        amount: days
            .skip(i)
            .take(groupSize)
            .fold(0, (sum, day) => sum + day.total),
      ));
    }
    final maximum = math.max(
      1,
      groups.fold(0, (value, group) => math.max(value, group.amount)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: groups
                .map(
                  (group) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Tooltip(
                        message:
                            'Từ ${DateFormat('dd/MM').format(group.date)} · ${money(group.amount)}',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                NumberFormat.compact(locale: 'vi')
                                    .format(group.amount),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Container(
                              height: math.max(3, 110 * group.amount / maximum),
                              width: 22,
                              decoration: BoxDecoration(
                                color: group.amount == 0
                                    ? AsterColors.border
                                    : AsterColors.navy,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 9),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                DateFormat('dd/MM').format(group.date),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AsterColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          groupSize == 1
              ? 'Mỗi cột là một ngày.'
              : 'Mỗi cột gộp tối đa $groupSize ngày, bắt đầu từ ngày trên trục.',
          style: const TextStyle(fontSize: 11, color: AsterColors.muted),
        ),
      ],
    );
  }
}
