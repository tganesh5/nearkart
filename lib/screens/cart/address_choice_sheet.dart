import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/catalog_provider.dart';
import '../customer/my_addresses_screen.dart';

/// An address the customer picked, ready to drop into checkout.
class ChosenAddress {
  const ChosenAddress({
    required this.address,
    this.latitude,
    this.longitude,
    this.notes,
  });

  final String address;
  final double? latitude;
  final double? longitude;
  final String? notes;

  bool get hasLocation => latitude != null && longitude != null;
}

/// Lets the customer reuse a saved address or one they have had an order
/// delivered to before, instead of retyping it at every checkout.
Future<ChosenAddress?> showAddressChoiceSheet(
  BuildContext context, {
  required String uid,
}) {
  return showModalBottomSheet<ChosenAddress>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddressChoiceSheet(uid: uid),
  );
}

class _AddressChoiceSheet extends ConsumerWidget {
  const _AddressChoiceSheet({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Deliver to',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Held on to because this context is gone once the sheet
                    // has been popped.
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => const MyAddressesScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _SavedAddresses(uid: uid),
            const SizedBox(height: 16),
            _RecentLocations(uid: uid),
          ],
        ),
      ),
    );
  }
}

class _SavedAddresses extends StatelessWidget {
  const _SavedAddresses({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _SectionShell(
            title: 'Saved addresses',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const _SectionShell(
            title: 'Saved addresses',
            child: _Hint(
              'Nothing saved yet. Use Manage to add home and work addresses '
              'for faster checkout.',
            ),
          );
        }

        return _SectionShell(
          title: 'Saved addresses',
          child: Column(
            children: [
              for (final doc in docs)
                _AddressTile(
                  icon: _iconFor(doc.data()['label']?.toString()),
                  title: doc.data()['label']?.toString() ?? 'Address',
                  subtitle: doc.data()['address']?.toString() ?? '',
                  hasLocation: doc.data()['location'] is GeoPoint,
                  onTap: () {
                    final data = doc.data();
                    final location = data['location'];
                    Navigator.pop(
                      context,
                      ChosenAddress(
                        address: data['address']?.toString() ?? '',
                        latitude: location is GeoPoint
                            ? location.latitude
                            : null,
                        longitude: location is GeoPoint
                            ? location.longitude
                            : null,
                        notes: data['notes']?.toString(),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  static IconData _iconFor(String? label) {
    return switch (label?.toLowerCase()) {
      'home' => Icons.home_outlined,
      'work' || 'office' => Icons.work_outline,
      _ => Icons.location_on_outlined,
    };
  }
}

/// Places previous orders went to.
///
/// Taken from the customer's own orders rather than a separate history, so
/// there is nothing extra to keep in step and nothing new to store.
class _RecentLocations extends ConsumerWidget {
  const _RecentLocations({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider(uid));

    return orders.when(
      loading: () => const _SectionShell(
        title: 'Recent locations',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const _SectionShell(
        title: 'Recent locations',
        child: _Hint('Could not load recent locations.'),
      ),
      data: (docs) {
        final recent = <ChosenAddress>[];
        final seen = <String>{};

        // Already newest first. One entry per distinct address, capped so the
        // sheet stays a short list rather than an order history.
        for (final doc in docs) {
          final data = doc.data();
          if (data['deliveryType'] != 'delivery') continue;
          final address = data['deliveryAddress']?.toString().trim() ?? '';
          if (address.isEmpty || !seen.add(address.toLowerCase())) continue;

          final location = data['deliveryLocation'];
          recent.add(
            ChosenAddress(
              address: address,
              latitude: location is GeoPoint ? location.latitude : null,
              longitude: location is GeoPoint ? location.longitude : null,
            ),
          );
          if (recent.length == 5) break;
        }

        if (recent.isEmpty) {
          return const _SectionShell(
            title: 'Recent locations',
            child: _Hint('Addresses you have ordered to will show up here.'),
          );
        }

        return _SectionShell(
          title: 'Recent locations',
          child: Column(
            children: [
              for (final entry in recent)
                _AddressTile(
                  icon: Icons.history,
                  title: entry.address,
                  hasLocation: entry.hasLocation,
                  onTap: () => Navigator.pop(context, entry),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.icon,
    required this.title,
    required this.hasLocation,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool hasLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        [
          if (subtitle?.trim().isNotEmpty == true) subtitle!.trim(),
          // The order needs a map pin, so say when one is missing instead of
          // letting checkout reject it later.
          if (!hasLocation) 'No map pin saved — set it on the map',
        ].join('\n'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: hasLocation ? AppColors.textSecondary : AppColors.warning,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: AppColors.textHint),
      ),
    );
  }
}
