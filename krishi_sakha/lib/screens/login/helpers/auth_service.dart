import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/web.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:lottie/lottie.dart'; // Add this dependency
import 'package:krishi_sakha/utils/routes/routes.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Sign Up with email and password
  static Future<AuthResult> signUp({
    required BuildContext context,
    required String email,
    required String password,
    String? fullName,
    Map<String, dynamic>? additionalData,
  }) async {
    try {

      
      // Show loading dialog
      _showLoadingDialog(context, 'Creating your account...');

      // Prepare user data
      Map<String, dynamic>? userData;
      if (fullName != null || additionalData != null) {
        userData = {
          if (fullName != null) 'full_name': fullName,
          ...?additionalData,
        };
      }

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: userData,
      );

      // Hide loading dialog
      if (context.mounted) Navigator.of(context).pop();

      if (response.user != null) {
        if (response.user!.emailConfirmedAt == null) {
          // Email confirmation required
          await _showSuccessDialog(
            context,
            'Account Created!',
            'Please check your email and click the confirmation link to activate your account.',
          );
          return AuthResult.success('Email confirmation required');
        } else {
          // Account created and confirmed
          await _showSuccessDialog(
            context,
            'Welcome!',
            'Your account has been created successfully.',
          );
          if (context.mounted) context.go(AppRoutes.home);
          return AuthResult.success('Account created successfully');
        }
      } else {
        await _showErrorDialog(context, 'Signup Failed', 'Unable to create account. Please try again.');
        return AuthResult.error('Signup failed');
      }
    } on AuthException catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      String errorMessage = _getAuthErrorMessage(e);
      await _showErrorDialog(context, 'Signup Error', errorMessage);
      return AuthResult.error(errorMessage);
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      await _showErrorDialog(context, 'Error', 'An unexpected error occurred. Please try again.');
      return AuthResult.error('Unexpected error: ${e.toString()}');
    }
  }

  /// Sign In with email and password
  static Future<AuthResult> signIn({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    try {
      // Show loading dialog
      _showLoadingDialog(context, 'Signing you in...');

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      // Hide loading dialog
      if (context.mounted) Navigator.of(context).pop();

      if (response.user != null) {
        await _showSuccessDialog(
          context,
          'Welcome Back!',
          'You have been signed in successfully.',
        );
        if (context.mounted) context.go(AppRoutes.home);
        return AuthResult.success('Signed in successfully');
      } else {
        await _showErrorDialog(context, 'Sign In Failed', 'Invalid credentials. Please try again.');
        return AuthResult.error('Sign in failed');
      }
    } on AuthException catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      String errorMessage = _getAuthErrorMessage(e);
      await _showErrorDialog(context, 'Sign In Error', errorMessage);
      return AuthResult.error(errorMessage);
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      await _showErrorDialog(context, 'Error', 'An unexpected error occurred. Please try again.');
      return AuthResult.error('Unexpected error: ${e.toString()}');
    }
  }

  /// Sign Out current user
  static Future<AuthResult> signOut({required BuildContext context}) async {
    try {
      _showLoadingDialog(context, 'Signing out...');
      
      await _supabase.auth.signOut();
      
      if (context.mounted) Navigator.of(context).pop();
      
      await _showSuccessDialog(
        context,
        'Signed Out',
        'You have been signed out successfully.',
      );
      
      if (context.mounted) context.go(AppRoutes.login);
      return AuthResult.success('Signed out successfully');
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      await _showErrorDialog(context, 'Error', 'Failed to sign out. Please try again.');
      return AuthResult.error('Sign out failed: ${e.toString()}');
    }
  }

  /// Reset password via email
  static Future<AuthResult> resetPassword({
    required BuildContext context,
    required String email,
    String? redirectUrl,
  }) async {
    try {
      _showLoadingDialog(context, 'Sending reset email...');

      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectUrl ?? 'your-app://reset-password',
      );

      if (context.mounted) Navigator.of(context).pop();

      await _showSuccessDialog(
        context,
        'Reset Email Sent',
        'Please check your email for password reset instructions.',
      );
      return AuthResult.success('Reset email sent');
    } on AuthException catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      String errorMessage = _getAuthErrorMessage(e);
      await _showErrorDialog(context, 'Reset Error', errorMessage);
      return AuthResult.error(errorMessage);
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      await _showErrorDialog(context, 'Error', 'Failed to send reset email. Please try again.');
      return AuthResult.error('Reset failed: ${e.toString()}');
    }
  }

  /// Update password (user must be logged in)
  static Future<AuthResult> updatePassword({
    required BuildContext context,
    required String newPassword,
  }) async {
    try {
      _showLoadingDialog(context, 'Updating password...');

      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (context.mounted) Navigator.of(context).pop();

      if (response.user != null) {
        await _showSuccessDialog(
          context,
          'Password Updated',
          'Your password has been updated successfully.',
        );
        return AuthResult.success('Password updated successfully');
      } else {
        await _showErrorDialog(context, 'Update Failed', 'Failed to update password.');
        return AuthResult.error('Password update failed');
      }
    } on AuthException catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      String errorMessage = _getAuthErrorMessage(e);
      await _showErrorDialog(context, 'Update Error', errorMessage);
      return AuthResult.error(errorMessage);
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      await _showErrorDialog(context, 'Error', 'Failed to update password. Please try again.');
      return AuthResult.error('Update failed: ${e.toString()}');
    }
  }

  /// Check if user is currently signed in
  static bool get isSignedIn => _supabase.auth.currentUser != null;

  /// Get current user
  static User? get currentUser => _supabase.auth.currentUser;

  /// Get current user ID
  static String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Get current user email
  static String? get currentUserEmail => _supabase.auth.currentUser?.email;

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // PRIVATE METHODS FOR UI DIALOGS

  /// Show loading dialog with animation
  static void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).dialogBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lottie Placeholder - Replace with your loading animation
                  Lottie.asset(
                  'assets/lottie/IntroFirst.json',
                  width: 80,
                  height: 80,
                ),
          
                
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show success dialog with animation
  static Future<void> _showSuccessDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).dialogBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
             
                Lottie.asset(
                  'assets/lottie/success.json',
                  width: 80,
                  height: 80,
                  repeat: false,
                ),
                
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show error dialog with animation
  static Future<void> _showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).dialogBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lottie Placeholder - Replace with your error animation
           
                // Replace above container with:
                Lottie.asset(
                  'assets/lottie/error.json',
                  width: 80,
                  height: 80,
                  repeat: false,
                ),
                
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Convert Supabase auth errors to user-friendly messages
  static String _getAuthErrorMessage(AuthException e) {
    switch (e.message.toLowerCase()) {
      case 'invalid login credentials':
        return 'Invalid email or password. Please check your credentials and try again.';
      case 'email not confirmed':
        return 'Please confirm your email address before signing in.';
      case 'user already registered':
        return 'An account with this email already exists. Please sign in instead.';
      case 'password should be at least 6 characters':
        return 'Password must be at least 6 characters long.';
      case 'signup disabled':
        return 'Account registration is currently disabled. Please try again later.';
      case 'email rate limit exceeded':
        return 'Too many requests. Please wait a few minutes before trying again.';
      case 'invalid email':
        return 'Please enter a valid email address.';
      case 'weak password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'user not found':
        return 'No account found with this email address.';
      default:
        return e.message.isNotEmpty ? e.message : 'An authentication error occurred.';
    }
  }
}

/// Result class for authentication operations
class AuthResult {
  final bool isSuccess;
  final String message;

  const AuthResult._(this.isSuccess, this.message);

  factory AuthResult.success(String message) => AuthResult._(true, message);
  factory AuthResult.error(String message) => AuthResult._(false, message);

  @override
  String toString() => 'AuthResult(isSuccess: $isSuccess, message: $message)';
}