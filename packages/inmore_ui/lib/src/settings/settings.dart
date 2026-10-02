import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in each app's `main()` with the loaded instance, so reading a
/// setting is synchronous and the first frame is already in the right theme
/// and language — no flash of English before Arabic loads.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

/// The languages the apps are translated into.
const supportedLocales = [Locale('en'), Locale('ar')];

/// How this person wants the app to look and read.
///
/// Stored per device, not per account: the choice is about the person in
/// front of this screen, and it has to apply on the sign-in screen too,
/// before anyone is known.
@immutable
class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.system, this.locale});

  final ThemeMode themeMode;

  /// Null means "follow the device".
  final Locale? locale;

  AppSettings copyWith({ThemeMode? themeMode, Locale? locale}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
      );
}

class SettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'settings.theme';
  static const _localeKey = 'settings.locale';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final theme = switch (_prefs.getString(_themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final code = _prefs.getString(_localeKey);
    return AppSettings(
      themeMode: theme,
      locale: code == null ? null : Locale(code),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _prefs.setString(_localeKey, locale.languageCode);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Which supported language to show for a device locale the user has not
/// overridden. Arabic for any Arabic device, English for everything else.
Locale resolveLocale(Locale? chosen, Locale? device) {
  if (chosen != null) return chosen;
  return device?.languageCode == 'ar' ? const Locale('ar') : const Locale('en');
}

/// Keeps the core formatter in step with the language on screen.
///
/// Called from the app's `MaterialApp.builder`, i.e. inside the resolved
/// [Localizations], so it always matches what the widgets below are reading.
void syncFormatting(Locale locale) => Fmt.locale = locale.languageCode;
