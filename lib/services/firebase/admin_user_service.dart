import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/utils/phone_auth.dart';
import '../../models/user_model.dart';

/// A problem worth showing the admin verbatim.
class AdminUserException implements Exception {
  const AdminUserException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Account administration performed by an admin on somebody else's behalf.
class AdminUserService {
  /// Creates a sign-in account and its profile document, returning the new uid.
  ///
  /// The account is created through a second Firebase app because
  /// `createUserWithEmailAndPassword` signs in as the new user on whichever app
  /// it runs on — doing it on the default app would sign the admin out.
  ///
  /// When an email is supplied, the account is opened with a throwaway
  /// password from a secure generator and the person is emailed a reset
  /// link — the admin never learns it.
  ///
  /// When email is omitted they sign in with their mobile number, so the
  /// admin must set [initialPassword] and tell them once. That value is not
  /// stored after this call.
  Future<String> createAccount({
    required String name,
    String email = '',
    required String phone,
    required UserRole role,
    String? initialPassword,
    AccountStatus status = AccountStatus.active,
  }) async {
    final visibleEmail = displayEmail(email);
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      throw const AdminUserException('Enter a valid 10-digit mobile number');
    }
    if (visibleEmail.isEmpty &&
        (initialPassword == null || initialPassword.length < 6)) {
      throw const AdminUserException(
        'Set an initial password when the account has no email.',
      );
    }
    final authEmail = visibleEmail.isEmpty
        ? phoneAuthEmail(digits)
        : visibleEmail;
    final password = visibleEmail.isEmpty
        ? initialPassword!
        : _generateTransientPassword();

    final secondary = await Firebase.initializeApp(
      // Unique, so a previous failure that left an app behind cannot clash.
      name: 'adminUserCreation-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
      final created = credential.user;
      if (created == null) {
        throw const AdminUserException('Could not create the account.');
      }

      try {
        // Written with the admin's own session: security rules let an admin
        // choose the role and status, which self signup deliberately cannot.
        await FirebaseFirestore.instance
            .collection('users')
            .doc(created.uid)
            .set({
              'name': name.trim(),
              'email': visibleEmail,
              'phone': digits,
              'role': role.name,
              'status': status.name,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (error) {
        // Do not leave a sign-in account with no profile behind. The
        // credential is still valid here, which is why this runs before
        // signing the secondary app out.
        await created.delete().catchError((_) {});
        throw AdminUserException(
          error is FirebaseException && error.code == 'permission-denied'
              ? 'Only an admin can create accounts.'
              : 'Could not save the new profile.',
        );
      }

      await secondaryAuth.signOut();

      if (visibleEmail.isNotEmpty) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: visibleEmail);
      }

      return created.uid;
    } on FirebaseAuthException catch (error) {
      throw AdminUserException(switch (error.code) {
        'email-already-in-use' =>
          'That email address already has an account. Search for it instead.',
        'invalid-email' => 'That email address is not valid.',
        'operation-not-allowed' =>
          'Email sign-in is disabled for this project.',
        _ => 'Could not create the account.',
      });
    } finally {
      await secondary.delete();
    }
  }

  /// Emails a fresh password link, for somebody who cannot get in.
  Future<void> sendPasswordReset(String email) async {
    final visible = displayEmail(email);
    if (visible.isEmpty) {
      throw const AdminUserException(
        'This account has no email. They sign in with their mobile number.',
      );
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: visible);
    } on FirebaseAuthException {
      throw const AdminUserException('Could not send the reset email.');
    }
  }

  /// A single-use value that exists only long enough to open the account.
  ///
  /// Not a credential anyone holds: it is generated per call from
  /// [Random.secure], never persisted, never shown, and is replaced the moment
  /// the new user follows their reset link.
  String _generateTransientPassword() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%^&*';
    final random = Random.secure();
    return List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
