import 'package:flutter/material.dart';
import '../l10n/l10n_extensions.dart';
import '../services/language_service.dart';

class LanguageSettingsScreen extends StatelessWidget {
  final LanguageService languageService;

  const LanguageSettingsScreen({super.key, required this.languageService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.languageScreenTitle),
      ),
      body: ValueListenableBuilder<Locale?>(
        valueListenable: languageService.localeNotifier,
        builder: (context, currentLocale, _) {
          return ListView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
            children: [
              _LanguageOptionTile(
                label: context.l10n.languageSystemDefault,
                isSelected: currentLocale == null,
                onTap: () => languageService.setLocale(null),
              ),
              _LanguageOptionTile(
                label: context.l10n.languageEnglish,
                isSelected: currentLocale?.languageCode == 'en',
                onTap: () => languageService.setLocale(const Locale('en')),
              ),
              _LanguageOptionTile(
                label: context.l10n.languageChinese,
                isSelected: currentLocale?.languageCode == 'zh',
                onTap: () => languageService.setLocale(const Locale('zh')),
              ),
              _LanguageOptionTile(
                label: context.l10n.languageFrench,
                isSelected: currentLocale?.languageCode == 'fr',
                onTap: () => languageService.setLocale(const Locale('fr')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
