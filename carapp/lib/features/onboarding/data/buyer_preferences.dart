/// What the user said they want to do. Mirrors the `user_intent` enum.
enum UserIntent {
  buy,
  sell,
  browse,
  dealer;

  String get dbName => name;

  static UserIntent? fromName(String? value) =>
      UserIntent.values.where((e) => e.name == value).firstOrNull;
}

/// Budget presets shown as pills. Cents, like the database.
enum BudgetOption {
  upTo5k(null, 500000),
  from5to10k(500000, 1000000),
  from10to15k(1000000, 1500000),
  from15to25k(1500000, 2500000),
  over25k(2500000, null);

  const BudgetOption(this.minCents, this.maxCents);
  final int? minCents;
  final int? maxCents;

  static BudgetOption? match(int? minCents, int? maxCents) => BudgetOption.values
      .where((o) => o.minCents == minCents && o.maxCents == maxCents)
      .firstOrNull;
}

/// Optional buyer preferences. Every field can stay empty ("Qualsiasi").
class BuyerPreferences {
  const BuyerPreferences({
    this.categoryId,
    this.budget,
    this.makeIds = const [],
    this.yearMin,
    this.mileageMaxKm,
    this.noviceDriver = false,
    this.province,
    this.maxDistanceKm,
  });

  final String? categoryId; // 'car' | 'motorcycle' | null = all
  final BudgetOption? budget;
  final List<String> makeIds;
  final int? yearMin;
  final int? mileageMaxKm;
  final bool noviceDriver;

  /// "Dove sei?": the capital the user picked (also on their profile).
  final String? province;

  /// How far they would go; with [province] it becomes the feed's
  /// distance filter until they change it.
  final int? maxDistanceKm;

  static const yearOptions = [2015, 2018, 2021];
  static const mileageOptions = [50000, 100000, 150000];

  bool get isEmpty =>
      categoryId == null &&
      budget == null &&
      makeIds.isEmpty &&
      yearMin == null &&
      mileageMaxKm == null &&
      !noviceDriver &&
      province == null &&
      maxDistanceKm == null;

  static const _unset = Object();

  BuyerPreferences copyWith({
    Object? categoryId = _unset,
    Object? budget = _unset,
    List<String>? makeIds,
    Object? yearMin = _unset,
    Object? mileageMaxKm = _unset,
    bool? noviceDriver,
    Object? province = _unset,
    Object? maxDistanceKm = _unset,
  }) =>
      BuyerPreferences(
        categoryId: identical(categoryId, _unset) ? this.categoryId : categoryId as String?,
        budget: identical(budget, _unset) ? this.budget : budget as BudgetOption?,
        makeIds: makeIds ?? this.makeIds,
        yearMin: identical(yearMin, _unset) ? this.yearMin : yearMin as int?,
        mileageMaxKm:
            identical(mileageMaxKm, _unset) ? this.mileageMaxKm : mileageMaxKm as int?,
        noviceDriver: noviceDriver ?? this.noviceDriver,
        province: identical(province, _unset) ? this.province : province as String?,
        maxDistanceKm:
            identical(maxDistanceKm, _unset) ? this.maxDistanceKm : maxDistanceKm as int?,
      );

  // ---- local cache ----

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'budget': budget?.name,
        'make_ids': makeIds,
        'year_min': yearMin,
        'mileage_max_km': mileageMaxKm,
        'novice_driver': noviceDriver,
        'province': province,
        'max_distance_km': maxDistanceKm,
      };

  factory BuyerPreferences.fromJson(Map<String, dynamic> json) => BuyerPreferences(
        categoryId: json['category_id'] as String?,
        budget: BudgetOption.values
            .where((b) => b.name == json['budget'])
            .firstOrNull,
        makeIds: List<String>.from((json['make_ids'] as List?) ?? const []),
        yearMin: (json['year_min'] as num?)?.toInt(),
        mileageMaxKm: (json['mileage_max_km'] as num?)?.toInt(),
        noviceDriver: (json['novice_driver'] as bool?) ?? false,
        province: json['province'] as String?,
        maxDistanceKm: (json['max_distance_km'] as num?)?.toInt(),
      );

  // ---- `buyer_preferences` row ----

  Map<String, dynamic> toRow(String profileId) => {
        'profile_id': profileId,
        'category_ids': categoryId == null ? null : [categoryId],
        'make_ids': makeIds.isEmpty ? null : makeIds,
        'price_min_cents': budget?.minCents,
        'price_max_cents': budget?.maxCents,
        'year_min': yearMin,
        'mileage_max_km': mileageMaxKm,
        'novice_driver': noviceDriver,
        'max_distance_km': maxDistanceKm,
      };
}