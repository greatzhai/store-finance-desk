import 'package:flutter/material.dart';
import '../models/i18n.dart';
import '../widgets/panel.dart';

class MappingsPage extends StatelessWidget {
  const MappingsPage({
    super.key,
    required this.appMappingsController,
    required this.message,
    required this.onSave,
    required this.unmappedApps,
    required this.onPopulateTemplate,
  });

  final TextEditingController appMappingsController;
  final String? message;
  final VoidCallback onSave;
  final Map<String, List<String>> unmappedApps;
  final VoidCallback onPopulateTemplate;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: I18n.t('title_mappings'),
      subtitle: I18n.t('subtitle_mappings'),
      footer: message == null
          ? null
          : Text(
              message!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          
          final leftPanel = ConfigSection(
            title: I18n.t('panel_mappings_settings'),
            icon: Icons.apps_outlined,
            action: ConfigActions(
              onSave: onSave,
              saveLabel: I18n.t('btn_save'),
            ),
            children: [
              ConfigTextField(
                controller: appMappingsController,
                label: I18n.t('lbl_mappings_rule'),
                maxLines: wide ? 14 : 8,
              ),
            ],
          );

          final guidePanel = Panel(
            title: I18n.t('mappings_guide_title'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 1; i <= 5; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.help_center_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            I18n.t('mappings_guide_item_$i'),
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );

          if (wide) {
            Widget rightPanel;
            if (unmappedApps.isNotEmpty) {
              rightPanel = Panel(
                title: I18n.t('tip_unmapped_apps'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in unmappedApps.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '• ${I18n.t('lbl_raw_id')}：${entry.key} \n  (${I18n.t('lbl_related_skus')}: ${entry.value.join(", ")})',
                          style: const TextStyle(fontSize: 12, color: Color(0xff4a544f)),
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onPopulateTemplate,
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: Text(I18n.t('btn_populate_template')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              rightPanel = Panel(
                title: I18n.t('tip_unmapped_apps_empty'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        I18n.t('tip_unmapped_apps_empty_desc'),
                        style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xff4a544f)),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: leftPanel),
                      const SizedBox(width: 12),
                      Expanded(child: rightPanel),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                guidePanel,
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftPanel,
                if (unmappedApps.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Panel(
                    title: I18n.t('tip_unmapped_apps'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in unmappedApps.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '• ${I18n.t('lbl_raw_id')}：${entry.key} \n  (${I18n.t('lbl_related_skus')}: ${entry.value.join(", ")})',
                              style: const TextStyle(fontSize: 12, color: Color(0xff4a544f)),
                            ),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: onPopulateTemplate,
                          icon: const Icon(Icons.auto_awesome, size: 14),
                          label: Text(I18n.t('btn_populate_template')),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                guidePanel,
              ],
            );
          }
        },
      ),
    );
  }
}
