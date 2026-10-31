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

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _search = '';
  int _page = 1;
  Timer? _debounce;
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  GuestQuery get _query => (search: _search, page: _page);
  void _edit([Guest? guest]) => showAsterSheet<void>(
    context: context,
    form: true,
    builder: (_) => GuestForm(guest: guest),
  );

  @override
  Widget build(BuildContext context) => PageBody(
    onRefresh: () async {
      await ref.refresh(guestsProvider(_query).future).then((_) {});
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeading(
          title: 'Khách hàng',
          leading: const MoreBackButton(),
          action: IconButton.filled(
            tooltip: 'Thêm khách hàng',
            onPressed: _edit,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Tên hoặc điện thoại',
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
        const SizedBox(height: 22),
        AsyncContent(
          value: ref.watch(guestsProvider(_query)),
          onRetry: () => ref.invalidate(guestsProvider(_query)),
          builder: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${data.count} khách',
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              if (data.items.isEmpty)
                const EmptyState(
                  icon: Icons.people_outline,
                  title: 'Không tìm thấy khách',
                  message: '',
                ),
              ...data.items.map(
                (guest) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => showAsterSheet<void>(
                        context: context,
                        builder: (_) => GuestDetail(guest: guest),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFEAF2EF),
                              child: Text(
                                guest.name.isEmpty
                                    ? '?'
                                    : guest.name.substring(0, 1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AsterColors.teal,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    guest.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AsterColors.ink,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    guest.phone,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: AsterColors.muted,
                            ),
                          ],
                        ),
                      ),
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
  );
}

class GuestDetail extends ConsumerStatefulWidget {
  const GuestDetail({
    super.key,
    this.guest,
    this.guestId,
    this.onBack,
    this.onUpdated,
  });
  final Guest? guest;
  final int? guestId;
  final VoidCallback? onBack;
  final ValueChanged<Guest>? onUpdated;
  @override
  ConsumerState<GuestDetail> createState() => _GuestDetailState();
}

class _GuestDetailState extends ConsumerState<GuestDetail> {
  late Guest? _guest = widget.guest;
  bool _editing = false;
  int _editVersion = 0;
  HotelBooking? _selected;

  void _back() {
    if (sheetIsBusy(context)) return;
    setState(() {
      _editing = false;
      _selected = null;
    });
    setSheetHeight(context, .85);
  }

  Widget _profile(Guest guest) => SingleChildScrollView(
    key: const PageStorageKey('guest_profile'),
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeading(
          title: 'Hồ sơ khách',
          action: IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        if (widget.onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Quay lại'),
            ),
          ),
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE1F0E9),
              child: Text(
                guest.name.isEmpty ? '?' : guest.name.characters.first,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AsterColors.teal,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                guest.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Sửa khách hàng',
              onPressed: () {
                setState(() => _editing = true);
                setSheetHeight(context, .95);
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DetailSection(
          title: 'Liên hệ',
          icon: Icons.contact_phone_outlined,
          children: [
            DetailField(
              label: 'Điện thoại',
              value: guest.phone,
              copyable: true,
            ),
            if (guest.email.isNotEmpty)
              DetailField(label: 'Email', value: guest.email, copyable: true),
          ],
        ),
        if (guest.notes.isNotEmpty)
          DetailSection(
            title: 'Ghi chú',
            icon: Icons.notes_rounded,
            children: [
              Text(guest.notes, style: const TextStyle(color: AsterColors.ink)),
            ],
          ),
        if (guest.createdAt != null)
          DetailField(label: 'Ngày tạo', value: dateStamp(guest.createdAt!)),
        const SizedBox(height: 12),
        BookingHistory(
          customerId: guest.id,
          onSelected: (booking) {
            setState(() => _selected = booking);
          },
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authProvider).user?.canAccessCustomers != true) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Không có quyền xem hồ sơ khách.'),
      );
    }
    final data = _guest == null
        ? ref.watch(guestDetailProvider(widget.guestId!))
        : AsyncData(_guest!);
    return PopScope(
      canPop: !_editing && _selected == null && widget.onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _selected != null || sheetIsBusy(context)) return;
        if (_editing) {
          _back();
        } else {
          widget.onBack?.call();
        }
      },
      child: data.when(
        loading: () => _fallback(const LoadingCards()),
        error: (error, _) => _fallback(
          Column(
            children: [
              InlineError(error.toString()),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(guestDetailProvider(widget.guestId!)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (guest) => SheetPages(
          index: _selected != null
              ? 2
              : _editing
              ? 1
              : 0,
          children: [
            _profile(guest),
            GuestForm(
              key: ValueKey(_editVersion),
              guest: guest,
              onBack: _back,
              onSaved: (saved) {
                widget.onUpdated?.call(saved);
                setState(() {
                  _guest = saved;
                  _editing = false;
                  _editVersion++;
                });
                setSheetHeight(context, .85);
              },
            ),
            if (_selected != null)
              BookingDetail(
                key: ValueKey(_selected!.id),
                booking: _selected!,
                onBack: _back,
                onGuest: _back,
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        ScreenHeading(
          title: 'Hồ sơ khách',
          action: IconButton(
            tooltip: widget.onBack == null ? 'Đóng' : 'Quay lại',
            onPressed: widget.onBack ?? () => Navigator.pop(context),
            icon: Icon(
              widget.onBack == null ? Icons.close : Icons.arrow_back_rounded,
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class GuestForm extends ConsumerStatefulWidget {
  const GuestForm({super.key, this.guest, this.onSaved, this.onBack});
  final Guest? guest;
  final ValueChanged<Guest>? onSaved;
  final VoidCallback? onBack;
  @override
  ConsumerState<GuestForm> createState() => _GuestFormState();
}

class _GuestFormState extends ConsumerState<GuestForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.guest?.name);
  late final _phone = TextEditingController(text: widget.guest?.phone);
  late final _email = TextEditingController(text: widget.guest?.email);
  late final _notes = TextEditingController(text: widget.guest?.notes);
  bool _busy = false;
  String? _error;
  Map<String, String> _fields = {};
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
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
      final saved = await ref.read(apiProvider).saveGuest({
        'full_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'notes': _notes.text.trim(),
      }, id: widget.guest?.id);
      if (!mounted) return;
      ref.invalidate(guestsProvider);
      ref.invalidate(guestDetailProvider);
      ref.invalidate(bookingLookupProvider);
      ref.invalidate(bookingsProvider);
      ref.invalidate(dashboardProvider);
      setSheetBusy(context, false);
      setState(() => _busy = false);
      showMessage(context, 'Đã lưu');
      if (widget.onSaved != null) {
        widget.onSaved!(saved);
      } else {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
          _fields = error is ApiFailure ? error.fields : {};
        });
        setSheetBusy(context, false);
        _revealServerError();
      }
    }
  }

  void _revealServerError() {
    final name = [
      'full_name',
      'phone',
      'email',
      'notes',
    ].where(_fields.containsKey).firstOrNull;
    final key = switch (name) {
      'full_name' => 'guest_name',
      'phone' => 'guest_phone',
      'email' => 'guest_email',
      'notes' => 'guest_notes',
      _ => 'guest_error',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void visit(Element element) {
        if (element.widget.key == Key(key)) {
          Scrollable.ensureVisible(
            element,
            duration: motionDuration(context, 220),
            alignment: .15,
          );
        } else {
          element.visitChildren(visit);
        }
      }

      context.visitChildElements(visit);
    });
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
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeading(
                title: widget.guest == null ? 'Thêm khách' : 'Khách hàng',
                action: IconButton(
                  tooltip: widget.onBack == null ? 'Đóng' : 'Quay lại',
                  onPressed: _busy
                      ? null
                      : widget.onBack ?? () => Navigator.pop(context),
                  icon: Icon(
                    widget.onBack == null
                        ? Icons.close
                        : Icons.arrow_back_rounded,
                  ),
                ),
              ),
              TextFormField(
                key: const Key('guest_name'),
                controller: _name,
                enabled: !_busy,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {
                  _error = null;
                  _fields.remove('full_name');
                }),
                decoration: InputDecoration(
                  labelText: 'Họ và tên',
                  counterText: '',
                  errorText: _fields['full_name'],
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập họ tên.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('guest_phone'),
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {
                  _error = null;
                  _fields.remove('phone');
                }),
                decoration: InputDecoration(
                  labelText: 'Số điện thoại',
                  errorText: _fields['phone'],
                ),
                validator: (value) =>
                    value == null ||
                        !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(value.trim())
                    ? 'Nhập số điện thoại gồm 9–15 chữ số.'
                    : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('guest_email'),
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {
                  _error = null;
                  _fields.remove('email');
                }),
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: _fields['email'],
                ),
                validator: (value) =>
                    value != null &&
                        value.trim().isNotEmpty &&
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(value.trim())
                    ? 'Email chưa hợp lệ.'
                    : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('guest_notes'),
                controller: _notes,
                enabled: !_busy,
                maxLength: 300,
                maxLines: 2,
                onChanged: (_) => setState(() {
                  _error = null;
                  _fields.remove('notes');
                }),
                decoration: InputDecoration(
                  labelText: 'Ghi chú',
                  counterText: '',
                  errorText: _fields['notes'],
                ),
              ),
              if (_error != null &&
                  (_fields.isEmpty ||
                      _fields.keys.any(
                        (field) => ![
                          'full_name',
                          'phone',
                          'email',
                          'notes',
                        ].contains(field),
                      ))) ...[
                const SizedBox(height: 12),
                InlineError(_error!, key: const Key('guest_error')),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: PressScale(
                  child: FilledButton(
                    key: const Key('guest_save'),
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const AsterLoader(size: 24)
                        : const Text('Lưu'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}
