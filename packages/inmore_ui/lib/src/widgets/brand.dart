import 'package:flutter/material.dart';

import '../theme/tokens.dart';

const _package = 'inmore_ui';

/// The "iM" mark on its own — ink on light grounds, white on dark ones.
///
/// [onDark] forces the white version, for the dark brand panels that stay
/// dark in either theme.
class InmoreMark extends StatelessWidget {
  const InmoreMark({this.height = 32, this.onDark, super.key});

  final double height;
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final white = onDark ?? context.theme.brightness == Brightness.dark;
    return Image.asset(
      white ? 'assets/brand/mark_white.png' : 'assets/brand/mark_ink.png',
      package: _package,
      height: height,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Inmore',
    );
  }
}

/// The full logo: the mark with the CMYK stripe beneath it.
class InmoreLogo extends StatelessWidget {
  const InmoreLogo({this.height = 96, this.onDark, super.key});

  final double height;
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final white = onDark ?? context.theme.brightness == Brightness.dark;
    return Image.asset(
      white ? 'assets/brand/logo_white.png' : 'assets/brand/logo_ink.png',
      package: _package,
      height: height,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Inmore',
    );
  }
}

/// Four rounded bars in process order — the logo's signature, used as a
/// divider on brand surfaces.
class CmykStripe extends StatelessWidget {
  const CmykStripe({
    this.height = 4,
    this.gap = 6,
    this.width,
    this.onDark = false,
    super.key,
  });

  final double height;
  final double gap;
  final double? width;

  /// On a ground that is dark whatever the theme, lift the key ink so all
  /// four bars show.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colours = onDark ? InmoreTokens.dark.cmyk : context.tokens.cmyk;
    return SizedBox(
      width: width,
      height: height,
      // Stretch: the bars have no child, so without it they are 0px tall.
      child: Row(
        // The logo's order, C-M-Y-K, in either language.
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < colours.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colours[i],
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// An indeterminate progress bar in the four inks.
///
/// Four short bars chase each other across the track, the way sheets move
/// through a four-colour press. Used wherever something is loading in the
/// background over content that is already visible.
class CmykProgressBar extends StatefulWidget {
  const CmykProgressBar({this.height = 3, super.key});

  final double height;

  @override
  State<CmykProgressBar> createState() => _CmykProgressBarState();
}

class _CmykProgressBarState extends State<CmykProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _CmykPainter(
            animation: _controller,
            colours: context.tokens.cmyk,
            rtl: Directionality.of(context) == TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

class _CmykPainter extends CustomPainter {
  _CmykPainter({
    required this.animation,
    required this.colours,
    required this.rtl,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Color> colours;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final segment = size.width * 0.14;
    final spacing = segment * 0.35;
    final train = colours.length * segment + (colours.length - 1) * spacing;
    final travel = size.width + train;
    final t = Curves.easeInOutSine.transform(animation.value);
    final head = -train + travel * t;
    final radius = Radius.circular(size.height);

    for (var i = 0; i < colours.length; i++) {
      // Cyan leads, key trails.
      var left = head + (colours.length - 1 - i) * (segment + spacing);
      if (rtl) left = size.width - left - segment;
      final rect = Rect.fromLTWH(left, 0, segment, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = colours[i],
      );
    }
  }

  @override
  bool shouldRepaint(_CmykPainter old) =>
      old.colours != colours || old.rtl != rtl;
}

/// The first thing on screen while the session is being restored: the mark
/// and the press bar, centred on the brand ground.
class BrandLoader extends StatelessWidget {
  const BrandLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InmoreMark(height: 56),
            SizedBox(height: Space.xl),
            SizedBox(width: 120, child: CmykProgressBar()),
          ],
        ),
      ),
    );
  }
}

/// The opening moment: the mark on the brand ground, the stripe printed in
/// beneath it one ink at a time — cyan, magenta, yellow, key — then the app
/// fades up through it. About 1.2s, once per launch.
///
/// It sits over [child] rather than in front of it, so the app is already
/// restoring the session and loading data underneath; the intro adds no wait
/// of its own beyond the animation. Skipped when the system asks for reduced
/// motion. Put it in `MaterialApp.builder`, around the navigator.
///
/// On Android 12+ the native splash shows the mark alone at this same size and
/// place, so the hand-off is seamless and the stripe looks like it is printed
/// onto the splash. The default [markHeight] matches that splash: the icon is
/// drawn at 288dp and the mark fills 376/960 of `splash_android12_*.png`.
/// Change the two together.
class LaunchIntro extends StatefulWidget {
  const LaunchIntro({
    required this.child,
    this.markHeight = 112,
    this.fadeInMark = false,
    super.key,
  });

  final Widget child;
  final double markHeight;

  /// Fade the mark in as well. For the desktop, which has no native splash
  /// already showing it.
  final bool fadeInMark;

  @override
  State<LaunchIntro> createState() => _LaunchIntroState();
}

class _LaunchIntroState extends State<LaunchIntro>
    with SingleTickerProviderStateMixin {
  // The timeline, in milliseconds.
  static const _total = 1250;
  static const _markIn = 250;
  static const _firstBar = 180;
  static const _barStagger = 90;
  static const _barGrow = 380;
  static const _fadeOutFrom = 950;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  );

  late final Animation<double> _mark = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, _markIn / _total, curve: Curves.easeOut),
  );

  late final Animation<double> _overlay = ReverseAnimation(CurvedAnimation(
    parent: _controller,
    curve: const Interval(_fadeOutFrom / _total, 1, curve: Curves.easeInOut),
  ));

  // easeOutBack overshoots by ~10% and settles: each bar lands with a small
  // bounce, like a roller laying the ink down.
  late final List<Animation<double>> _bars = [
    for (var i = 0; i < 4; i++)
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          (_firstBar + i * _barStagger) / _total,
          (_firstBar + i * _barStagger + _barGrow) / _total,
          curve: Curves.easeOutBack,
        ),
      ),
  ];

  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_done || _controller.isAnimating) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _done = true;
      return;
    }
    _controller.forward().whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always a Stack with the app first: switching to `widget.child` alone
    // when done would rebuild the navigator and lose where the person is.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_done)
          Positioned.fill(
            child: AbsorbPointer(
              child: FadeTransition(
                opacity: _overlay,
                child: _IntroFrame(
                  markHeight: widget.markHeight,
                  mark: widget.fadeInMark ? _mark : kAlwaysCompleteAnimation,
                  bars: _bars,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IntroFrame extends StatelessWidget {
  const _IntroFrame({
    required this.markHeight,
    required this.mark,
    required this.bars,
  });

  final double markHeight;
  final Animation<double> mark;
  final List<Animation<double>> bars;

  @override
  Widget build(BuildContext context) {
    // The logo's own proportions: the stripe spans the mark's width, sits 8%
    // of the mark's height below it and is 3.5% of it tall.
    final markWidth = markHeight * 480 / 410;
    final stripeHeight = (markHeight * 0.035).clamp(3.0, 8.0);
    final colours = context.tokens.cmyk;

    return ColoredBox(
      color: context.theme.colorScheme.surface,
      child: Center(
        // Sized to the mark alone, so the mark sits exactly where the native
        // splash left it and the stripe hangs below without moving it.
        child: SizedBox(
          width: markWidth,
          height: markHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              FadeTransition(
                opacity: mark,
                child: InmoreMark(height: markHeight),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: markHeight * 1.08,
                height: stripeHeight,
                child: Row(
                  textDirection: TextDirection.ltr,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < colours.length; i++) ...[
                      if (i > 0) SizedBox(width: markWidth * 0.06),
                      Expanded(
                        child: _PrintedBar(
                          progress: bars[i],
                          colour: colours[i],
                          radius: stripeHeight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One bar of the stripe growing from its left end. Width rather than a
/// scale transform, so the rounded ends stay round while it grows.
class _PrintedBar extends AnimatedWidget {
  const _PrintedBar({
    required Animation<double> progress,
    required this.colour,
    required this.radius,
  }) : super(listenable: progress);

  final Color colour;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    if (t <= 0) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: t,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
