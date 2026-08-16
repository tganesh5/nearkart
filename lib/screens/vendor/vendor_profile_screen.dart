import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class VendorProfileScreen extends ConsumerWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Store')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryLight,
                    child: const Icon(Icons.store, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Krishna Kirana Store',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Verified Vendor',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Grocery & Kirana • Koramangala, Bangalore',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: 'Store Settings',
              items: [
                _SettingItem(icon: Icons.edit, label: 'Edit Store Details', onTap: () {}),
                _SettingItem(icon: Icons.access_time, label: 'Store Timings', onTap: () {}),
                _SettingItem(icon: Icons.delivery_dining, label: 'Delivery Settings', onTap: () {}),
                _SettingItem(icon: Icons.payment, label: 'Payment Settings', onTap: () {}),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: 'Account',
              items: [
                _SettingItem(icon: Icons.person, label: 'Profile', onTap: () {}),
                _SettingItem(icon: Icons.analytics, label: 'Analytics', onTap: () {}),
                _SettingItem(icon: Icons.help_outline, label: 'Help & Support', onTap: () {}),
                _SettingItem(
                  icon: Icons.logout,
                  label: 'Logout',
                  isDestructive: true,
                  onTap: () {
                    ref.read(authProvider.notifier).logout();
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
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: items
                .map((item) => Column(
                      children: [
                        item,
                        if (item != items.last) const Divider(height: 0),
                      ],
                    ))
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

  const _SettingItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.textSecondary,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textHint,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
