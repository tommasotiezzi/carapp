import '../../../l10n/gen/app_localizations.dart';
import '../data/auth_repository.dart';

/// The Italian message for a failed sign in, sign up or account change.
String authFailureMessage(AppLocalizations t, AuthFailure f) => switch (f) {
      AuthFailure.invalidCredentials => t.loginErrorCredentials,
      AuthFailure.emailTaken => t.loginErrorExists,
      AuthFailure.weakPassword => t.loginErrorWeak,
      AuthFailure.emailNotConfirmed => t.loginErrorNotConfirmed,
      AuthFailure.rateLimited => t.loginErrorRateLimit,
      AuthFailure.generic => t.loginErrorGeneric,
    };
