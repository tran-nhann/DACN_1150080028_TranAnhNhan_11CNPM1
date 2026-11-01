import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/form_layout.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'room_images.dart';

class RoomForm extends ConsumerStatefulWidget {
  const RoomForm({super.key, this.room, this.onBack, this.onSaved});
  final HotelRoom? room;
  final VoidCallback? onBack;
  final ValueChanged<HotelRoom>? onSaved;
  @override
  ConsumerState<RoomForm> createState() => _RoomFormState();
}

class _RoomFormState extends ConsumerState<RoomForm> {
  final _form = GlobalKey<FormState>();
  late final _number = TextEditingController(text: widget.room?.number);
  late final _floor = TextEditingController(text: '${widget.room?.floor ?? 1}');
  late final _description = TextEditingController(
    text: widget.room?.description,
  );
  late final _area = TextEditingController(
    text: widget.room?.area?.toString() ?? '',
  );
  late final _bedCount = TextEditingController(
    text: widget.room?.bedCount?.toString() ?? '',
  );
  late final _view = TextEditingController(text: widget.room?.view);
  late final _notes = TextEditingController(text: widget.room?.notes);
  late final _amenities = TextEditingController(
    text: widget.room?.amenities.join(', '),
  );
  late int? _type = widget.room?.type.id;
  late String _bedType = widget.room?.bedType ?? '';
  late final List<RoomPhoto> _images = [...?widget.room?.images];
  final _uploads = <Uint8List>[];
  int? _coverUpload;
  bool _busy = false, _picking = false;
  String? _error;
  Map<String, String> _fields = {};

  @override
  void dispose() {
    for (final controller in [
      _number,
      _floor,
      _description,
      _area,
      _bedCount,
      _view,
      _notes,
      _amenities,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    if (_picking || _busy) return;
    setState(() => _picking = true);
    setSheetBusy(context, true);
    try {
      final files = await ImagePicker().pickMultiImage();
      if (!mounted || files.isEmpty) return;
      if (_images.length + _uploads.length + files.length > 10) {
        throw const ApiFailure('Mỗi phòng tối đa 10 ảnh.');
      }
      final photos = <Uint8List>[];
      for (final file in files) {
        if (await file.length() > 5 * 1024 * 1024) {
          throw const ApiFailure(
            'Mỗi ảnh tối đa 5 MB. Chọn ảnh JPG, PNG hoặc WebP.',
          );
        }
        photos.add(await file.readAsBytes());
      }
      if (mounted) {
        setState(() {
          _uploads.addAll(photos);
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setSheetBusy(context, false);
        setState(() => _picking = false);
      }
    }
  }

  Future<void> _save() async {
    if (_busy || _picking || !validateAndReveal(context, _form)) return;
    setState(() {
      _busy = true;
      _error = null;
      _fields = {};
    });
    setSheetBusy(context, true);
    try {
      final saved = await ref
          .read(apiProvider)
          .saveRoom(
            {
              'number': _number.text.trim(),
              'floor': int.parse(_floor.text.trim()),
              'room_type_id': _type,
              'description': _description.text.trim(),
              'area': _area.text.trim().isEmpty
                  ? null
                  : _area.text.trim().replaceAll(',', '.'),
              'bed_type': _bedType,
              'bed_count': int.tryParse(_bedCount.text.trim()),
              'view': _view.text.trim(),
              'amenities': _amenities.text
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toSet()
                  .toList(),
              'notes': _notes.text.trim(),
              'image_ids': _images.map((image) => image.id).toList(),
              'cover_upload_index': _coverUpload,
            },
            id: widget.room?.id,
            images: _uploads,
          );
      if (!mounted) return;
      refreshRooms(ref);
      ref.invalidate(bookingsProvider);
      ref.invalidate(bookingLookupProvider);
      ref.invalidate(availabilityProvider);
      setSheetBusy(context, false);
      setState(() => _busy = false);
      showMessage(
        context,
        widget.room == null ? 'Đã thêm phòng' : 'Đã lưu phòng',
      );
      if (widget.onSaved != null) {
        widget.onSaved!(saved);
      } else {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) return;
      setSheetBusy(context, false);
      setState(() {
        _busy = false;
        _error = error.toString();
        _fields = error is ApiFailure ? error.fields : {};
      });
      final key = switch (_fields.keys.firstOrNull) {
        'number' => 'room_number',
        'floor' => 'room_floor',
        'room_type_id' => 'room_type',
        'area' => 'room_area',
        'bed_count' => 'room_bed_count',
        _ => 'room_error',
      };
      revealField(context, Key(key));
    }
  }

  Widget _text(
    String name,
    String label,
    TextEditingController controller, {
    int? maxLength,
    int lines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      key: Key('room_$name'),
      controller: controller,
      enabled: !_busy && !_picking,
      minLines: lines,
      maxLines: lines,
      maxLength: maxLength,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, errorText: _fields[name]),
      onChanged: (_) => setState(() {
        _fields.remove(name);
        _error = null;
      }),
      validator: validator,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final locked = _busy || _picking;
    final typesValue = ref.watch(roomTypesProvider);
    return PopScope(
      canPop: !locked,
      child: PinnedFormLayout(
        header: ScreenHeading(
          title: widget.room == null ? 'Thêm phòng' : 'Sửa phòng',
          action: IconButton(
            tooltip: widget.onBack == null ? 'Đóng' : 'Quay lại',
            onPressed: locked
                ? null
                : widget.onBack ?? () => Navigator.pop(context),
            icon: Icon(
              widget.onBack == null ? Icons.close : Icons.arrow_back_rounded,
            ),
          ),
        ),
        body: AsyncContent(
          value: typesValue,
          onRetry: () => ref.invalidate(roomTypesProvider),
          builder: (types) => Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _text(
                  'number',
                  'Số phòng',
                  _number,
                  maxLength: 10,
                  validator: (value) =>
                      RegExp(r'^[A-Za-z0-9-]{1,10}$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Dùng 1–10 chữ, số hoặc dấu gạch ngang.',
                ),
                _text(
                  'floor',
                  'Tầng',
                  _floor,
                  keyboard: TextInputType.number,
                  validator: (value) {
                    final n = int.tryParse(value?.trim() ?? '');
                    return n == null || n < 1 || n > 32767
                        ? 'Nhập tầng hợp lệ.'
                        : null;
                  },
                ),
                DropdownButtonFormField<int>(
                  key: const Key('room_type'),
                  initialValue: _type,
                  isExpanded: true,
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
                  onChanged: locked
                      ? null
                      : (value) => setState(() {
                          _type = value;
                          _fields.remove('room_type_id');
                        }),
                  validator: (value) =>
                      value == null ? 'Vui lòng chọn loại phòng.' : null,
                ),
                const SizedBox(height: 10),
                if (types.any((type) => type.id == _type))
                  Text(
                    'Tối đa ${types.firstWhere((type) => type.id == _type).capacity} khách · Giá theo loại phòng',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AsterColors.muted,
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Hình ảnh phòng',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tối đa 10 ảnh JPG, PNG, WebP · 5 MB/ảnh. Ảnh đầu tiên là ảnh bìa.',
                  style: TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 12),
                for (
                  var index = 0;
                  index < _images.length + _uploads.length;
                  index++
                )
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          height: 54,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: index < _images.length
                                ? RoomPhotoView(photo: _images[index])
                                : Image.memory(
                                    _uploads[index - _images.length],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, error, stack) =>
                                        const PhotoPlaceholder(error: true),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            index ==
                                    (_coverUpload == null
                                        ? 0
                                        : _images.length + _coverUpload!)
                                ? 'Ảnh bìa'
                                : 'Ảnh ${index + 1}',
                          ),
                        ),
                        if (index !=
                            (_coverUpload == null
                                ? 0
                                : _images.length + _coverUpload!))
                          IconButton(
                            tooltip: 'Đặt làm ảnh bìa',
                            onPressed: locked
                                ? null
                                : () => setState(() {
                                    if (index >= _images.length) {
                                      _coverUpload = index - _images.length;
                                    } else {
                                      _coverUpload = null;
                                      _images.insert(
                                        0,
                                        _images.removeAt(index),
                                      );
                                    }
                                  }),
                            icon: const Icon(Icons.star_outline),
                          ),
                        IconButton(
                          tooltip: 'Xóa ảnh ${index + 1}',
                          onPressed: locked
                              ? null
                              : () => setState(() {
                                  if (index < _images.length) {
                                    _images.removeAt(index);
                                  } else {
                                    final uploadIndex = index - _images.length;
                                    if (_coverUpload == uploadIndex) {
                                      _coverUpload = null;
                                    } else if (_coverUpload != null &&
                                        _coverUpload! > uploadIndex) {
                                      _coverUpload = _coverUpload! - 1;
                                    }
                                    _uploads.removeAt(uploadIndex);
                                  }
                                }),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  key: const Key('room_add_photos'),
                  onPressed: locked || _images.length + _uploads.length >= 10
                      ? null
                      : _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_picking ? 'Đang chọn ảnh…' : 'Chọn ảnh phòng'),
                ),
                const SizedBox(height: 24),
                _text(
                  'description',
                  'Mô tả phòng',
                  _description,
                  lines: 4,
                  maxLength: 2000,
                ),
                _text(
                  'area',
                  'Diện tích (m²)',
                  _area,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final n = double.tryParse(
                      value.trim().replaceAll(',', '.'),
                    );
                    return n == null || !n.isFinite || n < 1 || n > 9999.99
                        ? 'Nhập diện tích từ 1 đến 9999,99 m².'
                        : null;
                  },
                ),
                DropdownButtonFormField<String>(
                  key: const Key('room_bed_type'),
                  initialValue: _bedType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Loại giường',
                    errorText: _fields['bed_type'],
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Chưa cập nhật'),
                    ),
                    ...roomBedTypes.entries.map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    ),
                  ],
                  onChanged: locked
                      ? null
                      : (value) => setState(() => _bedType = value ?? ''),
                ),
                const SizedBox(height: 18),
                _text(
                  'bed_count',
                  'Số giường',
                  _bedCount,
                  keyboard: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final n = int.tryParse(value.trim());
                    return n == null || n < 1 || n > 20
                        ? 'Nhập từ 1 đến 20 giường.'
                        : null;
                  },
                ),
                _text('view', 'Hướng nhìn', _view, maxLength: 100),
                _text(
                  'amenities',
                  'Tiện nghi (ngăn cách bằng dấu phẩy)',
                  _amenities,
                  lines: 3,
                  validator: (value) {
                    final items = (value ?? '')
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toSet();
                    return items.length > 30 || items.any((e) => e.length > 50)
                        ? 'Tối đa 30 tiện nghi, mỗi mục tối đa 50 ký tự.'
                        : null;
                  },
                ),
                _text(
                  'notes',
                  'Ghi chú nội bộ',
                  _notes,
                  lines: 3,
                  maxLength: 300,
                ),
                if (_error != null) ...[
                  InlineError(_error!, key: const Key('room_error')),
                  const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ),
        footer: FilledButton(
          key: const Key('room_save'),
          onPressed: locked || !typesValue.hasValue ? null : _save,
          child: _busy
              ? const AsterLoader(size: 24)
              : Text(widget.room == null ? 'Thêm phòng' : 'Lưu thay đổi'),
        ),
      ),
    );
  }
}
