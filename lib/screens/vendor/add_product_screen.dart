import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key, required this.storeId});

  final String storeId;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockController = TextEditingController();
  String _selectedCategory = 'Staples';
  String _selectedUnit = 'kg';
  bool _isAvailable = true;
  bool _saving = false;
  XFile? _photo;

  final _categories = [
    'Staples',
    'Beverages',
    'Snacks',
    'Cooking Oil',
    'Pulses',
    'Spices',
    'Personal Care',
    'Cleaning',
    'Dairy',
    'Frozen',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _saving ? null : _pickPhoto,
                child: Container(
                  height: 160,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.divider,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _photo == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 40,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add Product Photo',
                              style: TextStyle(color: AppColors.textHint),
                            ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(_photo!.path), fit: BoxFit.cover),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 16,
                                child: IconButton(
                                  tooltip: 'Remove photo',
                                  padding: EdgeInsets.zero,
                                  iconSize: 18,
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      setState(() => _photo = null),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  hintText: 'e.g., Tata Gold Tea 500g',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of the product',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Selling Price (₹)',
                        hintText: '0',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _mrpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'MRP (₹)',
                        hintText: '0',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: AppConstants.productUnits
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedUnit = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock Count',
                        hintText: '100',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Available for sale'),
                subtitle: Text(
                  _isAvailable ? 'Visible to customers' : 'Hidden from store',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                value: _isAvailable,
                onChanged: (val) => setState(() => _isAvailable = val),
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Add Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text);
    final mrp = double.tryParse(_mrpController.text);
    final stock = int.tryParse(_stockController.text);
    if (name.isEmpty ||
        price == null ||
        price <= 0 ||
        stock == null ||
        stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name, valid price, and stock.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final imageUrl = await _uploadPhoto();
      await FirebaseFirestore.instance.collection('products').add({
        if (imageUrl != null) 'imageUrl': imageUrl,
        'storeId': widget.storeId,
        'name': name,
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'price': price,
        if (mrp != null && mrp > 0) 'mrp': mrp,
        'unit': _selectedUnit,
        'quantity': 1.0,
        'stockCount': stock,
        'isAvailable': _isAvailable,
        'isFeatured': false,
        'searchKeywords': name.toLowerCase().split(RegExp(r'\s+')),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product added successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to add product.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      // Downscale on device so uploads stay small on patchy connections.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      setState(() => _photo = picked);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the photo picker.')),
      );
    }
  }

  Future<String?> _uploadPhoto() async {
    final photo = _photo;
    if (photo == null) return null;

    final extension = photo.path.split('.').last.toLowerCase();
    final ref = FirebaseStorage.instance.ref(
      'products/${widget.storeId}/'
      '${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    try {
      await ref.putFile(File(photo.path));
      return await ref.getDownloadURL();
    } on FirebaseException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo upload failed; saving without an image.'),
          ),
        );
      }
      return null;
    }
  }
}
