import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Delivery settings for a store.
///
/// [storeId] and [initialData] are optional so an admin can open this for any
/// store. Left out, it falls back to the store owned by the signed-in manager,
/// which is how the vendor tab uses it.
class DeliverySettingsScreen extends StatefulWidget {
  const DeliverySettingsScreen({super.key, this.storeId, this.initialData});

  final String? storeId;
  final Map<String, dynamic>? initialData;

  @override
  State<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends State<DeliverySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _radius = TextEditingController();

  String _mode = 'own';
  String? _storeId;
  String? _partnerId;
  bool _offersDelivery = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provided = widget.initialData;
    if (widget.storeId != null && provided != null) {
      _storeId = widget.storeId;
      _apply(provided);
      _loading = false;
    } else {
      _loadStore();
    }
  }

  @override
  void dispose() {
    _radius.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> data) {
    _partnerId = data['deliveryPartnerId'] as String?;
    final stored = (data['deliveryMode'] ?? '').toString();
    // 'own' with nobody registered means the manager is already doing the
    // delivering, which is also the sensible default for a new store.
    _mode = stored.isEmpty || (stored == 'own' && _partnerId == null)
        ? 'self'
        : stored;
    _offersDelivery = data['offersDelivery'] != false;
    _radius.text = _number(data['deliveryRadius'], 5);
  }

  static String _number(Object? value, num fallback) {
    final parsed = value is num ? value : num.tryParse(value?.toString() ?? '');
    return (parsed ?? fallback).toString();
  }

  Future<void> _loadStore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final store = snapshot.docs.first;
        _storeId = store.id;
        _apply(store.data());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _storeId == null
          ? const Center(child: Text('No store is assigned to this account.'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Fulfilment method',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: _mode,
                    onChanged: (value) => setState(() => _mode = value!),
                    child: const Column(
                      children: [
                        RadioListTile(
                          value: 'self',
                          title: Text('I deliver it myself'),
                          subtitle: Text(
                            'Orders stay with you. The Orders tab gives you '
                            'navigation to the customer and the buttons to '
                            'complete the delivery.',
                          ),
                        ),
                        RadioListTile(
                          value: 'own',
                          title: Text('My delivery partner'),
                          subtitle: Text(
                            'Assign orders to your registered delivery '
                            'partner.',
                          ),
                        ),
                        RadioListTile(
                          value: 'partner',
                          title: Text('Third-party delivery partner'),
                          subtitle: Text(
                            'Dispatch through the configured logistics '
                            'provider.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_mode == 'own') ...[
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'deliveryPartner')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final partners = snapshot.data?.docs ?? const [];
                        return DropdownButtonFormField<String>(
                          initialValue:
                              partners.any(
                                (partner) => partner.id == _partnerId,
                              )
                              ? _partnerId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Default delivery partner',
                          ),
                          items: partners
                              .map(
                                (partner) => DropdownMenuItem(
                                  value: partner.id,
                                  child: Text(
                                    (partner.data()['name'] ?? partner.id)
                                        .toString(),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => _partnerId = value,
                        );
                      },
                    ),
                  ],
                  const Divider(height: 32),
                  Text(
                    'Delivery area',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _offersDelivery,
                    onChanged: (value) =>
                        setState(() => _offersDelivery = value),
                    title: const Text('Offer delivery'),
                    subtitle: const Text(
                      'Turn off to accept pickup orders only',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _radius,
                    enabled: _offersDelivery,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Delivery radius (km)',
                      helperText: 'How far from the store you will deliver',
                    ),
                    validator: (value) {
                      if (!_offersDelivery) return null;
                      final radius = double.tryParse((value ?? '').trim());
                      if (radius == null) return 'Enter a number';
                      if (radius <= 0) return 'Must be more than 0';
                      if (radius > 50) return 'Keep it within 50 km';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save delivery settings'),
                  ),
                ],
              ),
            ),
    );
  }

  void _message(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.error : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mode == 'own' && _partnerId == null) {
      _message('Select a delivery partner.');
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(_storeId)
          .update({
            'deliveryMode': _mode,
            'deliveryPartnerId': _mode == 'own' ? _partnerId : null,
            'offersDelivery': _offersDelivery,
            'deliveryRadius': double.parse(_radius.text.trim()),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      _message('Delivery settings updated.');
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'You do not have permission to change this store.'
            : 'Unable to save delivery settings.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
