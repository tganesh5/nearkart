import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';
import 'phone_capture_screen.dart';
import '../admin/admin_shell.dart';
import '../customer/customer_shell.dart';
import '../delivery/delivery_partner_shell.dart';
import '../vendor/vendor_shell.dart';

class RoleHome extends ConsumerWidget {
  const RoleHome({super.key, required this.user});

  /// The profile as it stood when this screen was pushed.
  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the live profile: saving a phone number or having a role changed
    // updates the provider, and this screen decides what to show from it. The
    // pushed-in snapshot is only a fallback for the moment after sign-out
    // clears the provider but before the route is replaced.
    final user = ref.watch(authProvider).user ?? this.user;

    if (user.status != AccountStatus.active) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account approval')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(switch (user.status) {
                  AccountStatus.pending => Icons.hourglass_top,
                  AccountStatus.suspended => Icons.lock_outline,
                  _ => Icons.cancel_outlined,
                }, size: 72),
                const SizedBox(height: 16),
                Text(
                  switch (user.status) {
                    AccountStatus.pending =>
                      '${user.role.label} registration pending',
                    AccountStatus.suspended => 'Account deactivated',
                    _ => 'Registration was not approved',
                  },
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(switch (user.status) {
                  AccountStatus.pending =>
                    'An administrator must approve this account before '
                        'staff features become available.',
                  AccountStatus.suspended =>
                    'An administrator has withdrawn access to this '
                        'account.',
                  _ => 'Contact a NearKart administrator for assistance.',
                }, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Every persona must be reachable by phone before using the app, so the
    // other parties on an order can always call.
    if (user.phone.trim().isEmpty) {
      return PhoneCaptureScreen(role: user.role);
    }

    return switch (user.role) {
      UserRole.customer => const CustomerShell(),
      UserRole.storeManager => const VendorShell(),
      UserRole.admin => const AdminShell(),
      UserRole.deliveryPartner => const DeliveryPartnerShell(),
    };
  }
}
