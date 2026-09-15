import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/phone_auth.dart';
import '../../providers/platform_settings_provider.dart';

/// Admin-only configuration of the platform fee and the account that receives
/// it.
///
/// The fee rule and payee UPI id are saved to `settings/platform`, which
/// customer devices read to build the payment request. Bank account details go
/// to `settings/platform_payout`, which security rules restrict to admins, so
/// they are never shipped to a shopper's device.
class PlatformSettingsScreen extends StatefulWidget {
  const PlatformSettingsScreen({super.key});

  @override
  State<PlatformSettingsScreen> createState() => _PlatformSettingsScreenState();
}

class _PlatformSettingsScreenState extends State<PlatformSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _feePercent = TextEditingController();
  final _minFee = TextEditingController();
  final _maxFee = TextEditingController();
  final _upiId = TextEditingController();
  final _payeeName = TextEditingController();

  final _companyName = TextEditingController();
  final _supportPhone = TextEditingController();
  final _supportEmail = TextEditingController();
  final _supportHours = TextEditingController();
  final _website = TextEditingController();
  final _registeredAddress = TextEditingController();

  final _legalName = TextEditingController();
  final _accountName = TextEditingController();
  final _bankName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _ifsc = TextEditingController();
  final _gstin = TextEditingController();
  final _pan = TextEditingController();
  final _cin = TextEditingController();

  bool _isFeeEnabled = true;
  bool _loading = true;
  bool _saving = false;
  bool _revealAccountNumber = false;
  String? _storedAccountNumber;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _feePercent,
      _minFee,
      _maxFee,
      _upiId,
      _payeeName,
      _companyName,
      _supportPhone,
      _supportEmail,
      _supportHours,
      _website,
      _registeredAddress,
      _legalName,
      _accountName,
      _bankName,
      _accountNumber,
      _ifsc,
      _gstin,
      _pan,
      _cin,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final db = FirebaseFirestore.instance;
    try {
      final fee = await db.doc(PlatformSettings.docPath).get();
      final payout = await db.doc(PlatformSettings.payoutDocPath).get();
      if (!mounted) return;

      final settings = PlatformSettings.fromMap(fee.data() ?? const {});
      final payoutData = payout.data() ?? const <String, dynamic>{};

      setState(() {
        _feePercent.text = _number(settings.feePercent);
        _minFee.text = _number(settings.minFee);
        _maxFee.text = settings.maxFee == null ? '' : _number(settings.maxFee!);
        _upiId.text = settings.upiId ?? '';
        _payeeName.text = settings.payeeName;
        _isFeeEnabled = settings.isFeeEnabled;

        _companyName.text = settings.companyName;
        _supportPhone.text = settings.supportPhone ?? '';
        _supportEmail.text = settings.supportEmail ?? '';
        _supportHours.text = settings.supportHours;
        _website.text = settings.website ?? '';
        _registeredAddress.text = settings.registeredAddress ?? '';

        _legalName.text = payoutData['legalName']?.toString() ?? '';
        _accountName.text = payoutData['accountName']?.toString() ?? '';
        _bankName.text = payoutData['bankName']?.toString() ?? '';
        _storedAccountNumber = payoutData['accountNumber']?.toString();
        _accountNumber.text = _storedAccountNumber ?? '';
        _ifsc.text = payoutData['ifsc']?.toString() ?? '';
        _gstin.text = payoutData['gstin']?.toString() ?? '';
        _pan.text = payoutData['pan']?.toString() ?? '';
        _cin.text = payoutData['cin']?.toString() ?? '';
        _loading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(
        error.code == 'permission-denied'
            ? 'Only an admin can view platform settings.'
            : 'Could not load platform settings.',
      );
    }
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company & fees')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionTitle('Company'),
                  const SizedBox(height: 4),
                  Text(
                    'Shown on Help & Support and on receipts. Support email '
                    'is optional.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _companyName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Brand name'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _supportPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Support phone',
                      prefixText: '+91 ',
                    ),
                    validator: (value) {
                      final digits = (value ?? '').replaceAll(
                        RegExp(r'\D'),
                        '',
                      );
                      if (digits.isEmpty) return null;
                      if (digits.length != 10) {
                        return 'Enter a 10-digit mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _supportEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Support email (optional)',
                    ),
                    validator: optionalEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _supportHours,
                    decoration: const InputDecoration(
                      labelText: 'Support hours',
                      hintText: '9 AM to 9 PM',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _website,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Website (optional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _registeredAddress,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Registered address (optional)',
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Convenience fee'),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile(
                      value: _isFeeEnabled,
                      onChanged: (value) =>
                          setState(() => _isFeeEnabled = value),
                      title: const Text('Charge a platform fee'),
                      subtitle: Text(
                        _isFeeEnabled
                            ? 'Added on top of the order at checkout'
                            : 'Customers pay the order amount only',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _feePercent,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Fee percentage',
                      suffixText: '%',
                      helperText: 'Percentage of the order value',
                    ),
                    // Keeps the sample-order preview below in step.
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final percent = double.tryParse((value ?? '').trim());
                      if (percent == null || percent < 0 || percent > 100) {
                        return 'Enter a percentage between 0 and 100';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minFee,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Minimum fee',
                            prefixText: '₹ ',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: _optionalAmount,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _maxFee,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Cap (optional)',
                            prefixText: '₹ ',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: _optionalAmount,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _FeePreview(
                    percent: double.tryParse(_feePercent.text.trim()) ?? 0,
                    minFee: double.tryParse(_minFee.text.trim()) ?? 0,
                    maxFee: double.tryParse(_maxFee.text.trim()),
                    enabled: _isFeeEnabled,
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Fee collection account'),
                  const SizedBox(height: 4),
                  Text(
                    'The UPI id customer devices pay the fee into. A UPI id is '
                    'a payee address, so it is safe to share.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _upiId,
                    decoration: const InputDecoration(
                      labelText: 'Platform UPI ID',
                      hintText: 'nearkart@okhdfcbank',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (!_isFeeEnabled) return null;
                      if (text.isEmpty) {
                        return 'Required while the fee is switched on';
                      }
                      if (!RegExp(
                        r'^[\w.\-]{2,}@[A-Za-z]{2,}$',
                      ).hasMatch(text)) {
                        return 'Enter a valid UPI ID like name@bank';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _payeeName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Payee name shown in the UPI app',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Bank account that receives platform fees'),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Visible to admins only. Never shared with '
                            'customers, stores or delivery partners.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _legalName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Legal entity name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _accountName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Account holder name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bankName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Bank name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _accountNumber,
                    keyboardType: TextInputType.number,
                    obscureText: !_revealAccountNumber,
                    decoration: InputDecoration(
                      labelText: 'Account number',
                      helperText: _storedAccountNumber == null
                          ? null
                          : 'Saved: ${_mask(_storedAccountNumber!)}',
                      suffixIcon: IconButton(
                        tooltip: _revealAccountNumber ? 'Hide' : 'Show',
                        icon: Icon(
                          _revealAccountNumber
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => _revealAccountNumber = !_revealAccountNumber,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final digits = (value ?? '').replaceAll(
                        RegExp(r'\D'),
                        '',
                      );
                      if (digits.isEmpty) return null;
                      if (digits.length < 8 || digits.length > 18) {
                        return 'Enter a valid account number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ifsc,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'IFSC code'),
                    validator: (value) {
                      final text = (value ?? '').trim().toUpperCase();
                      if (text.isEmpty) return null;
                      if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(text)) {
                        return 'Enter a valid IFSC like HDFC0001234';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _gstin,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'GSTIN (optional)',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim().toUpperCase();
                      if (text.isEmpty) return null;
                      if (text.length != 15) return 'GSTIN is 15 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pan,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'PAN (optional)',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim().toUpperCase();
                      if (text.isEmpty) return null;
                      if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(text)) {
                        return 'Enter a valid PAN like ABCDE1234F';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cin,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'CIN (optional)',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim().toUpperCase();
                      if (text.isEmpty) return null;
                      if (text.length < 8) return 'Enter a valid CIN';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save settings'),
                  ),
                ],
              ),
            ),
    );
  }

  static String _mask(String value) {
    if (value.length <= 4) return '••••';
    return '••••${value.substring(value.length - 4)}';
  }

  String? _optionalAmount(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final amount = double.tryParse(text);
    if (amount == null || amount < 0) return 'Enter a valid amount';
    return null;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final db = FirebaseFirestore.instance;
    final maxFee = double.tryParse(_maxFee.text.trim());

    try {
      await db.doc(PlatformSettings.docPath).set({
        'feePercent': double.parse(_feePercent.text.trim()),
        'minFee': double.tryParse(_minFee.text.trim()) ?? 0,
        'maxFee': maxFee,
        'isFeeEnabled': _isFeeEnabled,
        'upiId': _upiId.text.trim(),
        'payeeName': _payeeName.text.trim(),
        'companyName': _companyName.text.trim(),
        'supportPhone': _supportPhone.text.replaceAll(RegExp(r'\D'), ''),
        'supportEmail': displayEmail(_supportEmail.text),
        'supportHours': _supportHours.text.trim(),
        'website': _website.text.trim(),
        'registeredAddress': _registeredAddress.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await db.doc(PlatformSettings.payoutDocPath).set({
        'legalName': _legalName.text.trim(),
        'accountName': _accountName.text.trim(),
        'bankName': _bankName.text.trim(),
        'accountNumber': _accountNumber.text.replaceAll(RegExp(r'\D'), ''),
        'ifsc': _ifsc.text.trim().toUpperCase(),
        'gstin': _gstin.text.trim().toUpperCase(),
        'pan': _pan.text.trim().toUpperCase(),
        'cin': _cin.text.trim().toUpperCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(
        () => _storedAccountNumber = _accountNumber.text.replaceAll(
          RegExp(r'\D'),
          '',
        ),
      );
      _message('Platform settings saved.');
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'Only an admin can change platform settings.'
            : 'Could not save platform settings.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Shows what the current rule charges on a few sample baskets.
class _FeePreview extends StatelessWidget {
  const _FeePreview({
    required this.percent,
    required this.minFee,
    required this.maxFee,
    required this.enabled,
  });

  final double percent;
  final double minFee;
  final double? maxFee;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final settings = PlatformSettings(
      feePercent: percent,
      minFee: minFee,
      maxFee: maxFee,
      isFeeEnabled: enabled,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fee on a sample order',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          for (final amount in const [200.0, 800.0, 2500.0])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${amount.toStringAsFixed(0)} order',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '₹${settings.feeFor(amount).toStringAsFixed(2)} fee',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
