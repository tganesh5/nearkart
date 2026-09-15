import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../auth/login_screen.dart';
import '../common/account_profile_screen.dart';
import '../common/help_support_screen.dart';
import 'delivery_settings_screen.dart';
import 'edit_store_screen.dart';
import 'payment_settings_screen.dart';
import 'store_timings_screen.dart';
import 'vendor_analytics_screen.dart';

class VendorProfileScreen extends ConsumerWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Store')),
      body: store.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Unable to load your store.')),
        data: (doc) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (doc == null)
              const _NoStoreCard()
            else
              _StoreHeader(data: doc.data()),
            const SizedBox(height: 16),
            _SettingsSection(
              title: 'Store Settings',
              items: [
                _SettingItem(
                  icon: Icons.edit,
                  label: 'Edit Store Details',
                  enabled: doc != null,
                  onTap: () => _open(
                    context,
                    EditStoreScreen(storeId: doc!.id, initialData: doc.data()),
                  ),
                ),
                _SettingItem(
                  icon: Icons.access_time,
                  label: 'Store Timings',
                  enabled: doc != null,
                  onTap: () => _open(
                    context,
                    StoreTimingsScreen(
                      storeId: doc!.id,
                      initialData: doc.data(),
                    ),
                  ),
                ),
                _SettingItem(
                  icon: Icons.delivery_dining,
                  label: 'Delivery Settings',
                  enabled: doc != null,
                  onTap: () => _open(context, const DeliverySettingsScreen()),
                ),
                _SettingItem(
                  icon: Icons.payment,
                  label: 'Payment Settings',
                  enabled: doc != null,
                  onTap: () => _open(
                    context,
                    PaymentSettingsScreen(
                      storeId: doc!.id,
                      initialData: doc.data(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: 'Account',
              items: [
                _SettingItem(
                  icon: Icons.person,
                  label: 'Profile',
                  onTap: () => _open(context, const AccountProfileScreen()),
                ),
                _SettingItem(
                  icon: Icons.analytics,
                  label: 'Analytics',
                  enabled: doc != null,
                  onTap: () =>
                      _open(context, VendorAnalyticsScreen(storeId: doc!.id)),
                ),
                _SettingItem(
                  icon: Icons.help_outline,
                  label: 'Help & Support',
                  onTap: () => _open(context, const HelpSupportScreen()),
                ),
                _SettingItem(
                  icon: Icons.logout,
                  label: 'Logout',
                  isDestructive: true,
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final isOpen = data['isOpen'] != false;
    final isVerified = data['isVerified'] == true;
    final location = [
      data['category'],
      data['city'],
    ].map((value) => value?.toString().trim()).where((value) => value?.isNotEmpty == true).join(' • ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primaryLight,
            child: Icon(Icons.store, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            data['name']?.toString().trim().isNotEmpty == true
                ? data['name'].toString()
                : 'Unnamed store',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isVerified ? Icons.verified : Icons.verified_outlined,
                size: 16,
                color: isVerified ? AppColors.primary : AppColors.textHint,
              ),
              const SizedBox(width: 4),
              Text(
                isVerified ? 'Verified store' : 'Not verified yet',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: (isOpen ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOpen ? 'Open' : 'Closed',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOpen ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              location,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
          if (data['address']?.toString().trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              data['address'].toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoStoreCard extends StatelessWidget {
  const _NoStoreCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.storefront_outlined, size: 40, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text(
            'No store assigned yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'An admin needs to create a store and assign it to this account '
            'before you can manage it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          child: Column(
            children: items
                .map(
                  (item) => Column(
                    children: [
                      item,
                      if (item != items.last) const Divider(height: 0),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool enabled;

  const _SettingItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textSecondary;

    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: enabled ? color : AppColors.textHint, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: !enabled
              ? AppColors.textHint
              : (isDestructive ? AppColors.error : AppColors.textPrimary),
        ),
      ),
      subtitle: enabled ? null : const Text('Needs a store', style: TextStyle(fontSize: 11)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
      onTap: enabled ? onTap : null,
    );
  }
}
