import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../common/location_picker_screen.dart';
import 'admin_store_detail_screen.dart';
import 'manager_assignment.dart';
import 'platform_settings_screen.dart';
import 'user_management_screen.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NearKart Admin'),
        actions: [
          IconButton(
            tooltip: 'Manage users',
            icon: const Icon(Icons.manage_accounts_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserManagementScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Company, fees & bank account',
            icon: const Icon(Icons.apartment_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlatformSettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _StoreSetupDialog(),
        ),
        icon: const Icon(Icons.add_business),
        label: const Text('Add store'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('stores').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load stores.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No stores configured yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final store = snapshot.data!.docs[index];
              final data = store.data();
              final isBlacklisted = data['isBlacklisted'] == true;
              final isActive = data['isActive'] != false;
              final isUnassigned = data['ownerId']?.toString().isEmpty ?? true;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isBlacklisted
                        ? AppColors.error.withValues(alpha: 0.12)
                        : AppColors.primaryLight,
                    child: Icon(
                      isBlacklisted ? Icons.block : Icons.store,
                      color: isBlacklisted
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          (data['name'] ?? 'Unnamed store').toString(),
                        ),
                      ),
                      if (isBlacklisted)
                        const _StatusBadge(
                          label: 'Blacklisted',
                          color: AppColors.error,
                        )
                      // Shown ahead of 'Inactive' because it is the reason
                      // for it, and the one the admin can act on.
                      else if (isUnassigned)
                        const _StatusBadge(
                          label: 'No manager',
                          color: AppColors.warning,
                        )
                      else if (!isActive)
                        const _StatusBadge(
                          label: 'Inactive',
                          color: AppColors.warning,
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${data['address'] ?? 'No address'}\n'
                    '${data['city'] ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminStoreDetailScreen(storeId: store.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

/// What the admin chose to do when the typed manager had no account.
enum _NoAccountChoice { addUser, unassigned }

class _StoreSetupDialog extends StatefulWidget {
  const _StoreSetupDialog();

  @override
  State<_StoreSetupDialog> createState() => _StoreSetupDialogState();
}

class _StoreSetupDialogState extends State<_StoreSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _managerId = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _upiId = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _managerId,
      _phone,
      _address,
      _city,
      _pincode,
      _latitude,
      _longitude,
      _upiId,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set up store'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'Store name'),
                _field(
                  _managerId,
                  'Store manager (email or phone)',
                  hint: 'Leave blank to assign later',
                  optional: true,
                ),
                _field(_phone, 'Store phone'),
                _field(_address, 'Address'),
                _field(_city, 'City'),
                _field(_pincode, 'Pincode'),
                _LocationField(
                  latitude: _latitude,
                  longitude: _longitude,
                  onPick: _pickLocation,
                ),
                _field(
                  _upiId,
                  'Store UPI ID',
                  hint: 'name@bank, can be added later',
                  optional: true,
                  validator: _validateUpi,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create store'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    String? hint,
    bool optional = false,
    String? Function(String)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (value) {
          final text = (value ?? '').trim();
          if (text.isEmpty) return optional ? null : 'Required';
          return validator?.call(text);
        },
      ),
    );
  }

  static String? _validateUpi(String value) {
    return RegExp(r'^[\w.\-]{2,}@[A-Za-z]{2,}$').hasMatch(value)
        ? null
        : 'Enter a valid UPI ID like name@bank';
  }

  /// The address details typed so far, so the map opens near the right place
  /// instead of a default city.
  String _locationQuery() {
    return [_address.text, _city.text, _pincode.text]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(', ');
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: 'Store location',
          initialLatitude: double.tryParse(_latitude.text),
          initialLongitude: double.tryParse(_longitude.text),
          initialQuery: _locationQuery(),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _latitude.text = picked.latitude.toStringAsFixed(6);
      _longitude.text = picked.longitude.toStringAsFixed(6);
      // Only fill address details the admin has not typed themselves.
      if (_address.text.trim().isEmpty && picked.address != null) {
        _address.text = picked.address!;
      }
      if (_city.text.trim().isEmpty && picked.city != null) {
        _city.text = picked.city!;
      }
      if (_pincode.text.trim().isEmpty && picked.pincode != null) {
        _pincode.text = picked.pincode!;
      }
    });
  }

  /// Resolves the typed manager to a uid, or null to leave the store
  /// unassigned. [proceed] is false when the admin backed out.
  ///
  /// A blank field means "assign later". A value that matches nothing offers
  /// either creating the account now or carrying on without a manager, rather
  /// than blocking: a shop is often registered before its owner has signed up.
  Future<({bool proceed, String? managerId})> _resolveManager() async {
    const cancelled = (proceed: false, managerId: null);
    final typed = _managerId.text.trim();
    if (typed.isEmpty) return (proceed: true, managerId: null);

    final UserDoc? found;
    try {
      found = await findManagerAccount(typed);
    } on AmbiguousManagerException catch (error) {
      _showError(
        'More than one account uses that ${error.field}. '
        'Enter the email address instead.',
      );
      return cancelled;
    }

    if (found == null) {
      if (!mounted) return cancelled;
      switch (await _confirmNoAccount(typed)) {
        case _NoAccountChoice.addUser:
          if (!mounted) return cancelled;
          final isEmail = typed.contains('@');
          final uid = await showAddUserDialog(
            context,
            initialEmail: isEmail ? typed : null,
            initialPhone: isEmail ? null : typed.replaceAll(RegExp(r'\D'), ''),
            initialRole: UserRole.storeManager,
          );
          return uid == null ? cancelled : (proceed: true, managerId: uid);
        case _NoAccountChoice.unassigned:
          return (proceed: true, managerId: null);
        case null:
          return cancelled;
      }
    }

    if (!mounted) return cancelled;
    final promoted = await ensureManagerRole(context, found);
    return promoted ? (proceed: true, managerId: found.id) : cancelled;
  }

  Future<_NoAccountChoice?> _confirmNoAccount(String typed) {
    return showDialog<_NoAccountChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No account yet'),
        content: Text(
          'Nothing matches "$typed". Either create an account for them now, '
          'or create the store and assign a manager later.\n\n'
          'Without a manager the store is created deactivated, so customers '
          'cannot order from a store nobody is managing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _NoAccountChoice.unassigned),
            child: const Text('Create unassigned'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _NoAccountChoice.addUser),
            child: const Text('Add user'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final latitude = double.tryParse(_latitude.text);
    final longitude = double.tryParse(_longitude.text);
    if (latitude == null || longitude == null) {
      _showError('Choose the store location on the map.');
      return;
    }

    setState(() => _saving = true);
    try {
      final resolved = await _resolveManager();
      if (!resolved.proceed) return;
      final managerId = resolved.managerId;

      await FirebaseFirestore.instance.collection('stores').add({
        // Empty rather than absent: security rules compare this field, and a
        // missing field makes the rule error instead of simply denying.
        'ownerId': managerId ?? '',
        'name': _name.text.trim(),
        'description': '',
        'category': 'General',
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'pincode': _pincode.text.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'upiId': _upiId.text.trim(),
        'isOpen': true,
        // A store with no manager would take orders nobody ever sees.
        'isActive': managerId != null,
        'isVerified': true,
        'offersDelivery': true,
        'deliveryMode': 'own',
        'deliveryRadius': 5.0,
        'deliveryFee': 30.0,
        'minOrderAmount': 99.0,
        'rating': 0.0,
        'totalRatings': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            managerId == null
                ? 'Store created without a manager. Assign one to activate it.'
                : 'Store created.',
          ),
        ),
      );
    } on FirebaseException {
      _showError('Unable to create the store.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}

/// Shows the coordinates chosen on the map instead of asking the admin to
/// type latitude and longitude by hand.
class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.latitude,
    required this.longitude,
    required this.onPick,
  });

  final TextEditingController latitude;
  final TextEditingController longitude;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        double.tryParse(latitude.text) != null &&
        double.tryParse(longitude.text) != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Store location',
          errorText: hasLocation ? null : 'Required',
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasLocation
                    ? '${latitude.text}, ${longitude.text}'
                    : 'Not chosen yet',
                style: TextStyle(
                  color: hasLocation
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(hasLocation ? 'Change' : 'Choose on map'),
            ),
          ],
        ),
      ),
    );
  }
}
