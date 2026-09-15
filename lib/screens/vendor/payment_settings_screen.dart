import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({
    super.key,
    required this.storeId,
    required this.initialData,
  });

  final String storeId;
  final Map<String, dynamic> initialData;

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _upiId;
  late final TextEditingController _minOrderAmount;
  late final TextEditingController _deliveryFee;

  late bool _acceptsCod;
  late bool _acceptsOnline;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _upiId = TextEditingController(text: data['upiId']?.toString() ?? '');
    _minOrderAmount = TextEditingController(
      text: _number(data['minOrderAmount'], 99),
    );
    _deliveryFee = TextEditingController(
      text: _number(data['deliveryFee'], 30),
    );
    // Default to accepting both so existing stores keep working unchanged.
    _acceptsCod = data['acceptsCod'] != false;
    _acceptsOnline = data['acceptsOnline'] != false;
  }

  static String _number(Object? value, num fallback) {
    final number = value is num ? value : fallback;
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
  }

  @override
  void dispose() {
    _upiId.dispose();
    _minOrderAmount.dispose();
    _deliveryFee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Accepted payment methods',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: _acceptsCod,
                    onChanged: (value) => setState(() => _acceptsCod = value),
                    title: const Text('Cash on delivery'),
                    secondary: const Icon(Icons.payments_outlined),
                  ),
                  const Divider(height: 0),
                  SwitchListTile(
                    value: _acceptsOnline,
                    onChanged: (value) =>
                        setState(() => _acceptsOnline = value),
                    title: const Text('Online payment (UPI)'),
                    secondary: const Icon(Icons.qr_code_2_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _upiId,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'yourstore@okhdfcbank',
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (!_acceptsOnline) return null;
                if (text.isEmpty) {
                  return 'Required when online payment is on';
                }
                if (!RegExp(r'^[\w.\-]{2,}@[A-Za-z]{2,}$').hasMatch(text)) {
                  return 'Enter a valid UPI ID like name@bank';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Order limits',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minOrderAmount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimum order',
                      prefixText: '₹ ',
                    ),
                    validator: _positiveNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _deliveryFee,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Delivery fee',
                      prefixText: '₹ ',
                    ),
                    validator: _positiveNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Customers see these amounts at checkout.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save payment settings'),
            ),
          ],
        ),
      ),
    );
  }

  String? _positiveNumber(String? value) {
    final amount = double.tryParse((value ?? '').trim());
    if (amount == null || amount < 0) return 'Enter a valid amount';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptsCod && !_acceptsOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one payment method switched on.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .update({
            'upiId': _upiId.text.trim(),
            'acceptsCod': _acceptsCod,
            'acceptsOnline': _acceptsOnline,
            'minOrderAmount': double.parse(_minOrderAmount.text.trim()),
            'deliveryFee': double.parse(_deliveryFee.text.trim()),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment settings saved.')),
      );
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save payment settings.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
