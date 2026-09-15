import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../common/location_picker_screen.dart';

const storeCategories = <String>[
  'General',
  'Grocery & Kirana',
  'Fruits & Vegetables',
  'Dairy & Bakery',
  'Meat & Fish',
  'Pharmacy',
  'Stationery',
  'Electronics',
];

class EditStoreScreen extends StatefulWidget {
  const EditStoreScreen({
    super.key,
    required this.storeId,
    required this.initialData,
  });

  final String storeId;
  final Map<String, dynamic> initialData;

  @override
  State<EditStoreScreen> createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends State<EditStoreScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _pincode;

  late String _category;
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _name = TextEditingController(text: _string(data['name']));
    _description = TextEditingController(text: _string(data['description']));
    _phone = TextEditingController(text: _string(data['phone']));
    _address = TextEditingController(text: _string(data['address']));
    _city = TextEditingController(text: _string(data['city']));
    _pincode = TextEditingController(text: _string(data['pincode']));

    final category = _string(data['category']);
    _category = storeCategories.contains(category)
        ? category
        : storeCategories.first;
    _latitude = (data['latitude'] as num?)?.toDouble();
    _longitude = (data['longitude'] as num?)?.toDouble();
  }

  static String _string(Object? value) => value?.toString() ?? '';

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _phone,
      _address,
      _city,
      _pincode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _latitude != null && _longitude != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit store details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Store name'),
              textCapitalization: TextCapitalization.words,
              validator: _required,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final category in storeCategories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What does your store sell?',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Contact phone',
                helperText: 'Shown to customers and delivery partners',
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.length < 10) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
              validator: _required,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'City'),
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _pincode,
                    decoration: const InputDecoration(labelText: 'Pincode'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final digits = (value ?? '').replaceAll(
                        RegExp(r'\D'),
                        '',
                      );
                      if (digits.length != 6) return '6 digits';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Store location'),
                subtitle: Text(
                  hasLocation
                      ? '${_latitude!.toStringAsFixed(6)}, '
                            '${_longitude!.toStringAsFixed(6)}'
                      : 'Not set — customers cannot find this store',
                ),
                trailing: TextButton(
                  onPressed: _pickLocation,
                  child: Text(hasLocation ? 'Change' : 'Set'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: 'Store location',
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialQuery: [
            _address.text,
            _city.text,
            _pincode.text,
          ].map((v) => v.trim()).where((v) => v.isNotEmpty).join(', '),
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
      if (_city.text.trim().isEmpty && picked.city != null) {
        _city.text = picked.city!;
      }
      if (_pincode.text.trim().isEmpty && picked.pincode != null) {
        _pincode.text = picked.pincode!;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      _showMessage('Set the store location on the map first.');
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .update({
            'name': _name.text.trim(),
            'description': _description.text.trim(),
            'category': _category,
            'phone': _phone.text.trim(),
            'address': _address.text.trim(),
            'city': _city.text.trim(),
            'pincode': _pincode.text.trim(),
            'latitude': _latitude,
            'longitude': _longitude,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      Navigator.of(context).pop();
      _showMessage('Store details saved.');
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showMessage(
        error.code == 'permission-denied'
            ? 'You do not have permission to edit this store.'
            : 'Could not save the store details.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
