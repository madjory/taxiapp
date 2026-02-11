import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared/services/auth_service.dart';
import 'package:shared/services/firestore_service.dart';
import 'package:shared/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  User? get firebaseUser => _authService.currentUser;
  UserModel? _user;
  UserModel? get user => _user;

  String? _verificationId;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  AuthProvider(this._authService, this._firestoreService);

  /// Load user profile from Firestore.
  Future<void> loadUser() async {
    final uid = firebaseUser?.uid;
    if (uid == null) return;
    _user = await _firestoreService.getUser(uid);
    notifyListeners();
  }

  /// Start phone verification flow.
  Future<void> verifyPhone(String phoneNumber) async {
    _setLoading(true);
    _error = null;

    await _authService.verifyPhone(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        await _signInWithCredential(credential);
      },
      verificationFailed: (e) {
        _error = e.message ?? 'Verification failed';
        _setLoading(false);
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        _setLoading(false);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// Submit the 6-digit OTP code.
  Future<bool> submitOtp(String code, {required String name}) async {
    if (_verificationId == null) {
      _error = 'No verification ID. Please request a new code.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _signInWithCredential(credential, name: name);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Invalid code';
      _setLoading(false);
      return false;
    }
  }

  Future<void> _signInWithCredential(
    PhoneAuthCredential credential, {
    String? name,
  }) async {
    final userCredential =
        await _authService.signInWithCredential(credential);
    final fbUser = userCredential.user;
    if (fbUser != null) {
      await _authService.ensureUserDocument(
        uid: fbUser.uid,
        name: name ?? fbUser.displayName ?? 'Rider',
        phone: fbUser.phoneNumber ?? '',
      );
      await loadUser();
    }
    _setLoading(false);
  }

  /// Update the user's display name.
  Future<void> updateName(String name) async {
    final uid = firebaseUser?.uid;
    if (uid == null) return;
    await _firestoreService.updateUser(uid, {'name': name});
    await loadUser();
  }

  /// Sign out.
  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _verificationId = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
