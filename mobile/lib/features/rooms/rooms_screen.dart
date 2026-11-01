import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/detail_widgets.dart';
import '../../core/models.dart';
import '../bookings/booking_history.dart';
import '../bookings/bookings_screen.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../shell/app_shell.dart';
import 'room_form.dart';
import 'room_card.dart';
import 'room_filters.dart';
import 'room_images.dart';
import 'room_timeline_view.dart';

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
  bool _isTimeline = false;
  String _search = '';
  late String _condition = widget.initialStatus;
  late int? _floor = widget.initialFloor;
  int _page = 1;
  int? _typeId;
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
      _typeId = null;
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

  RoomQuery get _query => (
    search: _search,
    condition: _condition,
    floor: _floor,
    roomType: _typeId,
    page: _page,
  );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final data = ref.watch(roomsProvider(_query));
    final floors = ref.watch(dashboardProvider).value?.floors ?? [];
    final types = ref.watch(roomTypesProvider);
    return PageBody(
      scrollController: _scroll,
      onRefresh: () async {
        if (_isTimeline) {
          ref.invalidate(timelineProvider);
        } else {
          await ref.refresh(roomsProvider(_query).future).then((_) {});
        }
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
                      builder: (_) => const RoomForm(),
                    ),
                    icon: const Icon(Icons.add),
                  )
                : null,
          ),
          // View Switcher (Sleek Capsule)
          Container(
            height: 38 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AsterColors.border),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (_isTimeline) setState(() => _isTimeline = false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: !_isTimeline
                            ? AsterColors.navy
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_isTimeline
                            ? [
                                BoxShadow(
                                  color: AsterColors.navy.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            size: 16,
                            color: !_isTimeline
                                ? Colors.white
                                : AsterColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Thẻ phòng',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: !_isTimeline
                                    ? Colors.white
                                    : AsterColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (!_isTimeline) setState(() => _isTimeline = true);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: _isTimeline
                            ? AsterColors.navy
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isTimeline
                            ? [
                                BoxShadow(
                                  color: AsterColors.navy.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_view_week_rounded,
                            size: 16,
                            color: _isTimeline
                                ? Colors.white
                                : AsterColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Sơ đồ lịch',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _isTimeline
                                    ? Colors.white
                                    : AsterColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isTimeline)
            RoomTimelineView(
              floor: _floor,
              floors: floors,
              onFloorChanged: (f) => setState(() => _floor = f),
            )
          else ...[
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
            RoomFilters(
              types: types.value ?? [],
              typesLoading: types.isLoading || types.hasError,
              floors: floors.map((item) => item.floor).toList(),
              status: _condition,
              floor: _floor,
              typeId: _typeId,
              onType: (value) => setState(() {
                _typeId = value;
                _page = 1;
              }),
              onFloor: (value) => setState(() {
                _floor = value;
                _page = 1;
              }),
              onStatus: (value) => setState(() {
                _condition = value;
                _page = 1;
              }),
              onClear: () => setState(() {
                _typeId = null;
                _floor = null;
                _condition = '';
                _page = 1;
              }),
            ),
            if (types.hasError)
              TextButton.icon(
                onPressed: () => ref.invalidate(roomTypesProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Không tải được hạng phòng · Thử lại'),
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
                            (constraints.maxWidth - (columns - 1) * 12) /
                            columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: result.items
                              .map(
                                (room) => SizedBox(
                                  width: width,
                                  child: RoomCard(
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
        ],
      ),
    );
  }
}

IconData _amenityIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('wifi') || lower.contains('mạng')) {
    return Icons.wifi_rounded;
  }
  if (lower.contains('điều hòa') ||
      lower.contains('máy lạnh') ||
      lower.contains('ac')) {
    return Icons.ac_unit_rounded;
  }
  if (lower.contains('tv') || lower.contains('tivi')) return Icons.tv_rounded;
  if (lower.contains('bồn tắm') ||
      lower.contains('tắm') ||
      lower.contains('jacuzzi')) {
    return Icons.bathtub_outlined;
  }
  if (lower.contains('ban công') || lower.contains('view')) {
    return Icons.balcony_rounded;
  }
  if (lower.contains('minibar') || lower.contains('tủ lạnh')) {
    return Icons.kitchen_outlined;
  }
  if (lower.contains('máy sấy')) return Icons.air_rounded;
  if (lower.contains('bàn')) return Icons.desk_rounded;
  if (lower.contains('áo choàng')) return Icons.dry_cleaning_outlined;
  if (lower.contains('cà phê') || lower.contains('trà')) {
    return Icons.coffee_rounded;
  }
  return Icons.check_circle_outline_rounded;
}

class RoomDetail extends ConsumerStatefulWidget {
  const RoomDetail({super.key, required this.room});
  final HotelRoom room;
  @override
  ConsumerState<RoomDetail> createState() => RoomDetailState();
}

class RoomDetailState extends ConsumerState<RoomDetail> {
  HotelBooking? _selected;
  late HotelRoom _room = widget.room;
  bool _editing = false;
  int _editVersion = 0;
  void _back() {
    setState(() {
      _selected = null;
      _editing = false;
    });
    setSheetHeight(context, .85);
  }

  late String _condition = widget.room.condition;
  bool _busy = false;
  String? _error;
  Future<void> _confirmCleaned() async {
    if (_busy || _room.updatedAt == null) return;
    final confirmed = await showAsterConfirm(
      context,
      title: 'Xác nhận đã dọn?',
      details:
          'Phòng ${_room.number} đã được dọn và kiểm tra, sẵn sàng nhận khách.',
      label: 'Xác nhận đã dọn',
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    setSheetBusy(context, true);
    try {
      final updated = await ref
          .read(apiProvider)
          .confirmCleaned(_room.id, _room.updatedAt!);
      if (!mounted) return;
      refreshRooms(ref);
      setSheetBusy(context, false);
      setState(() {
        _room = updated;
        _condition = updated.condition;
        _busy = false;
      });
      showMessage(context, 'Đã xác nhận dọn phòng');
    } catch (error) {
      if (!mounted) return;
      setSheetBusy(context, false);
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    setSheetBusy(context, true);
    try {
      await ref.read(apiProvider).changeCondition(_room.id, _condition);
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
    final room = _room;
    final isAdmin = ref.watch(authProvider).user?.isAdmin == true;
    return PopScope(
      canPop: !_busy && _selected == null && !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing && !sheetIsBusy(context)) _back();
      },
      child: SheetPages(
        index: _selected == null && !_editing ? 0 : 1,
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
                      if (isAdmin)
                        IconButton(
                          tooltip: 'Sửa phòng',
                          onPressed: _busy
                              ? null
                              : () {
                                  setState(() => _editing = true);
                                  setSheetHeight(context, .94);
                                },
                          icon: const Icon(Icons.edit_outlined),
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
                  if (canEdit && room.condition == 'cleaning') ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('room_confirm_cleaned'),
                        onPressed: _busy || room.updatedAt == null
                            ? null
                            : _confirmCleaned,
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: const Text('Xác nhận đã dọn'),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  RoomGallery(
                    key: ValueKey(room.images.map((e) => e.id).join(',')),
                    images: room.images,
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
                  DetailSection(
                    title: 'Thông tin phòng',
                    icon: Icons.bed_outlined,
                    children: [
                      DetailField(
                        inline: true,
                        label: 'Loại phòng',
                        value: room.type.name,
                      ),
                      DetailField(
                        inline: true,
                        label: 'Sức chứa',
                        value: '${room.type.capacity} khách',
                      ),
                      DetailField(
                        inline: true,
                        label: 'Diện tích',
                        value: room.area == null
                            ? 'Chưa cập nhật'
                            : '${room.area!.toStringAsFixed(2).replaceFirst(RegExp(r"\.?0+$"), "")} m²',
                      ),
                      DetailField(
                        inline: true,
                        label: 'Loại giường',
                        value: roomBedTypes[room.bedType] ?? 'Chưa cập nhật',
                      ),
                      DetailField(
                        inline: true,
                        label: 'Số giường',
                        value: room.bedCount?.toString() ?? 'Chưa cập nhật',
                      ),
                      DetailField(
                        inline: true,
                        label: 'Hướng nhìn',
                        value: room.view.isEmpty ? 'Chưa cập nhật' : room.view,
                      ),
                    ],
                  ),
                  DetailSection(
                    title: 'Mô tả',
                    icon: Icons.notes_rounded,
                    children: [
                      Text(
                        room.description.isNotEmpty
                            ? room.description
                            : room.type.description.isNotEmpty
                            ? room.type.description
                            : 'Chưa cập nhật mô tả phòng.',
                      ),
                    ],
                  ),
                  DetailSection(
                    title: 'Tiện nghi phòng',
                    icon: Icons.room_service_outlined,
                    children: [
                      if (room.amenities.isEmpty)
                        const Text('Chưa cập nhật tiện nghi.')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: room.amenities
                              .map(
                                (item) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AsterColors.border,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _amenityIcon(item),
                                        size: 14,
                                        color: AsterColors.navy,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        item,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AsterColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                  if (room.notes.isNotEmpty)
                    DetailSection(
                      title: 'Ghi chú nội bộ',
                      icon: Icons.notes_outlined,
                      children: [Text(room.notes)],
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
                  if (room.createdAt != null) ...[
                    DetailField(
                      inline: true,
                      label: 'Ngày tạo',
                      value: dateStamp(room.createdAt!),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (room.updatedAt != null)
                    DetailField(
                      inline: true,
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
          if (_editing)
            RoomForm(
              key: ValueKey(_editVersion),
              room: room,
              onBack: _back,
              onSaved: (saved) {
                setState(() {
                  _room = saved;
                  _condition = saved.condition;
                  _editing = false;
                  _editVersion++;
                });
                setSheetHeight(context, .85);
              },
            )
          else if (_selected != null)
            BookingDetail(
              booking: _selected!,
              onBack: _back,
              onUpdated: (updated) {
                setState(() {
                  _selected = updated;
                  _room = updated.room;
                  _condition = updated.room.condition;
                });
              },
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
