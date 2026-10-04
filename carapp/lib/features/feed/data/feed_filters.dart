import '../../onboarding/data/buyer_preferences.dart';

/// The parts of the filter UI. A pill opens one section, the "tune"
/// button opens them all.
enum FilterSection { vehicle, price, brand, year, mileage, fuel }

/// What the feed is filtered by. Empty = everything.
/// Same column names as `listings`, so it can become a saved search as is.
class FeedFilters {
  const FeedFilters({
    this.categoryId,
    this.priceMinCents,
    this.priceMaxCents,
    this.makeIds = const {},
    this.yearMin,
    this.mileageMaxKm,
    this.fuelTypes = const {},
  });

  final String? categoryId; // 'car' | 'motorcycle' | null = all
  final int? priceMinCents;
  final int? priceMaxCents;
  final Set<String> makeIds;
  final int? yearMin;
  final int? mileageMaxKm;
  final Set<String> fuelTypes; // `fuel_type` values

  static const empty = FeedFilters();

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

  BudgetOption? get budget => BudgetOption.match(priceMinCents, priceMaxCents);

  bool get hasPrice => priceMinCents != null || priceMaxCents != null;

  bool get isEmpty => activeCount == 0;

  /// Number of filter groups in use (badge on the "tune" button).
  int get activeCount => [
        categoryId != null,
        hasPrice,
        makeIds.isNotEmpty,
        yearMin != null,
        mileageMaxKm != null,
        fuelTypes.isNotEmpty,
      ].where((active) => active).length;

  /// Starting point taken from the onboarding "Cosa cerchi?" answers.
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
        FilterSection.vehicle => copyWith(categoryId: null, makeIds: const {}),
        FilterSection.price => copyWith(priceMinCents: null, priceMaxCents: null),
        FilterSection.brand => copyWith(makeIds: const {}),
        FilterSection.year => copyWith(yearMin: null),
        FilterSection.mileage => copyWith(mileageMaxKm: null),
        FilterSection.fuel => copyWith(fuelTypes: const {}),
      };

  static const _unset = Object();

  FeedFilters copyWith({
    Object? categoryId = _unset,
    Object? priceMinCents = _unset,
    Object? priceMaxCents = _unset,
    Set<String>? makeIds,
    Object? yearMin = _unset,
    Object? mileageMaxKm = _unset,
    Set<String>? fuelTypes,
  }) =>
      FeedFilters(
        categoryId: identical(categoryId, _unset) ? this.categoryId : categoryId as String?,
        priceMinCents:
            identical(priceMinCents, _unset) ? this.priceMinCents : priceMinCents as int?,
        priceMaxCents:
            identical(priceMaxCents, _unset) ? this.priceMaxCents : priceMaxCents as int?,
        makeIds: makeIds ?? this.makeIds,
        yearMin: identical(yearMin, _unset) ? this.yearMin : yearMin as int?,
        mileageMaxKm: identical(mileageMaxKm, _unset) ? this.mileageMaxKm : mileageMaxKm as int?,
        fuelTypes: fuelTypes ?? this.fuelTypes,
      );

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'price_min_cents': priceMinCents,
        'price_max_cents': priceMaxCents,
        'make_ids': makeIds.toList(),
        'year_min': yearMin,
        'mileage_max_km': mileageMaxKm,
        'fuel_types': fuelTypes.toList(),
      };

  factory FeedFilters.fromJson(Map<String, dynamic> json) => FeedFilters(
        categoryId: json['category_id'] as String?,
        priceMinCents: (json['price_min_cents'] as num?)?.toInt(),
        priceMaxCents: (json['price_max_cents'] as num?)?.toInt(),
        makeIds: Set<String>.from((json['make_ids'] as List?) ?? const []),
        yearMin: (json['year_min'] as num?)?.toInt(),
        mileageMaxKm: (json['mileage_max_km'] as num?)?.toInt(),
        fuelTypes: Set<String>.from((json['fuel_types'] as List?) ?? const []),
      );

  @override
  bool operator ==(Object other) =>
      other is FeedFilters &&
      other.categoryId == categoryId &&
      other.priceMinCents == priceMinCents &&
      other.priceMaxCents == priceMaxCents &&
      _sameSet(other.makeIds, makeIds) &&
      other.yearMin == yearMin &&
      other.mileageMaxKm == mileageMaxKm &&
      _sameSet(other.fuelTypes, fuelTypes);

  @override
  int get hashCode => Object.hash(
        categoryId,
        priceMinCents,
        priceMaxCents,
        Object.hashAllUnordered(makeIds),
        yearMin,
        mileageMaxKm,
        Object.hashAllUnordered(fuelTypes),
      );

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
}
