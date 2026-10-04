import '../../onboarding/data/buyer_preferences.dart';

/// The parts of the filter UI. A pill opens one section, the "tune"
/// button (and "Filtri" in Search) opens them all.
enum FilterSection { vehicle, price, brand, year, mileage, fuel, transmission, novice }

/// What the feed and Search show. Empty = everything. One shared state:
/// the feed pills, the filter sheet and the Search box all edit it.
/// Same names as the `listings` columns, so it is stored as is in
/// `saved_searches.filters`.
class FeedFilters {
  const FeedFilters({
    this.categoryId,
    this.priceMinCents,
    this.priceMaxCents,
    this.makeIds = const {},
    this.modelIds = const {},
    this.yearMin,
    this.yearMax,
    this.mileageMaxKm,
    this.fuelTypes = const {},
    this.transmission,
    this.noviceDriver = false,
    this.province,
    this.textWords = const [],
  });

  final String? categoryId; // 'car' | 'motorcycle' | null = all
  final int? priceMinCents;
  final int? priceMaxCents;
  final Set<String> makeIds;
  final Set<String> modelIds;
  final int? yearMin;
  final int? yearMax;
  final int? mileageMaxKm;
  final Set<String> fuelTypes; // `fuel_type` values
  final String? transmission; // `transmission_type` value

  /// Cars a novice driver may drive: see [noviceMaxPowerKw].
  final bool noviceDriver;

  /// Two-letter province code (`listings.province`), e.g. 'MI'.
  final String? province;

  /// Free words searched in version and description. Only set by the
  /// Search box when nothing else in the query was recognized.
  final List<String> textWords;

  static const empty = FeedFilters();

  /// Italian rule for the first 3 years of a B licence: max 105 kW
  /// (and 75 kW/t, which we cannot check: listings have no weight).
  /// Applied to cars only.
  static const noviceMaxPowerKw = 105;

  static const yearOptions = [2010, 2015, 2018, 2020, 2022];
  static const mileageOptions = [30000, 50000, 100000, 150000];
  static const fuelOptions = [
    'petrol',
    'diesel',
    'hybrid',
    'plugin_hybrid',
    'electric',
    'lpg',
    'cng',
  ];
  static const transmissionOptions = ['manual', 'automatic', 'semi_automatic'];

  BudgetOption? get budget => BudgetOption.match(priceMinCents, priceMaxCents);

  bool get hasPrice => priceMinCents != null || priceMaxCents != null;
  bool get hasYear => yearMin != null || yearMax != null;
  bool get hasBrand => makeIds.isNotEmpty || modelIds.isNotEmpty;

  bool get isEmpty => activeCount == 0;

  /// Number of filter groups in use (badge on the "tune" button).
  int get activeCount => [
        categoryId != null,
        hasPrice,
        hasBrand,
        hasYear,
        mileageMaxKm != null,
        fuelTypes.isNotEmpty,
        transmission != null,
        noviceDriver,
        province != null,
        textWords.isNotEmpty,
      ].where((active) => active).length;

  /// Starting point taken from the onboarding "Cosa cerchi?" answers.
  /// (The novice flag there means "show these first", not a filter.)
  factory FeedFilters.fromPreferences(BuyerPreferences p) => FeedFilters(
        categoryId: p.categoryId,
        priceMinCents: p.budget?.minCents,
        priceMaxCents: p.budget?.maxCents,
        makeIds: p.makeIds.toSet(),
        yearMin: p.yearMin,
        mileageMaxKm: p.mileageMaxKm,
      );

  /// Clears what [section] controls; the others stay.
  FeedFilters clear(FilterSection section) => switch (section) {
        FilterSection.vehicle =>
          copyWith(categoryId: null, makeIds: const {}, modelIds: const {}),
        FilterSection.price => copyWith(priceMinCents: null, priceMaxCents: null),
        FilterSection.brand => copyWith(makeIds: const {}, modelIds: const {}),
        FilterSection.year => copyWith(yearMin: null, yearMax: null),
        FilterSection.mileage => copyWith(mileageMaxKm: null),
        FilterSection.fuel => copyWith(fuelTypes: const {}),
        FilterSection.transmission => copyWith(transmission: null),
        FilterSection.novice => copyWith(noviceDriver: false),
      };

  static const _unset = Object();

  FeedFilters copyWith({
    Object? categoryId = _unset,
    Object? priceMinCents = _unset,
    Object? priceMaxCents = _unset,
    Set<String>? makeIds,
    Set<String>? modelIds,
    Object? yearMin = _unset,
    Object? yearMax = _unset,
    Object? mileageMaxKm = _unset,
    Set<String>? fuelTypes,
    Object? transmission = _unset,
    bool? noviceDriver,
    Object? province = _unset,
    List<String>? textWords,
  }) =>
      FeedFilters(
        categoryId: identical(categoryId, _unset) ? this.categoryId : categoryId as String?,
        priceMinCents:
            identical(priceMinCents, _unset) ? this.priceMinCents : priceMinCents as int?,
        priceMaxCents:
            identical(priceMaxCents, _unset) ? this.priceMaxCents : priceMaxCents as int?,
        makeIds: makeIds ?? this.makeIds,
        modelIds: modelIds ?? this.modelIds,
        yearMin: identical(yearMin, _unset) ? this.yearMin : yearMin as int?,
        yearMax: identical(yearMax, _unset) ? this.yearMax : yearMax as int?,
        mileageMaxKm: identical(mileageMaxKm, _unset) ? this.mileageMaxKm : mileageMaxKm as int?,
        fuelTypes: fuelTypes ?? this.fuelTypes,
        transmission:
            identical(transmission, _unset) ? this.transmission : transmission as String?,
        noviceDriver: noviceDriver ?? this.noviceDriver,
        province: identical(province, _unset) ? this.province : province as String?,
        textWords: textWords ?? this.textWords,
      );

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'price_min_cents': priceMinCents,
        'price_max_cents': priceMaxCents,
        'make_ids': makeIds.toList(),
        'model_ids': modelIds.toList(),
        'year_min': yearMin,
        'year_max': yearMax,
        'mileage_max_km': mileageMaxKm,
        'fuel_types': fuelTypes.toList(),
        'transmission': transmission,
        'novice_driver': noviceDriver,
        'province': province,
        'text_words': textWords,
      };

  /// Missing keys (filters saved by an older app) read as "not set".
  factory FeedFilters.fromJson(Map<String, dynamic> json) {
    Set<String> set(String key) => Set<String>.from((json[key] as List?) ?? const []);
    int? integer(String key) => (json[key] as num?)?.toInt();
    return FeedFilters(
      categoryId: json['category_id'] as String?,
      priceMinCents: integer('price_min_cents'),
      priceMaxCents: integer('price_max_cents'),
      makeIds: set('make_ids'),
      modelIds: set('model_ids'),
      yearMin: integer('year_min'),
      yearMax: integer('year_max'),
      mileageMaxKm: integer('mileage_max_km'),
      fuelTypes: set('fuel_types'),
      transmission: json['transmission'] as String?,
      noviceDriver: (json['novice_driver'] as bool?) ?? false,
      province: json['province'] as String?,
      textWords: List<String>.from((json['text_words'] as List?) ?? const []),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FeedFilters &&
      other.categoryId == categoryId &&
      other.priceMinCents == priceMinCents &&
      other.priceMaxCents == priceMaxCents &&
      _sameSet(other.makeIds, makeIds) &&
      _sameSet(other.modelIds, modelIds) &&
      other.yearMin == yearMin &&
      other.yearMax == yearMax &&
      other.mileageMaxKm == mileageMaxKm &&
      _sameSet(other.fuelTypes, fuelTypes) &&
      other.transmission == transmission &&
      other.noviceDriver == noviceDriver &&
      other.province == province &&
      _sameList(other.textWords, textWords);

  @override
  int get hashCode => Object.hash(
        categoryId,
        priceMinCents,
        priceMaxCents,
        Object.hashAllUnordered(makeIds),
        Object.hashAllUnordered(modelIds),
        yearMin,
        yearMax,
        mileageMaxKm,
        Object.hashAllUnordered(fuelTypes),
        transmission,
        noviceDriver,
        province,
        Object.hashAll(textWords),
      );

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
