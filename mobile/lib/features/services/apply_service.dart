import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/form_layout.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import 'stay_services.dart';

class ApplyServicePanel extends ConsumerStatefulWidget {
  const ApplyServicePanel({
    super.key,
    required this.service,
    required this.onBack,
    this.onApplied,
  });
  final HotelService service;
  final VoidCallback onBack;
  final VoidCallback? onApplied;
  @override
  ConsumerState<ApplyServicePanel> createState() => _ApplyServicePanelState();
}

class _ApplyServicePanelState extends ConsumerState<ApplyServicePanel> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  int _page = 1, _view = 0;
  HotelBooking? _booking;
  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _back() {
    if (sheetIsBusy(context)) return;
    if (_view == 1) {
      setState(() {
        _view = 0;
        _booking = null;
      });
    } else {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = (search: _search, status: 'checked_in', page: _page);
    final value = ref.watch(bookingsProvider(query));
    final allowed =
        ref.watch(authProvider).user?.canEditRooms == true &&
        widget.service.active &&
        widget.service.unitValid;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _view != 2) _back();
      },
      child: SheetPages(
        index: _view,
        children: [
          PinnedFormLayout(
            header: ScreenHeading(
              title: 'Áp dụng dịch vụ',
              leading: IconButton(
                tooltip: 'Quay lại',
                onPressed: _back,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.service.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('${money(widget.service.price)} / ${widget.service.unit}'),
                const SizedBox(height: 16),
                if (!allowed)
                  const InlineError(
                    'Dịch vụ cần đang bán, có đơn vị hợp lệ và tài khoản có quyền ghi dịch vụ.',
                  )
                else ...[
                  const Text('Chọn khách/phòng đang ở để ghi dịch vụ.'),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('apply_room_search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Số phòng hoặc tên khách đang ở',
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
                  const SizedBox(height: 14),
                  AsyncContent(
                    value: value,
                    onRetry: () => ref.invalidate(bookingsProvider(query)),
                    builder: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (data.items.isEmpty)
                          const EmptyState(
                            icon: Icons.hotel_outlined,
                            title: 'Không có phòng đang ở phù hợp',
                            message: 'Khách phải được Nhận phòng trước khi ghi dịch vụ. Thử số phòng hoặc tên khác.',
                          ),
                        for (final booking in data.items.where(
                          (booking) => booking.status == 'checked_in',
                        ))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: Colors.white,
                              child: ListTile(
                                key: Key('apply_booking_${booking.id}'),
                                title: Text(
                                  'Phòng ${booking.room.number} · ${booking.customerName}',
                                ),
                                subtitle: Text(
                                  '${booking.code}\n${DateFormat('dd/MM/yyyy').format(booking.start)} → ${DateFormat('dd/MM/yyyy').format(booking.end)}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                isThreeLine: true,
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setState(() {
                                    _booking = booking;
                                    _view = 1;
                                  });
                                },
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
              ],
            ),
            footer: OutlinedButton.icon(
              onPressed: () => ref.invalidate(bookingsProvider(query)),
              icon: const Icon(Icons.refresh),
              label: const Text('Làm mới phòng đang ở'),
            ),
          ),
          if (_booking != null && _view == 1)
            AddStayServiceForm(
              key: ValueKey(_booking!.id),
              bookingId: _booking!.id,
              initialService: widget.service,
              bookingLabel:
                  'Phòng ${_booking!.room.number} · ${_booking!.customerName}',
              onBack: _back,
              onSaved: () {
                widget.onApplied?.call();
                setState(() => _view = 2);
              },
            )
          else
            const SizedBox.shrink(),
          if (_booking != null && _view == 2)
            StayServicesPanel(booking: _booking!, onBack: widget.onBack)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
