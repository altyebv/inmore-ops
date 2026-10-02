import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

/// The first-run tour: a spotlight on each part of the shell in turn, with a
/// short card explaining it.
///
/// It runs once per person on each computer — the first time they sign in
/// there — and can be replayed from the help center or the account menu. The
/// steps are shaped by role, the same way the sidebar is: a designer is not
/// shown the New request button they don't have.

/// The parts of the screen the tour points at. Each widget it highlights is
/// wrapped in a [KeyedSubtree] with one of these keys; a step whose key is not
/// on screen is skipped rather than pointing at nothing.
abstract final class TourKeys {
  static final home = GlobalKey(debugLabel: 'tour.home');
  static final newRequest = GlobalKey(debugLabel: 'tour.newRequest');
  static final myWork = GlobalKey(debugLabel: 'tour.myWork');
  static final search = GlobalKey(debugLabel: 'tour.search');
  static final customers = GlobalKey(debugLabel: 'tour.customers');
  static final reports = GlobalKey(debugLabel: 'tour.reports');
  static final help = GlobalKey(debugLabel: 'tour.help');
  static final account = GlobalKey(debugLabel: 'tour.account');
}

String _seenKey(String employeeId) => 'tour.seen.$employeeId';

class TourStep {
  const TourStep({required this.title, required this.body, this.target});

  final String title;
  final String body;

  /// Null for a step with nothing to point at — the welcome.
  final GlobalKey? target;
}

List<TourStep> tourSteps(L10n l, Employee me) {
  final manages = me.role.canManageRequests;
  final firstName = me.fullName.trim().split(RegExp(r'\s+')).first;
  return [
    TourStep(
      title: l.tourWelcomeTitle(firstName),
      body: manages ? l.tourWelcomeManager : l.tourWelcomeWorker,
    ),
    TourStep(
      target: TourKeys.home,
      title: manages ? l.tourBoardTitle : l.tourHomeWorkTitle,
      body: manages ? l.tourBoardBody : l.tourHomeWorkBody,
    ),
    if (manages) ...[
      TourStep(
        target: TourKeys.newRequest,
        title: l.tourNewRequestTitle,
        body: l.tourNewRequestBody,
      ),
      TourStep(
        target: TourKeys.myWork,
        title: l.tourMyWorkTitle,
        body: l.tourMyWorkBody,
      ),
    ],
    TourStep(
      target: TourKeys.search,
      title: l.tourSearchTitle,
      body: l.tourSearchBody,
    ),
    TourStep(
      target: TourKeys.customers,
      title: l.tourCustomersTitle,
      body: l.tourCustomersBody,
    ),
    if (me.role.canSeeMoney)
      TourStep(
        target: TourKeys.reports,
        title: l.tourReportsTitle,
        body: l.tourReportsBody,
      ),
    TourStep(
      target: TourKeys.help,
      title: l.tourHelpTitle,
      body: l.tourHelpBody,
    ),
    TourStep(
      target: TourKeys.account,
      title: l.tourAccountTitle,
      body: l.tourAccountBody,
    ),
  ];
}

bool _running = false;

/// Shows the tour from the start. Goes to the landing screen first, because
/// that is where the board's New request button lives.
Future<void> startTour(BuildContext context, WidgetRef ref) async {
  final me = ref.read(currentEmployeeProvider).valueOrNull;
  if (me == null || _running) return;
  _running = true;
  try {
    final router = GoRouter.of(context);
    if (router.routerDelegate.currentConfiguration.uri.path != '/') {
      router.go('/');
      // Let the landing screen build so its targets exist.
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!context.mounted) return;
    final l = context.l10n;
    final steps = [
      for (final s in tourSteps(l, me))
        if (s.target == null || s.target!.currentContext != null) s,
    ];
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, __, ___) => _TourOverlay(steps: steps),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    await ref.read(sharedPreferencesProvider).setBool(_seenKey(me.id), true);
  } finally {
    _running = false;
  }
}

/// Starts the tour the first time someone signs in on this computer. Wraps
/// the shell, so it runs once the shell — and everything the tour points at —
/// is on screen.
class TourAutoStart extends ConsumerStatefulWidget {
  const TourAutoStart({required this.employee, required this.child, super.key});

  final Employee employee;
  final Widget child;

  @override
  ConsumerState<TourAutoStart> createState() => _TourAutoStartState();
}

class _TourAutoStartState extends ConsumerState<TourAutoStart> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final seen = ref
            .read(sharedPreferencesProvider)
            .getBool(_seenKey(widget.employee.id)) ??
        false;
    if (seen) return;
    // After the launch intro has faded and the first data has arrived.
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) startTour(context, ref);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({required this.steps});

  final List<TourStep> steps;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> {
  var _index = 0;

  var _closing = false;

  // Keys are read straight from the keyboard rather than through focus: the
  // route's own focus scope keeps the primary focus, so focus-based
  // shortcuts never saw Esc or the arrows.
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (_closing || event is! KeyDownEvent) return false;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward =
        rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
    final backward =
        rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _close();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == forward) {
      _next();
    } else if (key == backward) {
      _back();
    } else {
      return false;
    }
    return true;
  }

  // Once only: the handler stays registered until the fade-out ends, and a
  // second Esc must not pop the screen underneath.
  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.pop(context);
  }

  TourStep get _step => widget.steps[_index];
  bool get _last => _index == widget.steps.length - 1;

  void _next() => _last ? _close() : setState(() => _index++);

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  /// Where the current target is, with a little room around it. The overlay
  /// covers the whole window from its top-left corner, so window coordinates
  /// are the overlay's coordinates.
  Rect? _hole() {
    final box = _step.target?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return (box.localToGlobal(Offset.zero) & box.size).inflate(6);
  }

  @override
  Widget build(BuildContext context) {
    // Watching the size rebuilds on resize. The target is laid out after this
    // build, so measure again once the frame is done and follow it if it
    // moved.
    final window = MediaQuery.sizeOf(context);
    final hole = _hole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hole() != hole) setState(() {});
    });

    return Stack(
      children: [
        // Clicks outside the card do nothing — the tour is short, and a
        // stray click should not end it halfway.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: TweenAnimationBuilder<Rect?>(
              // No target: a hole of no size in the middle, so the first
              // spotlight grows out from where the welcome card was.
              tween: RectTween(
                end: hole ??
                    Rect.fromCenter(
                        center: window.center(Offset.zero),
                        width: 0,
                        height: 0),
              ),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, rect, _) => CustomPaint(
                painter: _ScrimPainter(
                  hole: rect,
                  scrim: Colors.black.withValues(alpha: 0.55),
                  ring: Cmyk.cyan,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _CardLayout(hole: hole),
            child: SizedBox(
              width: 340,
              child: _TourCard(
                key: ValueKey(_index),
                step: _step,
                index: _index,
                count: widget.steps.length,
                last: _last,
                onNext: _next,
                onBack: _index == 0 ? null : _back,
                onSkip: _close,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.index,
    required this.count,
    required this.last,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    super.key,
  });

  final TourStep step;
  final int index;
  final int count;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      // A soft drop shadow rather than Material elevation, which reads as a
      // hard dark frame against the dimmed screen.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: c.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(Radii.lg),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (step.target == null)
                      const SizedBox(
                          width: 64, child: CmykStripe(height: 3, gap: 4))
                    else
                      Text(l.tourStepOf(index + 1, count),
                          style: context.text.labelSmall
                              ?.copyWith(color: c.onSurfaceVariant)),
                    const Spacer(),
                    if (!last)
                      TextButton(
                        onPressed: onSkip,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: c.onSurfaceVariant,
                        ),
                        child: Text(l.tourSkip),
                      ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Text(step.title, style: context.text.titleMedium),
                const SizedBox(height: 6),
                Text(step.body,
                    style: context.text.bodyMedium
                        ?.copyWith(color: c.onSurfaceVariant, height: 1.45)),
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    _Dots(index: index, count: count),
                    const Spacer(),
                    if (onBack != null)
                      TextButton(onPressed: onBack, child: Text(l.tourBack)),
                    const SizedBox(width: Space.xs),
                    FilledButton(
                      onPressed: onNext,
                      child: Text(last ? l.tourDone : l.tourNext),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsetsDirectional.only(end: 4),
            width: i == index ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == index ? Cmyk.all[i % 4] : c.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Darkens everything except the target, and rings it.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.hole, required this.scrim, required this.ring});

  final Rect? hole;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    if (hole == null || hole!.isEmpty) {
      canvas.drawPath(screen, Paint()..color = scrim);
      return;
    }
    final cutout = RRect.fromRectAndRadius(hole!, const Radius.circular(10));
    canvas.drawPath(
      Path.combine(PathOperation.difference, screen, Path()..addRRect(cutout)),
      Paint()..color = scrim,
    );
    canvas.drawRRect(
      cutout,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.scrim != scrim || old.ring != ring;
}

/// Puts the card next to the target: beside it when the target hugs the left
/// or right edge (the sidebar, in either language, or a header button), below
/// or above it otherwise, and in the middle when there is no target.
class _CardLayout extends SingleChildLayoutDelegate {
  _CardLayout({required this.hole});

  final Rect? hole;

  static const _gap = 14.0;
  static const _margin = 16.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size card) {
    final h = hole;
    if (h == null) {
      return Offset(
          (size.width - card.width) / 2, (size.height - card.height) / 2);
    }

    double clampX(double x) =>
        x.clamp(_margin, size.width - card.width - _margin);
    double clampY(double y) =>
        y.clamp(_margin, size.height - card.height - _margin);

    final nearLeft = h.center.dx < size.width * 0.25;
    final nearRight = h.center.dx > size.width * 0.75;
    final fitsRight = h.right + _gap + card.width + _margin <= size.width;
    final fitsLeft = h.left - _gap - card.width >= _margin;

    if (nearLeft && fitsRight) {
      return Offset(h.right + _gap, clampY(h.center.dy - card.height / 2));
    }
    if (nearRight && fitsLeft) {
      return Offset(
          h.left - _gap - card.width, clampY(h.center.dy - card.height / 2));
    }
    if (h.bottom + _gap + card.height + _margin <= size.height) {
      return Offset(clampX(h.center.dx - card.width / 2), h.bottom + _gap);
    }
    return Offset(clampX(h.center.dx - card.width / 2),
        clampY(h.top - _gap - card.height));
  }

  @override
  bool shouldRelayout(_CardLayout old) => old.hole != hole;
}
