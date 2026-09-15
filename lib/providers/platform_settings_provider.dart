import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platform fee rule and the account that collects it.
///
/// Lives at `settings/platform`, which is publicly readable because customer
/// devices need the fee rule and the payee UPI id to build a payment request.
/// A UPI id is a payee address, not a secret. Payout bank details are kept in
/// the admin-only `settings/platform_payout` document instead.
class PlatformSettings {
  const PlatformSettings({
    this.feePercent = 0.5,
    this.minFee = 0,
    this.maxFee,
    this.isFeeEnabled = true,
    this.upiId,
    this.payeeName = 'NearKart',
    this.companyName = 'NearKart',
    this.supportPhone,
    this.supportEmail,
    this.supportHours = '9 AM to 9 PM',
    this.website,
    this.registeredAddress,
  });

  final double feePercent;
  final double minFee;
  final double? maxFee;
  final bool isFeeEnabled;
  final String? upiId;
  final String payeeName;
  final String companyName;
  final String? supportPhone;
  final String? supportEmail;
  final String supportHours;
  final String? website;
  final String? registeredAddress;

  static const docPath = 'settings/platform';
  static const payoutDocPath = 'settings/platform_payout';

  factory PlatformSettings.fromMap(Map<String, dynamic> map) {
    return PlatformSettings(
      feePercent: (map['feePercent'] as num?)?.toDouble() ?? 0.5,
      minFee: (map['minFee'] as num?)?.toDouble() ?? 0,
      maxFee: (map['maxFee'] as num?)?.toDouble(),
      isFeeEnabled: map['isFeeEnabled'] != false,
      upiId: map['upiId']?.toString(),
      payeeName: map['payeeName']?.toString() ?? 'NearKart',
      companyName: map['companyName']?.toString() ?? 'NearKart',
      supportPhone: map['supportPhone']?.toString(),
      supportEmail: map['supportEmail']?.toString(),
      supportHours: map['supportHours']?.toString() ?? '9 AM to 9 PM',
      website: map['website']?.toString(),
      registeredAddress: map['registeredAddress']?.toString(),
    );
  }

  /// Fee charged on an order, clamped to the configured floor and ceiling.
  double feeFor(double orderAmount) {
    if (!isFeeEnabled || orderAmount <= 0) return 0;
    var fee = orderAmount * (feePercent / 100);
    if (fee < minFee) fee = minFee;
    final ceiling = maxFee;
    if (ceiling != null && ceiling > 0 && fee > ceiling) fee = ceiling;
    return double.parse(fee.toStringAsFixed(2));
  }

  /// True once an admin has recorded where the fee should be collected.
  bool get canCollectFee => isFeeEnabled && (upiId?.trim().isNotEmpty ?? false);

  Map<String, dynamic> toMap() => {
    'feePercent': feePercent,
    'minFee': minFee,
    'maxFee': maxFee,
    'isFeeEnabled': isFeeEnabled,
    'upiId': upiId,
    'payeeName': payeeName,
    'companyName': companyName,
    'supportPhone': supportPhone,
    'supportEmail': supportEmail,
    'supportHours': supportHours,
    'website': website,
    'registeredAddress': registeredAddress,
  };
}

/// Streams the platform fee configuration, falling back to defaults until an
/// admin saves one.
final platformSettingsProvider = StreamProvider<PlatformSettings>((ref) {
  return FirebaseFirestore.instance
      .doc(PlatformSettings.docPath)
      .snapshots()
      .map(
        (doc) => doc.exists
            ? PlatformSettings.fromMap(doc.data() ?? const {})
            : const PlatformSettings(),
      );
});
