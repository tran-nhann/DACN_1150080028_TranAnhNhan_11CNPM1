import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/models.dart';
import '../../core/form_layout.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../customers/customers_screen.dart';
import 'booking_service_cart.dart';

String dateOnly(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
String shortDate(DateTime date) => DateFormat('dd/MM').format(date);

class BookingForm extends ConsumerStatefulWidget {
  const BookingForm({super.key, this.initialRoom, this.initialStart});
  final HotelRoom? initialRoom;
  final DateTime? initialStart;
  @override
  ConsumerState<BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends ConsumerState<BookingForm> {
  int _step = 0, _guests = 1;
  int _direction = 1;
  final _guestAnchor = GlobalKey();
  final _roomsAnchor = GlobalKey();
  late DateTime _start, _end;
  Guest? _guest;
  HotelRoom? _room;
  final _services = <BookingServiceChoice>[];
  int get _serviceTotal => _services.fold(0, (sum, item) => sum + item.total);

  Future<void> _pickService() async {
    if (_busy) return;
    final service = await pickBookingService(context);
    if (!mounted || service == null) return;
    setState(() {
      final index = _services.indexWhere(
        (item) => item.service.id == service.id,
      );
      if (index < 0) {
        _services.add(BookingServiceChoice(service, 1));
      } else {
        _services[index] = BookingServiceChoice(
          service,
          _services[index].quantity,
        );
      }
      _requestKey = const Uuid().v4();
      _error = null;
    });
  }

  String _requestKey = const Uuid().v4();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialStart != null) {
      _start = widget.initialStart!;
      _end = _start.add(const Duration(days: 1));
    } else {
      final today = ref.read(dashboardProvider).value?.date ?? DateTime.now();
      _start = DateTime(today.year, today.month, today.day);
      _end = _start.add(const Duration(days: 1));
    }
    if (widget.initialRoom != null) {
      _room = widget.initialRoom;
    }
  }

  AvailabilityQuery get _query => (
    start: dateOnly(_start),
    end: dateOnly(_end),
    guests: _guests,
    exclude: null,
  );
  void _changed() {
    _requestKey = const Uuid().v4();
    _room = null;
    _error = null;
  }

  Future<void> _dates() async {
    final today = ref.read(dashboardProvider).value?.date ?? DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 455)),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      helpText: 'Ngày nhận · ngày trả',
      saveText: 'Chọn',
    );
    if (!mounted || range == null) return;
    if (range.start == _start && range.end == _end) return;
    final nights = range.duration.inDays;
    if (nights < 1 ||
        nights > 90 ||
        range.start
                .difference(DateTime(today.year, today.month, today.day))
                .inDays >
            365) {
      setState(() => _error = 'Chọn 1–90 đêm, nhận phòng trong 365 ngày tới.');
      revealField(context, const Key('booking_error'));
      return;
    }
    setState(() {
      _start = range.start;
      _end = range.end;
      _changed();
    });
  }

  Future<void> _pickGuest() async {
    final guest = await showAsterSheet<Guest>(
      context: context,
      builder: (_) => const GuestPicker(),
    );
    if (!mounted || guest == null) return;
    setState(() {
      if (_guest?.id != guest.id) _requestKey = const Uuid().v4();
      _guest = guest;
      _error = null;
    });
  }

  void _goStep(int step) {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _direction = step >= _step ? 1 : -1;
      _step = step;
      _error = null;
    });
  }

  void _back() {
    if (_busy) return;
    if (_step > 0) {
      _goStep(_step - 1);
    } else {
      context.pop();
    }
  }

  void _missing(GlobalKey anchor, String message) {
    setState(() => _error = message);
    final target = anchor.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: .1,
        duration: motionDuration(context, 220),
      );
    }
  }

  Future<void> _submit() async {
    if (_busy || _room == null || _guest == null) return;
    if (_services.any((item) => item.quantity < 1 || item.quantity > 999)) {
      setState(() => _error = 'Số lượng dịch vụ phải từ 1–999.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await ref.read(apiProvider).createBooking({
        'room_id': _room!.id,
        'customer_id': _guest!.id,
        'start_date': dateOnly(_start),
        'end_date': dateOnly(_end),
        'guests': _guests,
        'expected_nightly_rate': _room!.type.rate,
        if (_services.isNotEmpty)
          'services': _services.map((item) => item.toJson()).toList(),
      }, _requestKey);
      if (!mounted) return;
      refreshBookings(ref);
      context.go('/bookings?status=confirmed&created=${created.id}');
      showMessage(context, 'Đã đặt phòng ${_room!.number}.');
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
        revealField(context, const Key('booking_error'));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && _step == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_busy && _step > 0) _back();
    },
    child: Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Đặt phòng'),
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: _busy ? null : _back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: PinnedFormLayout(
          header: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
            child: Row(
              children: List.generate(
                3,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: motionDuration(context, 160),
                          height: 4,
                          decoration: BoxDecoration(
                            color: index <= _step
                                ? AsterColors.teal
                                : AsterColors.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          ['Lịch', 'Phòng', 'Chốt'][index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: index == _step
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: index == _step
                                ? AsterColors.ink
                                : AsterColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: MotionSwap(
            direction: _direction,
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null &&
                      _error != 'Chọn khách hàng.' &&
                      _error != 'Chọn phòng.')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InlineError(
                        _error!,
                        key: const Key('booking_error'),
                      ),
                    ),
                  _step == 0
                      ? _details()
                      : _step == 1
                      ? _rooms()
                      : _review(),
                ],
              ),
            ),
          ),
          footer: PressScale(
            child: FilledButton(
              key: const Key('booking_next'),
              onPressed: _busy
                  ? null
                  : () {
                      if (_step == 2) {
                        _submit();
                      } else if (_step == 0 && _guest == null) {
                        _missing(_guestAnchor, 'Chọn khách hàng.');
                      } else if (_step == 1 && _room == null) {
                        _missing(_roomsAnchor, 'Chọn phòng.');
                      } else if (_step == 1 &&
                          _services.any(
                            (item) => item.quantity < 1 || item.quantity > 999,
                          )) {
                        _missing(
                          _roomsAnchor,
                          'Số lượng dịch vụ phải từ 1–999.',
                        );
                      } else {
                        _goStep(_step + 1);
                      }
                    },
              child: _busy
                  ? const AsterLoader(size: 24, color: Colors.white)
                  : Text(_step == 2 ? 'Đặt phòng' : 'Tiếp tục'),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Lịch lưu trú', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Surface(
        padding: EdgeInsets.zero,
        child: ListTile(
          key: const Key('booking_dates'),
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(
            Icons.calendar_month_outlined,
            color: AsterColors.teal,
          ),
          title: Text(
            '${shortDate(_start)} → ${shortDate(_end)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${_end.difference(_start).inDays} đêm · ${_start.year}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _dates,
        ),
      ),
      const SizedBox(height: 16),
      Surface(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.people_outline, color: AsterColors.teal),
            const SizedBox(width: 16),
            const Expanded(child: Text('Số khách')),
            IconButton(
              tooltip: 'Giảm khách',
              onPressed: _guests > 1
                  ? () => setState(() {
                      _guests--;
                      _changed();
                    })
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$_guests',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            IconButton(
              tooltip: 'Thêm khách',
              onPressed: _guests < 20
                  ? () => setState(() {
                      _guests++;
                      _changed();
                    })
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      Surface(
        key: _guestAnchor,
        padding: EdgeInsets.zero,
        child: ListTile(
          key: const Key('booking_guest'),
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.person_outline, color: AsterColors.teal),
          title: Text(
            _guest?.name ?? 'Chọn khách hàng',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: _guest == null
              ? (_error == 'Chọn khách hàng.'
                    ? Text(
                        _error!,
                        style: const TextStyle(color: AsterColors.red),
                      )
                    : null)
              : Text(_guest!.phone),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickGuest,
        ),
      ),
    ],
  );

  Widget _rooms() => AsyncContent(
    key: _roomsAnchor,
    value: ref.watch(availabilityProvider(_query)),
    onRetry: () => ref.invalidate(availabilityProvider(_query)),
    builder: (data) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error == 'Chọn phòng.') InlineError(_error!),
        Text(
          '${data.count} phòng phù hợp',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        Text('${shortDate(_start)} → ${shortDate(_end)} · $_guests khách'),
        const SizedBox(height: 20),
        if (data.items.isEmpty)
          const EmptyState(
            icon: Icons.bed_outlined,
            title: 'Hết phòng phù hợp',
            message: '',
          ),
        ...data.items.map(
          (room) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RoomChoice(
                key: Key('select_room_${room.id}'),
                room: room,
                selected: _room?.id == room.id,
                onTap: () => setState(() {
                  if (_room?.id != room.id) _requestKey = const Uuid().v4();
                  _room = room;
                  _error = null;
                }),
              ),
              if (_room?.id == room.id) _serviceCart(),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _serviceCart() => BookingServiceCart(
    items: _services,
    busy: _busy,
    onAdd: _pickService,
    onQuantity: (id, quantity) => setState(() {
      final index = _services.indexWhere((item) => item.service.id == id);
      _services[index] = BookingServiceChoice(
        _services[index].service,
        quantity,
      );
      _requestKey = const Uuid().v4();
    }),
    onRemove: (id) => setState(() {
      _services.removeWhere((item) => item.service.id == id);
      _requestKey = const Uuid().v4();
    }),
  );

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ScreenHeading(
        title: 'Phòng ${_room!.number}',
        action: IconButton(
          key: const Key('review_edit_room'),
          tooltip: 'Sửa phòng',
          onPressed: _busy ? null : () => _goStep(1),
          icon: const Icon(Icons.edit_outlined),
        ),
      ),
      Text(_room!.type.name),
      const SizedBox(height: 22),
      Surface(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const Key('review_edit_details'),
                tooltip: 'Sửa lịch và khách',
                onPressed: _busy ? null : () => _goStep(0),
                icon: const Icon(Icons.edit_calendar_outlined),
              ),
            ),
            _line('Khách hàng', _guest!.name),
            _line('Nhận phòng', DateFormat('dd/MM/yyyy').format(_start)),
            _line('Trả phòng', DateFormat('dd/MM/yyyy').format(_end)),
            _line(
              'Lưu trú',
              '${_end.difference(_start).inDays} đêm · $_guests khách',
            ),
            const Divider(height: 28),
            _line('Giá / đêm', money(_room!.type.rate)),
            const SizedBox(height: 12),
            _line(
              'Tiền phòng',
              money(_room!.type.rate * _end.difference(_start).inDays),
              bold: true,
            ),
            if (_services.isNotEmpty) ...[
              const Divider(height: 24),
              for (final item in _services)
                _line(
                  '${item.service.name} · ${item.quantity} ${item.service.unit}',
                  money(item.total),
                ),
              _line('Dịch vụ đặt kèm', money(_serviceTotal)),
              _line(
                'Tổng dự kiến',
                money(
                  _room!.type.rate * _end.difference(_start).inDays +
                      _serviceTotal,
                ),
                bold: true,
              ),
              TextButton(
                key: const Key('review_edit_services'),
                onPressed: _busy ? null : () => _goStep(1),
                child: const Text('Sửa dịch vụ đặt kèm'),
              ),
            ],
          ],
        ),
      ),
    ],
  );
  Widget _line(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final vertical = MediaQuery.textScalerOf(context).scale(1) > 1.4;
        final caption = Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        );
        final amount = Text(
          value,
          textAlign: vertical ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            color: AsterColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: bold ? 17 : 12,
          ),
        );
        return vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [caption, const SizedBox(height: 4), amount],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: caption),
                  const SizedBox(width: 12),
                  Expanded(flex: 6, child: amount),
                ],
              );
      },
    ),
  );
}

class GuestPicker extends ConsumerStatefulWidget {
  const GuestPicker({super.key});
  @override
  ConsumerState<GuestPicker> createState() => _GuestPickerState();
}

class _GuestPickerState extends ConsumerState<GuestPicker> {
  String _search = '';
  int _page = 1, _formVersion = 0;
  bool _adding = false;
  Guest? _created;
  Timer? _debounce;
  final _searchController = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _back() {
    if (sheetIsBusy(context)) return;
    setState(() => _adding = false);
    setSheetHeight(context, .85);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Widget _list() {
    final query = (search: _search, page: _page);
    return SingleChildScrollView(
      controller: _scroll,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          children: [
            ScreenHeading(
              title: 'Khách hàng',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Thêm khách hàng',
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    onPressed: () {
                      setState(() => _adding = true);
                      setSheetHeight(context, .95);
                    },
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Tên hoặc điện thoại',
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
            AsyncContent(
              value: ref.watch(guestsProvider(query)),
              onRetry: () => ref.invalidate(guestsProvider(query)),
              builder: (data) {
                final guests = [
                  if (_created != null &&
                      !data.items.any((guest) => guest.id == _created!.id))
                    _created!,
                  ...data.items,
                ];
                return Column(
                  children: [
                    if (guests.isEmpty)
                      const EmptyState(
                        icon: Icons.person_search_outlined,
                        title: 'Không tìm thấy khách',
                        message: '',
                      ),
                    ...guests.map(
                      (guest) => ListTile(
                        key: Key('pick_guest_${guest.id}'),
                        title: Text(
                          guest.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(guest.phone),
                        leading: const Icon(Icons.person_outline),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, guest),
                      ),
                    ),
                    Pager(
                      page: _page,
                      hasNext: data.hasNext,
                      onPage: (page) => setState(() => _page = page),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_adding,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _adding) _back();
    },
    child: SheetPages(
      index: _adding ? 1 : 0,
      children: [
        _list(),
        GuestForm(
          key: ValueKey(_formVersion),
          onBack: _back,
          onSaved: (guest) {
            setState(() {
              _created = guest;
              _adding = false;
              _formVersion++;
            });
            setSheetHeight(context, .85);
            FocusManager.instance.primaryFocus?.unfocus();
            if (_scroll.hasClients) _scroll.jumpTo(0);
          },
        ),
      ],
    ),
  );
}
