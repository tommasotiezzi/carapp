/// Province capitals (capoluoghi) with their coordinates: where users and
/// listings are placed. Generated from open data (ISTAT names + coordinates);
/// the same list is in the `province_capitals` table (migration 14).
library;

import 'dart:math' as math;

class Capital {
  const Capital(this.code, this.name, this.lat, this.lng);

  /// Two-letter province code, as in `listings.province`.
  final String code;
  final String name;
  final double lat;
  final double lng;

  /// "Siena (SI)"
  String get label => '$name ($code)';
}

class ItalianCapitals {
  ItalianCapitals._();

  /// Alphabetical by name.
  static const all = <Capital>[
    Capital('AG', 'Agrigento', 37.30971, 13.58457),
    Capital('AL', 'Alessandria', 44.91297, 8.61540),
    Capital('AN', 'Ancona', 43.61676, 13.51888),
    Capital('AO', 'Aosta', 45.73750, 7.32015),
    Capital('AR', 'Arezzo', 43.46643, 11.88229),
    Capital('AP', 'Ascoli Piceno', 42.85322, 13.57691),
    Capital('AT', 'Asti', 44.89913, 8.20414),
    Capital('AV', 'Avellino', 40.91405, 14.79529),
    Capital('BA', 'Bari', 41.12560, 16.86737),
    Capital('BT', 'Barletta', 41.31956, 16.27718),
    Capital('BL', 'Belluno', 46.13838, 12.21704),
    Capital('BN', 'Benevento', 41.12970, 14.78152),
    Capital('BG', 'Bergamo', 45.69441, 9.66842),
    Capital('BI', 'Biella', 45.56651, 8.05408),
    Capital('BO', 'Bologna', 44.49437, 11.34172),
    Capital('BZ', 'Bolzano', 46.49933, 11.35662),
    Capital('BS', 'Brescia', 45.53993, 10.21910),
    Capital('BR', 'Brindisi', 40.63849, 17.94602),
    Capital('CA', 'Cagliari', 39.21531, 9.11062),
    Capital('CL', 'Caltanissetta', 37.49213, 14.06185),
    Capital('CB', 'Campobasso', 41.55775, 14.65916),
    Capital('CE', 'Caserta', 41.07466, 14.33240),
    Capital('CT', 'Catania', 37.50288, 15.08705),
    Capital('CZ', 'Catanzaro', 38.90598, 16.59440),
    Capital('CH', 'Chieti', 42.35103, 14.16755),
    Capital('CO', 'Como', 45.80999, 9.08516),
    Capital('CS', 'Cosenza', 39.29309, 16.25610),
    Capital('CR', 'Cremona', 45.13337, 10.02421),
    Capital('KR', 'Crotone', 39.08037, 17.12539),
    Capital('CN', 'Cuneo', 44.39330, 7.55117),
    Capital('EN', 'Enna', 37.56706, 14.27909),
    Capital('FM', 'Fermo', 43.16059, 13.71840),
    Capital('FE', 'Ferrara', 44.83599, 11.61869),
    Capital('FI', 'Firenze', 43.76923, 11.25589),
    Capital('FG', 'Foggia', 41.46227, 15.54305),
    Capital('FC', 'Forlì', 44.22269, 12.04069),
    Capital('FR', 'Frosinone', 41.63965, 13.35117),
    Capital('GE', 'Genova', 44.41149, 8.93270),
    Capital('GO', 'Gorizia', 45.94150, 13.62213),
    Capital('GR', 'Grosseto', 42.76027, 11.11356),
    Capital('IM', 'Imperia', 43.88571, 8.02785),
    Capital('IS', 'Isernia', 41.58801, 14.22575),
    Capital('AQ', "L'Aquila", 42.35122, 13.39844),
    Capital('SP', 'La Spezia', 44.10705, 9.82819),
    Capital('LT', 'Latina', 41.46759, 12.90368),
    Capital('LE', 'Lecce', 40.35354, 18.17191),
    Capital('LC', 'Lecco', 45.85576, 9.39339),
    Capital('LI', 'Livorno', 43.55235, 10.30868),
    Capital('LO', 'Lodi', 45.31441, 9.50372),
    Capital('LU', 'Lucca', 43.84432, 10.50151),
    Capital('MC', 'Macerata', 43.30024, 13.45307),
    Capital('MN', 'Mantova', 45.15727, 10.79277),
    Capital('MS', 'Massa', 44.03674, 10.14174),
    Capital('MT', 'Matera', 40.66751, 16.59793),
    Capital('ME', 'Messina', 38.19396, 15.55572),
    Capital('MI', 'Milano', 45.46679, 9.19035),
    Capital('MO', 'Modena', 44.64600, 10.92615),
    Capital('MB', 'Monza', 45.58439, 9.27358),
    Capital('NA', 'Napoli', 40.83957, 14.25085),
    Capital('NO', 'Novara', 45.44589, 8.62192),
    Capital('NU', 'Nuoro', 40.32319, 9.33030),
    Capital('OR', 'Oristano', 39.90381, 8.59118),
    Capital('PD', 'Padova', 45.40693, 11.87609),
    Capital('PA', 'Palermo', 38.11570, 13.36236),
    Capital('PR', 'Parma', 44.80107, 10.32835),
    Capital('PV', 'Pavia', 45.18509, 9.16016),
    Capital('PG', 'Perugia', 43.10676, 12.38825),
    Capital('PU', 'Pesaro', 43.91014, 12.91346),
    Capital('PE', 'Pescara', 42.46458, 14.21365),
    Capital('PC', 'Piacenza', 45.05193, 9.69263),
    Capital('PI', 'Pisa', 43.71553, 10.40127),
    Capital('PT', 'Pistoia', 43.93346, 10.91734),
    Capital('PN', 'Pordenone', 45.95444, 12.66003),
    Capital('PZ', 'Potenza', 40.63947, 15.80515),
    Capital('PO', 'Prato', 43.88062, 11.09703),
    Capital('RG', 'Ragusa', 36.92509, 14.73070),
    Capital('RA', 'Ravenna', 44.41722, 12.19914),
    Capital('RC', 'Reggio Calabria', 38.10923, 15.64345),
    Capital('RE', 'Reggio Emilia', 44.69735, 10.63008),
    Capital('RI', 'Rieti', 42.40488, 12.86206),
    Capital('RN', 'Rimini', 44.06090, 12.56563),
    Capital('RM', 'Roma', 41.89277, 12.48367),
    Capital('RO', 'Rovigo', 45.07107, 11.79007),
    Capital('SA', 'Salerno', 40.67822, 14.75940),
    Capital('SS', 'Sassari', 40.72668, 8.55967),
    Capital('SV', 'Savona', 44.30750, 8.48111),
    Capital('SI', 'Siena', 43.31816, 11.33191),
    Capital('SR', 'Siracusa', 37.05992, 15.29333),
    Capital('SO', 'Sondrio', 46.17099, 9.87147),
    Capital('TA', 'Taranto', 40.47355, 17.23238),
    Capital('TE', 'Teramo', 42.65892, 13.70440),
    Capital('TR', 'Terni', 42.56071, 12.64669),
    Capital('TO', 'Torino', 45.07327, 7.68069),
    Capital('TP', 'Trapani', 38.01850, 12.51366),
    Capital('TN', 'Trento', 46.06894, 11.12123),
    Capital('TV', 'Treviso', 45.66755, 12.24507),
    Capital('TS', 'Trieste', 45.64944, 13.76814),
    Capital('UD', 'Udine', 46.06256, 13.23484),
    Capital('VA', 'Varese', 45.81702, 8.82287),
    Capital('VE', 'Venezia', 45.43490, 12.33845),
    Capital('VB', 'Verbania', 45.92145, 8.55108),
    Capital('VC', 'Vercelli', 45.32398, 8.42323),
    Capital('VR', 'Verona', 45.43839, 10.99353),
    Capital('VV', 'Vibo Valentia', 38.67624, 16.10158),
    Capital('VI', 'Vicenza', 45.54750, 11.54597),
    Capital('VT', 'Viterbo', 42.41738, 12.10473),
  ];

  static final Map<String, Capital> byCode = {for (final c in all) c.code: c};

  /// Great-circle distance in km between two capitals (null if unknown).
  static double? distanceKm(String? a, String? b) {
    final x = byCode[a], y = byCode[b];
    if (x == null || y == null) return null;
    return haversineKm(x.lat, x.lng, y.lat, y.lng);
  }

  static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final h = math.pow(math.sin(rad(lat2 - lat1) / 2), 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(rad(lng2 - lng1) / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  /// Province codes whose capital is within [km] of [center]'s capital
  /// (the center included). Empty if [center] is unknown.
  static Set<String> within(String center, int km) {
    final c = byCode[center];
    if (c == null) return const {};
    return {
      for (final x in all)
        if (haversineKm(c.lat, c.lng, x.lat, x.lng) <= km) x.code,
    };
  }

  /// The capital closest to a point (e.g. the phone's position, later).
  static Capital nearestTo(double lat, double lng) => all.reduce((best, x) =>
      haversineKm(lat, lng, x.lat, x.lng) < haversineKm(lat, lng, best.lat, best.lng) ? x : best);
}
