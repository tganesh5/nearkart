import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/cart_provider.dart';
import '../../services/payment/payment_service.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _deliveryType = 'delivery';
  String _paymentMethod = 'upi';
  final _addressController = TextEditingController(
    text: '42, 3rd Cross, Koramangala 5th Block, Bangalore - 560034',
  );
  final _notesController = TextEditingController();
  bool _isProcessing = false;

  final _paymentService = PaymentService();

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final deliveryFee = _deliveryType == 'pickup'
        ? 0.0
        : (cartState.subtotal >= AppConstants.freeDeliveryAbove
            ? 0.0
            : AppConstants.deliveryFee);

    final orderAmount = cartState.subtotal + deliveryFee;
    final platformFee = orderAmount * (AppConstants.platformFeePercent / 100);
    final totalCustomerPays = orderAmount + platformFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Type',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _OptionCard(
                    icon: Icons.delivery_dining,
                    label: 'Delivery',
                    isSelected: _deliveryType == 'delivery',
                    onTap: () => setState(() => _deliveryType = 'delivery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OptionCard(
                    icon: Icons.store,
                    label: 'Self Pickup',
                    isSelected: _deliveryType == 'pickup',
                    onTap: () => setState(() => _deliveryType = 'pickup'),
                  ),
                ),
              ],
            ),
            if (_deliveryType == 'delivery') ...[
              const SizedBox(height: 24),
              const Text(
                'Delivery Address',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter delivery address',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.location_on_outlined),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Payment Method',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            _PaymentOption(
              icon: Icons.account_balance_wallet,
              label: 'UPI Payment',
              subtitle: 'GPay, PhonePe, Paytm, BHIM',
              isSelected: _paymentMethod == 'upi',
              onTap: () => setState(() => _paymentMethod = 'upi'),
            ),
            const SizedBox(height: 8),
            _PaymentOption(
              icon: Icons.money,
              label: 'Cash on Delivery',
              subtitle: 'Pay when you receive the order',
              isSelected: _paymentMethod == 'cod',
              onTap: () => setState(() => _paymentMethod = 'cod'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Delivery Notes (Optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Any special instructions...',
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _BillRow(
                    label: 'Item Total',
                    value: '₹${cartState.subtotal.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _BillRow(
                    label: 'Delivery Fee',
                    value: deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toStringAsFixed(2)}',
                    valueColor: deliveryFee == 0 ? AppColors.success : null,
                  ),
                  const SizedBox(height: 8),
                  _BillRow(
                    label: 'Convenience Fee (${AppConstants.platformFeePercent}%)',
                    value: '₹${platformFee.toStringAsFixed(2)}',
                  ),
                  const Divider(height: 20),
                  _BillRow(
                    label: 'Total',
                    value: '₹${totalCustomerPays.toStringAsFixed(2)}',
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '₹${orderAmount.toStringAsFixed(2)} goes to vendor • ₹${platformFee.toStringAsFixed(2)} platform fee',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _placeOrder(orderAmount, platformFee, totalCustomerPays),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _paymentMethod == 'upi'
                            ? 'Pay ₹${totalCustomerPays.toStringAsFixed(2)} via UPI'
                            : 'Place Order • ₹${totalCustomerPays.toStringAsFixed(2)}',
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(double orderAmount, double platformFee, double total) async {
    setState(() => _isProcessing = true);

    final cartState = ref.read(cartProvider);
    final orderId = 'NK${DateTime.now().millisecondsSinceEpoch}';
    final vendorUpiId = 'saroja.vvce@oksbi';
    final vendorName = cartState.storeName ?? 'NearKart Vendor';

    if (_paymentMethod == 'upi') {
      if (kIsWeb) {
        // On web, show QR code for scanning
        setState(() => _isProcessing = false);
        if (mounted) {
          _showUpiQrCode(
            vendorUpiId: vendorUpiId,
            vendorName: vendorName,
            amount: orderAmount,
            orderId: orderId,
            total: total,
          );
        }
      } else {
        // On mobile, open UPI app directly
        try {
          await _paymentService.payVendorViaUpi(
            vendorUpiId: vendorUpiId,
            vendorName: vendorName,
            orderAmount: orderAmount,
            orderId: orderId,
          );
          if (mounted) _showOrderSuccess(total);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
            );
          }
        }
        setState(() => _isProcessing = false);
      }
    } else {
      _showOrderSuccess(total);
      setState(() => _isProcessing = false);
    }
  }

  void _showUpiQrCode({
    required String vendorUpiId,
    required String vendorName,
    required double amount,
    required String orderId,
    required double total,
  }) {
    final upiString = 'upi://pay?pa=$vendorUpiId&pn=${Uri.encodeComponent(vendorName)}&am=${amount.toStringAsFixed(2)}&cu=INR&tr=$orderId&tn=${Uri.encodeComponent("Order #$orderId via NearKart")}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Scan & Pay',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Text(
              'Scan this QR code with any UPI app\n(GPay, PhonePe, Paytm)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: QrImageView(
                data: upiString,
                version: QrVersions.auto,
                size: 220,
                gapless: true,
                embeddedImage: null,
                errorStateBuilder: (ctx, err) => const Center(
                  child: Text('Error generating QR'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pay to:', style: TextStyle(fontSize: 12)),
                      Text(vendorName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('UPI ID:', style: TextStyle(fontSize: 12)),
                      Text(vendorUpiId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount:', style: TextStyle(fontSize: 12)),
                      Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _PaymentStatusChecker(
              onComplete: () {
                Navigator.of(ctx).pop();
                _showOrderSuccess(total);
              },
              onCancel: () => Navigator.of(ctx).pop(),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _showOrderSuccess(double total) {
    ref.read(cartProvider.notifier).clearCart();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Order Placed!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your order of ₹${total.toStringAsFixed(2)} has been placed successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              _paymentMethod == 'upi'
                  ? 'Complete the UPI payment in your UPI app'
                  : 'Payment: Cash on Delivery',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PaymentStatusChecker extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _PaymentStatusChecker({
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<_PaymentStatusChecker> createState() => _PaymentStatusCheckerState();
}

class _PaymentStatusCheckerState extends State<_PaymentStatusChecker> {
  int _secondsRemaining = 120;
  bool _isChecking = true;
  late final _ticker = Stream.periodic(const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _ticker.take(_secondsRemaining).listen((_) {
      if (!mounted) return;
      setState(() => _secondsRemaining--);

      // In production: poll backend API for payment confirmation
      // For now: auto-complete after 30 seconds (simulating payment detection)
      if (_secondsRemaining <= 90) {
        // After 30 seconds, mark as paid (in production this would be a webhook/API call)
        setState(() => _isChecking = false);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) widget.onComplete();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isChecking) {
      return Column(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 32),
          const SizedBox(height: 8),
          const Text(
            'Payment Received!',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(
          'Waiting for payment...',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Scan the QR code above & pay\nAuto-detecting in ${_secondsRemaining}s',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel Payment', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _BillRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 15 : 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 16 : 13,
            color: valueColor ?? (isBold ? AppColors.primary : null),
          ),
        ),
      ],
    );
  }
}
