import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

bool reducedMotion(BuildContext context) {
  final media = MediaQuery.of(context);
  return media.disableAnimations || media.accessibleNavigation;
}

Duration motionDuration(BuildContext context, int milliseconds) =>
    reducedMotion(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});
  final Widget child;
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;
  void _press(bool value) {
    if (widget.child is ButtonStyleButton &&
        !(widget.child as ButtonStyleButton).enabled) {
      value = false;
    }
    if (value != _pressed) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _press(true),
    onPointerUp: (_) => _press(false),
    onPointerCancel: (_) => _press(false),
    child: AnimatedScale(
      scale: _pressed && !reducedMotion(context) ? .98 : 1,
      duration: motionDuration(context, 90),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}

class MotionSwap extends StatelessWidget {
  const MotionSwap({
    super.key,
    required this.child,
    this.milliseconds = 220,
    this.direction = 1,
    this.distance = 16,
  });
  final Widget child;
  final int milliseconds, direction;
  final double distance;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AnimatedSwitcher(
      duration: motionDuration(context, milliseconds),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (view, animation) {
        final entering = view.key == child.key;
        final slide = distance / math.max(1, constraints.maxWidth);
        return IgnorePointer(
          ignoring: !entering,
          child: ExcludeSemantics(
            excluding: !entering,
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(
                    entering ? direction * slide : -direction * slide,
                    0,
                  ),
                  end: Offset.zero,
                ).animate(animation),
                child: view,
              ),
            ),
          ),
        );
      },
      child: child,
    ),
  );
}

/// Validate every field, then reveal the first invalid field after layout.
bool validateAndReveal(BuildContext context, GlobalKey<FormState> form) {
  final invalid = form.currentState?.validateGranularly() ?? {};
  if (invalid.isEmpty) return form.currentState != null;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final field = invalid.first;
    if (field.mounted) {
      Scrollable.ensureVisible(
        field.context,
        duration: motionDuration(context, 220),
        alignment: .15,
      );
    }
  });
  return false;
}

void revealField(BuildContext context, Key key) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    void visit(Element element) {
      if (element.widget.key == key) {
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

class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AsterColors.red.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AsterColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AsterColors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

class ConfirmPanel extends StatelessWidget {
  const ConfirmPanel({
    super.key,
    required this.title,
    required this.details,
    required this.label,
    required this.onConfirm,
    required this.onBack,
    this.onClose,
    this.busy = false,
    this.error,
    this.destructive = false,
  });
  final String title, details, label;
  final VoidCallback onConfirm, onBack;
  final VoidCallback? onClose;
  final bool busy, destructive;
  final String? error;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onClose != null)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Đóng',
              onPressed: busy ? null : onClose,
              icon: const Icon(Icons.close),
            ),
          ),
        const SizedBox(height: 12),
        Icon(
          destructive ? Icons.event_busy_outlined : Icons.check_circle_outline,
          size: 42,
          color: destructive ? AsterColors.red : AsterColors.teal,
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(details, textAlign: TextAlign.center),
        if (error != null) ...[
          const SizedBox(height: 20),
          InlineError(error!, key: const Key('confirm_error')),
        ],
        const SizedBox(height: 28),
        PressScale(
          child: FilledButton(
            key: const Key('confirm_action'),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AsterColors.red)
                : null,
            onPressed: busy ? null : onConfirm,
            child: Text(label),
          ),
        ),
        const SizedBox(height: 8),
        PressScale(
          child: TextButton(
            onPressed: busy ? null : onBack,
            child: const Text('Quay lại'),
          ),
        ),
      ],
    ),
  );
}

Future<bool?> showAsterConfirm(
  BuildContext context, {
  required String title,
  required String details,
  required String label,
  bool destructive = false,
}) => showGeneralDialog<bool>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: AsterColors.ink.withValues(alpha: .35),
  transitionDuration: motionDuration(context, 180),
  transitionBuilder: (_, animation, _, child) => FadeTransition(
    opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
    child: ScaleTransition(
      scale: Tween<double>(begin: .96, end: 1).animate(animation),
      child: child,
    ),
  ),
  pageBuilder: (dialogContext, _, _) => SafeArea(
    child: Dialog(
      constraints: const BoxConstraints(maxWidth: 400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConfirmPanel(
        title: title,
        details: details,
        label: label,
        destructive: destructive,
        onConfirm: () => Navigator.pop(dialogContext, true),
        onBack: () => Navigator.pop(dialogContext, false),
        onClose: () => Navigator.pop(dialogContext, false),
      ),
    ),
  ),
);

bool sheetIsBusy(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_SheetScope>()?.controller.busy ??
    false;

class SheetPages extends StatefulWidget {
  const SheetPages({
    super.key,
    required this.index,
    required this.children,
    this.confirmationIndex = -1,
  });
  final int index;
  final List<Widget> children;
  final int confirmationIndex;
  @override
  State<SheetPages> createState() => _SheetPagesState();
}

class _SheetPagesState extends State<SheetPages>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this, value: 1);
  int _direction = 1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _animation.stop();
      _animation.value = 1;
    }
  }

  @override
  void didUpdateWidget(SheetPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _direction = widget.index > oldWidget.index ? 1 : -1;
      _animation.duration = motionDuration(
        context,
        widget.index == widget.confirmationIndex ||
                oldWidget.index == widget.confirmationIndex
            ? 180
            : 220,
      );
      if (reducedMotion(context)) {
        _animation.value = 1;
      } else {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final curve = _animation.drive(CurveTween(curve: Curves.easeOutCubic));
      return Stack(
        alignment: Alignment.topCenter,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            Offstage(
              offstage: i != widget.index,
              child: TickerMode(
                enabled: i == widget.index,
                child: FadeTransition(
                  opacity: curve,
                  child: i == widget.confirmationIndex
                      ? ScaleTransition(
                          scale: Tween<double>(
                            begin: .96,
                            end: 1,
                          ).animate(curve),
                          child: widget.children[i],
                        )
                      : SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(
                              _direction *
                                  16 /
                                  math.max(1, constraints.maxWidth),
                              0,
                            ),
                            end: Offset.zero,
                          ).animate(curve),
                          child: widget.children[i],
                        ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class SheetController extends ChangeNotifier {
  bool busy = false;
  double heightFactor = .85;

  void update({bool? busy, double? heightFactor}) {
    final nextBusy = busy ?? this.busy;
    final nextHeight = heightFactor ?? this.heightFactor;
    if (nextBusy == this.busy && nextHeight == this.heightFactor) return;
    this.busy = nextBusy;
    this.heightFactor = nextHeight;
    notifyListeners();
  }
}

class _SheetScope extends InheritedWidget {
  const _SheetScope({required this.controller, required super.child});
  final SheetController controller;
  @override
  bool updateShouldNotify(_SheetScope oldWidget) =>
      controller != oldWidget.controller;
}

void setSheetBusy(BuildContext context, bool busy) => context
    .getInheritedWidgetOfExactType<_SheetScope>()
    ?.controller
    .update(busy: busy);

void setSheetHeight(BuildContext context, double factor) => context
    .getInheritedWidgetOfExactType<_SheetScope>()
    ?.controller
    .update(heightFactor: factor);

class _AsterSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _AsterSheetRoute({
    required this.sheetController,
    required super.builder,
    required super.capturedThemes,
    required super.barrierLabel,
    required super.sheetAnimationStyle,
  }) : super(
         isScrollControlled: true,
         useSafeArea: true,
         showDragHandle: true,
         constraints: const BoxConstraints(maxWidth: 480),
         backgroundColor: Colors.white,
         modalBarrierColor: AsterColors.ink.withValues(alpha: .35),
         shape: const RoundedRectangleBorder(
           borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
         ),
         clipBehavior: Clip.antiAlias,
       ) {
    sheetController.addListener(_changed);
  }
  final SheetController sheetController;
  @override
  bool get isDismissible => !sheetController.busy;
  @override
  bool get enableDrag => !sheetController.busy;
  void _changed() {
    changedInternalState();
    // Rebuild the route page as well: the drag gesture is owned by BottomSheet.
    changedExternalState();
  }

  @override
  void dispose() {
    sheetController.removeListener(_changed);
    sheetController.dispose();
    super.dispose();
  }
}

Future<T?> showAsterSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool form = false,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final controller = SheetController()..heightFactor = form ? .95 : .85;
  return navigator.push<T>(
    _AsterSheetRoute<T>(
      sheetController: controller,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      sheetAnimationStyle: AnimationStyle(
        duration: motionDuration(context, 280),
        reverseDuration: motionDuration(context, 280),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      ),
      builder: (sheetContext) => _SheetScope(
        controller: controller,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final media = MediaQuery.of(context);
            final keyboard = media.viewInsets.bottom;
            final height = math.max(
              0.0,
              (media.size.height - media.padding.top) *
                      controller.heightFactor -
                  keyboard -
                  32,
            );
            return PopScope(
              canPop: !controller.busy,
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboard),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height),
                  child: MediaQuery(
                    data: media.copyWith(viewInsets: EdgeInsets.zero),
                    child: Builder(builder: builder),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class ExpandableDetails extends StatelessWidget {
  const ExpandableDetails({
    super.key,
    required this.description,
    this.notes = '',
  });
  final String description, notes;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 12),
    shape: const Border(),
    collapsedShape: const Border(),
    title: const Text(
      'Chi tiết',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    children: [
      if (description.isNotEmpty)
        Align(alignment: Alignment.centerLeft, child: Text(description)),
      if (notes.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(alignment: Alignment.centerLeft, child: Text(notes)),
        ),
    ],
  );
}
