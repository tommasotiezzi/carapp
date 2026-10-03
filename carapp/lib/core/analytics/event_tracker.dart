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
    final batch = List<Map<String, dynamic>>.of(_queue);
    _queue.clear();
    try {
      await _client.from('events').insert(batch);
    } catch (e) {
      // Offline or transient error: put the batch back, retry later.
      _queue.insertAll(0, batch);
      if (kDebugMode) debugPrint('EventTracker flush failed: $e');
    } finally {
      _flushing = false;
    }
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
