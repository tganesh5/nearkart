import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../common/order_contact_actions.dart';
import '../delivery/delivery_partner_shell.dart';

class VendorOrdersScreen extends StatelessWidget {
  const VendorOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get(),
      builder: (context, storeSnapshot) {
        if (!storeSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (storeSnapshot.data!.docs.isEmpty) {
          return const Scaffold(
            appBar: _OrdersAppBar(),
            body: Center(child: Text('No store is assigned to this account.')),
          );
        }

        final store = storeSnapshot.data!.docs.first;
        return _StoreOrders(storeId: store.id, storeData: store.data());
      },
    );
  }
}

class _OrdersAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _OrdersAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(title: const Text('Orders'));
}

class _StoreOrders extends StatelessWidget {
  const _StoreOrders({required this.storeId, required this.storeData});

  final String storeId;
  final Map<String, dynamic> storeData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _OrdersAppBar(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('storeId', isEqualTo: storeId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load orders.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                aTime?.millisecondsSinceEpoch ?? 0,
              );
            });

          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _OrderCard(order: orders[index], storeData: storeData),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({required this.order, required this.storeData});

  final QueryDocumentSnapshot<Map<String, dynamic>> order;
  final Map<String, dynamic> storeData;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _updating = false;

  /// Whether this order is the store's own to deliver.
  ///
  /// True when the store is set up to deliver its own orders, and also when a
  /// delivery order never got a partner assigned — otherwise it would sit at
  /// "ready for pickup" forever with nobody able to take it further.
  bool get _storeDelivers {
    final data = widget.order.data();
    if (data['deliveryType'] != 'delivery') return false;

    final mode =
        (data['deliveryMode'] ?? widget.storeData['deliveryMode'] ?? '')
            .toString();
    if (mode == 'partner') return false;
    if (mode == 'self') return true;
    return data['assignedDeliveryPartnerId']?.toString().isEmpty ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.order.data();
    final status = (data['status'] ?? 'placed').toString();
    final items = data['items'] as List<dynamic>? ?? const [];
    final total = (data['totalAmount'] as num? ?? 0).toDouble();
    final storeDelivers = _storeDelivers;
    final nextStatus = _nextStatus(status, storeDelivers: storeDelivers);
    final onTheWay = status == 'readyForPickup' || status == 'outForDelivery';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${widget.order.id}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              (data['customerName'] ?? 'Customer').toString(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text((data['deliveryAddress'] ?? 'Pickup order').toString()),
            const SizedBox(height: 8),
            Text('${items.length} items • ₹${total.toStringAsFixed(2)}'),
            if (data['assignedDeliveryPartnerId'] != null) ...[
              const SizedBox(height: 6),
              Text(
                data['deliveryPartnerName'] == null
                    ? 'Delivery partner assigned'
                    : '${data['deliveryPartnerName']} is delivering',
                style: const TextStyle(color: AppColors.success),
              ),
            ],
            const SizedBox(height: 12),
            OrderContactActions(
              data: data,
              viewer: OrderViewer.store,
              orderId: widget.order.id,
            ),
            if (storeDelivers && onTheWay) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeliveryOrderMapScreen(
                      orderId: widget.order.id,
                      initialData: data,
                      viewer: OrderViewer.store,
                    ),
                  ),
                ),
                icon: const Icon(Icons.navigation_outlined, size: 18),
                label: const Text('Navigate & deliver'),
              ),
            ],
            if (nextStatus != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  // An order already on its way can no longer be called off.
                  if (status != 'outForDelivery') ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _updating
                            ? null
                            : () => _updateStatus('cancelled'),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _updating
                          ? null
                          : () => _updateStatus(nextStatus),
                      child: Text(_actionLabel(nextStatus)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updating = true);
    try {
      final data = widget.order.data();
      final update = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (status == 'delivered') 'deliveredAt': FieldValue.serverTimestamp(),
      };

      var partnerId = data['assignedDeliveryPartnerId']?.toString();
      if (status == 'readyForPickup' &&
          data['deliveryType'] == 'delivery' &&
          widget.storeData['deliveryMode'] != 'partner' &&
          widget.storeData['deliveryPartnerId'] != null) {
        partnerId = widget.storeData['deliveryPartnerId'].toString();
        update['assignedDeliveryPartnerId'] = partnerId;
      }

      // Only a store manager may read a delivery partner's profile, so the
      // store is the one that copies their contact onto the order. Without
      // this the customer would have no way to call their rider.
      if (partnerId != null &&
          partnerId.isNotEmpty &&
          (data['deliveryPartnerPhone']?.toString().isEmpty ?? true)) {
        final contact = await _partnerContact(partnerId);
        if (contact != null) {
          update['deliveryPartnerName'] = contact['name'];
          update['deliveryPartnerPhone'] = contact['phone'];
        }
      }

      await widget.order.reference.update(update);
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update the order.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<Map<String, String>?> _partnerContact(String partnerId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(partnerId)
          .get();
      final data = doc.data();
      final phone = data?['phone']?.toString() ?? '';
      if (phone.isEmpty) return null;
      return {
        'name': data?['name']?.toString() ?? 'Delivery partner',
        'phone': phone,
      };
    } on FirebaseException {
      // A missing contact must not block the status change.
      return null;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'cancelled' => AppColors.error,
      'delivered' => AppColors.success,
      'readyForPickup' || 'outForDelivery' => AppColors.delivery,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}

/// The next step the store can take. A store delivering its own orders carries
/// them all the way to delivered; otherwise the handover ends at ready.
String? _nextStatus(String status, {required bool storeDelivers}) {
  return switch (status) {
    'placed' => 'confirmed',
    'confirmed' => 'preparing',
    'preparing' => 'readyForPickup',
    'readyForPickup' => storeDelivers ? 'outForDelivery' : null,
    'outForDelivery' => storeDelivers ? 'delivered' : null,
    _ => null,
  };
}

String _actionLabel(String status) {
  return switch (status) {
    'confirmed' => 'Confirm',
    'preparing' => 'Start preparing',
    'readyForPickup' => 'Ready',
    'outForDelivery' => 'Start delivery',
    'delivered' => 'Mark delivered',
    _ => 'Next',
  };
}

String _formatStatus(String value) {
  return value
      .replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => ' ${match.group(1)!.toLowerCase()}',
      )
      .replaceFirstMapped(
        RegExp(r'^.'),
        (match) => match.group(0)!.toUpperCase(),
      );
}
