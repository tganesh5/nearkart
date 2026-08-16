import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Past Orders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ActiveOrders(),
            _PastOrders(),
          ],
        ),
      ),
    );
  }
}

class _ActiveOrders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No active orders',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Your current orders will appear here',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PastOrders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ['Krishna Kirana Store', 'Fresh Farm Veggies', 'Annapurna Sweets'][index],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Delivered',
                      style: TextStyle(fontSize: 11, color: AppColors.success),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${3 + index} items • ₹${(345 + index * 210).toStringAsFixed(0)}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '${7 + index} Jul 2026',
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Reorder', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Rate Order', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
