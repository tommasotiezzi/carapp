import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'italian_capitals.dart';

enum LocationFailure { serviceOff, denied, unavailable }

class LocationException implements Exception {
  const LocationException(this.failure);
  final LocationFailure failure;
}

/// "Usa la mia posizione": the capital closest to the phone. A coarse fix
/// is enough (only the province matters), so it is quick and needs only
/// the approximate-location permission. Throws [LocationException].
typedef NearestCapitalLocator = Future<Capital> Function();

Future<Capital> locateNearestCapital() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationException(LocationFailure.serviceOff);
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw const LocationException(LocationFailure.denied);
  }
  Position? position;
  try {
    position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );
  } catch (_) {
    position = await Geolocator.getLastKnownPosition();
  }
  if (position == null) throw const LocationException(LocationFailure.unavailable);
  return ItalianCapitals.nearestTo(position.latitude, position.longitude);
}

/// Overridden in tests.
final nearestCapitalLocatorProvider = Provider<NearestCapitalLocator>((ref) => locateNearestCapital);
