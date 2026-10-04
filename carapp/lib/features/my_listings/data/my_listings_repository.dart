import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../sell/data/sell_draft.dart';

/// One of the user's listings (own, or their dealer's), from
/// `my_listings()`: what the seller may know about it.
class MyListing {
  const MyListing({
    required this.id,
    required this.status,
    required this.categoryId,
    this.title,
    this.version,
    this.year,
    this.mileageKm,
    this.priceCents,
    this.coverPath,
    this.city,
    this.publishedAt,
    this.saves = 0,
    this.chats = 0,
    this.lastOfferAt,
    this.lastOfferPriceCents,
  });

  final String id;
  final String status; // `listing_status`
  final String categoryId;
  final String? title;
  final String? version;
  final int? year;
  final int? mileageKm;
  final int? priceCents;
  final String? coverPath;
  final String? city;
  final DateTime? publishedAt;

  /// How many people saved it (never who).
  final int saves;
  final int chats;
  final DateTime? lastOfferAt;
  final int? lastOfferPriceCents;

  /// One offer to the savers every 24 h (`offer_to_savers()`).
  static const offerEvery = Duration(hours: 24);

  bool get isActive => status == 'active';

  /// When the next offer can go; null = now.
  DateTime? nextOfferAt(DateTime now) {
    final last = lastOfferAt;
    if (last == null) return null;
    final next = last.add(offerEvery);
    return next.isAfter(now) ? next : null;
  }

  bool canOffer(DateTime now) => isActive && saves > 0 && priceCents != null && nextOfferAt(now) == null;

  MyListing copyWith({String? status, int? priceCents, DateTime? lastOfferAt, int? lastOfferPriceCents}) =>
      MyListing(
        id: id,
        status: status ?? this.status,
        categoryId: categoryId,
        title: title,
        version: version,
        year: year,
        mileageKm: mileageKm,
        priceCents: priceCents ?? this.priceCents,
        coverPath: coverPath,
        city: city,
        publishedAt: publishedAt,
        saves: saves,
        chats: chats,
        lastOfferAt: lastOfferAt ?? this.lastOfferAt,
        lastOfferPriceCents: lastOfferPriceCents ?? this.lastOfferPriceCents,
      );

  factory MyListing.fromRow(Map<String, dynamic> row) {
    DateTime? time(String key) => DateTime.tryParse((row[key] as String?) ?? '')?.toLocal();
    int? integer(String key) => (row[key] as num?)?.toInt();
    return MyListing(
      id: row['id'] as String,
      status: row['status'] as String,
      categoryId: (row['category_id'] as String?) ?? 'car',
      title: row['title'] as String?,
      version: row['version'] as String?,
      year: integer('year'),
      mileageKm: integer('mileage_km'),
      priceCents: integer('price_cents'),
      coverPath: row['cover_path'] as String?,
      city: row['city'] as String?,
      publishedAt: time('published_at'),
      saves: integer('saves') ?? 0,
      chats: integer('chats') ?? 0,
      lastOfferAt: time('last_offer_at'),
      lastOfferPriceCents: integer('last_offer_price_cents'),
    );
  }
}

enum OfferFailure { notLower, tooLow, tooSoon, noSavers, unavailable, other }

class OfferException implements Exception {
  const OfferException(this.failure);

  final OfferFailure failure;

  /// Maps the errors raised by `offer_to_savers()`.
  factory OfferException.from(Object error) {
    final message = error is PostgrestException ? error.message : '';
    return OfferException(switch (message) {
      _ when message.contains('offer_not_lower') => OfferFailure.notLower,
      _ when message.contains('offer_too_low') => OfferFailure.tooLow,
      _ when message.contains('offer_too_soon') => OfferFailure.tooSoon,
      _ when message.contains('no_savers') => OfferFailure.noSavers,
      _ when message.contains('listing_unavailable') => OfferFailure.unavailable,
      _ => OfferFailure.other,
    });
  }
}

/// "I miei annunci": reads through `my_listings()`, status and price
/// through plain updates (the `protect_listing_fields` trigger allows
/// active → sold / removed, sold → active, draft → removed, and the
/// price), offers through `offer_to_savers()`.
class MyListingsRepository {
  MyListingsRepository(this._client);

  final SupabaseClient _client;

  Future<List<MyListing>> fetch() async {
    final rows = await _client.rpc<List<dynamic>>('my_listings');
    return rows.cast<Map<String, dynamic>>().map(MyListing.fromRow).toList();
  }

  Future<void> setStatus(String listingId, String status) =>
      _client.from('listings').update({'status': status}).eq('id', listingId);

  /// The listing's data as the sell form edits it ("Modifica annuncio").
  /// null when it is not the user's (RLS) or does not exist.
  Future<({String categoryId, String status, SellDetails details})?> fetchForEdit(String listingId) async {
    final row = await _client.from('listings').select(editColumns).eq('id', listingId).maybeSingle();
    if (row == null) return null;
    return (
      categoryId: row['category_id'] as String,
      status: row['status'] as String,
      details: SellDetails.fromJson(row),
    );
  }

  static const editColumns = 'category_id, status, make_id, model_id, version, year, mileage_km, price_cents, '
      'fuel_type, transmission, power_kw, euro_class, owners_count, color, has_service_history, description, '
      'city, province, whatsapp_enabled, attributes';

  /// Saves the edited data (the `protect_listing_fields` trigger allows
  /// data and price; never media, dates or status).
  Future<void> updateDetails(String listingId, SellDetails details) =>
      _client.from('listings').update(details.toListingRow()).eq('id', listingId);

  Future<void> updatePrice(String listingId, int priceCents) =>
      _client.from('listings').update({'price_cents': priceCents}).eq('id', listingId);

  /// A reserved price to everyone who saved the listing. Returns how many
  /// got it. Throws [OfferException].
  Future<int> offerToSavers(String listingId, int priceCents) async {
    try {
      final n = await _client.rpc<Object?>('offer_to_savers', params: {
        'p_listing_id': listingId,
        'p_price_cents': priceCents,
      });
      return (n as num).toInt();
    } catch (e) {
      throw OfferException.from(e);
    }
  }
}

final myListingsRepositoryProvider = Provider<MyListingsRepository>(
  (ref) => MyListingsRepository(ref.watch(supabaseProvider)),
);
