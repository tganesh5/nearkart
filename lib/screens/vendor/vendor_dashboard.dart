import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/store_provider.dart';

class VendorDashboard extends ConsumerWidget {
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenOrders;

  const VendorDashboard({super.key, this.onOpenProducts, this.onOpenOrders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications are coming soon.')),
            ),
          ),
        ],
      ),
      body: store.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Unable to load your store.')),
        data: (doc) {
          if (doc == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No store is assigned to this account yet. An admin needs '
                  'to create one and assign it to you.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _Dashboard(
            storeId: doc.id,
            storeData: doc.data(),
            onOpenProducts: onOpenProducts,
            onOpenOrders: onOpenOrders,
          );
        },
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({
    required this.storeId,
    required this.storeData,
    this.onOpenProducts,
    this.onOpenOrders,
  });

  final String storeId;
  final Map<String, dynamic> storeData;
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(storeOrdersProvider(storeId)).value ?? const [];
    final products = ref.watch(storeProductsProvider(storeId)).value ?? const [];

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfMonth = DateTime(now.year, now.month);

    var todaySales = 0.0;
    var monthSales = 0.0;
    var todayOrders = 0;
    var pendingOrders = 0;
    final customers = <String>{};

    for (final doc in orders) {
      final data = doc.data();
      final status = (data['status'] ?? 'placed').toString();
      final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      final customerId = data['customerId']?.toString();
      if (customerId != null && customerId.isNotEmpty) {
        customers.add(customerId);
      }
      // Orders still needing the store's attention.
      if (['placed', 'confirmed', 'preparing'].contains(status)) {
        pendingOrders++;
      }
      if (status == 'cancelled') continue;
      if (createdAt != null && !createdAt.isBefore(startOfDay)) {
        todaySales += total;
        todayOrders++;
      }
      if (createdAt != null && !createdAt.isBefore(startOfMonth)) {
        monthSales += total;
      }
    }

    final rating = (storeData['rating'] as num?)?.toDouble() ?? 0;
    final isOpen = storeData['isOpen'] != false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Welcome back!',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: isOpen
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            size: 8,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOpen ? 'Store Open' : 'Store Closed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  storeData['name']?.toString() ?? 'Your store',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _QuickStat(
                      label: "Today's Sales",
                      value: '₹${todaySales.toStringAsFixed(0)}',
                    ),
                    const SizedBox(width: 24),
                    _QuickStat(label: 'Orders', value: '$todayOrders'),
                    const SizedBox(width: 24),
                    _QuickStat(
                      label: 'Rating',
                      value: rating == 0
                          ? 'New'
                          : '${rating.toStringAsFixed(1)} ★',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Quick Stats',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.shopping_bag,
                  iconColor: AppColors.primary,
                  label: 'Total Products',
                  value: '${products.length}',
                  onTap: onOpenProducts,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.pending_actions,
                  iconColor: AppColors.warning,
                  label: 'Pending Orders',
                  value: '$pendingOrders',
                  onTap: onOpenOrders,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people_outline,
                  iconColor: AppColors.delivery,
                  label: 'Customers',
                  value: '${customers.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.trending_up,
                  iconColor: AppColors.success,
                  label: 'This Month',
                  value: '₹${monthSales.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (orders.isNotEmpty)
                TextButton(
                  onPressed: onOpenOrders,
                  child: const Text('View all'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No orders yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...orders.take(3).map(
              (doc) => _RecentOrderTile(
                orderId: doc.id,
                data: doc.data(),
                onTap: onOpenOrders,
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;

  const _QuickStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({
    required this.orderId,
    required this.data,
    this.onTap,
  });

  final String orderId;
  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'placed').toString();
    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    final customer = data['customerName']?.toString().trim();
    final statusColor = switch (status) {
      'delivered' => AppColors.success,
      'cancelled' => AppColors.error,
      'readyForPickup' || 'outForDelivery' => AppColors.delivery,
      _ => AppColors.warning,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer?.isNotEmpty == true ? customer! : 'Customer',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _formatStatus(status),
                        style: TextStyle(fontSize: 11, color: statusColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
