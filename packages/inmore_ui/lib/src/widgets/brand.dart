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
