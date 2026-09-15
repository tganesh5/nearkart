import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/cart_provider.dart';
import 'customer_home_screen.dart';
import 'customer_search_screen.dart';
import '../cart/cart_screen.dart';
import '../orders/customer_orders_screen.dart';
import 'customer_profile_screen.dart';

class CustomerShell extends ConsumerStatefulWidget {
  const CustomerShell({super.key});

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell> {
  static const _searchTab = 1;

  int _currentIndex = 0;

  void _goToTab(int index) => setState(() => _currentIndex = index);

  Widget _screenFor(int index) {
    switch (index) {
      case 1:
        return const CustomerSearchScreen();
      case 2:
        return const CartScreen();
      case 3:
        return const CustomerOrdersScreen();
      case 4:
        return const CustomerProfileScreen();
      default:
        return CustomerHomeScreen(onSeeAllStores: () => _goToTab(_searchTab));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);

    return Scaffold(
      body: _screenFor(_currentIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _goToTab,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: AppColors.primary),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cartState.totalItems > 0,
              label: Text('${cartState.totalItems}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: cartState.totalItems > 0,
              label: Text('${cartState.totalItems}'),
              child: const Icon(Icons.shopping_cart, color: AppColors.primary),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppColors.primary),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
