import 'package:flutter/material.dart';
import '../models/i18n.dart';
import '../widgets/panel.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onClearData,
    this.message,
  });

  final String language;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onClearData;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final systemPanel = ConfigSection(
      title: I18n.t('panel_system_settings'),
      icon: Icons.settings_outlined,
      action: const SizedBox.shrink(),
      children: [
        DropdownButtonFormField<String>(
          initialValue: language,
          decoration: InputDecoration(
            labelText: I18n.t('lbl_system_language'),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'zh', child: Text('简体中文 (Chinese)')),
            DropdownMenuItem(value: 'zh_tw', child: Text('繁體中文 (Chinese Traditional)')),
            DropdownMenuItem(value: 'en', child: Text('English (US)')),
            DropdownMenuItem(value: 'ja', child: Text('日本語 (Japanese)')),
            DropdownMenuItem(value: 'ko', child: Text('한국어 (Korean)')),
            DropdownMenuItem(value: 'es', child: Text('Español (Spanish)')),
            DropdownMenuItem(value: 'de', child: Text('Deutsch (German)')),
            DropdownMenuItem(value: 'fr', child: Text('Français (French)')),
            DropdownMenuItem(value: 'pt', child: Text('Português (Portuguese)')),
            DropdownMenuItem(value: 'ru', child: Text('Русский (Russian)')),
          ],
          onChanged: (val) {
            if (val != null) {
              onLanguageChanged(val);
            }
          },
        ),
      ],
    );
    final dangerZonePanel = ConfigSection(
      title: I18n.t('panel_danger_zone'),
      icon: Icons.warning_amber_outlined,
      action: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: onClearData,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(I18n.t('btn_clear_all_data')),
          ),
        ],
      ),
      children: [
        Text(
          I18n.t('danger_zone_desc'),
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
    );

    return PageShell(
      title: I18n.t('title_settings'),
      subtitle: I18n.t('subtitle_settings'),
      footer: message == null
          ? null
          : Text(
              message!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          systemPanel,
          const SizedBox(height: 12),
          dangerZonePanel,
        ],
      ),
    );
  }
}
