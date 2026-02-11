import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Verify phone number and trigger OTP.
  Future<void> verifyPhone({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  /// Sign in with OTP credential.
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) {
    return _auth.signInWithCredential(credential);
  }

  /// Create or update the user document in Firestore after sign-in.
  Future<void> ensureUserDocument({
    required String uid,
    required String name,
    required String phone,
  }) async {
    final docRef = _firestore.collection(Collections.users).doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      final user = UserModel(
        uid: uid,
        name: name,
        phone: phone,
        createdAt: DateTime.now(),
      );
      await docRef.set(user.toFirestore());
    }
  }

  /// Sign out.
  Future<void> signOut() => _auth.signOut();
}
