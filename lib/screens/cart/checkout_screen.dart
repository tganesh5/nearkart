import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/cart_provider.dart';
import '../../core/exceptions/app_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../services/location/location_service.dart';
import '../common/location_picker_screen.dart';
import '../../services/payment/payment_service.dart';
import 'address_choice_sheet.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _deliveryType = 'delivery';
  String _paymentMethod = 'upi';
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isProcessing = false;
  double? _deliveryLatitude;
  double? _deliveryLongitude;

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
    // The fee rule is set by an admin in Platform & fees; the constant is only
    // a fallback for the first load before settings arrive.
    final platformSettings =
        ref.watch(platformSettingsProvider).value ?? const PlatformSettings();
    final platformFee = platformSettings.feeFor(orderAmount);
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
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : _chooseSavedAddress,
                icon: const Icon(Icons.bookmark_border),
                label: const Text('Saved & recent addresses'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _chooseOnMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Choose on map'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _useCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use my location'),
                    ),
                  ),
                ],
              ),
              if (_deliveryLatitude != null && _deliveryLongitude != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pin set at '
                        '${_deliveryLatitude!.toStringAsFixed(5)}, '
                        '${_deliveryLongitude!.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
                    value: deliveryFee == 0
                        ? 'FREE'
                        : '₹${deliveryFee.toStringAsFixed(2)}',
                    valueColor: deliveryFee == 0 ? AppColors.success : null,
                  ),
                  if (platformFee > 0) ...[
                    const SizedBox(height: 8),
                    _BillRow(
                      label:
                          'Convenience Fee '
                          '(${platformSettings.feePercent}%)',
                      value: '₹${platformFee.toStringAsFixed(2)}',
                    ),
                  ],
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
                platformFee > 0
                    ? '₹${orderAmount.toStringAsFixed(2)} goes to vendor • '
                          '₹${platformFee.toStringAsFixed(2)} platform fee'
                    : '₹${orderAmount.toStringAsFixed(2)} goes to vendor',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () => _placeOrder(
                        orderAmount,
                        platformFee,
                        totalCustomerPays,
                      ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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

  Future<void> _placeOrder(
    double orderAmount,
    double platformFee,
    double total,
  ) async {
    final cartState = ref.read(cartProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || cartState.storeId == null || cartState.items.isEmpty) {
      _showError('Your session or cart is no longer valid.');
      return;
    }
    if (_deliveryType == 'delivery' &&
        (_addressController.text.trim().isEmpty ||
            _deliveryLatitude == null ||
            _deliveryLongitude == null)) {
      _showError('Add the delivery address and map location.');
      return;
    }

    setState(() => _isProcessing = true);

    final orderId = 'NK${DateTime.now().millisecondsSinceEpoch}';
    try {
      final store = await FirebaseFirestore.instance
          .collection('stores')
          .doc(cartState.storeId)
          .get();
      if (!store.exists) {
        _showError('This store is no longer available.');
        return;
      }
      final storeData = store.data()!;
      final vendorUpiId = (storeData['upiId'] ?? '').toString();
      final vendorName =
          (storeData['name'] ?? cartState.storeName ?? 'NearKart Store')
              .toString();

      Future<bool> saveOrder() => _persistOrder(
        orderId: orderId,
        orderAmount: orderAmount,
        platformFee: platformFee,
        total: total,
        storeData: storeData,
      );

      if (_paymentMethod == 'upi') {
        if (vendorUpiId.isEmpty) {
          _showError('UPI is not configured for this store.');
        } else if (kIsWeb) {
          setState(() => _isProcessing = false);
          if (mounted) {
            _showUpiQrCode(
              vendorUpiId: vendorUpiId,
              vendorName: vendorName,
              amount: orderAmount,
              orderId: orderId,
              total: total,
              onPaymentComplete: saveOrder,
            );
          }
        } else {
          await _paymentService.payVendorViaUpi(
            vendorUpiId: vendorUpiId,
            vendorName: vendorName,
            orderAmount: orderAmount,
            orderId: orderId,
          );
          if (await saveOrder() && mounted) _showOrderSuccess(total);
        }
      } else {
        if (await saveOrder() && mounted) _showOrderSuccess(total);
      }
    } catch (_) {
      _showError('Unable to place the order. Please try again.');
    } finally {
      if (mounted && _isProcessing) setState(() => _isProcessing = false);
    }
  }

  /// Reuses an address the customer has saved or ordered to before.
  Future<void> _chooseSavedAddress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showError('Please sign in again.');
      return;
    }

    final chosen = await showAddressChoiceSheet(context, uid: uid);
    if (chosen == null || !mounted) return;

    setState(() {
      _addressController.text = chosen.address;
      if (chosen.hasLocation) {
        _deliveryLatitude = chosen.latitude;
        _deliveryLongitude = chosen.longitude;
      }
      final notes = chosen.notes?.trim() ?? '';
      if (notes.isNotEmpty && _notesController.text.trim().isEmpty) {
        _notesController.text = notes;
      }
    });

    // An address saved without a pin cannot be ordered to, so go straight to
    // the map rather than failing when they press Place order.
    if (!chosen.hasLocation) {
      _showError('That address has no map pin. Set it on the map.');
      await _chooseOnMap();
    }
  }

  /// Picking on the map needs no GPS fix at all, so it stays responsive even
  /// where location services are slow or unavailable.
  Future<void> _chooseOnMap() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: 'Delivery location',
          initialLatitude: _deliveryLatitude,
          initialLongitude: _deliveryLongitude,
          initialQuery: _addressController.text,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _deliveryLatitude = picked.latitude;
      _deliveryLongitude = picked.longitude;
      if (_addressController.text.trim().isEmpty && picked.address != null) {
        _addressController.text = picked.address!;
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isProcessing = true);
    try {
      final location = await LocationService().getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _deliveryLatitude = location.latitude;
        _deliveryLongitude = location.longitude;
        // Keep whatever the customer typed if no address could be resolved.
        if (location.address?.isNotEmpty == true) {
          _addressController.text = location.address!;
        }
      });
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Unable to get your location. Choose it on the map instead.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool> _persistOrder({
    required String orderId,
    required double orderAmount,
    required double platformFee,
    required double total,
    required Map<String, dynamic> storeData,
  }) async {
    final cartState = ref.read(cartProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || cartState.storeId == null) return false;

    // The contact details come from the signed-in profile, not from the
    // Firebase Auth record: email and Google sign-in never populate
    // phoneNumber there, so it would always be blank.
    final profile = ref.read(authProvider).user;

    final storeLatitude = storeData['latitude'];
    final storeLongitude = storeData['longitude'];
    await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
      'customerId': user.uid,
      'customerName': profile?.name ?? user.displayName ?? '',
      'customerPhone': profile?.phone ?? '',
      'storeId': cartState.storeId,
      'storeName': storeData['name'] ?? cartState.storeName ?? '',
      // Copied so the customer and the delivery partner can call the store
      // without needing to read the store document.
      'storePhone': storeData['phone']?.toString() ?? '',
      'items': cartState.items
          .map(
            (item) => {
              'productId': item.product.id,
              'name': item.product.name,
              'price': item.product.price,
              'quantity': item.quantity,
            },
          )
          .toList(),
      'subtotal': cartState.subtotal,
      'deliveryFee': orderAmount - cartState.subtotal,
      'platformFee': platformFee,
      'totalAmount': total,
      'status': 'placed',
      'deliveryType': _deliveryType,
      'deliveryAddress': _deliveryType == 'delivery'
          ? _addressController.text.trim()
          : storeData['address'] ?? '',
      'deliveryNotes': _notesController.text.trim(),
      if (_deliveryLatitude != null && _deliveryLongitude != null)
        'deliveryLocation': GeoPoint(_deliveryLatitude!, _deliveryLongitude!),
      if (storeLatitude is num && storeLongitude is num)
        'storeLocation': GeoPoint(
          storeLatitude.toDouble(),
          storeLongitude.toDouble(),
        ),
      'deliveryMode': storeData['deliveryMode'] ?? 'own',
      if (storeData['deliveryMode'] != 'partner' &&
          storeData['deliveryPartnerId'] != null)
        'assignedDeliveryPartnerId': storeData['deliveryPartnerId'],
      'paymentMethod': _paymentMethod,
      'paymentStatus': 'pending',
      'isPaid': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showUpiQrCode({
    required String vendorUpiId,
    required String vendorName,
    required double amount,
    required String orderId,
    required double total,
    required Future<bool> Function() onPaymentComplete,
  }) {
    final upiString =
        'upi://pay?pa=$vendorUpiId&pn=${Uri.encodeComponent(vendorName)}&am=${amount.toStringAsFixed(2)}&cu=INR&tr=$orderId&tn=${Uri.encodeComponent("Order #$orderId via NearKart")}';

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
                  errorStateBuilder: (ctx, err) =>
                      const Center(child: Text('Error generating QR')),
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
                        Text(
                          vendorName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('UPI ID:', style: TextStyle(fontSize: 12)),
                        Text(
                          vendorUpiId,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount:', style: TextStyle(fontSize: 12)),
                        Text(
                          '₹${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _PaymentStatusChecker(
                onComplete: () async {
                  Navigator.of(ctx).pop();
                  if (await onPaymentComplete() && mounted) {
                    _showOrderSuccess(total);
                  }
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
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 40,
              ),
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
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
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
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
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
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 20,
              ),
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
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
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
          child: const Text(
            'Cancel Payment',
            style: TextStyle(color: AppColors.error),
          ),
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
