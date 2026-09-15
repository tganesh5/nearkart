import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/phone_auth.dart';
import '../models/user_model.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> tryAutoLogin() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    try {
      await _completeSession(firebaseUser);
    } catch (_) {
      // Profile fetch failed; splash will send them to login.
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: authEmailFromIdentifier(email),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Authentication failed. Please try again.',
        );
        return false;
      }

      // Auth already succeeded. A Firestore blip must not bounce the user
      // back to the login form as if the password were wrong.
      await _completeSession(firebaseUser, fallbackEmail: email);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: messageForAuthCode(e.code),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }

  Future<bool> loginWithFirebaseUser(User firebaseUser) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _ensureProfile(firebaseUser);
      await _completeSession(firebaseUser);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to complete sign-in.',
      );
      return false;
    }
  }

  /// Writes a customer profile the first time a Google account signs in.
  /// Failures are ignored here so a network blip cannot undo Auth.
  Future<void> _ensureProfile(User firebaseUser) async {
    try {
      final docRef = _firestore.collection('users').doc(firebaseUser.uid);
      final doc = await docRef.get();
      if (doc.exists) return;
      await docRef.set({
        'name': firebaseUser.displayName ?? '',
        'email': displayEmail(firebaseUser.email),
        'phone': firebaseUser.phoneNumber ?? '',
        'role': UserRole.customer.name,
        'status': AccountStatus.active.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Profile is created again from PhoneCapture or the next successful
      // session once Firestore is reachable.
    }
  }

  Future<void> _completeSession(
    User firebaseUser, {
    String? fallbackEmail,
  }) async {
    Map<String, dynamic>? data;
    try {
      data = (await _firestore.collection('users').doc(firebaseUser.uid).get())
          .data();
    } catch (_) {
      data = null;
    }

    state = AuthState(
      user: UserModel(
        id: firebaseUser.uid,
        name: data?['name'] ?? firebaseUser.displayName ?? '',
        phone: data?['phone'] ?? firebaseUser.phoneNumber ?? '',
        email: _visibleEmail(
          data?['email']?.toString(),
          firebaseUser.email,
          fallbackEmail,
        ),
        role: UserRole.fromStoredValue(data?['role']),
        status: AccountStatus.fromStoredValue(data?['status']),
        createdAt:
            (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ),
      isAuthenticated: true,
    );
  }

  /// Records a mobile number for the signed-in account. Needed because Google
  /// sign-in never supplies one, and orders are unusable without a contact
  /// number for every party.
  Future<bool> updatePhone(String phone) async {
    final user = state.user;
    final firebaseUser = _auth.currentUser;
    if (user == null || firebaseUser == null) {
      state = state.copyWith(error: 'Please sign in again.');
      return false;
    }

    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      state = state.copyWith(error: 'Enter a valid 10-digit mobile number');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'phone': digits,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      state = AuthState(
        user: user.copyWith(phone: digits),
        isAuthenticated: true,
      );
      return true;
    } on FirebaseException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.code == 'permission-denied'
            ? 'You do not have permission to change this number.'
            : 'Could not save your mobile number.',
      );
      return false;
    } catch (_) {
      // Never leave the caller stuck on a disabled button and a spinner.
      state = state.copyWith(
        isLoading: false,
        error: 'Could not save your mobile number. Please try again.',
      );
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    return _signUp(
      name: name,
      phone: phone,
      email: email,
      password: password,
      role: role,
    );
  }

  Future<bool> _signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
    required UserRole role,
    String? upiId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final validationError = _validateSignup(
      name,
      phone,
      email,
      password,
      upiId: upiId,
    );
    if (validationError != null) {
      state = state.copyWith(isLoading: false, error: validationError);
      return false;
    }

    try {
      final visibleEmail = displayEmail(email);
      final authEmail = visibleEmail.isEmpty
          ? phoneAuthEmail(phone.trim())
          : visibleEmail;

      final credential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Account creation failed.',
        );
        return false;
      }

      await firebaseUser.updateDisplayName(name.trim());
      final accountStatus = role == UserRole.customer
          ? AccountStatus.active
          : AccountStatus.pending;

      final userData = {
        'name': name.trim(),
        'phone': phone.trim(),
        'email': visibleEmail,
        'role': role.name,
        'status': accountStatus.name,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (upiId != null) userData['upiId'] = upiId.trim();

      await _firestore.collection('users').doc(firebaseUser.uid).set(userData);

      state = AuthState(
        user: UserModel(
          id: firebaseUser.uid,
          name: name.trim(),
          phone: phone.trim(),
          email: visibleEmail,
          role: role,
          status: accountStatus,
          createdAt: DateTime.now(),
        ),
        isAuthenticated: true,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: messageForAuthCode(e.code),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }

  Future<String?> getVendorUpiId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['upiId'] as String?;
  }

  String? _validateSignup(
    String name,
    String phone,
    String email,
    String password, {
    String? upiId,
  }) {
    if (name.trim().length < 2) return 'Name must be at least 2 characters';
    if (phone.length != 10 || !RegExp(r'^\d{10}$').hasMatch(phone)) {
      return 'Enter a valid 10-digit mobile number';
    }
    final emailError = optionalEmail(email);
    if (emailError != null) return emailError;
    if (password.length < 6) return 'Password must be at least 6 characters';
    if (upiId != null && !upiId.contains('@')) {
      return 'Enter a valid UPI ID (e.g., name@bank)';
    }
    return null;
  }

  String _visibleEmail(String? stored, String? authEmail, String? fallback) {
    for (final candidate in [stored, authEmail, fallback]) {
      final visible = displayEmail(candidate);
      if (visible.isNotEmpty) return visible;
    }
    return '';
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(error: messageForAuthCode(e.code));
      return false;
    } catch (_) {
      state = state.copyWith(
        error: 'Could not send the reset email. Check your connection.',
      );
      return false;
    }
  }

  String messageForAuthCode(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'network-request-failed':
        return 'Cannot reach NearKart. Check your internet connection '
            'and try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    state = AuthState();
  }

  Future<void> deleteAccount() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).delete();
      }
      await _auth.currentUser?.delete();
    } catch (_) {}
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
