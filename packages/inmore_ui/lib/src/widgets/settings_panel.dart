import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/labels.dart';
import '../settings/settings.dart';
import '../theme/tokens.dart';

/// Appearance and language, as two segmented choices.
///
/// Both apps show this — the desktop in a dialog, the phone in a sheet.
/// Changes apply immediately; there is no Save.
class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final current = Localizations.localeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.appearance, style: context.text.titleSmall),
        const SizedBox(height: Space.sm),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: ThemeMode.system,
              icon: const Icon(Icons.brightness_auto_outlined, size: 18),
              label: Text(l.themeSystem),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: const Icon(Icons.light_mode_outlined, size: 18),
              label: Text(l.themeLight),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: const Icon(Icons.dark_mode_outlined, size: 18),
              label: Text(l.themeDark),
            ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (s) => controller.setThemeMode(s.first),
        ),
        const SizedBox(height: Space.xl),
        Text(l.language, style: context.text.titleSmall),
        const SizedBox(height: Space.sm),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
            ButtonSegment(value: 'ar', label: Text(l.languageArabic)),
          ],
          selected: {current.languageCode},
          onSelectionChanged: (s) => controller.setLocale(Locale(s.first)),
        ),
      ],
    );
  }
}

/// A one-tap switch to the other language, for screens before sign-in.
///
/// Labelled in the language it switches *to*, so someone who cannot read the
/// current one can still find it.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({this.foreground, super.key});

  final Color? foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: foreground),
      onPressed: () => ref
          .read(settingsProvider.notifier)
          .setLocale(Locale(arabic ? 'en' : 'ar')),
      icon: const Icon(Icons.translate_rounded, size: 18),
      label: Text(arabic ? l.languageEnglish : l.languageArabic),
    );
  }
}
