import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../common/location_picker_screen.dart';
import '../vendor/delivery_settings_screen.dart';
import '../vendor/edit_store_screen.dart';
import '../vendor/payment_settings_screen.dart';
import '../vendor/store_timings_screen.dart';
import 'manager_assignment.dart';
import 'product_setup_dialog.dart';
import 'user_management_screen.dart';

class AdminStoreDetailScreen extends StatelessWidget {
  const AdminStoreDetailScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final storeRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId);

    return Scaffold(
      appBar: AppBar(title: const Text('Store details')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => ProductSetupDialog(storeId: storeId),
        ),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Add product'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: storeRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load this store.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('This store no longer exists.'));
          }

          final data = snapshot.data!.data()!;
          final latitude = (data['latitude'] as num?)?.toDouble();
          final longitude = (data['longitude'] as num?)?.toDouble();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(data: data),
              const SizedBox(height: 16),
              _ModerationSection(storeRef: storeRef, data: data),
              const SizedBox(height: 16),
              _EditSection(storeId: storeId, data: data),
              const SizedBox(height: 16),
              _MapPreview(
                latitude: latitude,
                longitude: longitude,
                onChange: () => _changeLocation(
                  context,
                  storeRef,
                  latitude,
                  longitude,
                  [data['address'], data['city'], data['pincode']]
                      .map((value) => value?.toString().trim() ?? '')
                      .where((value) => value.isNotEmpty)
                      .join(', '),
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Contact & address',
                children: [
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: _text(data['address']),
                  ),
                  _DetailRow(
                    icon: Icons.location_city_outlined,
                    label: 'City',
                    value: _text(data['city']),
                  ),
                  _DetailRow(
                    icon: Icons.markunread_mailbox_outlined,
                    label: 'Pincode',
                    value: _text(data['pincode']),
                  ),
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: _text(data['phone']),
                  ),
                  _EditableRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'UPI ID',
                    value: _text(data['upiId']),
                    onEdit: () => _editUpiId(
                      context,
                      storeRef,
                      data['upiId']?.toString() ?? '',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ManagerSection(
                storeRef: storeRef,
                ownerId: data['ownerId']?.toString(),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Delivery',
                children: [
                  _DetailRow(
                    icon: Icons.delivery_dining_outlined,
                    label: 'Mode',
                    value: data['deliveryMode'] == 'partner'
                        ? 'Third-party partner'
                        : 'Own delivery',
                  ),
                  _DetailRow(
                    icon: Icons.social_distance_outlined,
                    label: 'Radius',
                    value: '${_text(data['deliveryRadius'], fallback: '0')} km',
                  ),
                  _DetailRow(
                    icon: Icons.currency_rupee,
                    label: 'Delivery fee',
                    value: '₹${_text(data['deliveryFee'], fallback: '0')}',
                  ),
                  _DetailRow(
                    icon: Icons.shopping_basket_outlined,
                    label: 'Minimum order',
                    value: '₹${_text(data['minOrderAmount'], fallback: '0')}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ProductsSection(storeId: storeId),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editUpiId(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> storeRef,
    String current,
  ) async {
    final upiId = await showDialog<String>(
      context: context,
      builder: (_) => _UpiIdDialog(initialValue: current),
    );
    if (upiId == null || !context.mounted) return;

    try {
      await storeRef.update({
        'upiId': upiId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(upiId.isEmpty ? 'UPI ID removed.' : 'UPI ID saved.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Only an admin or the store owner can change this.'
                : 'Unable to save the UPI ID.',
          ),
        ),
      );
    }
  }

  Future<void> _changeLocation(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> storeRef,
    double? latitude,
    double? longitude,
    String query,
  ) async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: 'Store location',
          initialLatitude: latitude,
          initialLongitude: longitude,
          initialQuery: query,
        ),
      ),
    );
    if (picked == null || !context.mounted) return;

    try {
      await storeRef.update({
        'latitude': picked.latitude,
        'longitude': picked.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Store location updated.')));
    } on FirebaseException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update the location.')),
      );
    }
  }
}

String _text(Object? value, {String fallback = 'Not set'}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final isOpen = data['isOpen'] == true;
    final isVerified = data['isVerified'] == true;

    return Row(
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primaryLight,
          child: Icon(Icons.store, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(data['name'], fallback: 'Unnamed store'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  _Chip(
                    label: isOpen ? 'Open' : 'Closed',
                    color: isOpen ? AppColors.success : AppColors.error,
                  ),
                  if (isVerified)
                    const _Chip(label: 'Verified', color: AppColors.primary),
                  if (data['isBlacklisted'] == true)
                    const _Chip(label: 'Blacklisted', color: AppColors.error)
                  else if (data['ownerId']?.toString().isEmpty ?? true)
                    const _Chip(label: 'No manager', color: AppColors.warning)
                  else if (data['isActive'] == false)
                    const _Chip(label: 'Deactivated', color: AppColors.warning),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Admin-only controls. Security rules reject these fields from anyone who is
/// not an admin, so the switches below are the only way they change.
class _ModerationSection extends StatefulWidget {
  const _ModerationSection({required this.storeRef, required this.data});

  final DocumentReference<Map<String, dynamic>> storeRef;
  final Map<String, dynamic> data;

  @override
  State<_ModerationSection> createState() => _ModerationSectionState();
}

class _ModerationSectionState extends State<_ModerationSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isActive = data['isActive'] != false;
    final isVerified = data['isVerified'] == true;
    final isBlacklisted = data['isBlacklisted'] == true;
    final isUnassigned = data['ownerId']?.toString().isEmpty ?? true;
    final reason = data['blacklistReason']?.toString();

    return _Section(
      title: 'Admin controls',
      children: [
        if (isBlacklisted)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.block, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    const Text(
                      'Blacklisted',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reason?.isNotEmpty == true ? reason! : 'No reason recorded.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: isActive && !isBlacklisted && !isUnassigned,
          // A store with no manager must stay hidden: its orders would reach
          // nobody. Assigning a manager unlocks this switch.
          onChanged: _busy || isBlacklisted || isUnassigned
              ? null
              : (value) => _setActive(value),
          title: const Text('Store active'),
          subtitle: Text(
            isBlacklisted
                ? 'Blacklisted stores stay deactivated'
                : isUnassigned
                ? 'Assign a store manager before listing this store'
                : isActive
                ? 'Listed for customers and accepting new orders'
                : 'Hidden from customers; no new orders accepted',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: isVerified,
          onChanged: _busy ? null : (value) => _setVerified(value),
          title: const Text('Verified badge'),
          subtitle: const Text(
            'Shows a verified mark to customers',
            style: TextStyle(fontSize: 12),
          ),
        ),
        const Divider(height: 20),
        SizedBox(
          width: double.infinity,
          child: isBlacklisted
              ? OutlinedButton.icon(
                  onPressed: _busy ? null : _removeFromBlacklist,
                  icon: const Icon(Icons.restore),
                  label: const Text('Remove from blacklist'),
                )
              : OutlinedButton.icon(
                  onPressed: _busy ? null : _blacklist,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  icon: const Icon(Icons.block),
                  label: const Text('Blacklist store'),
                ),
        ),
      ],
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _update(Map<String, dynamic> values, String success) async {
    setState(() => _busy = true);
    try {
      await widget.storeRef.update({
        ...values,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message(success);
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'Only an admin can change store status.'
            : 'Could not update the store.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActive(bool value) {
    return _update({
      'isActive': value,
    }, value ? 'Store activated.' : 'Store deactivated.');
  }

  Future<void> _setVerified(bool value) {
    return _update({
      'isVerified': value,
    }, value ? 'Verified badge added.' : 'Verified badge removed.');
  }

  Future<void> _blacklist() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _BlacklistDialog(),
    );
    if (reason == null) return;

    // Blacklisting also deactivates, so the store cannot trade while banned.
    await _update({
      'isBlacklisted': true,
      'isActive': false,
      'blacklistReason': reason,
      'blacklistedAt': FieldValue.serverTimestamp(),
    }, 'Store blacklisted.');
  }

  Future<void> _removeFromBlacklist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from blacklist?'),
        content: const Text(
          'The store stays deactivated until you switch it back on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _update({
      'isBlacklisted': false,
      'blacklistReason': null,
      'blacklistedAt': null,
    }, 'Store removed from the blacklist.');
  }
}

class _BlacklistDialog extends StatefulWidget {
  const _BlacklistDialog();

  @override
  State<_BlacklistDialog> createState() => _BlacklistDialogState();
}

class _BlacklistDialogState extends State<_BlacklistDialog> {
  static const _reasons = <String>[
    'Repeated order cancellations',
    'Selling prohibited items',
    'Fraudulent pricing',
    'Customer safety complaints',
    'Fake or unverifiable business',
  ];

  final _notes = TextEditingController();
  String? _reason;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Blacklist store'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The store is hidden from customers and blocked from taking '
                'new orders or editing its catalogue. Orders already in '
                'progress can still be completed.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: [
                  for (final reason in _reasons)
                    DropdownMenuItem(value: reason, child: Text(reason)),
                ],
                onChanged: (value) => setState(() => _reason = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _reason == null
              ? null
              : () {
                  final notes = _notes.text.trim();
                  Navigator.pop(
                    context,
                    notes.isEmpty ? _reason! : '$_reason — $notes',
                  );
                },
          child: const Text('Blacklist'),
        ),
      ],
    );
  }
}

/// Opens the same editors the store manager uses, so an admin can fix any
/// field without a second set of forms to keep in step.
class _EditSection extends StatelessWidget {
  const _EditSection({required this.storeId, required this.data});

  final String storeId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Edit store',
      children: [
        _EditLink(
          icon: Icons.storefront_outlined,
          label: 'Name, category, contact and address',
          onTap: () => _open(
            context,
            EditStoreScreen(storeId: storeId, initialData: data),
          ),
        ),
        _EditLink(
          icon: Icons.delivery_dining_outlined,
          label: 'Delivery radius, area and partner',
          onTap: () => _open(
            context,
            DeliverySettingsScreen(storeId: storeId, initialData: data),
          ),
        ),
        _EditLink(
          icon: Icons.payments_outlined,
          label: 'Payment methods, fees and minimum order',
          onTap: () => _open(
            context,
            PaymentSettingsScreen(storeId: storeId, initialData: data),
          ),
        ),
        _EditLink(
          icon: Icons.access_time,
          label: 'Opening hours and closed days',
          onTap: () => _open(
            context,
            StoreTimingsScreen(storeId: storeId, initialData: data),
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _EditLink extends StatelessWidget {
  const _EditLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

/// Adds or changes the UPI id customers pay into. Empty clears it, which
/// switches the store to cash only until a new one is set.
class _UpiIdDialog extends StatefulWidget {
  const _UpiIdDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_UpiIdDialog> createState() => _UpiIdDialogState();
}

class _UpiIdDialogState extends State<_UpiIdDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _upiId = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _upiId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialValue.isEmpty ? 'Add UPI ID' : 'Change UPI ID'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Online payments go straight to this UPI ID. Leave it blank '
                'to take cash only.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _upiId,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'yourstore@okhdfcbank',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  if (!RegExp(r'^[\w.\-]{2,}@[A-Za-z]{2,}$').hasMatch(text)) {
                    return 'Enter a valid UPI ID like name@bank';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _upiId.text.trim());
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.latitude,
    required this.longitude,
    required this.onChange,
  });

  final double? latitude;
  final double? longitude;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final hasLocation = latitude != null && longitude != null;
    final point = hasLocation ? LatLng(latitude!, longitude!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            child: point == null
                ? const ColoredBox(
                    color: AppColors.inputFill,
                    child: Center(child: Text('No location set')),
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 16,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.nearkart.nearkart',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                hasLocation
                    ? '${latitude!.toStringAsFixed(6)}, '
                          '${longitude!.toStringAsFixed(6)}'
                    : 'Coordinates not set',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            TextButton.icon(
              onPressed: onChange,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: Text(hasLocation ? 'Change' : 'Set location'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ManagerSection extends StatefulWidget {
  const _ManagerSection({required this.storeRef, required this.ownerId});

  final DocumentReference<Map<String, dynamic>> storeRef;
  final String? ownerId;

  @override
  State<_ManagerSection> createState() => _ManagerSectionState();
}

class _ManagerSectionState extends State<_ManagerSection> {
  bool _busy = false;

  bool get _assigned => widget.ownerId?.isNotEmpty == true;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Store manager',
      children: [
        if (!_assigned)
          const _DetailRow(
            icon: Icons.person_off_outlined,
            label: 'Manager',
            value: 'Not assigned — the store stays hidden until one is set',
          )
        else
          _ManagerDetails(ownerId: widget.ownerId!),
        const Divider(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _assign,
                icon: Icon(
                  _assigned ? Icons.swap_horiz : Icons.person_add_alt,
                  size: 18,
                ),
                label: Text(_assigned ? 'Change manager' : 'Assign manager'),
              ),
            ),
            if (_assigned) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _unassign,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: const Text('Unassign'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _assign() async {
    final typed = await showDialog<String>(
      context: context,
      builder: (_) => const _ManagerLookupDialog(),
    );
    if (typed == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final UserDoc? account;
      try {
        account = await findManagerAccount(typed);
      } on AmbiguousManagerException catch (error) {
        _message(
          'More than one account uses that ${error.field}. '
          'Enter the email address instead.',
        );
        return;
      }
      // Nobody matched, so offer to create the account here rather than
      // sending the admin off to find another screen.
      if (account == null) {
        if (!mounted) return;
        final uid = await _createManager(typed);
        if (uid == null) return;
        await widget.storeRef.update({
          'ownerId': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _message(
          'Account created and assigned. They have been emailed a link to '
          'set a password.',
        );
        return;
      }

      if (!mounted) return;
      if (!await ensureManagerRole(context, account)) return;

      await widget.storeRef.update({
        'ownerId': account.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message(
        'Manager assigned. Switch the store on under Admin controls to list '
        'it for customers.',
      );
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'Only an admin can change the store manager.'
            : 'Unable to assign the manager.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Offers to open a store-manager account for somebody who has none yet,
  /// pre-filling whatever the admin already typed.
  Future<String?> _createManager(String typed) async {
    final wanted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No account yet'),
        content: Text(
          'Nothing matches "$typed". Create a store manager account for them '
          'now? They will be emailed a link to set their own password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add user'),
          ),
        ],
      ),
    );
    if (wanted != true || !mounted) return null;

    final isEmail = typed.contains('@');
    return showAddUserDialog(
      context,
      initialEmail: isEmail ? typed : null,
      initialPhone: isEmail ? null : typed.replaceAll(RegExp(r'\D'), ''),
      initialRole: UserRole.storeManager,
    );
  }

  Future<void> _unassign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unassign manager?'),
        content: const Text(
          'They lose access to this store immediately. The store is also '
          'deactivated, since nobody would be left to handle its orders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await widget.storeRef.update({
        'ownerId': '',
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Manager unassigned and the store deactivated.');
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'Only an admin can change the store manager.'
            : 'Unable to unassign the manager.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ManagerDetails extends StatelessWidget {
  const _ManagerDetails({required this.ownerId});

  final String ownerId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        // Fall back to the raw id so the admin can still identify the account.
        final name = data?['name']?.toString();
        final email = data?['email']?.toString();
        final phone = data?['phone']?.toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Name',
              value: name?.isNotEmpty == true ? name! : ownerId,
            ),
            if (email?.isNotEmpty == true)
              _DetailRow(
                icon: Icons.mail_outline,
                label: 'Email',
                value: email!,
              ),
            if (phone?.isNotEmpty == true)
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: phone!,
              ),
            _DetailRow(
              icon: Icons.badge_outlined,
              label: 'Role',
              value: _text(data?['role']),
            ),
          ],
        );
      },
    );
  }
}

/// Asks for an email or phone number to look a manager up by.
class _ManagerLookupDialog extends StatefulWidget {
  const _ManagerLookupDialog();

  @override
  State<_ManagerLookupDialog> createState() => _ManagerLookupDialogState();
}

class _ManagerLookupDialogState extends State<_ManagerLookupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign store manager'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The account must already exist. If the role is not store '
                'manager yet, you will be asked before it is changed.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _value,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Email or phone',
                  hintText: 'manager@example.com or 9876543210',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter an email address or phone number'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Look up')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _value.text.trim());
  }
}

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('storeId', isEqualTo: storeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Section(
            title: 'Products',
            children: [Text('Unable to load products.')],
          );
        }
        if (!snapshot.hasData) {
          return const _Section(
            title: 'Products',
            children: [Center(child: CircularProgressIndicator())],
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const _Section(
            title: 'Products',
            children: [Text('No products added yet.')],
          );
        }

        return _Section(
          title: 'Products (${docs.length})',
          children: [
            for (final doc in docs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(_text(doc.data()['name']))),
                    Text(
                      '₹${_text(doc.data()['price'], fallback: '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Stock ${_text(doc.data()['stockCount'], fallback: '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// A detail row with an edit affordance on the right.
class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DetailRow(icon: icon, label: label, value: value),
        ),
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Edit $label',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
