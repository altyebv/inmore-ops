import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inmore_core/inmore_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/gen/l10n.dart';

/// What kind of failure this is, which decides what the person can do about
/// it: wait for the network, ask for permission, sign in again, or report it.
enum ErrorKind {
  offline,
  timeout,
  permission,
  notFound,
  session,
  refused,
  unknown
}

/// An exception, sorted and put into words.
///
/// The database writes its own refusals for humans ("This item is already
/// covered by approved quotation v2"), so for [ErrorKind.refused] the server's
/// message is kept as the detail under a translated title. Everything else
/// gets a translated title and body, with the raw text kept for "Copy details".
class AppError {
  const AppError._(this.kind, this.raw, [this.serverMessage]);

  factory AppError.from(Object error) {
    if (error is AppError) return error;
    if (error is PermissionDeniedException) {
      return AppError._(ErrorKind.permission, error);
    }
    if (error is NotFoundException) {
      return AppError._(ErrorKind.notFound, error);
    }
    if (error is InactiveAccountException) {
      return AppError._(ErrorKind.permission, error);
    }
    if (error is TimeoutException) return AppError._(ErrorKind.timeout, error);
    if (error is http.ClientException || _looksOffline('$error')) {
      return AppError._(ErrorKind.offline, error);
    }
    if (error is AuthException) {
      final code = error.code ?? '';
      if (error.statusCode == '401' ||
          code.contains('session') ||
          code.contains('refresh_token') ||
          code.contains('jwt')) {
        return AppError._(ErrorKind.session, error);
      }
      return AppError._(ErrorKind.refused, error, error.message);
    }
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == 'PGRST301' || code == 'PGRST303' || code.contains('JWT')) {
        return AppError._(ErrorKind.session, error);
      }
      if (code == '42501') {
        return AppError._(ErrorKind.permission, error, error.message);
      }
      if (code == 'PGRST116') return AppError._(ErrorKind.notFound, error);
      // A trigger guard or check constraint, worded for a person.
      return AppError._(ErrorKind.refused, error, error.message);
    }
    if (error is String) return AppError._(ErrorKind.refused, error, error);
    return AppError._(ErrorKind.unknown, error);
  }

  final ErrorKind kind;
  final Object raw;
  final String? serverMessage;

  /// Matched by text rather than `is SocketException`: `dart:io` does not
  /// exist on the web, and the owner app keeps a web build for quick checks.
  static bool _looksOffline(String s) =>
      s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection refused') ||
      s.contains('Connection closed') ||
      s.contains('Network is unreachable') ||
      s.contains('XMLHttpRequest error');

  bool get isRetryable =>
      kind == ErrorKind.offline ||
      kind == ErrorKind.timeout ||
      kind == ErrorKind.unknown;

  IconData get icon => switch (kind) {
        ErrorKind.offline => Icons.wifi_off_rounded,
        ErrorKind.timeout => Icons.hourglass_bottom_rounded,
        ErrorKind.permission => Icons.lock_outline_rounded,
        ErrorKind.notFound => Icons.search_off_rounded,
        ErrorKind.session => Icons.logout_rounded,
        ErrorKind.refused => Icons.block_rounded,
        ErrorKind.unknown => Icons.error_outline_rounded,
      };

  String title(L10n l) => switch (kind) {
        ErrorKind.offline => l.errorOfflineTitle,
        ErrorKind.timeout => l.errorTimeoutTitle,
        ErrorKind.permission => l.errorPermissionTitle,
        ErrorKind.notFound => l.errorNotFoundTitle,
        ErrorKind.session => l.errorSessionTitle,
        ErrorKind.refused => l.errorRefusedTitle,
        ErrorKind.unknown => l.errorUnknownTitle,
      };

  String message(L10n l) => switch (kind) {
        ErrorKind.offline => l.errorOfflineBody,
        ErrorKind.timeout => l.errorTimeoutBody,
        ErrorKind.permission => raw is InactiveAccountException
            ? l.accountInactive
            : l.errorPermissionBody,
        ErrorKind.notFound => l.errorNotFoundBody,
        ErrorKind.session => l.errorSessionBody,
        ErrorKind.refused => serverMessage ?? '$raw',
        ErrorKind.unknown => l.errorUnknownBody,
      };

  /// One line for a snackbar: the most specific thing we can say.
  String short(L10n l) => switch (kind) {
        ErrorKind.refused => serverMessage ?? '$raw',
        ErrorKind.permission ||
        ErrorKind.notFound ||
        ErrorKind.offline ||
        ErrorKind.session =>
          message(l),
        _ => title(l),
      };

  String get details => '$raw';
}
