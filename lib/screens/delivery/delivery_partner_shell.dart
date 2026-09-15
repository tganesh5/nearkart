import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../common/order_contact_actions.dart';

class DeliveryPartnerShell extends ConsumerWidget {
  const DeliveryPartnerShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in again.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('assignedDeliveryPartnerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load assigned deliveries.'),
                  );
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
                  return const _EmptyDeliveries();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _DeliveryCard(orderId: order.id, data: order.data());
                  },
                );
              },
            ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.orderId, required this.data});

  final String orderId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'assigned').toString();
    final address = (data['deliveryAddress'] ?? 'Address unavailable')
        .toString();

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Icon(Icons.delivery_dining, color: AppColors.primary),
        ),
        title: Text(
          'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('$address\n${_formatStatus(status)}'),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                DeliveryOrderMapScreen(orderId: orderId, initialData: data),
          ),
        ),
      ),
    );
  }
}

/// Navigation and delivery completion for one order.
///
/// Used by the assigned delivery partner and, when a store delivers its own
/// orders, by the store manager — [viewer] only decides whom the contact
/// buttons offer to reach.
class DeliveryOrderMapScreen extends StatelessWidget {
  const DeliveryOrderMapScreen({
    super.key,
    required this.orderId,
    required this.initialData,
    this.viewer = OrderViewer.deliveryPartner,
  });

  final String orderId;
  final Map<String, dynamic> initialData;
  final OrderViewer viewer;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? initialData;
        final customerLocation = _readLocation(
          data,
          geoPointKey: 'deliveryLocation',
          latitudeKey: 'deliveryLatitude',
          longitudeKey: 'deliveryLongitude',
        );
        final storeLocation = _readLocation(
          data,
          geoPointKey: 'storeLocation',
          latitudeKey: 'storeLatitude',
          longitudeKey: 'storeLongitude',
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Delivery Details')),
          body: Column(
            children: [
              Expanded(
                flex: 3,
                child: customerLocation == null
                    ? const _MissingLocation()
                    : _LocationSummary(
                        customerLocation: customerLocation,
                        storeLocation: storeLocation,
                      ),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        (data['deliveryAddress'] ?? 'Address unavailable')
                            .toString(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data['customerName'] ?? 'Customer'} • '
                        '${_formatStatus((data['status'] ?? '').toString())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if ((data['deliveryNotes'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(data['deliveryNotes'].toString()),
                        ),
                      const SizedBox(height: 16),
                      OrderContactActions(
                        data: data,
                        viewer: viewer,
                        orderId: orderId,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: customerLocation == null
                            ? null
                            : () => _openNavigation(customerLocation),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate to customer'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _updateStatus(context, 'outForDelivery'),
                        icon: const Icon(Icons.delivery_dining),
                        label: const Text('Start delivery'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _updateStatus(context, 'delivered'),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark delivered'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openNavigation(_Coordinates destination) async {
    final nativeUri = Uri.parse(
      'google.navigation:q=${destination.latitude},'
      '${destination.longitude}&mode=d',
    );
    if (await canLaunchUrl(nativeUri)) {
      await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      return;
    }

    final webUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'driving',
    });
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
            if (status == 'delivered')
              'deliveredAt': FieldValue.serverTimestamp(),
          });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order marked ${_formatStatus(status)}.')),
      );
    } on FirebaseException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update this order.')),
      );
    }
  }
}

_Coordinates? _readLocation(
  Map<String, dynamic> data, {
  required String geoPointKey,
  required String latitudeKey,
  required String longitudeKey,
}) {
  final geoPoint = data[geoPointKey];
  if (geoPoint is GeoPoint) {
    return _Coordinates(geoPoint.latitude, geoPoint.longitude);
  }

  final latitude = data[latitudeKey];
  final longitude = data[longitudeKey];
  if (latitude is num && longitude is num) {
    return _Coordinates(latitude.toDouble(), longitude.toDouble());
  }
  return null;
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

class _Coordinates {
  const _Coordinates(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary({
    required this.customerLocation,
    required this.storeLocation,
  });

  final _Coordinates customerLocation;
  final _Coordinates? storeLocation;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primaryLight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.navigation_rounded,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Customer location ready',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${customerLocation.latitude.toStringAsFixed(5)}, '
                '${customerLocation.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (storeLocation != null) ...[
                const SizedBox(height: 6),
                const Text(
                  'Route starts from the configured store location.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDeliveries extends StatelessWidget {
  const _EmptyDeliveries();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('No deliveries assigned'),
        ],
      ),
    );
  }
}

class _MissingLocation extends StatelessWidget {
  const _MissingLocation();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.inputFill,
      child: Center(child: Text('Customer map location is unavailable.')),
    );
  }
}
