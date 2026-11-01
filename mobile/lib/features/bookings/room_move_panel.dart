import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/api.dart';
import '../../core/detail_widgets.dart';
import '../../core/form_layout.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/room_move_models.dart';
import '../../core/widgets.dart';
import 'billing_panel.dart';

final roomMoveOptionsProvider = FutureProvider.autoDispose
    .family<RoomMoveOptions, int>(
      (ref, id) => ref
          .watch(apiProvider)
          .roomMoveOptions(id)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () =>
                throw const ApiFailure('Tải phòng trống quá lâu. Bấm Thử lại.'),
          ),
      retry: (_, _) => null,
    );

class RoomMovePanel extends ConsumerStatefulWidget {
  const RoomMovePanel({
    super.key,
    required this.booking,
    required this.onBack,
    required this.onMoved,
  });
  final HotelBooking booking;
  final VoidCallback onBack;
  final ValueChanged<HotelBooking> onMoved;
  @override
  ConsumerState<RoomMovePanel> createState() => _RoomMovePanelState();
}

class _RoomMovePanelState extends ConsumerState<RoomMovePanel> {
  final _reason = TextEditingController();
  HotelRoom? _room;
  String _mode = 'target', _condition = 'cleaning', _key = const Uuid().v4();
  String? _error;
  RoomMoveQuote? _quote;
  bool _busy = false, _sending = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _inputs => {
    'room_id': _room!.id,
    'price_mode': _mode,
    'old_room_condition': _condition,
    'reason': _reason.text.trim(),
  };

  void _edit(VoidCallback update) {
    if (_busy) return;
    setState(() {
      update();
      _quote = null;
      _error = null;
      _key = const Uuid().v4();
    });
  }

  Future<void> _preview() async {
    if (_busy || _room == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Nhập lý do chuyển phòng.');
      revealField(context, const Key('move_error'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    setSheetBusy(context, true);
    try {
      final quote = await ref
          .read(apiProvider)
          .roomMoveQuote(widget.booking.id, _inputs)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setSheetBusy(context, false);
      setState(() {
        _busy = false;
        _quote = quote;
        _key = const Uuid().v4();
      });
    } catch (error) {
      if (!mounted) return;
      setSheetBusy(context, false);
      setState(() {
        _busy = false;
        _error = error is TimeoutException
            ? 'Xem chênh lệch quá lâu. Vui lòng thử lại.'
            : error.toString();
      });
      revealField(context, const Key('move_error'));
    }
  }

  Future<void> _commit() async {
    if (_busy || _quote == null) return;
    setState(() {
      _busy = true;
      _sending = true;
      _error = null;
    });
    setSheetBusy(context, true);
    try {
      final updated = await ref.read(apiProvider).moveRoom(widget.booking.id, {
        ..._inputs,
        'quote_token': _quote!.token,
      }, _key);
      if (!mounted) return;
      setSheetBusy(context, false);
      setState(() {
        _busy = false;
        _sending = false;
      });
      refreshBookings(ref);
      ref.invalidate(roomMoveOptionsProvider);
      widget.onMoved(updated);
      showMessage(context, 'Đã chuyển sang phòng ${updated.room.number}');
    } catch (error) {
      if (!mounted) return;
      setSheetBusy(context, false);
      // Keep the exact quote/key after a network failure so retry cannot move twice.
      setState(() {
        _busy = false;
        _sending = false;
        _error = error.toString();
      });
      revealField(context, const Key('move_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(roomMoveOptionsProvider(widget.booking.id));
    final editable =
        ref.watch(authProvider).user?.canEditRooms == true &&
        widget.booking.status == 'checked_in';
    final q = _quote;
    final selected =
        !options.isLoading &&
        !options.hasError &&
        options.value?.rooms.any((row) => row.id == _room?.id) == true;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) {
          if (_quote != null) {
            _edit(() {});
          } else {
            widget.onBack();
          }
        }
      },
      child: PinnedFormLayout(
        header: ScreenHeading(
          title: q == null ? 'Chuyển phòng' : 'Xác nhận chuyển phòng',
          action: IconButton(
            tooltip: 'Quay lại',
            onPressed: _busy
                ? null
                : q == null
                ? widget.onBack
                : () => _edit(() {}),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Phòng ${widget.booking.room.number} · ${widget.booking.customerName}',
            ),
            const SizedBox(height: 12),
            if (!editable)
              const InlineError(
                'Chỉ admin/lễ tân được chuyển phòng cho khách đang ở.',
              )
            else if (q != null) ...[
              DetailSection(
                title: '${q.from} → ${q.to}',
                icon: Icons.move_up_rounded,
                children: [
                  DetailField(
                    label: 'Tính từ đêm',
                    value: DateFormat('dd/MM/yyyy').format(q.date),
                  ),
                  DetailField(
                    label: 'Số đêm còn lại',
                    value: '${q.nights} đêm',
                  ),
                  DetailField(
                    label: 'Giá hiện tại / đêm',
                    value: money(q.oldRate),
                  ),
                  DetailField(
                    label: 'Giá sau chuyển / đêm',
                    value: money(q.newRate),
                  ),
                  DetailField(
                    label: 'Tiền phòng trước chuyển',
                    value: money(q.oldTotal),
                  ),
                  DetailField(
                    label: 'Tiền phòng sau chuyển',
                    value: money(q.newTotal),
                  ),
                  DetailField(
                    label: q.difference < 0
                        ? 'Giảm tiền phòng'
                        : q.difference > 0
                        ? 'Tăng tiền phòng'
                        : 'Chênh lệch',
                    value: money(q.difference.abs()),
                    emphasize: true,
                  ),
                  DetailField(
                    label: 'Phòng cũ',
                    value: _condition == 'maintenance' ? 'Bảo trì' : 'Cần dọn',
                  ),
                  DetailField(label: 'Lý do', value: _reason.text.trim()),
                ],
              ),
              BillTotals(
                room: q.newTotal,
                services: q.services,
                total: q.total,
              ),
              const SizedBox(height: 12),
              Text(q.policy),
              const SizedBox(height: 8),
              const Text(
                'Xác nhận chuyển chỉ cập nhật lưu trú; thanh toán khi trả phòng.',
              ),
            ] else
              AsyncContent(
                value: options,
                onRetry: () =>
                    ref.invalidate(roomMoveOptionsProvider(widget.booking.id)),
                builder: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(data.policy),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('move_price_mode'),
                      initialValue: _mode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Cách tính giá',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'target',
                          child: Text('Giá phòng mới'),
                        ),
                        DropdownMenuItem(
                          value: 'keep',
                          child: Text('Giữ giá hiện tại'),
                        ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => _edit(() => _mode = value!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('move_old_condition'),
                      initialValue: _condition,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Phòng cũ sau chuyển',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cleaning',
                          child: Text('Cần dọn'),
                        ),
                        DropdownMenuItem(
                          value: 'maintenance',
                          child: Text('Bảo trì'),
                        ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => _edit(() => _condition = value!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('move_reason'),
                      controller: _reason,
                      enabled: !_busy,
                      maxLength: 300,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Lý do chuyển phòng',
                      ),
                      onChanged: (_) => _edit(() {}),
                    ),
                    const SizedBox(height: 12),
                    const Text('Chọn phòng mới'),
                    const SizedBox(height: 8),
                    if (data.rooms.isEmpty)
                      const EmptyState(
                        icon: Icons.bed_outlined,
                        title: 'Chưa có phòng phù hợp',
                        message: 'Cần phòng đã dọn, đủ sức chứa và trống đến ngày trả.',
                      ),
                    for (final room in data.rooms)
                      RoomChoice(
                        key: Key('move_room_${room.id}'),
                        room: room,
                        selected: _room?.id == room.id,
                        nightlyRate: _mode == 'keep'
                            ? widget.booking.nightlyRate
                            : room.type.rate,
                        onTap: _busy ? null : () => _edit(() => _room = room),
                      ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: InlineError(_error!, key: const Key('move_error')),
              ),
          ],
        ),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (q != null)
              OutlinedButton(
                key: const Key('move_edit'),
                onPressed: _busy
                    ? null
                    : () {
                        _edit(() {});
                        ref.invalidate(
                          roomMoveOptionsProvider(widget.booking.id),
                        );
                      },
                child: const Text('Chọn lại / cập nhật chênh lệch'),
              ),
            FilledButton(
              key: Key(q == null ? 'move_preview' : 'move_confirm'),
              onPressed: !editable || _busy || (q == null && !selected)
                  ? null
                  : q == null
                  ? _preview
                  : _commit,
              child: _busy
                  ? const AsterLoader(size: 24)
                  : Text(
                      q == null
                          ? 'Xem chênh lệch'
                          : _sending
                          ? 'Đang chuyển phòng'
                          : 'Xác nhận chuyển phòng',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
