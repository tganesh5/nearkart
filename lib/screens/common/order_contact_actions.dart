import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';

/// Who is looking at the order, which decides whom they may call.
enum OrderViewer { customer, store, deliveryPartner }

/// Call buttons for the other parties on an order.
///
/// Numbers are read from the order document rather than from `users`, because
/// security rules deliberately stop a customer reading a store manager's or
/// delivery partner's profile. Each number is copied onto the order by whoever
/// is allowed to see it: the customer writes their own at checkout, and the
/// store writes the delivery partner's when it assigns them.
class OrderContactActions extends StatelessWidget {
  const OrderContactActions({
    super.key,
    required this.data,
    required this.viewer,
    this.orderId,
    this.fallbackStorePhone,
  });

  final Map<String, dynamic> data;
  final OrderViewer viewer;

  /// Only used to open a chat that says which order it is about.
  final String? orderId;

  /// Used for orders placed before store numbers were copied onto the order.
  final String? fallbackStorePhone;

  /// The other parties this viewer is allowed to contact, in call order.
  List<_Contact> get _contacts {
    final customer = _Contact(
      label: _name('customerName', 'Customer'),
      role: 'Customer',
      phone: _phone('customerPhone'),
      icon: Icons.person_outline,
    );
    final storePhone = _phone('storePhone');
    final store = _Contact(
      label: _name('storeName', 'Store'),
      role: 'Store',
      phone: storePhone.isNotEmpty
          ? storePhone
          : normalisePhone(fallbackStorePhone),
      icon: Icons.storefront_outlined,
    );
    final partner = _Contact(
      label: _name('deliveryPartnerName', 'Delivery partner'),
      role: 'Delivery partner',
      phone: _phone('deliveryPartnerPhone'),
      icon: Icons.delivery_dining_outlined,
    );

    return switch (viewer) {
      OrderViewer.customer => [store, partner],
      OrderViewer.store => [customer, partner],
      OrderViewer.deliveryPartner => [customer, store],
    };
  }

  String _name(String key, String fallback) {
    final value = data[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  String _phone(String key) => normalisePhone(data[key]?.toString());

  /// Turns a stored number into something a dialler accepts. Numbers are
  /// captured as 10 local digits, so the country code is added back here
  /// rather than being stored in a second format.
  static String normalisePhone(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.startsWith('+')) {
      return trimmed.replaceAll(RegExp(r'[^\d+]'), '');
    }
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return digits;
  }

  @override
  Widget build(BuildContext context) {
    // A delivery partner is only relevant once one is on the order.
    final reachable = _contacts
        .where((contact) => contact.phone.isNotEmpty)
        .toList();

    if (reachable.isEmpty) {
      return Text(
        'No contact number recorded for this order yet.',
        style: TextStyle(fontSize: 12, color: AppColors.textHint),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final contact in reachable)
          _ContactButtons(
            contact: contact,
            onCall: () => _call(context, contact),
            onChat: () => _chat(context, contact),
          ),
      ],
    );
  }

  Future<void> _call(BuildContext context, _Contact contact) async {
    await _launch(context, contact, Uri(scheme: 'tel', path: contact.phone));
  }

  /// Opens WhatsApp for this number. wa.me works whether or not the app is
  /// installed, falling back to the browser, which is why it is preferred over
  /// the whatsapp:// scheme.
  Future<void> _chat(BuildContext context, _Contact contact) async {
    final digits = contact.phone.replaceAll(RegExp(r'\D'), '');
    final order = orderId?.trim() ?? '';
    await _launch(
      context,
      contact,
      Uri.https('wa.me', '/$digits', {
        'text': order.isEmpty
            ? 'Hi, I am contacting you about a NearKart order.'
            : 'Hi, this is about NearKart order #$order.',
      }),
    );
  }

  Future<void> _launch(BuildContext context, _Contact contact, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showNumber(context, contact);
      }
    } on Exception {
      if (context.mounted) _showNumber(context, contact);
    }
  }

  /// Falls back to showing the number when no dialler is available, so the
  /// call can still be made by hand.
  void _showNumber(BuildContext context, _Contact contact) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(contact.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contact.role, style: TextStyle(color: AppColors.textHint)),
            const SizedBox(height: 8),
            SelectableText(contact.phone, style: const TextStyle(fontSize: 18)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Contact {
  const _Contact({
    required this.label,
    required this.role,
    required this.phone,
    required this.icon,
  });

  final String label;
  final String role;
  final String phone;
  final IconData icon;
}

class _ContactButtons extends StatelessWidget {
  const _ContactButtons({
    required this.contact,
    required this.onCall,
    required this.onChat,
  });

  final _Contact contact;
  final VoidCallback onCall;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final role = contact.role.toLowerCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: onCall,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            foregroundColor: AppColors.primary,
          ),
          icon: Icon(contact.icon, size: 18),
          label: Text('Call $role', style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: onChat,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            foregroundColor: AppColors.success,
            minimumSize: const Size(0, 40),
          ),
          child: Tooltip(
            message: 'WhatsApp $role',
            child: const Icon(Icons.chat_outlined, size: 18),
          ),
        ),
      ],
    );
  }
}
