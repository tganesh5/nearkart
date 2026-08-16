import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      final doc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        state = AuthState(
          user: UserModel(
            id: firebaseUser.uid,
            name: data['name'] ?? firebaseUser.displayName ?? '',
            phone: data['phone'] ?? '',
            email: firebaseUser.email ?? '',
            role: data['role'] == 'vendor' ? UserRole.vendor : UserRole.customer,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
          ),
          isAuthenticated: true,
        );
      }
    } catch (_) {
      // Firestore fetch failed; user stays logged out
    }
  }

  Future<bool> login(String email, String password, UserRole role) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
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

      final doc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();
      final data = doc.data();

      state = AuthState(
        user: UserModel(
          id: firebaseUser.uid,
          name: data?['name'] ?? firebaseUser.displayName ?? '',
          phone: data?['phone'] ?? '',
          email: firebaseUser.email ?? email,
          role: data?['role'] == 'vendor' ? UserRole.vendor : UserRole.customer,
          createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
        ),
        isAuthenticated: true,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _mapAuthError(e.code),
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

  Future<bool> loginWithFirebaseUser(User firebaseUser, UserRole role) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final docRef = _firestore.collection('users').doc(firebaseUser.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'name': firebaseUser.displayName ?? '',
          'email': firebaseUser.email ?? '',
          'phone': firebaseUser.phoneNumber ?? '',
          'role': role.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final data = doc.exists ? doc.data() : null;

      state = AuthState(
        user: UserModel(
          id: firebaseUser.uid,
          name: data?['name'] ?? firebaseUser.displayName ?? '',
          phone: data?['phone'] ?? firebaseUser.phoneNumber ?? '',
          email: firebaseUser.email ?? '',
          role: data?['role'] == 'vendor' ? UserRole.vendor : UserRole.customer,
          createdAt: DateTime.now(),
        ),
        isAuthenticated: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to complete sign-in.',
      );
      return false;
    }
  }

  Future<bool> signUpVendor({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String upiId,
  }) async {
    return _signUp(
      name: name,
      phone: phone,
      email: email,
      password: password,
      role: UserRole.vendor,
      upiId: upiId,
    );
  }

  Future<bool> signUpCustomer({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    return _signUp(
      name: name,
      phone: phone,
      email: email,
      password: password,
      role: UserRole.customer,
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

    final validationError =
        _validateSignup(name, phone, email, password, upiId: upiId);
    if (validationError != null) {
      state = state.copyWith(isLoading: false, error: validationError);
      return false;
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
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

      final userData = {
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (upiId != null) userData['upiId'] = upiId.trim();

      await _firestore.collection('users').doc(firebaseUser.uid).set(userData);

      state = AuthState(
        user: UserModel(
          id: firebaseUser.uid,
          name: name.trim(),
          phone: phone.trim(),
          email: email.trim(),
          role: role,
          createdAt: DateTime.now(),
        ),
        isAuthenticated: true,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _mapAuthError(e.code),
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
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email)) {
      return 'Enter a valid email address';
    }
    if (password.length < 6) return 'Password must be at least 6 characters';
    if (upiId != null && !upiId.contains('@')) {
      return 'Enter a valid UPI ID (e.g., name@bank)';
    }
    return null;
  }

  String _mapAuthError(String code) {
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
