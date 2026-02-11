import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared/services/auth_service.dart';
import 'package:shared/services/firestore_service.dart';
import 'package:shared/models/driver_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  User? get firebaseUser => _authService.currentUser;
  DriverModel? _driver;
  DriverModel? get driver => _driver;

  String? _verificationId;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  AuthProvider(this._authService, this._firestoreService);

  /// Load driver profile from Firestore. Returns true if driver doc exists.
  Future<bool> loadDriver() async {
    final uid = firebaseUser?.uid;
    if (uid == null) return false;
    _driver = await _firestoreService.getDriver(uid);
    notifyListeners();
    return _driver != null;
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
  Future<bool> submitOtp(String code) async {
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
      await _signInWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Invalid code';
      _setLoading(false);
      return false;
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    await _authService.signInWithCredential(credential);
    // Don't create user doc — driver doc is created during registration.
    await loadDriver();
    _setLoading(false);
  }

  /// Register a new driver profile.
  Future<void> registerDriver({
    required String name,
    required String carModel,
    required String plateNumber,
    required double ratePerKm,
  }) async {
    final uid = firebaseUser?.uid;
    final phone = firebaseUser?.phoneNumber ?? '';
    if (uid == null) return;

    _setLoading(true);
    _error = null;

    try {
      final driver = DriverModel(
        uid: uid,
        name: name,
        phone: phone,
        carModel: carModel,
        plateNumber: plateNumber,
        ratePerKm: ratePerKm,
        createdAt: DateTime.now(),
      );
      await _firestoreService.createDriver(driver);
      await loadDriver();
    } catch (e) {
      _error = 'Registration failed: $e';
    }

    _setLoading(false);
  }

  /// Sign out.
  Future<void> signOut() async {
    await _authService.signOut();
    _driver = null;
    _verificationId = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
