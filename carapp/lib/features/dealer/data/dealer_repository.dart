import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

enum DealerSignupError { invalidVat, vatTaken, viesUnavailable, generic }

class DealerSignupException implements Exception {
  const DealerSignupException(this.error);
  final DealerSignupError error;
}

/// Dealer creation runs in the `dealer-signup` Edge Function:
/// it checks the VAT number with VIES and creates dealer, owner membership
/// and the free-trial subscription in one go, with server permissions.
class DealerRepository {
  DealerRepository(this._client);

  final SupabaseClient _client;

  /// Accepts "IT01234567890", "01234567890", with or without spaces.
  static String? normalizeItalianVat(String input) {
    var v = input.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (v.startsWith('IT')) v = v.substring(2);
    return RegExp(r'^\d{11}$').hasMatch(v) ? v : null;
  }

  Future<void> signUp({required String vatNumber, required String displayName}) async {
    try {
      await _client.functions.invoke(
        'dealer-signup',
        body: {'vat_number': vatNumber, 'display_name': displayName.trim()},
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? details['error'] : null;
      throw DealerSignupException(switch (code) {
        'vat_invalid' => DealerSignupError.invalidVat,
        'vat_taken' => DealerSignupError.vatTaken,
        'vies_unavailable' => DealerSignupError.viesUnavailable,
        _ => DealerSignupError.generic,
      });
    } catch (_) {
      throw const DealerSignupException(DealerSignupError.generic);
    }
  }
}

final dealerRepositoryProvider = Provider<DealerRepository>(
  (ref) => DealerRepository(ref.watch(supabaseProvider)),
);