import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

typedef UserDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Raised when an email or phone number matches more than one account, so the
/// admin is asked to disambiguate instead of a wrong manager being assigned.
class AmbiguousManagerException implements Exception {
  const AmbiguousManagerException(this.field);

  /// 'phone number' or 'email address', for use in a message.
  final String field;
}

/// Finds an account by email or phone so the admin never has to know the
/// Firestore document id. Returns null when nothing matches.
Future<UserDoc?> findManagerAccount(String value) async {
  final users = FirebaseFirestore.instance.collection('users');

  Future<UserDoc?> firstMatch(String field, String target) async {
    if (target.isEmpty) return null;
    // Fetch two so a shared phone number is reported rather than guessed at.
    final snapshot = await users.where(field, isEqualTo: target).limit(2).get();
    if (snapshot.docs.length > 1) {
      throw AmbiguousManagerException(
        field == 'phone' ? 'phone number' : 'email address',
      );
    }
    return snapshot.docs.isEmpty ? null : snapshot.docs.first;
  }

  if (value.contains('@')) {
    // Email signup keeps the typed casing, Google sign-in stores lowercase.
    return await firstMatch('email', value) ??
        await firstMatch('email', value.toLowerCase());
  }

  final digits = value.replaceAll(RegExp(r'\D'), '');
  final national = digits.length > 10
      ? digits.substring(digits.length - 10)
      : digits;
  return await firstMatch('phone', value) ??
      await firstMatch('phone', national);
}

/// 'vendor' is the legacy name for the store manager role.
bool isManagerRole(String? role) => role == 'storeManager' || role == 'vendor';

/// Asks before changing somebody's role, then makes them a store manager.
///
/// Returns false when the admin backs out, so the caller can abandon the whole
/// operation rather than assigning a store to an account that cannot open it.
Future<bool> ensureManagerRole(BuildContext context, UserDoc account) async {
  final data = account.data();
  final role = data['role']?.toString();
  if (isManagerRole(role)) return true;

  final name = data['name']?.toString().trim();
  final email = data['email']?.toString().trim();
  final label = name?.isNotEmpty == true
      ? name!
      : (email?.isNotEmpty == true ? email! : 'This account');

  final promote = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Make store manager?'),
      content: Text(
        '$label is currently ${role ?? 'not assigned a role'}. '
        'Assigning this store will change the role to store manager '
        'and activate the account.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Make manager'),
        ),
      ],
    ),
  );
  if (promote != true) return false;

  await account.reference.update({
    'role': 'storeManager',
    'status': 'active',
    'updatedAt': FieldValue.serverTimestamp(),
  });
  return true;
}
