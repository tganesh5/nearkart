import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../../core/exceptions/app_exception.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logger.i('User signed up: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      _logger.e('Sign up failed', error: e);
      throw AuthException(
        _mapAuthErrorMessage(e.code),
        code: e.code,
        originalError: e,
      );
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logger.i('User signed in: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      _logger.e('Sign in failed', error: e);
      throw AuthException(
        _mapAuthErrorMessage(e.code),
        code: e.code,
        originalError: e,
      );
    }
  }

  Future<void> sendPhoneVerification({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) onAutoVerified,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException) onFailed,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: '+91$phoneNumber',
      timeout: const Duration(seconds: 60),
      verificationCompleted: onAutoVerified,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
      forceResendingToken: resendToken,
    );
  }

  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _mapAuthErrorMessage(e.code),
        code: e.code,
        originalError: e,
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _mapAuthErrorMessage(e.code),
        code: e.code,
        originalError: e,
      );
    }
  }

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _logger.i('User signed out');
  }

  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      _logger.w('User account deleted');
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _mapAuthErrorMessage(e.code),
        code: e.code,
        originalError: e,
      );
    }
  }

  String _mapAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please try again';
      case 'session-expired':
        return 'OTP expired. Please request a new one';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}
