import 'package:flutter/material.dart';
import 'package:inmore_core/inmore_core.dart';

/// The brand's four process inks, straight from the logo's stripe.
///
/// These are for brand moments — the stripe, the loading bar, the splash.
/// They are too bright to carry text on white, so anything a person has to
/// read uses the darker tones in [InmoreTokens] instead.
abstract final class Cmyk {
  static const cyan = Color(0xFF009FE3);
  static const magenta = Color(0xFFE6007E);
  static const yellow = Color(0xFFF6E000);
  static const key = Color(0xFF1D1D1B);

  static const all = [cyan, magenta, yellow, key];
}

/// Neutral ink and paper — the ground everything else sits on.
abstract final class Ground {
  static const ink = Color(0xFF1D1D1B);
  static const night = Color(0xFF121315);
  static const paper = Color(0xFFF6F6F4);
}

/// Colours with a meaning, tuned per brightness so text on them stays legible.
///
/// Material's [ColorScheme] has slots for primary/secondary/error but nothing
/// for "success", "a job in production" or "blocked on payment". Those live
/// here, read through `InmoreTokens.of(context)`.
@immutable
class InmoreTokens extends ThemeExtension<InmoreTokens> {
  const InmoreTokens({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.neutral,
    required this.stageNew,
    required this.stageQuotation,
    required this.stageDesign,
    required this.stageApproval,
    required this.stageProduction,
    required this.stageDelivery,
    required this.cmykKey,
  });

  static const light = InmoreTokens(
    success: Color(0xFF16804F),
    warning: Color(0xFFB4610A),
    danger: Color(0xFFC62828),
    info: Color(0xFF0077B6),
    neutral: Color(0xFF6B6C72),
    stageNew: Color(0xFF55606F),
    stageQuotation: Color(0xFFA67C00),
    stageDesign: Color(0xFFC2006B),
    stageApproval: Color(0xFF6A45D8),
    stageProduction: Color(0xFF0077B6),
    stageDelivery: Color(0xFF00796B),
    cmykKey: Cmyk.key,
  );

  static const dark = InmoreTokens(
    success: Color(0xFF4CCB8B),
    warning: Color(0xFFF5A84B),
    danger: Color(0xFFFF6B6B),
    info: Color(0xFF4CC3F5),
    neutral: Color(0xFF9C9DA3),
    stageNew: Color(0xFFA3AEBD),
    stageQuotation: Color(0xFFF2CB4C),
    stageDesign: Color(0xFFFF5CAD),
    stageApproval: Color(0xFFA98BFF),
    stageProduction: Color(0xFF4CC3F5),
    stageDelivery: Color(0xFF4DD0C1),
    // The key ink vanishes on a dark ground; a lifted grey keeps four bars.
    cmykKey: Color(0xFF55565C),
  );

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color neutral;
  final Color stageNew;
  final Color stageQuotation;
  final Color stageDesign;
  final Color stageApproval;
  final Color stageProduction;
  final Color stageDelivery;
  final Color cmykKey;

  static InmoreTokens of(BuildContext context) =>
      Theme.of(context).extension<InmoreTokens>() ?? light;

  List<Color> get cmyk => [Cmyk.cyan, Cmyk.magenta, Cmyk.yellow, cmykKey];

  /// One colour per pipeline stage, in pipeline order, so the stepper reads
  /// as a progression rather than a random set.
  Color stage(RequestStatus s) => switch (s) {
        RequestStatus.isNew => stageNew,
        RequestStatus.quotation => stageQuotation,
        RequestStatus.design => stageDesign,
        RequestStatus.customerApproval => stageApproval,
        RequestStatus.production => stageProduction,
        RequestStatus.delivery => stageDelivery,
        RequestStatus.completed => success,
        RequestStatus.cancelled => neutral,
      };

  Color task(TaskStatus s) => switch (s) {
        TaskStatus.todo => neutral,
        TaskStatus.inProgress => info,
        TaskStatus.blocked => danger,
        TaskStatus.done => success,
        TaskStatus.cancelled => neutral,
      };

  Color item(ItemStatus s) => switch (s) {
        ItemStatus.pending => neutral,
        ItemStatus.approved => success,
        ItemStatus.rejected => danger,
        ItemStatus.cancelled => neutral,
      };

  Color quotation(QuotationStatus s) => switch (s) {
        QuotationStatus.draft => neutral,
        QuotationStatus.presented => warning,
        QuotationStatus.approved => success,
        QuotationStatus.rejected => danger,
        QuotationStatus.superseded => neutral,
      };

  @override
  InmoreTokens copyWith() => this;

  @override
  InmoreTokens lerp(InmoreTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return InmoreTokens(
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      info: l(info, other.info),
      neutral: l(neutral, other.neutral),
      stageNew: l(stageNew, other.stageNew),
      stageQuotation: l(stageQuotation, other.stageQuotation),
      stageDesign: l(stageDesign, other.stageDesign),
      stageApproval: l(stageApproval, other.stageApproval),
      stageProduction: l(stageProduction, other.stageProduction),
      stageDelivery: l(stageDelivery, other.stageDelivery),
      cmykKey: l(cmykKey, other.cmykKey),
    );
  }
}

/// Spacing and radii, so both apps share one rhythm.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class Radii {
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 20.0;
}

extension InmoreThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  InmoreTokens get tokens => InmoreTokens.of(this);
}
