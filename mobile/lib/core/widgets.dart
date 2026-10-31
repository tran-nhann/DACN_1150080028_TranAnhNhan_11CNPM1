import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'theme.dart';
import 'loading.dart';
import 'interaction.dart';
import 'models.dart';
export 'loading.dart' show AsterLoader;
export 'interaction.dart';

String money(int amount) =>
    '${NumberFormat.decimalPattern('vi').format(amount)} ₫';

class Brand extends StatelessWidget {
  const Brand({super.key, this.light = false, this.compact = false});
  final bool light, compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: light ? Colors.white.withValues(alpha: .12) : AsterColors.dark,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(
          Icons.local_florist_outlined,
          color: Color(0xFFAAE4CD),
          size: 25,
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 11),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'aster',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                    color: light ? Colors.white : AsterColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(padding: padding, child: child),
  );
}

class ScreenHeading extends StatelessWidget {
  const ScreenHeading({
    super.key,
    required this.title,
    this.subtitle = '',
    this.action,
    this.leading,
  });
  final String title, subtitle;
  final Widget? action, leading;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    ),
  );
}

class ConditionBadge extends StatelessWidget {
  const ConditionBadge(this.condition, {super.key});
  final String condition;
  static (String, Color, IconData) details(String condition) =>
      switch (condition) {
        'occupied' => ('Đang ở', Color(0xFF3977A8), Icons.bed_outlined),
        'reserved' => (
          'Đã đặt',
          Color(0xFF7C62AB),
          Icons.event_available_outlined,
        ),
        'cleaning' => (
          'Cần dọn',
          AsterColors.amber,
          Icons.cleaning_services_outlined,
        ),
        'maintenance' => ('Bảo trì', AsterColors.red, Icons.build_outlined),
        _ => ('Sẵn sàng', AsterColors.teal, Icons.check_circle_outline),
      };
  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = details(condition);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
  });
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final content = value.when(
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (data) =>
          KeyedSubtree(key: const ValueKey('data'), child: builder(data)),
      loading: () => const LoadingCards(key: ValueKey('loading')),
      error: (error, stack) => EmptyState(
        key: const ValueKey('error'),
        icon: Icons.cloud_off_outlined,
        title: 'Không tải được',
        message: error.toString(),
        action: PressScale(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Thử lại'),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (value.hasValue && value.hasError) ...[
          InlineError(value.error.toString()),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Thử lại',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
        if (value.hasValue && value.isLoading)
          const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: AsterLoader(size: 24),
            ),
          ),
        MotionSwap(milliseconds: 180, distance: 0, child: content),
      ],
    );
  }
}

class LoadingCards extends StatelessWidget {
  const LoadingCards({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Đang tải dữ liệu',
    liveRegion: true,
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: LoadingMotion(
          builder: (_, phase) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(-3 + phase * 6, -.4),
              end: Alignment(-1 + phase * 6, .4),
              colors: const [
                Color(0x00FFFFFF),
                Color(0xB3FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0, .5, 1],
            ).createShader(bounds),
            child: Column(
              children: [
                Container(
                  height: 150,
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4EDEA),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bone(width: 94, height: 10),
                            const SizedBox(height: 16),
                            _bone(width: 64, height: 32),
                            const SizedBox(height: 12),
                            _bone(width: 74, height: 8),
                          ],
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD3E1DD),
                            width: 7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < 2; i++)
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AsterColors.border),
                    ),
                    child: Row(
                      children: [
                        _bone(width: 46, height: 46),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FractionallySizedBox(
                                widthFactor: .65,
                                child: _bone(height: 11),
                              ),
                              const SizedBox(height: 12),
                              FractionallySizedBox(
                                widthFactor: .4,
                                child: _bone(height: 8),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _bone(width: 24, height: 8),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  static Widget _bone({double? width, required double height}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFDDE7E4),
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

class RoomChoice extends StatelessWidget {
  const RoomChoice({
    super.key,
    required this.room,
    required this.selected,
    required this.onTap,
    this.nightlyRate,
  });
  final HotelRoom room;
  final bool selected;
  final VoidCallback? onTap;
  final int? nightlyRate;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: AnimatedContainer(
      duration: motionDuration(context, 160),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE4F2EA) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AsterColors.teal : AsterColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.number,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AsterColors.ink,
                        ),
                      ),
                    ),
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? AsterColors.teal : AsterColors.muted,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(room.type.name, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                Text(
                  '${money(nightlyRate ?? room.type.rate)} / đêm',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AsterColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${room.type.capacity} khách · Tầng ${room.floor}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Surface(
    child: SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Icon(icon, size: 42, color: AsterColors.teal),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
          const SizedBox(height: 18),
        ],
      ),
    ),
  );
}

class Pager extends StatelessWidget {
  const Pager({
    super.key,
    required this.page,
    required this.hasNext,
    required this.onPage,
  });
  final int page;
  final bool hasNext;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) {
    if (page == 1 && !hasNext) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Trang trước',
            onPressed: page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Trang $page'),
          IconButton(
            tooltip: 'Trang sau',
            onPressed: hasNext ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

OverlayEntry? _activeToast;

void showMessage(BuildContext context, String message, {bool success = true}) {
  if (success) {
    final overlay = Overlay.of(context, rootOverlay: true);
    _activeToast?.remove();
    _activeToast?.dispose();
    late final OverlayEntry entry;
    void dismiss() {
      if (_activeToast != entry) return;
      _activeToast = null;
      entry.remove();
      entry.dispose();
    }

    entry = OverlayEntry(
      builder: (_) => _SuccessToast(
        message: message,
        onDismiss: dismiss,
        onGone: () {
          if (_activeToast == entry) _activeToast = null;
        },
      ),
    );
    _activeToast = entry;
    overlay.insert(entry);
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(days: 1),
      showCloseIcon: true,
      content: Row(
        children: [
          Icon(Icons.error_outline, color: const Color(0xFFAAE4CD), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _SuccessToast extends StatefulWidget {
  const _SuccessToast({
    required this.message,
    required this.onDismiss,
    required this.onGone,
  });
  final String message;
  final VoidCallback onDismiss, onGone;
  @override
  State<_SuccessToast> createState() => _SuccessToastState();
}

class _SuccessToastState extends State<_SuccessToast> {
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer.cancel();
    widget.onGone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 20,
    right: 20,
    top: MediaQuery.paddingOf(context).top + 16,
    child: IgnorePointer(
      child: Semantics(
        liveRegion: true,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: motionDuration(context, 180),
          curve: Curves.easeOutCubic,
          builder: (_, value, child) => Opacity(opacity: value, child: child),
          child: Material(
            color: AsterColors.dark,
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFFAAE4CD),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
  );
}
