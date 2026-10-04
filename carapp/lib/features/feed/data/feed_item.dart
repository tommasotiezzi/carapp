/// One card of the feed, built from a `listings` row and its joins.
class FeedItem {
  const FeedItem({
    required this.id,
    required this.sellerType,
    required this.publishedAt,
    this.makeName,
    this.modelName,
    this.version,
    this.year,
    this.mileageKm,
    this.priceCents,
    this.fuelType,
    this.powerKw,
    this.description,
    this.city,
    this.coverPath,
    this.videoPath,
    this.dealerName,
    this.ownerId,
    this.dealerId,
    this.province,
    this.sellerDisplayName,
    this.sellerAvatarPath,
  });

  final String id;
  final String sellerType; // 'private' | 'dealer'
  final DateTime publishedAt;
  final String? makeName;
  final String? modelName;
  final String? version;
  final int? year;
  final int? mileageKm;
  final int? priceCents;
  final String? fuelType;
  final int? powerKw;
  final String? description;
  final String? city;
  final String? coverPath;
  final String? videoPath;
  final String? dealerName;
  final String? ownerId;
  final String? dealerId;

  /// Two-letter code: distance from the user's capital.
  final String? province;

  /// Private sellers: the name on their public profile (null = not set).
  final String? sellerDisplayName;
  final String? sellerAvatarPath;

  bool get isDealer => sellerType == 'dealer';

  /// "Volkswagen Golf 1.6 TDI Life"
  String get title => [makeName, modelName, version]
      .whereType<String>()
      .where((s) => s.trim().isNotEmpty)
      .join(' ');

  String get sellerName => isDealer
      ? (dealerName ?? 'Concessionario')
      : ((sellerDisplayName ?? '').trim().isEmpty ? 'Privato' : sellerDisplayName!.trim());

  /// Where tapping the seller's name or picture leads.
  String? get sellerPageId => isDealer ? dealerId : ownerId;

  /// Columns the feed needs, nothing more.
  static const selectColumns =
      'id, seller_type, published_at, version, year, mileage_km, price_cents, '
      'fuel_type, power_kw, description, city, province, cover_path, video_path, '
      'owner_id, dealer_id, '
      'make:makes(name), model:models(name), dealer:dealers(display_name), '
      'seller:public_profiles!owner_id(display_name, avatar_path)';

  factory FeedItem.fromRow(Map<String, dynamic> row) {
    String? nested(String key, String field) =>
        (row[key] as Map<String, dynamic>?)?[field] as String?;

    return FeedItem(
      id: row['id'] as String,
      sellerType: row['seller_type'] as String,
      publishedAt: DateTime.parse(row['published_at'] as String),
      makeName: nested('make', 'name'),
      modelName: nested('model', 'name'),
      version: row['version'] as String?,
      year: (row['year'] as num?)?.toInt(),
      mileageKm: (row['mileage_km'] as num?)?.toInt(),
      priceCents: (row['price_cents'] as num?)?.toInt(),
      fuelType: row['fuel_type'] as String?,
      powerKw: (row['power_kw'] as num?)?.toInt(),
      description: row['description'] as String?,
      city: row['city'] as String?,
      coverPath: row['cover_path'] as String?,
      videoPath: row['video_path'] as String?,
      dealerName: nested('dealer', 'display_name'),
      ownerId: row['owner_id'] as String?,
      dealerId: row['dealer_id'] as String?,
      province: row['province'] as String?,
      sellerDisplayName: nested('seller', 'display_name'),
      sellerAvatarPath: nested('seller', 'avatar_path'),
    );
  }
}
