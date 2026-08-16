import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class VendorOrdersScreen extends StatelessWidget {
  const VendorOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Active (3)'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OrdersList(type: 'active'),
            _OrdersList(type: 'completed'),
            _OrdersList(type: 'cancelled'),
          ],
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final String type;

  const _OrdersList({required this.type});

  @override
  Widget build(BuildContext context) {
    if (type == 'cancelled') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No cancelled orders',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: type == 'active' ? 3 : 5,
      itemBuilder: (context, index) {
        return _OrderCard(
          orderId: '#${1040 + index}',
          customerName: ['Rahul Kumar', 'Priya Sharma', 'Amit Reddy', 'Deepa M.', 'Kiran S.'][index % 5],
          itemCount: 2 + index,
          total: (245 + index * 120).toDouble(),
          status: type == 'active'
              ? ['Confirmed', 'Preparing', 'Ready'][index % 3]
              : 'Delivered',
          time: '${10 + index} min ago',
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final String customerName;
  final int itemCount;
  final double total;
  final String status;
  final String time;

  const _OrderCard({
    required this.orderId,
    required this.customerName,
    required this.itemCount,
    required this.total,
    required this.status,
    required this.time,
  });

  Color get _statusColor {
    switch (status) {
      case 'Confirmed':
        return AppColors.delivery;
      case 'Preparing':
        return AppColors.warning;
      case 'Ready':
        return AppColors.success;
      case 'Delivered':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order $orderId',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(customerName, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              Text(time, style: TextStyle(color: AppColors.textHint, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$itemCount items',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          if (status != 'Delivered') ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Reject', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      status == 'Ready' ? 'Hand Over' : 'Next Step',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
