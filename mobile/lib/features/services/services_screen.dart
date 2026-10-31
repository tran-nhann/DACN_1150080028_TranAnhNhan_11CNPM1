import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../shell/app_shell.dart';

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
          ServiceCatalog(key: _catalog, onSelected: admin ? _edit : null),
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
  });
  final ValueChanged<HotelService>? onSelected;
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
                      child: InkWell(
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
                                  Expanded(
                                    child: Text(
                                      service.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AsterColors.ink,
                                      ),
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
  const ServiceForm({super.key, this.service, this.onSaved});
  final ValueChanged<HotelService>? onSaved;
  final HotelService? service;
  @override
  ConsumerState<ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<ServiceForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.service?.name);
  late String? _unit = widget.service?.unit;
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
    super.dispose();
  }

  void _change(String field) => setState(() {
    _error = null;
    _fields.remove(field);
  });
  Future<void> _save() async {
    if (_busy || !validateAndReveal(context, _form)) return;
    setState(() {
      _busy = true;
      _error = null;
      _fields = {};
    });
    setSheetBusy(context, true);
    try {
      final saved = await ref.read(apiProvider).saveService({
        'name': _name.text.trim(),
        'unit': _unit,
        'unit_price': _price.text,
        'is_active': _active,
      }, id: widget.service?.id);
      if (!mounted) return;
      ref.invalidate(servicesProvider);
      setSheetBusy(context, false);
      setState(() => _busy = false);
      widget.onSaved?.call(saved);
      showMessage(context, 'Đã lưu');
      Navigator.pop(context);
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
    canPop: !_busy,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeading(
              title: widget.service == null ? 'Thêm dịch vụ' : 'Sửa dịch vụ',
              action: IconButton(
                tooltip: 'Đóng',
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
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
            PressScale(
              child: FilledButton(
                key: const Key('catalog_save'),
                onPressed:
                    _busy ||
                        !ref.watch(serviceUnitsProvider).hasValue ||
                        ref.watch(serviceUnitsProvider).hasError
                    ? null
                    : _save,
                child: _busy ? const AsterLoader(size: 24) : const Text('Lưu'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
