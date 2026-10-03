import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../storage/preferences.dart';
import '../supabase/supabase_client.dart';

/// Mirrors the `event_type` enum in the database.
enum AnalyticsEvent {
  impression('impression'),
  view('view'),
  watchTime('watch_time'),
  zoom('zoom'),
  openDetail('open_detail'),
  save('save'),
  unsave('unsave'),
  share('share'),
  contactChat('contact_chat'),
  contactWhatsapp('contact_whatsapp');

  const AnalyticsEvent(this.dbName);
  final String dbName;
}

/// Collects events in memory and writes them to `events` in batches:
/// when the queue is full, after a short delay, or when the app goes
/// to background. One insert per batch, never one per event.
class EventTracker with WidgetsBindingObserver {
  EventTracker(this._client, this._prefs) {
    _anonId = _prefs.getString(PrefKeys.anonId) ?? _createAnonId();
  }

  static const _maxBatch = 20;
  static const _flushDelay = Duration(seconds: 15);
  static const _maxQueue = 500;

  final SupabaseClient _client;
  final SharedPreferences _prefs;
  final _sessionId = const Uuid().v4();
  final _queue = <Map<String, dynamic>>[];
  late final String _anonId;
  Timer? _timer;
  bool _flushing = false;

  String _createAnonId() {
    final id = const Uuid().v4();
    _prefs.setString(PrefKeys.anonId, id);
    return id;
  }

  String get _platform => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        TargetPlatform.android => 'android',
        _ => 'web',
      };

  void track(AnalyticsEvent event, {String? listingId, num? value}) {
    if (_queue.length >= _maxQueue) _queue.removeAt(0);
    _queue.add({
      'type': event.dbName,
      'listing_id': listingId,
      'value': value,
      'profile_id': _client.auth.currentUser?.id,
      'anon_id': _anonId,
      'session_id': _sessionId,
      'platform': _platform,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    if (_queue.length >= _maxBatch) {
      flush();
    } else {
      _timer ??= Timer(_flushDelay, flush);
    }
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_flushing || _queue.isEmpty) return;

    _flushing = true;
    // RLS accepts profile_id only if null or the signed-in user: events
    // queued before a logout or account switch keep only their anon_id.
    final userId = _client.auth.currentUser?.id;
    final batch = [
      for (final e in _queue)
        e['profile_id'] == null || e['profile_id'] == userId
            ? e
            : {...e, 'profile_id': null},
    ];
    _queue.clear();
    try {
      await _client.from('events').insert(batch);
    } catch (e) {
      if (_isPermanent(e)) {
        // Retrying would fail forever and block every later event: drop it.
        if (kDebugMode) debugPrint('EventTracker dropped a batch: $e');
      } else {
        // Offline or transient error: put the batch back, retry later.
        _queue.insertAll(0, batch);
        if (kDebugMode) debugPrint('EventTracker flush failed: $e');
      }
    } finally {
      _flushing = false;
    }
  }

  /// Errors the database will return again on retry: data exceptions (22),
  /// integrity violations such as a deleted listing (23), access rules
  /// such as RLS (42). Network errors, 5xx and 429 stay retryable.
  static bool _isPermanent(Object error) {
    if (error is! PostgrestException) return false;
    // Postgres SQLSTATE codes have 5 chars; non-JSON responses carry the
    // 3-digit HTTP status here instead (429 must not match '42').
    final code = error.code ?? '';
    if (code.length != 5) return false;
    return code.startsWith('22') || code.startsWith('23') || code.startsWith('42');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      flush();
    }
  }
}

final eventTrackerProvider = Provider<EventTracker>((ref) {
  final tracker = EventTracker(
    ref.watch(supabaseProvider),
    ref.watch(sharedPreferencesProvider),
  );
  WidgetsBinding.instance.addObserver(tracker);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(tracker);
    tracker.flush();
  });
  return tracker;
});
