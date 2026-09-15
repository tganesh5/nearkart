import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

/// Shown after sign-in when the account has no mobile number.
///
/// Email sign-up collects a number, but Google sign-in never does and older
/// accounts predate the requirement. Every persona needs a reachable number so
/// customers, stores and delivery partners can call each other about an order.
class PhoneCaptureScreen extends ConsumerStatefulWidget {
  const PhoneCaptureScreen({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<PhoneCaptureScreen> createState() =>
      _PhoneCaptureScreenState();
}

class _PhoneCaptureScreenState extends ConsumerState<PhoneCaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _reason {
    return switch (widget.role) {
      UserRole.customer =>
        'Stores and delivery partners need to reach you about your orders.',
      UserRole.storeManager =>
        'Customers and delivery partners need to reach your store about '
            'orders.',
      UserRole.deliveryPartner =>
        'Customers and stores need to reach you during a delivery.',
      UserRole.admin =>
        'Stores and partners may need to reach you for escalations.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add your mobile number'),
        actions: [
          TextButton(
            onPressed: auth.isLoading ? null : _signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            const Icon(
              Icons.phone_in_talk_outlined,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'One last step',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _reason,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                prefixIcon: Icon(Icons.phone_outlined),
                prefixText: '+91 ',
                counterText: '',
              ),
              validator: (value) {
                if (value == null || value.length != 10) {
                  return 'Enter a valid 10-digit mobile number';
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: auth.isLoading ? null : _save,
              child: auth.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save and continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).updatePhone(_phone.text);
  }

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}
