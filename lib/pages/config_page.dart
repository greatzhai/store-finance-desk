import 'package:flutter/material.dart';
import '../models/i18n.dart';
import '../widgets/panel.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({
    super.key,
    required this.appleIssuerController,
    required this.appleKeyController,
    required this.appleVendorController,
    required this.applePrivateKeyController,
    required this.googleBucketController,
    required this.googleServiceAccountController,
    required this.message,
    required this.onSave,
    required this.isTestingApple,
    required this.isTestingGoogle,
    required this.onTestApple,
    required this.onTestGoogle,
  });

  final TextEditingController appleIssuerController;
  final TextEditingController appleKeyController;
  final TextEditingController appleVendorController;
  final TextEditingController applePrivateKeyController;
  final TextEditingController googleBucketController;
  final TextEditingController googleServiceAccountController;
  final String? message;
  final VoidCallback onSave;
  final bool isTestingApple;
  final bool isTestingGoogle;
  final VoidCallback onTestApple;
  final VoidCallback onTestGoogle;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: I18n.t('title_config'),
      subtitle: I18n.t('subtitle_config'),
      footer: message == null
          ? null
          : Text(
              message!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final applePanel = ConfigSection(
            title: I18n.t('panel_apple_connect'),
            icon: Icons.apple,
            action: ConfigActions(
              onSave: onSave,
              saveLabel: I18n.t('btn_save_config'),
              onTest: onTestApple,
              testLabel: isTestingApple ? I18n.t('btn_testing_config') : I18n.t('btn_test_config'),
              isTesting: isTestingApple,
            ),
            children: [
              ConfigTextField(
                controller: appleIssuerController,
                label: 'Issuer ID',
              ),
              ConfigTextField(controller: appleKeyController, label: 'Key ID'),
              ConfigTextField(
                controller: appleVendorController,
                label: 'Vendor Number',
              ),
              ConfigTextField(
                controller: applePrivateKeyController,
                label: I18n.t('lbl_apple_private_key'),
              ),
              Checklist(
                title: I18n.t('apple_checklist_title'),
                items: [
                  I18n.t('apple_checklist_item_1'),
                  I18n.t('apple_checklist_item_2'),
                  I18n.t('apple_checklist_item_3'),
                  I18n.t('apple_checklist_item_4'),
                ],
              ),
            ],
          );
          final googlePanel = ConfigSection(
            title: I18n.t('panel_google_connect'),
            icon: Icons.cloud_outlined,
            action: ConfigActions(
              onSave: onSave,
              saveLabel: I18n.t('btn_save_config'),
              onTest: onTestGoogle,
              testLabel: isTestingGoogle ? I18n.t('btn_testing_config') : I18n.t('btn_test_config'),
              isTesting: isTestingGoogle,
            ),
            children: [
              ConfigTextField(
                controller: googleBucketController,
                label: I18n.t('lbl_google_bucket'),
              ),
              ConfigTextField(
                controller: googleServiceAccountController,
                label: I18n.t('lbl_google_service_account'),
              ),
              Checklist(
                title: I18n.t('checklist_title'),
                items: [
                  I18n.t('checklist_item_1'),
                  I18n.t('checklist_item_2'),
                  I18n.t('checklist_item_3'),
                  I18n.t('checklist_item_4'),
                ],
              ),
            ],
          );
          return wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: applePanel),
                      const SizedBox(width: 12),
                      Expanded(child: googlePanel),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    applePanel,
                    const SizedBox(height: 12),
                    googlePanel,
                  ],
                );
        },
      ),
    );
  }
}
