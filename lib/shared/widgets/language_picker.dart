import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../services/locale_controller.dart';

/// Language name shown *in that language itself* (e.g. "English", "日本語")
/// rather than translated into the current UI language -- the universal
/// convention for language-name pickers (this is how iOS/Android/every
/// major app's own language picker works).
String localeEndonym(Locale locale) {
  switch (locale.languageCode) {
    case 'ja':
      return '日本語';
    case 'en':
      return 'English';
    default:
      return locale.languageCode;
  }
}

/// Wraps the picked value so `null` (pick "follow device setting") can be
/// told apart from `null` meaning "dialog dismissed without choosing"
/// (Navigator.pop()'s default when there's no explicit result).
class _LanguageChoice {
  const _LanguageChoice(this.locale);
  final Locale? locale;
}

/// Opens the language-picker dialog (PM request: available from both the
/// sign-in screen and the settings screen, defaulting to following the
/// device's own language setting). Does nothing if the user dismisses the
/// dialog without picking an option.
Future<void> showLanguagePicker(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = context.read<LocaleController>();
  final current = controller.locale;

  final choice = await showDialog<_LanguageChoice>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(l10n.languagePickerTitle),
      children: [
        RadioGroup<Locale?>(
          groupValue: current,
          onChanged: (value) =>
              Navigator.of(dialogContext).pop(_LanguageChoice(value)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<Locale?>(
                title: Text(l10n.languageMenuSubtitleSystem),
                value: null,
              ),
              for (final locale in AppLocalizations.supportedLocales)
                RadioListTile<Locale?>(
                  title: Text(localeEndonym(locale)),
                  value: locale,
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (choice != null) {
    await controller.setLocale(choice.locale);
  }
}

/// Compact icon-button entry point for screens without room for a full
/// settings-style menu item (e.g. the sign-in screen's app bar).
class LanguageIconButton extends StatelessWidget {
  const LanguageIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.language),
      tooltip: AppLocalizations.of(context)!.languageMenuTitle,
      onPressed: () => showLanguagePicker(context),
    );
  }
}
