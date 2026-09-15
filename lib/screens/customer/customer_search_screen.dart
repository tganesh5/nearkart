import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/store_model.dart';
import '../../providers/catalog_provider.dart';
import 'store_detail_screen.dart';

class CustomerSearchScreen extends ConsumerStatefulWidget {
  const CustomerSearchScreen({super.key, this.initialQuery});

  /// Set when arriving from a category, so the results are already filtered.
  final String? initialQuery;

  @override
  ConsumerState<CustomerSearchScreen> createState() =>
      _CustomerSearchScreenState();
}

class _CustomerSearchScreenState extends ConsumerState<CustomerSearchScreen> {
  late final _searchController = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  late String _query = widget.initialQuery?.trim() ?? '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StoreModel> _filter(List<StoreModel> stores) {
    if (_query.isEmpty) return stores;
    final needle = _query.toLowerCase();
    return stores
        .where(
          (store) =>
              store.name.toLowerCase().contains(needle) ||
              store.category.toLowerCase().contains(needle) ||
              (store.city?.toLowerCase().contains(needle) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(storesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialQuery?.trim().isNotEmpty == true
              ? widget.initialQuery!.trim()
              : 'Search',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'Search stores, products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (_query.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Popular Categories',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
                              'Grocery',
                              'Vegetables',
                              'Bakery',
                              'Pharmacy',
                              'Dairy',
                              'Electronics',
                            ]
                            .map(
                              (cat) => ActionChip(
                                label: Text(cat),
                                onPressed: () {
                                  _searchController.text = cat;
                                  setState(() => _query = cat);
                                },
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: stores.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('Unable to load stores.')),
              data: (allStores) {
                final filtered = _filter(allStores);
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        allStores.isEmpty
                            ? 'No stores are open on NearKart yet.'
                            : 'No stores in "$_query" yet. Try another '
                                  'category or search for a store by name.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final store = filtered[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryLight,
                        child: Icon(Icons.store, color: AppColors.primary),
                      ),
                      title: Text(store.name),
                      subtitle: Text(
                        store.isOpen
                            ? store.category
                            : '${store.category} • Closed',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: AppColors.rating,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            store.rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StoreDetailScreen(store: store),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
