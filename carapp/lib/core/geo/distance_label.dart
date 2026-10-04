import '../../l10n/gen/app_localizations.dart';
import 'italian_capitals.dart';

/// "51 km da te" / "Nella tua provincia" from the user's capital to a
/// listing's province; null when either is unknown.
String? distanceLabel(AppLocalizations t, {required String? home, required String? province}) {
  if (home == null || province == null) return null;
  if (home == province) return t.distanceHere;
  final km = ItalianCapitals.distanceKm(home, province);
  if (km == null) return null;
  // Rounded to 5 km beyond 20: capitals, not addresses.
  final shown = km < 20 ? km.round() : (km / 5).round() * 5;
  return t.distanceAway(shown);
}
