import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

class AsyncView<T> extends StatelessWidget {
  const AsyncView({required this.value, required this.builder, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => value.when(
        data: builder,
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text('$e', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

/// A big number with a label. The owner's app is counts and lists, not charts —
/// charts come once the underlying data has been trusted for a quarter.
class Figure extends StatelessWidget {
  const Figure({
    required this.value,
    required this.label,
    this.colour,
    this.onTap,
    super.key,
  });

  final String value;
  final String label;
  final Color? colour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colour,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {this.colour, this.icon, super.key});

  final String label;
  final Color? colour;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = colour ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

Color stageColour(RequestStatus s, ColorScheme scheme) => switch (s) {
      RequestStatus.isNew => scheme.primary,
      RequestStatus.quotation => Colors.amber,
      RequestStatus.design => Colors.purple,
      RequestStatus.customerApproval => Colors.orange,
      RequestStatus.production => Colors.blue,
      RequestStatus.delivery => Colors.teal,
      RequestStatus.completed => Colors.green,
      RequestStatus.cancelled => scheme.outline,
    };

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {this.trailing, super.key});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(trailing!, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class Nothing extends StatelessWidget {
  const Nothing(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}
