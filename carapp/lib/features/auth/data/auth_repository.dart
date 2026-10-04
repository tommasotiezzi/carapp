import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

/// Why sign in / sign up failed, mapped from Supabase error codes.
enum AuthFailure {
  invalidCredentials,
  emailTaken,
  weakPassword,
  emailNotConfirmed,
  rateLimited,
  generic,
}

class AuthFailureException implements Exception {
  const AuthFailureException(this.failure);
  final AuthFailure failure;
}

enum SignUpResult {
  /// Account created and signed in.
  signedIn,

  /// "Confirm email" is on in Supabase: the user must open the email first.
  confirmEmail,
}

/// Email + password login. (Email OTP codes are paused for now:
/// see "Login" in CLAUDE.md.)
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  static const minPasswordLength = 8;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

  static String _normalize(String email) => email.trim().toLowerCase();

  Future<void> signIn({required String email, required String password}) => _guard(
        () => _client.auth.signInWithPassword(email: _normalize(email), password: password),
      );

  Future<SignUpResult> signUp({required String email, required String password}) async {
    final res = await _guard(
      () => _client.auth.signUp(email: _normalize(email), password: password),
    );
    return res.session == null ? SignUpResult.confirmEmail : SignUpResult.signedIn;
  }

  Future<void> signOut() => _client.auth.signOut();

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw AuthFailureException(failureOf(e));
    }
  }

  /// Supabase error -> what the UI says. Codes:
  /// https://supabase.com/docs/guides/auth/debugging/error-codes
  static AuthFailure failureOf(Object error) {
    if (error is AuthWeakPasswordException) return AuthFailure.weakPassword;
    if (error is! AuthException) return AuthFailure.generic;
    return switch (error.code) {
      'invalid_credentials' => AuthFailure.invalidCredentials,
      'user_already_exists' || 'email_exists' => AuthFailure.emailTaken,
      'weak_password' => AuthFailure.weakPassword,
      'email_not_confirmed' => AuthFailure.emailNotConfirmed,
      'over_request_rate_limit' || 'over_email_send_rate_limit' => AuthFailure.rateLimited,
      _ => AuthFailure.generic,
    };
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);
