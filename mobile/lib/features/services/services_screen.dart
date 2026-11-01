import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/form_layout.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../shell/app_shell.dart';
import 'service_detail.dart';
import 'apply_service.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});
  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _catalog = GlobalKey<_ServiceCatalogState>();
  void _edit([HotelService? service]) => showAsterSheet<void>(
    context: context,
    form: true,
    builder: (_) => ServiceForm(
      service: service,
      onSaved: (saved) => _catalog.currentState?.reveal(saved),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authProvider).user?.isAdmin == true;
    return PageBody(
      onRefresh: () async {
        ref.invalidate(servicesProvider);
      },
      child: Column(
        children: [
          ScreenHeading(
            title: 'Dịch vụ',
            leading: const MoreBackButton(),
            action: admin
                ? IconButton.filled(
                    tooltip: 'Thêm dịch vụ',
                    onPressed: _edit,
                    icon: const Icon(Icons.add),
                  )
                : null,
          ),
          ServiceCatalog(
            key: _catalog,
            onApply: ref.watch(authProvider).user?.canEditRooms == true
                ? (service) => showAsterSheet<void>(
                    context: context,
                    form: true,
                    builder: (context) => ApplyServicePanel(
                      service: service,
                      onBack: () => Navigator.pop(context),
                    ),
                  )
                : null,
            onSelected: (service) => showAsterSheet<void>(
              context: context,
              builder: (_) => ServiceDetail(
                service: service,
                onSaved: (saved) => _catalog.currentState?.reveal(saved),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceCatalog extends ConsumerStatefulWidget {
  const ServiceCatalog({
    super.key,
    this.onSelected,
    this.activeOnly = false,
    this.selectedId,
    this.enabled = true,
    this.onApply,
  });
  final ValueChanged<HotelService>? onSelected;
  final ValueChanged<HotelService>? onApply;
  final bool activeOnly, enabled;
  final int? selectedId;
  @override
  ConsumerState<ServiceCatalog> createState() => _ServiceCatalogState();
}

class _ServiceCatalogState extends ConsumerState<ServiceCatalog> {
  String _search = '';
  bool? _active = true;
  int _page = 1;
  Timer? _debounce;
  final _searchController = TextEditingController();
  void reveal(HotelService service) {
    _debounce?.cancel();
    setState(() {
      _active = service.active;
      _search = service.name;
      _searchController.text = service.name;
      _page = 1;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      search: _search,
      active: widget.activeOnly ? true : _active,
      page: _page,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('service_search'),
          controller: _searchController,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            hintText: 'Tên dịch vụ',
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
        if (!widget.activeOnly) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                      (value: true, label: 'Đang bán'),
                      (value: false, label: 'Ngừng bán'),
                      (value: null, label: 'Tất cả'),
                    ]
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.label),
                        selected: _active == item.value,
                        onSelected: widget.enabled
                            ? (_) => setState(() {
                                _active = item.value;
                                _page = 1;
                              })
                            : null,
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 12),
        ],
        AsyncContent(
          value: ref.watch(servicesProvider(query)),
          onRetry: () => ref.invalidate(servicesProvider(query)),
          builder: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.items.isEmpty)
                const EmptyState(
                  icon: Icons.room_service_outlined,
                  title: 'Chưa có dịch vụ',
                  message: '',
                ),
              ...data.items.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnimatedContainer(
                    duration: motionDuration(context, 160),
                    decoration: BoxDecoration(
                      color: widget.selectedId == service.id
                          ? const Color(0xFFE5F2EB)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: widget.selectedId == service.id
                            ? AsterColors.teal
                            : AsterColors.border,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            key: Key('service_${service.id}'),
                            onTap:
                                widget.enabled &&
                                    widget.onSelected != null &&
                                    (!widget.activeOnly || service.unitValid)
                                ? () => widget.onSelected!(service)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      ServiceThumbnail(
                                        service: service,
                                        size: 44,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              service.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AsterColors.ink,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              serviceCategories[service
                                                      .category] ??
                                                  'Khác',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AsterColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (widget.onSelected != null)
                                        Icon(
                                          widget.selectedId == service.id
                                              ? Icons.check_circle
                                              : Icons.chevron_right,
                                          color: AsterColors.teal,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${money(service.price)} / ${service.unitValid ? service.unit : '—'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AsterColors.teal,
                                    ),
                                  ),
                                  if (!service.unitValid)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Cần chọn đơn vị',
                                        style: TextStyle(
                                          color: AsterColors.amber,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if (!service.active)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Ngừng bán',
                                        style: TextStyle(
                                          color: AsterColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (widget.onApply != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Tooltip(
                                  message: !service.unitValid
                                      ? 'Admin cần sửa và chọn đơn vị trước.'
                                      : !service.active
                                      ? 'Dịch vụ đã ngừng bán.'
                                      : 'Ghi dịch vụ cho một phòng đang ở',
                                  child: OutlinedButton.icon(
                                    key: Key('apply_service_${service.id}'),
                                    onPressed:
                                        widget.enabled &&
                                            service.active &&
                                            service.unitValid
                                        ? () => widget.onApply!(service)
                                        : null,
                                    icon: const Icon(
                                      Icons.add_shopping_cart_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Áp dụng'),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Pager(
                page: _page,
                hasNext: data.hasNext,
                onPage: (page) {
                  if (widget.enabled) {
                    setState(() => _page = page);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ServiceForm extends ConsumerStatefulWidget {
  const ServiceForm({super.key, this.service, this.onSaved, this.onBack});
  final ValueChanged<HotelService>? onSaved;
  final HotelService? service;
  final VoidCallback? onBack;
  @override
  ConsumerState<ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<ServiceForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.service?.name);
  late String? _unit = widget.service?.unit;
  late String _category = widget.service?.category ?? 'other';
  late final _description = TextEditingController(
    text: widget.service?.description,
  );
  late final _notes = TextEditingController(text: widget.service?.notes);
  Uint8List? _image;
  bool _removeImage = false, _picking = false;
  late final _price = TextEditingController(
    text: widget.service?.price.toString(),
  );
  late bool _active = widget.service?.active ?? true;
  bool _busy = false;
  String? _error;
  Map<String, String> _fields = {};
  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _change(String field) => setState(() {
    _error = null;
    _fields.remove(field);
  });
  Future<void> _pickImage() async {
    if (_busy || _picking) return;
    setState(() => _picking = true);
    setSheetBusy(context, true);
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (selected == null) return;
      if (await selected.length() > 5 * 1024 * 1024) {
        throw const ApiFailure('Ảnh tối đa 5 MB.');
      }
      final bytes = await selected.readAsBytes();
      if (mounted) {
        setState(() {
          _image = bytes;
          _removeImage = false;
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
          .saveService(
            {
              'name': _name.text.trim(),
              'unit': _unit,
              'unit_price': _price.text,
              'is_active': _active,
              'category': _category,
              'description': _description.text.trim(),
              'notes': _notes.text.trim(),
              'remove_image': _removeImage,
            },
            id: widget.service?.id,
            image: _image,
          );
      if (!mounted) return;
      ref.invalidate(servicesProvider);
      setSheetBusy(context, false);
      setState(() => _busy = false);
      widget.onSaved?.call(saved);
      showMessage(context, 'Đã lưu');
      if (widget.onBack == null) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setSheetBusy(context, false);
      setState(() {
        _busy = false;
        _error = error.toString();
        _fields = error is ApiFailure ? error.fields : {};
      });
      final field = [
        'name',
        'unit',
        'unit_price',
      ].where(_fields.containsKey).firstOrNull;
      revealField(
        context,
        Key(field == null ? 'service_error' : 'catalog_$field'),
      );
    }
  }

  Widget _unitField() {
    final units = ref.watch(serviceUnitsProvider);
    return units.when(
      skipLoadingOnRefresh: true,
      data: (items) {
        final selected = items.where((item) => item.value == _unit).firstOrNull;
        return DropdownButtonFormField<String>(
          key: const Key('catalog_unit'),
          initialValue: selected?.value,
          isExpanded: true,
          menuMaxHeight: 360,
          itemHeight: null,
          decoration: InputDecoration(
            labelText: 'Đơn vị',
            hintText: 'Chọn đơn vị',
            helperText: selected?.example,
            errorText:
                _fields['unit'] ??
                (_unit != null && selected == null
                    ? 'Đơn vị cũ “$_unit” không hợp lệ. Chọn lại.'
                    : null),
          ),
          selectedItemBuilder: (_) => items
              .map(
                (item) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(item.label),
                ),
              )
              .toList(),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item.value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.label),
                        Text(
                          item.example,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AsterColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _unit = value;
                  _error = null;
                  _fields.remove('unit');
                }),
          validator: (value) =>
              value == null || !items.any((item) => item.value == value)
              ? 'Chọn đơn vị.'
              : null,
        );
      },
      loading: () => const InputDecorator(
        decoration: InputDecoration(labelText: 'Đơn vị'),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AsterLoader(size: 20),
        ),
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineError('Không tải được đơn vị. ${error.toString()}'),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(serviceUnitsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_picking,
    child: PinnedFormLayout(
      header: ScreenHeading(
        title: widget.service == null ? 'Thêm dịch vụ' : 'Sửa dịch vụ',
        action: IconButton(
          tooltip: widget.onBack == null ? 'Đóng' : 'Quay lại',
          onPressed: _busy || _picking
              ? null
              : widget.onBack ?? () => Navigator.pop(context),
          icon: Icon(
            widget.onBack == null ? Icons.close : Icons.arrow_back_rounded,
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('catalog_name'),
              controller: _name,
              enabled: !_busy,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Tên dịch vụ',
                counterText: '',
                errorText: _fields['name'],
              ),
              onChanged: (_) => _change('name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nhập tên dịch vụ.'
                  : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const Key('catalog_category'),
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Nhóm dịch vụ',
                errorText: _fields['category'],
              ),
              items: serviceCategories.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _category = value ?? 'other'),
            ),
            const SizedBox(height: 14),
            _unitField(),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('catalog_unit_price'),
              controller: _price,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              decoration: InputDecoration(
                labelText: 'Đơn giá',
                suffixText: 'đ',
                errorText: _fields['unit_price'],
              ),
              onChanged: (_) => _change('unit_price'),
              validator: (value) =>
                  int.tryParse(value ?? '') == null ? 'Nhập đơn giá.' : null,
            ),
            const SizedBox(height: 12),
            if (_image != null ||
                (!_removeImage && widget.service?.imageUrl != null)) ...[
              Center(
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          _image!,
                          height: 130,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) =>
                              const Icon(Icons.broken_image_outlined, size: 48),
                        ),
                      )
                    : ServiceThumbnail(service: widget.service!, size: 130),
              ),
              TextButton.icon(
                onPressed: _busy || _picking
                    ? null
                    : () => setState(() {
                        _image = null;
                        _removeImage = true;
                      }),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Bỏ ảnh'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _busy || _picking ? null : _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_picking ? 'Đang chọn ảnh…' : 'Chọn ảnh dịch vụ'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('catalog_description'),
              controller: _description,
              enabled: !_busy,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: 'Mô tả dịch vụ',
                errorText: _fields['description'],
              ),
              onChanged: (_) => _change('description'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('catalog_notes'),
              controller: _notes,
              enabled: !_busy,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: 'Ghi chú nội bộ',
                errorText: _fields['notes'],
              ),
              onChanged: (_) => _change('notes'),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Đang bán'),
              value: _active,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _active = value),
            ),
            if (_error != null &&
                (_fields.isEmpty ||
                    _fields.keys.any(
                      (field) =>
                          !['name', 'unit', 'unit_price'].contains(field),
                    )))
              InlineError(_error!, key: const Key('service_error')),
            const SizedBox(height: 16),
          ],
        ),
      ),
      footer: PressScale(
        child: FilledButton(
          key: const Key('catalog_save'),
          onPressed:
              _busy ||
                  _picking ||
                  !ref.watch(serviceUnitsProvider).hasValue ||
                  ref.watch(serviceUnitsProvider).hasError
              ? null
              : _save,
          child: _busy ? const AsterLoader(size: 24) : const Text('Lưu'),
        ),
      ),
    ),
  );
}
