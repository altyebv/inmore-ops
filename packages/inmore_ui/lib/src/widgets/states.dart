import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

import '../feedback/app_error.dart';
import '../l10n/labels.dart';
import '../theme/tokens.dart';
import 'brand.dart';
import 'skeleton.dart';

/// Nothing here yet — and what to do about it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.compact = false,
    this.tone,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  /// Inside a panel rather than filling a page.
  final bool compact;

  /// Tints the icon — success green for "nothing is stuck".
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = tone ?? c.onSurfaceVariant;
    final size = compact ? 40.0 : 64.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? Space.lg : Space.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: (tone ?? c.onSurfaceVariant).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: size * 0.5, color: accent),
              ),
              SizedBox(height: compact ? Space.md : Space.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact
                    ? context.text.titleSmall
                    : context.text.titleMedium,
              ),
              if (body != null) ...[
                const SizedBox(height: Space.xs),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: Space.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A failed load, explained, with the way out.
class ErrorState extends ConsumerWidget {
  const ErrorState({
    required this.error,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final e = AppError.from(error);
    final c = context.colors;
    final accent = switch (e.kind) {
      ErrorKind.offline || ErrorKind.timeout => c.onSurfaceVariant,
      _ => c.error,
    };

    final actions = <Widget>[
      if (e.kind == ErrorKind.session)
        FilledButton(
          onPressed: () => ref.read(sessionRepositoryProvider).signOut(),
          child: Text(l.signIn),
        )
      else if (onRetry != null)
        FilledButton.tonalIcon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(l.retry),
        ),
      if (e.kind == ErrorKind.unknown) _CopyDetails(details: e.details),
    ];

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(e.icon, size: 18, color: accent),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title(l), style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(e.message(l), style: context.text.bodySmall),
                ],
              ),
            ),
            if (onRetry != null && e.kind != ErrorKind.session)
              IconButton(
                tooltip: l.retry,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
          ],
        ),
      );
    }

    return EmptyState(
      icon: e.icon,
      tone: accent,
      title: e.title(l),
      body: e.message(l),
      action: actions.isEmpty
          ? null
          : Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              alignment: WrapAlignment.center,
              children: actions,
            ),
    );
  }
}

class _CopyDetails extends StatefulWidget {
  const _CopyDetails({required this.details});

  final String details;

  @override
  State<_CopyDetails> createState() => _CopyDetailsState();
}

class _CopyDetailsState extends State<_CopyDetails> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextButton.icon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: widget.details));
        if (mounted) setState(() => _copied = true);
      },
      icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 16),
      label: Text(_copied ? l.copied : l.copyDetails),
    );
  }
}

/// Renders an async provider through its three states.
///
/// * **First load** — [loading], or placeholder rows. Never a bare spinner.
/// * **Data** — the builder. A background refresh keeps the data on screen
///   with the press bar across the top, so nothing flashes empty.
/// * **Error** — explained, with retry. If a refresh fails while data is
///   already showing, the data stays and a one-line notice sits above it:
///   slightly stale information beats a blank screen.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    required this.value,
    required this.builder,
    this.loading,
    this.onRetry,
    this.compact = false,
    this.showRefreshing = true,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? loading;
  final VoidCallback? onRetry;

  /// Inside a panel: smaller placeholders and a one-line error.
  final bool compact;

  /// Draw the press bar during a background refresh.
  final bool showRefreshing;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      final refreshing = showRefreshing && value.isLoading;
      final staleError = value.hasError && !value.isLoading;
      // Always the same Stack, with the content always first: a refresh
      // starting or ending must not rebuild the subtree, or every live
      // update would throw away the reader's scroll position.
      return Stack(
        fit: StackFit.passthrough,
        children: [
          builder(value.requireValue),
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (refreshing) const CmykProgressBar(height: 2),
                if (staleError)
                  Material(
                    color: context.colors.surfaceContainerLowest,
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                      child: ErrorState(
                        error: value.error!,
                        onRetry: onRetry,
                        compact: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    if (value.hasError) {
      return ErrorState(
          error: value.error!, onRetry: onRetry, compact: compact);
    }
    return loading ??
        (compact
            ? const SkeletonList(rows: 2, dense: true, padding: EdgeInsets.zero)
            : const SkeletonList());
  }
}
