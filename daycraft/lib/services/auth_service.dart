import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the current logged-in user
  static User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes (used by AuthGate in main.dart)
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email and password
  /// Returns null on success, or an error message string on failure
  static Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'The password is too weak (min 6 characters).';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'invalid-email':
          return 'The email address is not valid.';
        default:
          return e.message ?? 'An error occurred during sign up.';
      }
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Sign in with email and password
  /// Returns null on success, or an error message string on failure
  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        default:
          return e.message ?? 'An error occurred during sign in.';
      }
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Sign out the current user
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Update the user's display name in Firebase Auth
  static Future<void> updateDisplayName(String name) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.reload(); // Forces Firebase to refresh cached user data
      }
    } catch (e) {
      // Optional: Handle error or print it to console for debugging
      print("Error updating display name: $e");
    }
  }
}
