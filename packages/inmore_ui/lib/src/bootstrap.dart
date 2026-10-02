import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

/// The parts of `main()` both apps share.
///
/// Loads the date names for both languages before the first frame (the
/// formatter is used outside widgets too), and routes uncaught errors to the
/// log rather than letting a release build show a grey box.
Future<void> bootstrapUi() async {
  await initializeDateFormatting('en');
  await initializeDateFormatting('ar');

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    return true;
  };

  if (kReleaseMode) {
    // A build error in one widget should not grey out the whole screen.
    ErrorWidget.builder = (details) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        );
  }
}
