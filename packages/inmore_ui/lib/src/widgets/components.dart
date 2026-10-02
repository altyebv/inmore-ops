import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../theme/tokens.dart';

/// A small tinted label: a stage, a status, a warning.
///
/// The tint is the colour at low strength; the text is the colour pushed
/// towards the ink, so a yellow "Quotation" badge is still readable on white.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label,
      {this.color, this.icon, this.dot = false, super.key});

  final String label;
  final Color? color;
  final IconData? icon;

  /// A leading dot instead of an icon — for stages, where colour is the
  /// message and an icon would be noise.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = color ?? c.onSurfaceVariant;
    final dark = context.theme.brightness == Brightness.dark;
    final fg = dark
        ? Color.lerp(base, Colors.white, 0.12)!
        : Color.lerp(base, Colors.black, 0.25)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: base.withValues(alpha: dark ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: base, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled card: heading, optional subtitle, actions at the end, body.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(Space.lg, 4, Space.lg, Space.lg),
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                Space.lg, Space.md, Space.sm, Space.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon,
                        size: 18, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: Space.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: context.text.titleSmall),
                        if (subtitle != null)
                          Text(subtitle!, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A small caps heading between groups in a list.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {this.trailing, this.color, super.key});

  final String text;
  final String? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelMedium?.copyWith(
      color: color ?? context.colors.onSurfaceVariant,
      letterSpacing: 0.4,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, Space.xl, 4, Space.sm),
      child: Row(
        children: [
          Expanded(child: Text(text, style: style)),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: (color ?? context.colors.onSurfaceVariant)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(trailing!, style: style),
            ),
        ],
      ),
    );
  }
}

/// The top of a desktop page: title, a line of context, and its actions.
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.bottom,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(28, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: Space.sm)
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.headlineSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          )),
                    ],
                  ],
                ),
              ),
              for (final a in actions) ...[const SizedBox(width: Space.sm), a],
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: Space.lg), bottom!],
          const SizedBox(height: Space.lg),
        ],
      ),
    );
  }
}

/// A big number with a label, for dashboards.
class FigureTile extends StatelessWidget {
  const FigureTile({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
    super.key,
  });

  final String value;
  final String label;
  final IconData? icon;

  /// Paints the number and icon — red for "3 overdue", default otherwise.
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.colors.onSurfaceVariant;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(height: Space.md),
              ],
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: context.text.headlineSmall?.copyWith(
                    color: color ?? context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: context.text.bodySmall, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Initials in a tinted circle, coloured consistently per name.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {this.size = 32, super.key});

  final String name;
  final double size;

  static const _hues = [200.0, 330.0, 50.0, 265.0, 170.0, 15.0, 290.0, 140.0];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((p) => p.characters.first).join().toUpperCase();
    final hue = _hues[trimmed.hashCode.abs() % _hues.length];
    final dark = context.theme.brightness == Brightness.dark;
    final bg = HSLColor.fromAHSL(1, hue, 0.55, dark ? 0.28 : 0.9).toColor();
    final fg = HSLColor.fromAHSL(1, hue, 0.6, dark ? 0.85 : 0.3).toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        initials,
        style: context.text.labelMedium?.copyWith(
          color: fg,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A label above a value, for fact grids.
class Fact extends StatelessWidget {
  const Fact({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            )),
        const SizedBox(height: 4),
        DefaultTextStyle.merge(style: context.text.bodyMedium, child: child),
      ],
    );
  }
}

/// The text direction a string reads in, from its first strong character.
///
/// Flutter lays a field out in the app's direction, so an Arabic customer
/// name typed into the English UI would start at the left edge and look
/// broken while being typed. Fields and free text use this to follow their
/// content instead.
TextDirection? directionOf(String text) {
  if (text.trim().isEmpty) return null;
  return intl.Bidi.detectRtlDirectionality(text)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

/// A text field whose direction follows what is typed into it.
class AppField extends StatefulWidget {
  const AppField({
    required this.controller,
    this.label,
    this.hint,
    this.helper,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.fixedDirection,
    this.autofillHints,
    super.key,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffix;

  /// For emails, numbers and passwords, which are always left-to-right.
  final TextDirection? fixedDirection;
  final Iterable<String>? autofillHints;

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  TextDirection? _direction;

  @override
  void initState() {
    super.initState();
    _direction = directionOf(widget.controller.text);
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(AppField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    final d = directionOf(widget.controller.text);
    if (d != _direction) setState(() => _direction = d);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textDirection: widget.fixedDirection ?? _direction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        helperMaxLines: 2,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, size: 18),
        prefixText: widget.prefixText,
        suffixIcon: widget.suffix,
      ),
    );
  }
}

/// Text that reads in its own direction — for names and notes people typed,
/// which may be Arabic inside an English screen or the other way round.
class UserText extends StatelessWidget {
  const UserText(this.text,
      {this.style, this.maxLines, this.overflow, super.key});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final own = directionOf(text);
    final ambient = Directionality.of(context);
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: own,
      // Keep it on the screen's reading edge even when its own direction
      // differs, so a column of mixed names stays aligned.
      textAlign: own == null || own == ambient
          ? TextAlign.start
          : (ambient == TextDirection.rtl ? TextAlign.right : TextAlign.left),
    );
  }
}
