import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/billing_models.dart';
import '../../core/detail_widgets.dart';
import '../../core/form_layout.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../services/stay_services.dart';

class BillingPanel extends ConsumerStatefulWidget {
  const BillingPanel({
    super.key,
    required this.booking,
    required this.onBack,
    required this.onUpdated,
  });
  final HotelBooking booking;
  final VoidCallback onBack;
  final ValueChanged<HotelBooking> onUpdated;
  @override
  ConsumerState<BillingPanel> createState() => _BillingPanelState();
}

class _BillingPanelState extends ConsumerState<BillingPanel> {
  final _reference = TextEditingController(), _notes = TextEditingController();
  String? _method, _error, _fingerprint;
  String _key = const Uuid().v4();
  bool _received = false, _busy = false;
  HotelInvoice? _invoice;
  bool _editingServices = false;
  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_busy) return;
    if (_invoice != null ||
        ref.read(folioProvider(widget.booking.id)).value?.invoice != null) {
      try {
        final current = await ref
            .read(apiProvider)
            .getBooking(widget.booking.id);
        if (!mounted) return;
        widget.onUpdated(current);
      } catch (_) {
        // The invoice remains visible and read-only even if refreshing the booking fails.
      }
    }
    if (mounted) widget.onBack();
  }

  void _reload() {
    if (_busy) return;
    setState(() {
      _received = false;
      _error = null;
    });
    ref.invalidate(folioProvider(widget.booking.id));
  }

  Future<void> _pay(StayFolio folio) async {
    if (_busy || !_received || _method == null || !folio.canCheckout) return;
    final data = <String, dynamic>{
      'quote_token': folio.quote,
      'expected_total': folio.total.toString(),
      'method': _method,
      'payment_received': true,
      'reference': _reference.text.trim(),
      'notes': _notes.text.trim(),
    };
    final fingerprint = jsonEncode(data);
    if (_fingerprint != null && _fingerprint != fingerprint) {
      _key = const Uuid().v4();
    }
    _fingerprint = fingerprint;
    setState(() {
      _busy = true;
      _error = null;
    });
    setSheetBusy(context, true);
    try {
      final result = await ref
          .read(apiProvider)
          .checkout(widget.booking.id, data, _key);
      if (!mounted) return;
      setSheetBusy(context, false);
      setState(() {
        _busy = false;
        _invoice = result.invoice;
      });
      refreshBookings(ref);
      widget.onUpdated(result.booking);
      showMessage(context, 'Đã thu tiền và trả phòng · Phòng Cần dọn');
    } catch (error) {
      if (!mounted) return;
      setSheetBusy(context, false);
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(folioProvider(widget.booking.id));
    final invoice = _invoice ?? value.value?.invoice;
    final canPay = ref.watch(authProvider).user?.canEditRooms == true;
    final folio = value.value?.folio;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy && !_editingServices) _back();
      },
      child: invoice != null
          ? InvoicePanel(invoice: invoice, onBack: _back)
          : _editingServices
          ? StayServicesPanel(
              booking: widget.booking,
              onChanged: _reload,
              onBack: () {
                setState(() => _editingServices = false);
                _reload();
              },
            )
          : PinnedFormLayout(
              header: ScreenHeading(
                title: 'Quyết toán lưu trú',
                leading: IconButton(
                  tooltip: 'Quay lại',
                  onPressed: _busy ? null : _back,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                action: IconButton(
                  tooltip: 'Làm mới bảng kê',
                  onPressed: _busy ? null : _reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canPay && widget.booking.status == 'checked_in') ...[
                    OutlinedButton.icon(
                      key: const Key('folio_services_edit'),
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _editingServices = true;
                                _received = false;
                              });
                            },
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Bổ sung / hủy dịch vụ'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  AsyncContent(
                    value: value,
                    onRetry: _reload,
                    builder: (state) {
                      final current = state.folio;
                      if (current == null) {
                        return const Text('Không có bảng kê lưu trú.');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${current.guest} · Phòng ${current.roomNumber}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(current.start)} → ${DateFormat('dd/MM/yyyy').format(current.end)}',
                          ),
                          const SizedBox(height: 18),
                          BillLines(lines: current.lines),
                          BillTotals(
                            room: current.roomTotal,
                            services: current.serviceTotal,
                            total: current.total,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            current.policy,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AsterColors.muted,
                            ),
                          ),
                          if (!current.canCheckout) ...[
                            const SizedBox(height: 12),
                            InlineError(current.blockedReason),
                          ],
                          if (canPay && current.canCheckout) ...[
                            const SizedBox(height: 22),
                            DropdownButtonFormField<String>(
                              key: const Key('checkout_method'),
                              isExpanded: true,
                              initialValue: _method,
                              decoration: const InputDecoration(
                                labelText: 'Hình thức thanh toán',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'cash',
                                  child: Text('Tiền mặt'),
                                ),
                                DropdownMenuItem(
                                  value: 'bank_transfer',
                                  child: Text('Chuyển khoản'),
                                ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(() {
                                      _method = value;
                                      _received = false;
                                    }),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const Key('checkout_reference'),
                              controller: _reference,
                              enabled: !_busy,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                labelText: 'Mã giao dịch / tham chiếu (nếu có)',
                              ),
                            ),
                            TextField(
                              key: const Key('checkout_notes'),
                              controller: _notes,
                              enabled: !_busy,
                              maxLength: 300,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Ghi chú thanh toán',
                              ),
                            ),
                            CheckboxListTile(
                              key: const Key('checkout_received'),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _received,
                              onChanged: _busy || _method == null
                                  ? null
                                  : (value) => setState(
                                      () => _received = value == true,
                                    ),
                              title: Text('Đã nhận đủ ${money(current.total)}'),
                            ),
                            const Text(
                              'Chốt hóa đơn sẽ ghi nhận thanh toán, trả phòng và chuyển buồng sang Cần dọn.',
                            ),
                          ],
                          if (_error != null) ...[
                            InlineError(
                              _error!,
                              key: const Key('checkout_error'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _reload,
                              child: const Text('Tải lại bảng kê / hóa đơn'),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
              footer: canPay && folio?.canCheckout == true
                  ? FilledButton.icon(
                      key: const Key('checkout_submit'),
                      onPressed:
                          _busy ||
                              !_received ||
                              _method == null ||
                              value.isLoading ||
                              value.hasError
                          ? null
                          : () => _pay(folio!),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout_rounded),
                      label: const Text('Chốt hóa đơn & trả phòng'),
                    )
                  : OutlinedButton(
                      onPressed: _busy ? null : _back,
                      child: const Text('Quay lại'),
                    ),
            ),
    );
  }
}

class BillLines extends StatelessWidget {
  const BillLines({super.key, required this.lines});
  final List<BillLine> lines;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final kind in ['room', 'service'])
        DetailSection(
          title: kind == 'room' ? 'Tiền phòng' : 'Dịch vụ phát sinh',
          icon: kind == 'room'
              ? Icons.hotel_outlined
              : Icons.room_service_outlined,
          children: [
            if (!lines.any((line) => line.kind == kind))
              const Text('Không có dịch vụ tính tiền.'),
            for (final line in lines.where((line) => line.kind == kind))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      line.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    DetailField(
                      inline: true,
                      label:
                          '${line.quantity} ${line.unit} × ${money(line.price)}',
                      value: money(line.total),
                    ),
                  ],
                ),
              ),
          ],
        ),
    ],
  );
}

class BillTotals extends StatelessWidget {
  const BillTotals({
    super.key,
    required this.room,
    required this.services,
    required this.total,
  });
  final int room, services, total;
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailField(inline: true, label: 'Tiền phòng', value: money(room)),
        const SizedBox(height: 8),
        DetailField(inline: true, label: 'Dịch vụ', value: money(services)),
        const Divider(height: 24),
        DetailField(
          inline: true,
          label: 'Tổng thanh toán',
          value: money(total),
          emphasize: true,
        ),
      ],
    ),
  );
}

class InvoicePanel extends StatelessWidget {
  const InvoicePanel({super.key, required this.invoice, required this.onBack});
  final HotelInvoice invoice;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final payment = invoice.payment;
    return PinnedFormLayout(
      header: ScreenHeading(
        title: 'Hóa đơn đã thanh toán',
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(
            invoice.code,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text('${invoice.guest} · ${invoice.phone}'),
          Text('Phòng ${invoice.roomNumber} · ${invoice.roomType}'),
          Text('Đặt phòng ${invoice.bookingCode}'),
          Text(
            '${DateFormat('dd/MM/yyyy').format(invoice.start)} → ${DateFormat('dd/MM/yyyy').format(invoice.end)}',
          ),
          const SizedBox(height: 18),
          BillLines(lines: invoice.lines),
          BillTotals(
            room: invoice.roomTotal,
            services: invoice.serviceTotal,
            total: invoice.total,
          ),
          const SizedBox(height: 18),
          DetailSection(
            title: 'Phiếu thu ${payment.code}',
            icon: Icons.payments_outlined,
            children: [
              DetailField(
                inline: true,
                label: 'Đã thu',
                value: money(payment.amount),
                emphasize: true,
              ),
              DetailField(
                inline: true,
                label: 'Hình thức',
                value: payment.methodLabel,
              ),
              DetailField(
                inline: true,
                label: 'Thu lúc',
                value: dateStamp(payment.date),
              ),
              DetailField(
                inline: true,
                label: 'Người thu',
                value: payment.cashier,
              ),
              if (payment.reference.isNotEmpty)
                DetailField(
                  inline: true,
                  label: 'Tham chiếu',
                  value: payment.reference,
                ),
              if (payment.notes.isNotEmpty) Text(payment.notes),
            ],
          ),
          Text(
            'Lập lúc ${dateStamp(invoice.issuedAt)} · ${invoice.issuedBy}',
            style: const TextStyle(fontSize: 12, color: AsterColors.muted),
          ),
        ],
      ),
      footer: OutlinedButton.icon(
        key: const Key('invoice_copy'),
        onPressed: () async {
          final text = [
            'KHÁCH SẠN NGÀN SAO',
            'Hóa đơn ${invoice.code}',
            'Đặt phòng ${invoice.bookingCode}',
            '${invoice.guest} · ${invoice.phone}',
            'Phòng ${invoice.roomNumber} · ${invoice.roomType}',
            '${DateFormat('dd/MM/yyyy').format(invoice.start)} → ${DateFormat('dd/MM/yyyy').format(invoice.end)}',
            ...invoice.lines.map(
              (line) =>
                  '${line.name}: ${line.quantity} ${line.unit} × ${money(line.price)} = ${money(line.total)}',
            ),
            'TỔNG: ${money(invoice.total)}',
            'ĐÃ THU: ${money(payment.amount)} · ${payment.methodLabel}',
            'Phiếu thu ${payment.code} · ${dateStamp(payment.date)} · ${payment.cashier}',
            if (payment.reference.isNotEmpty)
              'Tham chiếu: ${payment.reference}',
          ].join('\n');
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) showMessage(context, 'Đã sao chép hóa đơn');
        },
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Sao chép hóa đơn'),
      ),
    );
  }
}
