import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

/// Renders an async provider with a loading and a readable error state.
///
/// The error path matters more than it looks: a denied write surfaces here,
/// and "You do not have permission to record a payment" is far more use than
/// a red Dart exception.
class AsyncView<T> extends StatelessWidget {
  const AsyncView(
      {required this.value, required this.builder, this.loading, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? loading;

  @override
  Widget build(BuildContext context) => value.when(
        data: builder,
        loading: () =>
            loading ??
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline,
                  size: 18, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Expanded(child: Text(describeError(e))),
            ],
          ),
        ),
      );
}

/// Turn an exception into something a supervisor can act on.
String describeError(Object e) {
  if (e is PermissionDeniedException) return e.toString();
  if (e is NotFoundException) return e.toString();
  // Postgres raises our trigger guards and check constraints with a message
  // written for a human; show that rather than the wrapper.
  final s = e.toString();
  final m = RegExp(r'message: ([^,]+)').firstMatch(s);
  return m?.group(1) ?? s;
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(describeError(e)),
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      behavior: SnackBarBehavior.floating,
      width: 520,
    ));
}

void showDone(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      width: 420,
      duration: const Duration(seconds: 2),
    ));
}

/// Run a mutation, show an error if it is refused, and report success.
///
/// Repositories already turn a silently-filtered RLS write into a
/// [PermissionDeniedException], so there is no "it said saved but nothing
/// happened" path here.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) showDone(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {this.color, this.icon, super.key});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.surfaceContainerHighest;
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
          if (icon != null) ...[Icon(icon, size: 12), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

Color statusColour(RequestStatus s, ColorScheme scheme) => switch (s) {
      RequestStatus.isNew => scheme.primary,
      RequestStatus.quotation => Colors.amber,
      RequestStatus.design => Colors.purple,
      RequestStatus.customerApproval => Colors.orange,
      RequestStatus.production => Colors.blue,
      RequestStatus.delivery => Colors.teal,
      RequestStatus.completed => Colors.green,
      RequestStatus.cancelled => scheme.outline,
    };

Color taskColour(TaskStatus s, ColorScheme scheme) => switch (s) {
      TaskStatus.todo => scheme.outline,
      TaskStatus.inProgress => Colors.blue,
      TaskStatus.blocked => Colors.red,
      TaskStatus.done => Colors.green,
      TaskStatus.cancelled => scheme.outline,
    };

Color quotationColour(QuotationStatus s, ColorScheme scheme) => switch (s) {
      QuotationStatus.draft => scheme.outline,
      QuotationStatus.presented => Colors.amber,
      QuotationStatus.approved => Colors.green,
      QuotationStatus.rejected => Colors.red,
      QuotationStatus.superseded => scheme.outline,
    };

/// A titled panel on the request detail screen.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.actions = const [],
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Text(subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
                const Spacer(),
                ...actions,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}
