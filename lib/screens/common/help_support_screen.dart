import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/phone_auth.dart';
import '../../providers/platform_settings_provider.dart';

class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = <(String, String)>[
    (
      'How do I track my order?',
      'Open the Orders tab and select the order. The status updates as the '
          'store confirms, prepares and dispatches it.',
    ),
    (
      'When am I charged?',
      'Cash on delivery is collected by the delivery partner. UPI payments '
          'are collected by the store at checkout.',
    ),
    (
      'How do I cancel an order?',
      'Orders can be cancelled until the store marks them as preparing. '
          'After that, contact the store directly using the number on the '
          'order.',
    ),
    (
      'My delivery address is wrong',
      'Addresses are captured from the map pin at checkout. Place the pin '
          'accurately, and add landmark details in the delivery notes.',
    ),
    (
      'I am a store owner and cannot sign in',
      'Store manager and delivery partner accounts need admin approval '
          'before the first sign-in. Contact support if it has been more '
          'than one working day.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(platformSettingsProvider).value ?? const PlatformSettings();
    final supportEmail = displayEmail(settings.supportEmail);
    final supportPhone = (settings.supportPhone ?? '').replaceAll(
      RegExp(r'\D'),
      '',
    );
    final hours = settings.supportHours.trim();
    final tel = supportPhone.length == 10 ? '+91$supportPhone' : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                if (supportEmail.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.mail_outline,
                      color: AppColors.primary,
                    ),
                    title: const Text('Email us'),
                    subtitle: Text(supportEmail),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _launch(
                      context,
                      Uri(
                        scheme: 'mailto',
                        path: supportEmail,
                        queryParameters: {
                          'subject': 'NearKart support request',
                        },
                      ),
                    ),
                  ),
                if (supportEmail.isNotEmpty && tel.isNotEmpty)
                  const Divider(height: 0),
                if (tel.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.call_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Call us'),
                    subtitle: Text(hours.isEmpty ? tel : '$tel • $hours'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _launch(context, Uri(scheme: 'tel', path: tel)),
                  ),
                if (supportEmail.isEmpty && tel.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.support_agent_outlined),
                    title: Text('Support contacts are not configured yet'),
                    subtitle: Text(
                      'An administrator can add them under Company & fees.',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Frequently asked',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (question, answer) in _faqs)
                  ExpansionTile(
                    title: Text(question, style: const TextStyle(fontSize: 14)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            answer,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No app available to open ${uri.scheme}.')),
      );
    }
  }
}
