import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/labels.dart';
import '../theme/tokens.dart';
import 'app_error.dart';

/// Tell the person a write was refused, in words they can act on.
void showError(BuildContext context, Object error) {
  final l = context.l10n;
  final e = AppError.from(error);
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(e.icon, size: 18, color: context.colors.onInverseSurface),
          const SizedBox(width: Space.md),
          Expanded(child: Text(e.short(l))),
        ],
      ),
      width: _snackWidth(context),
      duration: const Duration(seconds: 5),
      action: e.kind == ErrorKind.unknown
          ? SnackBarAction(
              label: l.copyDetails,
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: e.details)),
            )
          : null,
    ));
}

/// A quiet confirmation that something saved.
void showDone(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 18, color: context.colors.onInverseSurface),
          const SizedBox(width: Space.md),
          Expanded(child: Text(message)),
        ],
      ),
      width: _snackWidth(context),
      duration: const Duration(seconds: 2),
    ));
}

/// Floating snackbars sit centred and narrow on a wide desktop window, and
/// full-width on a phone.
double? _snackWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width > 700 ? 480 : null;

/// Run a mutation, show an error if it is refused, and report success.
///
/// Repositories already turn a silently-filtered RLS write into a
/// PermissionDeniedException, so there is no "it said saved but nothing
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

/// Ask before something that cannot be taken back.
///
/// [destructive] paints the confirm button in the error colour — for
/// cancelling a request, not for approving a price.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final c = context.colors;
      return AlertDialog(
        icon: icon == null
            ? null
            : Icon(icon, color: destructive ? c.error : c.onSurfaceVariant),
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(body, style: context.text.bodyMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel ?? context.l10n.cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: c.error,
                    foregroundColor: c.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
