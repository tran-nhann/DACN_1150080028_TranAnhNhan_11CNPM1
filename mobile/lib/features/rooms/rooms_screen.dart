import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/detail_widgets.dart';
import '../../core/models.dart';
import '../bookings/booking_history.dart';
import '../bookings/bookings_screen.dart';
import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../shell/app_shell.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({
    super.key,
    this.initialStatus = '',
    this.initialFloor,
    this.filterRevision,
  });
  final String initialStatus;
  final int? filterRevision, initialFloor;
  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  String _search = '';
  late String _condition = widget.initialStatus;
  late int? _floor = widget.initialFloor;
  int _page = 1;
  Timer? _debounce;
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  @override
  void didUpdateWidget(covariant RoomsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus ||
        oldWidget.initialFloor != widget.initialFloor ||
        oldWidget.filterRevision != widget.filterRevision) {
      _debounce?.cancel();
      _searchController.clear();
      _search = '';
      _floor = widget.initialFloor;
      _condition = widget.initialStatus;
      _page = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  RoomQuery get _query =>
      (search: _search, condition: _condition, floor: _floor, page: _page);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final data = ref.watch(roomsProvider(_query));
    final floors = ref.watch(dashboardProvider).value?.floors ?? [];
    return PageBody(
      scrollController: _scroll,
      onRefresh: () async {
        await ref.refresh(roomsProvider(_query).future).then((_) {});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(
            title: 'Phòng',
            action: user?.isAdmin == true
                ? IconButton.filled(
                    tooltip: 'Thêm phòng',
                    onPressed: () => showAsterSheet<void>(
                      context: context,
                      form: true,
                      builder: (_) => const _RoomForm(),
                    ),
                    icon: const Icon(Icons.add),
                  )
                : null,
          ),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Số phòng',
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
              children: [
                ...[
                  ('', 'Tất cả'),
                  ('ready', 'Sẵn sàng'),
                  ('occupied', 'Đang ở'),
                  ('reserved', 'Đã đặt'),
                  ('cleaning', 'Cần dọn'),
                  ('maintenance', 'Bảo trì'),
                ].map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        item.$2,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _condition == item.$1,
                      showCheckmark: false,
                      selectedColor: const Color(0xFFDFF0E8),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AsterColors.border),
                      onSelected: (_) => setState(() {
                        _condition = item.$1;
                        _page = 1;
                      }),
                    ),
                  ),
                ),
                PopupMenuButton<int?>(
                  tooltip: 'Lọc theo tầng',
                  onSelected: (floor) => setState(() {
                    _floor = floor == 0 ? null : floor;
                    _page = 1;
                  }),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 0, child: Text('Tất cả tầng')),
                    ...floors.map(
                      (floor) => PopupMenuItem(
                        value: floor.floor,
                        child: Text('Tầng ${floor.floor}'),
                      ),
                    ),
                  ],
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AsterColors.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.layers_outlined,
                          size: 16,
                          color: AsterColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _floor == null ? 'Tất cả tầng' : 'Tầng $_floor',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const Icon(Icons.expand_more, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AsyncContent(
            value: data,
            onRetry: () => ref.invalidate(roomsProvider(_query)),
            builder: (result) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.count} phòng',
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                if (result.items.isEmpty)
                  const EmptyState(
                    icon: Icons.bed_outlined,
                    title: 'Không tìm thấy phòng',
                    message: '',
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          MediaQuery.textScalerOf(context).scale(1) > 1.4
                          ? 1
                          : constraints.maxWidth >= 1000
                          ? 4
                          : constraints.maxWidth >= 650
                          ? 3
                          : 2;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: result.items
                            .map(
                              (room) => SizedBox(
                                width: width,
                                child: _RoomCard(
                                  room: room,
                                  onTap: () => showAsterSheet<void>(
                                    context: context,
                                    builder: (_) => RoomDetail(room: room),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                Pager(
                  page: _page,
                  hasNext: result.hasNext,
                  onPage: (page) => setState(() => _page = page),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});
  final HotelRoom room;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    room.number,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                      color: AsterColors.ink,
                    ),
                  ),
                ),
                const Icon(
                  Icons.bed_outlined,
                  color: AsterColors.muted,
                  size: 23,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              room.type.name,
              style: const TextStyle(fontSize: 11, color: AsterColors.muted),
            ),
            const SizedBox(height: 14),
            ConditionBadge(room.displayStatus),
            const SizedBox(height: 13),
            Text(
              money(room.type.rate),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AsterColors.ink,
              ),
            ),
            const Text('/ đêm', style: TextStyle(fontSize: 9)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 13,
                  color: AsterColors.muted,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    '${room.type.capacity} khách · Tầng ${room.floor}',
                    style: const TextStyle(fontSize: 10),
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

class RoomDetail extends ConsumerStatefulWidget {
  const RoomDetail({super.key, required this.room});
  final HotelRoom room;
  @override
  ConsumerState<RoomDetail> createState() => RoomDetailState();
}

class RoomDetailState extends ConsumerState<RoomDetail> {
  HotelBooking? _selected;
  void _back() {
    setState(() => _selected = null);
    setSheetHeight(context, .85);
  }

  late String _condition = widget.room.condition;
  bool _busy = false;
  String? _error;
  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    setSheetBusy(context, true);
    try {
      await ref.read(apiProvider).changeCondition(widget.room.id, _condition);
      if (!mounted) return;
      refreshRooms(ref);
      setSheetBusy(context, false);
      showMessage(context, 'Đã lưu');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setSheetBusy(context, false);
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(authProvider).user?.canEditRooms ?? false;
    final room = widget.room;
    return PopScope(
      canPop: !_busy && _selected == null,
      child: SheetPages(
        index: _selected == null ? 0 : 1,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Phòng ${room.number}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    '${room.type.name} · Tầng ${room.floor} · ${room.type.capacity} khách',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ConditionBadge(room.displayStatus),
                      if (!room.active) const Chip(label: Text('Ngừng bán')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Surface(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bed_outlined,
                          color: AsterColors.teal,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                money(room.type.rate),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Text(
                                '/ đêm',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (room.type.description.isNotEmpty || room.notes.isNotEmpty)
                    ExpandableDetails(
                      description: room.type.description,
                      notes: room.notes,
                    ),
                  const SizedBox(height: 26),
                  Text(
                    'Vận hành',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['ready', 'cleaning', 'maintenance']
                        .map(
                          (condition) => ChoiceChip(
                            label: Text(
                              ConditionBadge.details(condition).$1,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _condition == condition,
                            onSelected: !canEdit || _busy
                                ? null
                                : (_) => setState(() => _condition = condition),
                          ),
                        )
                        .toList(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    InlineError(_error!),
                  ],
                  if (canEdit && (_condition != room.condition || _busy)) ...[
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: PressScale(
                        child: FilledButton(
                          onPressed: _busy || _condition == room.condition
                              ? null
                              : _save,
                          child: _busy
                              ? const AsterLoader(size: 24)
                              : const Text('Lưu'),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (room.updatedAt != null)
                    DetailField(
                      label: 'Cập nhật',
                      value: dateStamp(room.updatedAt!),
                    ),
                  BookingHistory(
                    roomId: room.id,
                    onSelected: (booking) =>
                        setState(() => _selected = booking),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (_selected != null)
            BookingDetail(booking: _selected!, onBack: _back)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _RoomForm extends ConsumerStatefulWidget {
  const _RoomForm();
  @override
  ConsumerState<_RoomForm> createState() => _RoomFormState();
}

class _RoomFormState extends ConsumerState<_RoomForm> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController(),
      _floor = TextEditingController(text: '1');
  int? _type;
  bool _busy = false;
  String? _error;
  Map<String, String> _fields = {};
  @override
  void dispose() {
    _number.dispose();
    _floor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !validateAndReveal(context, _form)) return;
    setState(() {
      _busy = true;
      _error = null;
      _fields = {};
    });
    setSheetBusy(context, true);
    try {
      await ref.read(apiProvider).saveRoom({
        'number': _number.text.trim(),
        'floor': int.parse(_floor.text.trim()),
        'room_type_id': _type,
      });
      if (!mounted) return;
      refreshRooms(ref);
      setSheetBusy(context, false);
      showMessage(context, 'Đã thêm phòng');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setSheetBusy(context, false);
        setState(() {
          _busy = false;
          _error = error.toString();
          _fields = error is ApiFailure ? error.fields : {};
        });
        final field = switch ([
          'number',
          'floor',
          'room_type_id',
        ].where(_fields.containsKey).firstOrNull) {
          'number' => 'room_number',
          'floor' => 'room_floor',
          'room_type_id' => 'room_type',
          _ => 'room_error',
        };
        revealField(context, Key(field));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeading(
              title: 'Thêm phòng',
              action: IconButton(
                tooltip: 'Đóng',
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            AsyncContent(
              value: ref.watch(roomTypesProvider),
              onRetry: () => ref.invalidate(roomTypesProvider),
              builder: (types) => Form(
                key: _form,
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('room_number'),
                      controller: _number,
                      enabled: !_busy,
                      onChanged: (_) => setState(() {
                        _error = null;
                        _fields.remove('number');
                      }),
                      decoration: InputDecoration(
                        labelText: 'Số phòng',
                        errorText: _fields['number'],
                      ),
                      validator: (value) =>
                          value == null ||
                              !RegExp(r'^[A-Za-z0-9-]{1,10}$')
                                  .hasMatch(value.trim())
                          ? 'Dùng 1–10 chữ, số hoặc dấu gạch ngang.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const Key('room_floor'),
                      controller: _floor,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {
                        _error = null;
                        _fields.remove('floor');
                      }),
                      decoration: InputDecoration(
                        labelText: 'Tầng',
                        errorText: _fields['floor'],
                      ),
                      validator: (value) {
                        final floor = int.tryParse(value?.trim() ?? '');
                        return floor == null || floor < 1 || floor > 32767
                            ? 'Nhập tầng hợp lệ.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<int>(
                      key: const Key('room_type'),
                      isExpanded: true,
                      initialValue: _type,
                      decoration: InputDecoration(
                        labelText: 'Loại phòng',
                        errorText: _fields['room_type_id'],
                      ),
                      items: types
                          .map(
                            (type) => DropdownMenuItem(
                              value: type.id,
                              child: Text(
                                '${type.name} · ${money(type.rate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _type = value;
                              _error = null;
                              _fields.remove('room_type_id');
                            }),
                      validator: (value) =>
                          value == null ? 'Vui lòng chọn loại phòng.' : null,
                    ),
                    if (_error != null &&
                        (_fields.isEmpty ||
                            _fields.keys.any(
                              (field) => ![
                                'number',
                                'floor',
                                'room_type_id',
                              ].contains(field),
                            ))) ...[
                      const SizedBox(height: 16),
                      InlineError(_error!, key: const Key('room_error')),
                    ],
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: PressScale(
                        child: FilledButton(
                          key: const Key('room_save'),
                          onPressed: _busy ? null : _save,
                          child: _busy
                              ? const AsterLoader(size: 24)
                              : const Text('Thêm'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
