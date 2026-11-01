import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/detail_widgets.dart';
import '../../core/form_layout.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'services_screen.dart';
import 'apply_service.dart';

const serviceCategories = {
  'food': 'Ăn uống',
  'laundry': 'Giặt ủi',
  'transport': 'Đưa đón',
  'minibar': 'Minibar',
  'wellness': 'Thư giãn',
  'other': 'Khác',
};

class ServiceThumbnail extends ConsumerWidget {
  const ServiceThumbnail({super.key, required this.service, this.size = 54});
  final HotelService service;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = switch (service.category) {
      'food' => Icons.restaurant_rounded,
      'laundry' => Icons.local_laundry_service_outlined,
      'transport' => Icons.airport_shuttle_outlined,
      'minibar' => Icons.local_bar_outlined,
      'wellness' => Icons.spa_outlined,
      _ => Icons.room_service_outlined,
    };
    final fallback = ColoredBox(
      color: AsterColors.background,
      child: Center(
        child: Icon(icon, color: AsterColors.navy, size: size > 80 ? 44 : 25),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: service.imageUrl == null
              ? fallback
              : Image.network(
                  ref.watch(apiProvider).roomImageUrl(service.imageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => fallback,
                ),
        ),
      ),
    );
  }
}

class ServiceDetail extends ConsumerStatefulWidget {
  const ServiceDetail({super.key, required this.service, this.onSaved});
  final HotelService service;
  final ValueChanged<HotelService>? onSaved;
  @override
  ConsumerState<ServiceDetail> createState() => _ServiceDetailState();
}

class _ServiceDetailState extends ConsumerState<ServiceDetail> {
  late HotelService _service = widget.service;
  bool _editing = false, _busy = false, _applying = false;
  String? _error;
  void _back() {
    if (sheetIsBusy(context)) return;
    setState(() {
      _editing = false;
      _applying = false;
    });
    setSheetHeight(context, .85);
  }

  Future<void> _refreshAfterApply() async {
    try {
      final latest = await ref.read(apiProvider).getService(_service.id);
      if (!mounted) return;
      setState(() {
        _service = latest;
        _error = null;
      });
      widget.onSaved?.call(latest);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Đã ghi dịch vụ. Đóng và mở lại để tải số khoản sử dụng mới.',
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showAsterConfirm(
      context,
      title: 'Xóa dịch vụ?',
      details: _service.name,
      label: 'Xóa dịch vụ',
      destructive: true,
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    setSheetBusy(context, true);
    try {
      await ref.read(apiProvider).deleteService(_service.id);
      if (!mounted) return;
      ref.invalidate(servicesProvider);
      setSheetBusy(context, false);
      setState(() => _busy = false);
      showMessage(context, 'Đã xóa dịch vụ');
      Navigator.pop(context);
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
    final admin = ref.watch(authProvider).user?.isAdmin == true;
    final canApply = ref.watch(authProvider).user?.canEditRooms == true;
    return PopScope(
      canPop: !_busy && !_editing && !_applying,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) _back();
      },
      child: SheetPages(
        index: _applying
            ? 2
            : _editing
            ? 1
            : 0,
        children: [
          PinnedFormLayout(
            header: ScreenHeading(
              title: 'Chi tiết dịch vụ',
              action: IconButton(
                tooltip: 'Đóng',
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: ServiceThumbnail(service: _service, size: 130)),
                const SizedBox(height: 18),
                Text(
                  _service.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${money(_service.price)} / ${_service.unitValid ? _service.unit : 'Chưa chọn đơn vị'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AsterColors.navy,
                  ),
                ),
                const SizedBox(height: 18),
                DetailSection(
                  title: 'Thông tin dịch vụ',
                  icon: Icons.room_service_outlined,
                  children: [
                    DetailField(
                      inline: true,
                      label: 'Nhóm',
                      value: serviceCategories[_service.category] ?? 'Khác',
                    ),
                    DetailField(
                      inline: true,
                      label: 'Đơn vị',
                      value: _service.unitValid
                          ? _service.unit
                          : 'Cần cập nhật',
                    ),
                    DetailField(
                      inline: true,
                      label: 'Trạng thái',
                      value: _service.active ? 'Đang bán' : 'Ngừng bán',
                    ),
                    DetailField(
                      inline: true,
                      label: 'Khoản sử dụng',
                      value: '${_service.usageCount} khoản',
                    ),
                    if (_service.createdAt != null)
                      DetailField(
                        inline: true,
                        label: 'Ngày tạo',
                        value: dateStamp(_service.createdAt!),
                      ),
                    if (_service.updatedAt != null)
                      DetailField(
                        inline: true,
                        label: 'Cập nhật',
                        value: dateStamp(_service.updatedAt!),
                      ),
                  ],
                ),
                DetailSection(
                  title: 'Mô tả',
                  icon: Icons.notes_rounded,
                  children: [
                    Text(
                      _service.description.isEmpty
                          ? 'Chưa có mô tả dịch vụ.'
                          : _service.description,
                    ),
                  ],
                ),
                if (_service.notes.isNotEmpty)
                  DetailSection(
                    title: 'Ghi chú nội bộ',
                    icon: Icons.edit_note_rounded,
                    children: [Text(_service.notes)],
                  ),
                if (!_service.canDelete)
                  const Text(
                    'Dịch vụ đã có lịch sử sử dụng. Có thể sửa thông tin hoặc ngừng bán; lịch sử được giữ lại.',
                    style: TextStyle(fontSize: 12, color: AsterColors.muted),
                  ),
                if (_error != null) InlineError(_error!),
              ],
            ),
            footer: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canApply) ...[
                  if (!_service.active || !_service.unitValid)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        !_service.unitValid
                            ? 'Cần sửa và chọn đơn vị trước khi áp dụng.'
                            : 'Dịch vụ đã ngừng bán.',
                      ),
                    ),
                  FilledButton.icon(
                    key: const Key('service_apply'),
                    onPressed: _busy || !_service.active || !_service.unitValid
                        ? null
                        : () {
                            setState(() => _applying = true);
                            setSheetHeight(context, .95);
                          },
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Áp dụng cho phòng'),
                  ),
                  if (admin) const SizedBox(height: 8),
                ],
                if (admin)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        key: const Key('service_delete'),
                        onPressed: _busy || !_service.canDelete
                            ? null
                            : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Xóa'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('service_edit'),
                          onPressed: _busy
                              ? null
                              : () {
                                  setState(() => _editing = true);
                                  setSheetHeight(context, .95);
                                },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Sửa dịch vụ'),
                        ),
                      ),
                    ],
                  ),
                if (!admin && !canApply)
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
              ],
            ),
          ),
          if (_editing)
            ServiceForm(
              service: _service,
              onBack: _back,
              onSaved: (saved) {
                widget.onSaved?.call(saved);
                setState(() {
                  _service = saved;
                  _editing = false;
                });
                setSheetHeight(context, .85);
              },
            )
          else
            const SizedBox.shrink(),
          if (_applying)
            ApplyServicePanel(
              service: _service,
              onBack: _back,
              onApplied: _refreshAfterApply,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
