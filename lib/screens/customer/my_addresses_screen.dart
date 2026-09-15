import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../common/location_picker_screen.dart';

/// Saved delivery addresses, stored per user at users/{uid}/addresses.
class MyAddressesScreen extends StatelessWidget {
  const MyAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Addresses')),
        body: const Center(child: Text('Please sign in to save addresses.')),
      );
    }

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses');

    return Scaffold(
      appBar: AppBar(title: const Text('My Addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, collection, null, null),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: collection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load addresses.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No saved addresses',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save home and work addresses to check out faster.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(
                      _iconFor(data['label']?.toString()),
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(data['label']?.toString() ?? 'Address'),
                  subtitle: Text(
                    data['address']?.toString() ?? '',
                    maxLines: 3,
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _edit(context, collection, doc.id, data);
                      } else {
                        doc.reference.delete();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static IconData _iconFor(String? label) {
    return switch (label?.toLowerCase()) {
      'home' => Icons.home_outlined,
      'work' || 'office' => Icons.work_outline,
      _ => Icons.location_on_outlined,
    };
  }

  Future<void> _edit(
    BuildContext context,
    CollectionReference<Map<String, dynamic>> collection,
    String? docId,
    Map<String, dynamic>? existing,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddressDialog(
        collection: collection,
        docId: docId,
        existing: existing,
      ),
    );
  }
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({required this.collection, this.docId, this.existing});

  final CollectionReference<Map<String, dynamic>> collection;
  final String? docId;
  final Map<String, dynamic>? existing;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _address;
  late final TextEditingController _notes;

  double? _latitude;
  double? _longitude;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _label = TextEditingController(text: existing?['label']?.toString() ?? '');
    _address = TextEditingController(
      text: existing?['address']?.toString() ?? '',
    );
    _notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    final location = existing?['location'];
    if (location is GeoPoint) {
      _latitude = location.latitude;
      _longitude = location.longitude;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _latitude != null && _longitude != null;

    return AlertDialog(
      title: Text(widget.docId == null ? 'Add address' : 'Edit address'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _label,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    hintText: 'Home, Work, Mum\'s place',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Address'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Delivery notes (optional)',
                    hintText: 'Gate code, landmark',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.map_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Map location'),
                  subtitle: Text(
                    hasLocation
                        ? '${_latitude!.toStringAsFixed(5)}, '
                              '${_longitude!.toStringAsFixed(5)}'
                        : 'Not set',
                  ),
                  trailing: TextButton(
                    onPressed: _pickLocation,
                    child: Text(hasLocation ? 'Change' : 'Set'),
                  ),
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
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: 'Delivery location',
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialQuery: _address.text,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _latitude = picked.latitude;
      _longitude = picked.longitude;
      if (_address.text.trim().isEmpty && picked.address != null) {
        _address.text = picked.address!;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'label': _label.text.trim(),
        'address': _address.text.trim(),
        'notes': _notes.text.trim(),
        if (_latitude != null && _longitude != null)
          'location': GeoPoint(_latitude!, _longitude!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.docId == null) {
        await widget.collection.add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await widget.collection.doc(widget.docId).update(payload);
      }
      if (mounted) Navigator.pop(context);
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the address.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
