import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../common/order_contact_actions.dart';

const _openStatuses = ['placed', 'confirmed', 'preparing', 'readyForPickup',
  'outForDelivery'];

class CustomerOrdersScreen extends ConsumerWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: const Center(child: Text('Please sign in to see your orders.')),
      );
    }

    final orders = ref.watch(myOrdersProvider(uid));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'Active'), Tab(text: 'Past Orders')],
          ),
        ),
        body: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Center(child: Text('Unable to load your orders.')),
          data: (docs) {
            final active = docs
                .where(
                  (doc) => _openStatuses.contains(
                    (doc.data()['status'] ?? 'placed').toString(),
                  ),
                )
                .toList();
            final past = docs.where((doc) => !active.contains(doc)).toList();

            return TabBarView(
              children: [
                _OrderList(
                  docs: active,
                  emptyTitle: 'No active orders',
                  emptyHint: 'Your current orders will appear here',
                ),
                _OrderList(
                  docs: past,
                  emptyTitle: 'No past orders',
                  emptyHint: 'Delivered and cancelled orders appear here',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.docs,
    required this.emptyTitle,
    required this.emptyHint,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String emptyTitle;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              emptyHint,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) =>
          _OrderCard(orderId: docs[index].id, data: docs[index].data()),
    );
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  const _OrderCard({required this.orderId, required this.data});

  final String orderId;
  final Map<String, dynamic> data;

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _busy = false;

  /// Orders placed before store numbers were recorded have no `storePhone`.
  /// Store documents are readable by customers, so the live number can stand
  /// in for those. Only done for orders still in flight, to avoid a document
  /// listener per row in a long history.
  String? _liveStorePhone(Map<String, dynamic> data, bool isClosed) {
    if (isClosed) return null;
    if (data['storePhone']?.toString().trim().isNotEmpty == true) return null;
    final storeId = data['storeId']?.toString();
    if (storeId == null || storeId.isEmpty) return null;
    return ref.watch(storeByIdProvider(storeId)).value?.phone;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final status = (data['status'] ?? 'placed').toString();
    final items = (data['items'] as List<dynamic>? ?? const []);
    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final canCancel = ['placed', 'confirmed'].contains(status);
    final isClosed = status == 'delivered' || status == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data['storeName']?.toString().trim().isNotEmpty == true
                      ? data['storeName'].toString()
                      : 'Order '
                            '#${widget.orderId.substring(0, widget.orderId.length.clamp(0, 8))}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${items.length} item${items.length == 1 ? '' : 's'} • '
            '₹${total.toStringAsFixed(0)}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat('d MMM yyyy, h:mm a').format(createdAt),
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
          if (data['deliveryAddress']?.toString().trim().isNotEmpty ==
              true) ...[
            const SizedBox(height: 4),
            Text(
              data['deliveryAddress'].toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
          const Divider(height: 20),
          OrderContactActions(
            data: data,
            viewer: OrderViewer.customer,
            orderId: widget.orderId,
            fallbackStorePhone: _liveStorePhone(data, isClosed),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (canCancel)
                OutlinedButton(
                  onPressed: _busy ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Cancel order',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              if (isClosed) ...[
                OutlinedButton(
                  onPressed: _busy ? null : _reorder,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Reorder', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 12),
              ],
              if (status == 'delivered')
                TextButton(
                  onPressed: _busy ? null : _rate,
                  child: const Text(
                    'Rate Order',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              if (!canCancel && !isClosed)
                Text(
                  'The store is preparing this order.',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'The store will be notified. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      // Rules allow the customer to touch only these three keys.
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
            'cancelledAt': FieldValue.serverTimestamp(),
          });
      _message('Order cancelled.');
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'This order can no longer be cancelled.'
            : 'Could not cancel the order.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder() async {
    final storeId = widget.data['storeId']?.toString();
    final items = (widget.data['items'] as List<dynamic>? ?? const []);
    if (storeId == null || items.isEmpty) {
      _message('This order has no items to reorder.');
      return;
    }

    setState(() => _busy = true);
    try {
      // Re-read the catalogue so prices and availability are current.
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('storeId', isEqualTo: storeId)
          .get();
      final live = {
        for (final doc in snapshot.docs) doc.id: ProductModel.fromDoc(doc),
      };

      final cart = ref.read(cartProvider.notifier);
      cart.clearCart();

      var added = 0;
      var skipped = 0;
      for (final item in items) {
        if (item is! Map) continue;
        final product = live[item['productId']?.toString()];
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        if (product == null || !product.isAvailable || product.stockCount <= 0) {
          skipped++;
          continue;
        }
        cart.addItem(
          product,
          storeName: widget.data['storeName']?.toString(),
        );
        if (quantity > 1) cart.updateQuantity(product.id, quantity);
        added++;
      }

      if (added == 0) {
        _message('None of these items are available right now.');
        return;
      }
      _message(
        skipped == 0
            ? '$added item${added == 1 ? '' : 's'} added to your cart.'
            : '$added added, $skipped unavailable.',
      );
    } on FirebaseException {
      _message('Could not rebuild this order.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate() async {
    final result = await showDialog<({int rating, String comment})>(
      context: context,
      builder: (_) => const _RatingDialog(),
    );
    if (result == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('reviews').add({
        'customerId': uid,
        'orderId': widget.orderId,
        'storeId': widget.data['storeId'],
        'rating': result.rating,
        'comment': result.comment,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _message('Thanks for rating this order.');
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'Only the customer who placed this order can rate it.'
            : 'Could not save your rating.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate this order'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: AppColors.rating,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _comment,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comments (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            (rating: _rating, comment: _comment.text.trim()),
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'delivered' => AppColors.success,
      'cancelled' => AppColors.error,
      'readyForPickup' || 'outForDelivery' => AppColors.delivery,
      _ => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
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
