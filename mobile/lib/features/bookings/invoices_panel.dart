import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/billing_models.dart';
import '../../core/detail_widgets.dart';
import '../../core/form_layout.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import 'billing_panel.dart';

class InvoicesPanel extends ConsumerStatefulWidget {
  const InvoicesPanel({super.key});
  @override
  ConsumerState<InvoicesPanel> createState() => _InvoicesPanelState();
}

class _InvoicesPanelState extends ConsumerState<InvoicesPanel> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '', _method = '';
  int _page = 1;
  HotelInvoice? _selected;
  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (search: _search, method: _method, page: _page);
    final value = ref.watch(invoicesProvider(query));
    return PopScope(
      canPop: _selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = null);
      },
      child: _selected != null
          ? InvoicePanel(
              invoice: _selected!,
              onBack: () => setState(() => _selected = null),
            )
          : PinnedFormLayout(
              header: ScreenHeading(
                title: 'Hóa đơn & phiếu thu',
                action: IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Mã hóa đơn, khách, số phòng',
                      prefixIcon: Icon(Icons.search),
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final item in [
                        ('', 'Tất cả'),
                        ('cash', 'Tiền mặt'),
                        ('bank_transfer', 'Chuyển khoản'),
                      ])
                        ChoiceChip(
                          label: Text(item.$2),
                          selected: _method == item.$1,
                          onSelected: (_) => setState(() {
                            _method = item.$1;
                            _page = 1;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AsyncContent(
                    value: value,
                    onRetry: () => ref.invalidate(invoicesProvider(query)),
                    builder: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${data.count} hóa đơn'),
                        if (data.items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Chưa có hóa đơn phù hợp.'),
                          ),
                        for (final invoice in data.items)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Material(
                              color: Colors.white,
                              child: ListTile(
                                title: Text(
                                  '${invoice.code} · Phòng ${invoice.roomNumber}',
                                ),
                                subtitle: Text(
                                  '${invoice.guest}\n${money(invoice.total)} · ${invoice.payment.methodLabel}\n${dateStamp(invoice.payment.date)}',
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () =>
                                    setState(() => _selected = invoice),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              footer: Pager(
                page: _page,
                hasNext: value.value?.hasNext == true,
                onPage: (page) => setState(() => _page = page),
              ),
            ),
    );
  }
}
