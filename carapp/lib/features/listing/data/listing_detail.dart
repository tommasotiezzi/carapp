import '../../feed/data/feed_item.dart';

/// Everything the listing screen shows, from one `listings` row and its joins.
class ListingDetail {
  const ListingDetail({
    required this.id,
    required this.sellerType,
    required this.ownerId,
    required this.categoryId,
    required this.publishedAt,
    this.makeName,
    this.modelName,
    this.version,
    this.year,
    this.mileageKm,
    this.priceCents,
    this.fuelType,
    this.transmission,
    this.powerKw,
    this.euroClass,
    this.color,
    this.ownersCount,
    this.hasServiceHistory,
    this.warrantyMonths,
    this.description,
    this.city,
    this.province,
    this.coverPath,
    this.videoPath,
    this.dealer,
    this.photos = const [],
  });

  final String id;
  final String sellerType; // 'private' | 'dealer'
  final String ownerId;
  final String categoryId; // 'car' | 'motorcycle'
  final DateTime? publishedAt;
  final String? makeName;
  final String? modelName;
  final String? version;
  final int? year;
  final int? mileageKm;
  final int? priceCents;
  final String? fuelType;
  final String? transmission;
  final int? powerKw;
  final int? euroClass;
  final String? color;
  final int? ownersCount;
  final bool? hasServiceHistory;
  final int? warrantyMonths;
  final String? description;
  final String? city;
  final String? province;
  final String? coverPath;
  final String? videoPath;
  final ListingDealer? dealer;
  final List<ListingPhoto> photos;

  bool get isDealer => sellerType == 'dealer';

  /// The card data for grids (e.g. adding it to "Salvati" without a request).
  FeedItem toFeedItem() => FeedItem(
        id: id,
        sellerType: sellerType,
        publishedAt: publishedAt ?? DateTime.now(),
        makeName: makeName,
        modelName: modelName,
        version: version,
        year: year,
        mileageKm: mileageKm,
        priceCents: priceCents,
        fuelType: fuelType,
        powerKw: powerKw,
        description: description,
        city: city,
        coverPath: coverPath,
        videoPath: videoPath,
        dealerName: dealer?.displayName,
      );

  /// "Volkswagen Golf"
  String get title =>
      [makeName, modelName].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');

  /// "Milano (MI)"
  String? get location {
    if (city == null || city!.trim().isEmpty) return null;
    return province == null || province!.trim().isEmpty ? city : '$city ($province)';
  }

  /// Only rows the screen needs. Profiles are not readable by other users,
  /// so a private seller stays anonymous here.
  static const selectColumns =
      'id, seller_type, owner_id, category_id, published_at, version, year, '
      'mileage_km, price_cents, fuel_type, transmission, power_kw, euro_class, '
      'color, owners_count, has_service_history, warranty_months, description, '
      'city, province, cover_path, video_path, '
      'make:makes(name), model:models(name), '
      'dealer:dealers(id, display_name, city, province, logo_path, vat_verified_at), '
      'media:listing_media(kind, storage_path, width, height, sort_order)';

  factory ListingDetail.fromRow(Map<String, dynamic> row) {
    String? nested(String key, String field) =>
        (row[key] as Map<String, dynamic>?)?[field] as String?;
    int? toInt(String key) => (row[key] as num?)?.toInt();

    final dealerRow = row['dealer'] as Map<String, dynamic>?;
    final photos = ((row['media'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .where((m) => m['kind'] == 'photo')
        .map(ListingPhoto.fromRow)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return ListingDetail(
      id: row['id'] as String,
      sellerType: row['seller_type'] as String,
      ownerId: row['owner_id'] as String,
      categoryId: row['category_id'] as String,
      publishedAt: DateTime.tryParse((row['published_at'] as String?) ?? ''),
      makeName: nested('make', 'name'),
      modelName: nested('model', 'name'),
      version: row['version'] as String?,
      year: toInt('year'),
      mileageKm: toInt('mileage_km'),
      priceCents: toInt('price_cents'),
      fuelType: row['fuel_type'] as String?,
      transmission: row['transmission'] as String?,
      powerKw: toInt('power_kw'),
      euroClass: toInt('euro_class'),
      color: row['color'] as String?,
      ownersCount: toInt('owners_count'),
      hasServiceHistory: row['has_service_history'] as bool?,
      warrantyMonths: toInt('warranty_months'),
      description: row['description'] as String?,
      city: row['city'] as String?,
      province: row['province'] as String?,
      coverPath: row['cover_path'] as String?,
      videoPath: row['video_path'] as String?,
      dealer: dealerRow == null ? null : ListingDealer.fromRow(dealerRow),
      photos: photos,
    );
  }
}

class ListingDealer {
  const ListingDealer({
    required this.id,
    required this.displayName,
    this.city,
    this.province,
    this.logoPath,
    this.vatVerified = false,
  });

  final String id;
  final String displayName;
  final String? city;
  final String? province;
  final String? logoPath;
  final bool vatVerified;

  factory ListingDealer.fromRow(Map<String, dynamic> row) => ListingDealer(
        id: row['id'] as String,
        displayName: row['display_name'] as String,
        city: row['city'] as String?,
        province: row['province'] as String?,
        logoPath: row['logo_path'] as String?,
        vatVerified: row['vat_verified_at'] != null,
      );
}

class ListingPhoto {
  const ListingPhoto({
    required this.storagePath,
    required this.sortOrder,
    this.width,
    this.height,
  });

  final String storagePath;
  final int sortOrder;
  final int? width;
  final int? height;

  factory ListingPhoto.fromRow(Map<String, dynamic> row) => ListingPhoto(
        storagePath: row['storage_path'] as String,
        sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
        width: (row['width'] as num?)?.toInt(),
        height: (row['height'] as num?)?.toInt(),
      );
}

/// One row of `listing_questions`. RLS returns the public answered ones
/// plus the questions the signed-in user asked.
class ListingQuestion {
  const ListingQuestion({
    required this.id,
    required this.question,
    required this.createdAt,
    this.answer,
    this.askerId,
  });

  final String id;
  final String question;
  final DateTime createdAt;
  final String? answer;
  final String? askerId;

  bool get isAnswered => answer != null && answer!.trim().isNotEmpty;

  static const selectColumns = 'id, question, answer, asker_id, created_at';

  factory ListingQuestion.fromRow(Map<String, dynamic> row) => ListingQuestion(
        id: row['id'] as String,
        question: row['question'] as String,
        answer: row['answer'] as String?,
        askerId: row['asker_id'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}

/// Average and latest reviews of a dealer.
class DealerReviews {
  const DealerReviews({required this.count, this.average, this.latest = const []});

  final int count;
  final double? average;
  final List<DealerReview> latest;

  static const empty = DealerReviews(count: 0);
}

class DealerReview {
  const DealerReview({required this.rating, required this.createdAt, this.body});

  final int rating;
  final DateTime createdAt;
  final String? body;

  factory DealerReview.fromRow(Map<String, dynamic> row) => DealerReview(
        rating: (row['rating'] as num).toInt(),
        body: row['body'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
