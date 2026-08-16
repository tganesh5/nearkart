import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
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
                    radius: 36,
                    backgroundColor: AppColors.primaryLight,
                    child: const Icon(Icons.person, size: 32, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'User',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  if (user?.phone.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      '+91 ${user!.phone}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProfileOption(icon: Icons.location_on_outlined, label: 'My Addresses', onTap: () {}),
            _ProfileOption(icon: Icons.favorite_outline, label: 'Wishlist', onTap: () {}),
            _ProfileOption(icon: Icons.card_giftcard, label: 'Offers & Rewards', onTap: () {}),
            _ProfileOption(icon: Icons.help_outline, label: 'Help & Support', onTap: () {}),
            _ProfileOption(icon: Icons.info_outline, label: 'About NearKart', onTap: () {}),
            _ProfileOption(
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
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? AppColors.error : AppColors.textSecondary,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isDestructive ? AppColors.error : null,
            fontSize: 14,
          ),
        ),
        trailing: Icon(Icons.chevron_right, size: 20, color: AppColors.textHint),
        onTap: onTap,
      ),
    );
  }
}
