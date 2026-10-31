import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api.dart';
import '../../core/detail_widgets.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'services_screen.dart';

class StayServicesPanel extends ConsumerStatefulWidget {
  const StayServicesPanel({
    super.key,
    required this.booking,
    required this.onBack,
  });
  final HotelBooking booking;
  final VoidCallback onBack;
  @override
  ConsumerState<StayServicesPanel> createState() => _StayServicesPanelState();
}

class _StayServicesPanelState extends ConsumerState<StayServicesPanel> {
  int _view = 0, _page = 1, _formVersion = 0;
  ServiceUsage? _selected;
  void _back() {
    if (sheetIsBusy(context)) return;
    setState(() => _view = 0);
    setSheetHeight(context, .85);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _saved() {
    ref.invalidate(stayServicesProvider);
    setState(() {
      _view = 0;
      _page = 1;
      _formVersion++;
      _selected = null;
    });
    setSheetHeight(context, .85);
  }

  Widget _list() {
    final query = (bookingId: widget.booking.id, page: _page);
    final value = ref.watch(stayServicesProvider(query));
    final editable =
        ref.watch(authProvider).user?.canEditRooms == true &&
        value.value?.canEdit == true &&
        !value.hasError &&
        !value.isLoading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            key: const PageStorageKey('stay_services'),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeading(
                  title: 'Dịch vụ',
                  subtitle:
                      'Phòng ${widget.booking.room.number} · ${widget.booking.customerName}',
                  action: IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Quay lại'),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Làm mới dịch vụ',
                      onPressed: () => ref.invalidate(stayServicesProvider),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AsyncContent(
                  value: value,
                  onRetry: () => ref.invalidate(stayServicesProvider(query)),
                  builder: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DetailSection(
                        title: 'Tạm tính',
                        icon: Icons.receipt_long_outlined,
                        children: [
                          DetailField(
                            label: 'Tiền phòng',
                            value: money(data.roomTotal),
                          ),
                          DetailField(
                            label: 'Dịch vụ',
                            value: money(data.serviceTotal),
                          ),
                          DetailField(
                            label: 'Tổng',
                            value: money(data.estimatedTotal),
                            emphasize: true,
                          ),
                        ],
                      ),
                      Text(
                        '${data.count} khoản',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      if (data.items.isEmpty)
                        const EmptyState(
                          icon: Icons.room_service_outlined,
                          title: 'Chưa ghi dịch vụ',
                          message: '',
                        ),
                      ...data.items.map(
                        (usage) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Surface(
                            color: usage.cancelled
                                ? const Color(0xFFF7F7F7)
                                : AsterColors.background,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  usage.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AsterColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${usage.quantity} ${usage.unit} × ${money(usage.price)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  money(usage.total),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: usage.cancelled
                                        ? AsterColors.muted
                                        : AsterColors.teal,
                                    decoration: usage.cancelled
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${dateStamp(usage.createdAt)} · ${usage.createdBy}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                if (usage.cancelled) ...[
                                  const SizedBox(height: 12),
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.cancel_outlined,
                                        size: 16,
                                        color: AsterColors.red,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Đã hủy',
                                        style: TextStyle(
                                          color: AsterColors.red,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    usage.cancelReason,
                                    style: const TextStyle(
                                      color: AsterColors.ink,
                                    ),
                                  ),
                                  if (usage.cancelledAt != null)
                                    Text(
                                      '${dateStamp(usage.cancelledAt!)} · ${usage.cancelledBy ?? ''}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                ] else if (editable)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      key: Key('cancel_usage_${usage.id}'),
                                      onPressed: () {
                                        setState(() {
                                          _selected = usage;
                                          _view = 2;
                                        });
                                        setSheetHeight(context, .95);
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 18,
                                      ),
                                      label: const Text('Hủy khoản'),
                                    ),
                                  ),
                              ],
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
          ),
        ),
        if (editable)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: PressScale(
                child: FilledButton.icon(
                  key: const Key('add_stay_service'),
                  onPressed: () {
                    setState(() => _view = 1);
                    setSheetHeight(context, .95);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Ghi dịch vụ'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop || sheetIsBusy(context)) return;
      if (_view == 0) {
        widget.onBack();
      } else {
        _back();
      }
    },
    child: SheetPages(
      index: _view,
      children: [
        _list(),
        AddStayServiceForm(
          key: ValueKey(_formVersion),
          bookingId: widget.booking.id,
          onBack: _back,
          onSaved: _saved,
        ),
        if (_selected != null)
          CancelUsageForm(
            key: ValueKey(_selected!.id),
            bookingId: widget.booking.id,
            usage: _selected!,
            onBack: _back,
            onSaved: _saved,
          )
        else
          const SizedBox.shrink(),
      ],
    ),
  );
}

class AddStayServiceForm extends ConsumerStatefulWidget {
  const AddStayServiceForm({
    super.key,
    required this.bookingId,
    required this.onBack,
    required this.onSaved,
  });
  final int bookingId;
  final VoidCallback onBack, onSaved;
  @override
  ConsumerState<AddStayServiceForm> createState() => _AddStayServiceFormState();
}

class _AddStayServiceFormState extends ConsumerState<AddStayServiceForm> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  HotelService? _service;
  bool _busy = false;
  String _key = const Uuid().v4();
  String? _error;
  Map<String, String> _fields = {};
  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _service == null || !validateAndReveal(context, _form)) return;
    setState(() {
      _busy = true;
      _error = null;
      _fields = {};
    });
    setSheetBusy(context, true);
    try {
      final usage = await ref.read(apiProvider).addServiceUsage(
        widget.bookingId,
        {
          'service_id': _service!.id,
          'quantity': int.parse(_quantity.text),
          'expected_unit_price': _service!.price,
        },
        _key,
      );
      if (!mounted) return;
      setSheetBusy(context, false);
      setState(() => _busy = false);
      showMessage(context, usage.cancelled ? 'Khoản đã hủy' : 'Đã ghi');
      widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      ref.invalidate(stayServicesProvider);
      ref.invalidate(servicesProvider);
      setSheetBusy(context, false);
      setState(() {
        _busy = false;
        _error = error.toString();
        _fields = error is ApiFailure ? error.fields : {};
      });
      revealField(
        context,
        Key(_fields.containsKey('quantity') ? 'usage_quantity' : 'usage_error'),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(
            title: 'Ghi dịch vụ',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: _busy ? null : widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (_service == null)
            ServiceCatalog(
              activeOnly: true,
              enabled: !_busy,
              onSelected: (service) => setState(() {
                _service = service;
                _error = null;
                _fields = {};
                _key = const Uuid().v4();
              }),
            )
          else ...[
            Surface(
              color: AsterColors.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _service!.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${money(_service!.price)} / ${_service!.unit}'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('reselect_service'),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _service = null),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Chọn lại'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _form,
              child: TextFormField(
                key: const Key('usage_quantity'),
                controller: _quantity,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: InputDecoration(
                  labelText: 'Số lượng',
                  suffixText: _service!.unit,
                  errorText: _fields['quantity'],
                ),
                validator: (value) {
                  final count = int.tryParse(value ?? '');
                  return count == null || count < 1 || count > 999
                      ? 'Chọn 1–999.'
                      : null;
                },
                onChanged: (_) => setState(() {
                  _key = const Uuid().v4();
                  _error = null;
                  _fields = {};
                }),
              ),
            ),
            const SizedBox(height: 20),
            DetailField(
              label: 'Thành tiền',
              value: money(
                _service!.price * (int.tryParse(_quantity.text) ?? 0),
              ),
              emphasize: true,
            ),
            if (_error != null && !_fields.containsKey('quantity')) ...[
              const SizedBox(height: 14),
              InlineError(_error!, key: const Key('usage_error')),
            ],
            const SizedBox(height: 24),
            PressScale(
              child: FilledButton(
                key: const Key('usage_save'),
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const AsterLoader(size: 24)
                    : const Text('Ghi nhận'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class CancelUsageForm extends ConsumerStatefulWidget {
  const CancelUsageForm({
    super.key,
    required this.bookingId,
    required this.usage,
    required this.onBack,
    required this.onSaved,
  });
  final int bookingId;
  final ServiceUsage usage;
  final VoidCallback onBack, onSaved;
  @override
  ConsumerState<CancelUsageForm> createState() => _CancelUsageFormState();
}

class _CancelUsageFormState extends ConsumerState<CancelUsageForm> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error, _reasonError;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !validateAndReveal(context, _form)) return;
    setState(() {
      _busy = true;
      _error = null;
      _reasonError = null;
    });
    setSheetBusy(context, true);
    try {
      await ref
          .read(apiProvider)
          .cancelServiceUsage(
            widget.bookingId,
            widget.usage.id,
            _reason.text.trim(),
          );
      if (!mounted) return;
      setSheetBusy(context, false);
      setState(() => _busy = false);
      showMessage(context, 'Đã hủy khoản');
      widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      ref.invalidate(stayServicesProvider);
      setSheetBusy(context, false);
      setState(() {
        _busy = false;
        _error = error.toString();
        _reasonError = error is ApiFailure ? error.fields['reason'] : null;
      });
      revealField(
        context,
        Key(_reasonError == null ? 'cancel_usage_error' : 'usage_reason'),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeading(
              title: 'Hủy khoản?',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Quay lại',
                    onPressed: _busy ? null : widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Text(
              widget.usage.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${widget.usage.quantity} ${widget.usage.unit} · ${money(widget.usage.total)}',
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('usage_reason'),
              controller: _reason,
              enabled: !_busy,
              maxLength: 200,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Lý do',
                errorText: _reasonError,
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Nhập lý do.' : null,
              onChanged: (_) => setState(() {
                _error = null;
                _reasonError = null;
              }),
            ),
            if (_error != null && _reasonError == null)
              InlineError(_error!, key: const Key('cancel_usage_error')),
            const SizedBox(height: 20),
            PressScale(
              child: FilledButton(
                key: const Key('usage_cancel_confirm'),
                style: FilledButton.styleFrom(backgroundColor: AsterColors.red),
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const AsterLoader(size: 24)
                    : const Text('Hủy khoản'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
