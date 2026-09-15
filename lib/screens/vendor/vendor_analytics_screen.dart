import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class VendorAnalyticsScreen extends StatelessWidget {
  const VendorAnalyticsScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('storeId', isEqualTo: storeId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load analytics.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs.map((doc) => doc.data()).toList();
          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No orders yet. Analytics appear once customers start '
                  'ordering.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final stats = _Stats.from(orders);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.receipt_long,
                      color: AppColors.primary,
                      label: 'Total orders',
                      value: '${stats.totalOrders}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.currency_rupee,
                      color: AppColors.success,
                      label: 'Revenue delivered',
                      value: '₹${stats.deliveredRevenue.toStringAsFixed(0)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.trending_up,
                      color: AppColors.delivery,
                      label: 'Average order',
                      value: '₹${stats.averageOrder.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.people_outline,
                      color: AppColors.warning,
                      label: 'Customers',
                      value: '${stats.uniqueCustomers}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle('Orders by status'),
              const SizedBox(height: 8),
              _Panel(
                children: [
                  for (final entry in stats.byStatus.entries)
                    _BarRow(
                      label: _formatStatus(entry.key),
                      count: entry.value,
                      total: stats.totalOrders,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle('Top products'),
              const SizedBox(height: 8),
              _Panel(
                children: stats.topProducts.isEmpty
                    ? [const Text('No product data on these orders yet.')]
                    : [
                        for (final entry in stats.topProducts)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(entry.key)),
                                Text(
                                  '${entry.value} sold',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _Stats {
  _Stats({
    required this.totalOrders,
    required this.deliveredRevenue,
    required this.averageOrder,
    required this.uniqueCustomers,
    required this.byStatus,
    required this.topProducts,
  });

  final int totalOrders;
  final double deliveredRevenue;
  final double averageOrder;
  final int uniqueCustomers;
  final Map<String, int> byStatus;
  final List<MapEntry<String, int>> topProducts;

  factory _Stats.from(List<Map<String, dynamic>> orders) {
    final byStatus = <String, int>{};
    final customers = <String>{};
    final productCounts = <String, int>{};
    var deliveredRevenue = 0.0;
    var grossRevenue = 0.0;

    for (final order in orders) {
      final status = (order['status'] ?? 'placed').toString();
      byStatus[status] = (byStatus[status] ?? 0) + 1;

      final customerId = order['customerId']?.toString();
      if (customerId != null && customerId.isNotEmpty) {
        customers.add(customerId);
      }

      final total = (order['totalAmount'] as num?)?.toDouble() ?? 0;
      // Cancelled orders should not inflate takings.
      if (status != 'cancelled') grossRevenue += total;
      if (status == 'delivered') deliveredRevenue += total;

      for (final item in (order['items'] as List<dynamic>? ?? const [])) {
        if (item is! Map) continue;
        final name = item['name']?.toString();
        if (name == null || name.isEmpty) continue;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        productCounts[name] = (productCounts[name] ?? 0) + quantity;
      }
    }

    final billable = orders
        .where((order) => (order['status'] ?? '') != 'cancelled')
        .length;

    final top = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Stats(
      totalOrders: orders.length,
      deliveredRevenue: deliveredRevenue,
      averageOrder: billable == 0 ? 0 : grossRevenue / billable,
      uniqueCustomers: customers.length,
      byStatus: byStatus,
      topProducts: top.take(5).toList(),
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

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.inputFill,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
