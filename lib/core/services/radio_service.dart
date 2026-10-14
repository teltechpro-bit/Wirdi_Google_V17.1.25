
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/radio_station.dart';
import '../data/radio_stations.dart';
import 'playback_coordinator.dart';

enum RadioState { stopped, loading, playing, error }

/// Which source is currently serving the station list.
enum RadioSource {
  embedded,
  mp3quran,
  radioBrowser,
  dataRosy,
  uthumany,
  // BUGFIX: a successful merge of one or more LIVE sources was being
  // reported as RadioSource.fallback -- the exact same value used when
  // ALL live sources failed and the embedded offline list was kept.
  // That made it impossible to tell (from this enum alone) whether the
  // user was seeing the rich merged catalog or the small offline one.
  combined,
  fallback,
}

class RadioService extends ChangeNotifier {
  RadioService._();
  static final RadioService instance = RadioService._();

  final AudioPlayer _player = AudioPlayer();
  RadioState _state = RadioState.stopped;
  RadioStation? _currentStation;
  String? _errorMessage;
  Timer? _sleepTimer;
  Timer? _sleepCountdown;
  int? _sleepMinutesRemaining;
  Set<String> _favoriteIds = {};
  bool _initialized = false;

  // Start with embedded list immediately — no waiting
  List<RadioStation> _liveStations = kFallbackStations;
  bool _loadingLive = false;
  RadioSource _activeSource = RadioSource.embedded;
  String _sourceLabel = '18 curated Islamic stations';

  static const _favsKey = 'radio_favorites';

  // ── Getters ──────────────────────────────────────────────────────
  RadioState get state             => _state;
  RadioStation? get currentStation => _currentStation;
  String? get errorMessage         => _errorMessage;
  bool get isPlaying               => _state == RadioState.playing;
  bool get isLoading               => _state == RadioState.loading;
  int? get sleepMinutesRemaining   => _sleepMinutesRemaining;
  bool get hasSleepTimer           => _sleepTimer != null;
  bool get loadingLive             => _loadingLive;
  bool get loadingStations         => _loadingLive;
  RadioSource get activeSource     => _activeSource;
  String get sourceLabel           => _sourceLabel;
  bool isFavorite(String id)       => _favoriteIds.contains(id);

  List<RadioStation> get stations  => _liveStations;
  List<RadioStation> get allStations => _liveStations;

  List<RadioStation> get favoriteStations =>
      _liveStations.where((s) => _favoriteIds.contains(s.id)).toList();

  // Curated stations are probed as actual stream responses before they
  // enter the catalogue. A successful HTTP status alone is not sufficient:
  // HLS must return an EXT M3U playlist, and audio endpoints must return
  // audio-like content rather than an HTML/API error page.
  static const List<RadioStation> _curatedStreamCandidates = [
    RadioStation(id: 'w2q_egypt', nameAr: 'إذاعة القرآن الكريم من مصر', nameEn: 'Egypt Holy Quran Radio', streamUrl: 'https://way2quran.com/api/external-radio/stream/egypt-holy-quran-radio', country: 'Egypt', countryCode: 'EG', category: 'quran'),
    RadioStation(id: 'w2q_saudi', nameAr: 'إذاعة القرآن الكريم من السعودية', nameEn: 'Saudi Holy Quran Radio', streamUrl: 'https://way2quran.com/api/external-radio/stream/holy-quran-from-saudia-arabia', country: 'Saudi Arabia', countryCode: 'SA', category: 'quran'),
    RadioStation(id: 'w2q_kuwait', nameAr: 'إذاعة القرآن الكريم من الكويت', nameEn: 'Kuwait Quran Radio', streamUrl: 'https://way2quran.com/api/external-radio/stream/kuwait-quran', country: 'Kuwait', countryCode: 'KW', category: 'quran'),
    RadioStation(id: 'w2q_pakistan', nameAr: 'إذاعة القرآن الكريم من باكستان', nameEn: 'Pakistan Quran Radio', streamUrl: 'https://way2quran.com/api/external-radio/stream/pakistan-quran', country: 'Pakistan', countryCode: 'PK', category: 'quran'),
    RadioStation(id: 'w2q_palestine', nameAr: 'إذاعة القرآن الكريم من فلسطين', nameEn: 'Palestine Quran Radio', streamUrl: 'https://way2quran.com/api/external-radio/stream/palestine-quran', country: 'Palestine', countryCode: 'PS', category: 'quran'),
    RadioStation(id: 'w2q_sharjah', nameAr: 'إذاعة القرآن الكريم من الشارقة', nameEn: 'Sharjah Quran Radio', streamUrl: 'https://way2quran.com/api/external-radio/stream/uae-sharjah-quran', country: 'UAE', countryCode: 'AE', category: 'quran'),
    RadioStation(id: 'w2q_main', nameAr: 'الراديو الرئيسي', nameEn: 'Main Radio', streamUrl: 'https://way2quran.com/api/external-radio/stream/main-radio', country: 'International', countryCode: 'INT', category: 'quran'),
    RadioStation(id: 'w2q_beautiful', nameAr: 'روائع التلاوات', nameEn: 'Beautiful Recitations', streamUrl: 'https://way2quran.com/api/external-radio/stream/beautiful-recitations', country: 'International', countryCode: 'INT', category: 'quran'),
    RadioStation(id: 'w2q_short', nameAr: 'تلاوات قصيرة', nameEn: 'Short Recitations', streamUrl: 'https://way2quran.com/api/external-radio/stream/amazing-short-recitations', country: 'International', countryCode: 'INT', category: 'quran'),
    RadioStation(id: 'w2q_serenity', nameAr: 'آيات السكينة', nameEn: 'Verses of Serenity', streamUrl: 'https://way2quran.com/api/external-radio/stream/verses-of-serenity', country: 'International', countryCode: 'INT', category: 'quran'),
    RadioStation(id: 'w2q_tabari', nameAr: 'خلاصة تفسير الطبري', nameEn: 'Tafsir al-Tabari Summary', streamUrl: 'https://way2quran.com/api/external-radio/stream/interpretation-of-the-holy-qur-an-conclusion-from-tafsir-al-tabari', country: 'International', countryCode: 'INT', category: 'lectures'),
    RadioStation(id: 'w2q_mp3quran', nameAr: 'تلاوات MP3Quran', nameEn: 'MP3Quran Recitations', streamUrl: 'https://way2quran.com/api/external-radio/stream/mp3quran-109076', country: 'International', countryCode: 'INT', category: 'quran'),
    RadioStation(id: 'live_bahrain', nameAr: 'إذاعة القرآن الكريم من البحرين', nameEn: 'Bahrain Holy Quran Radio', streamUrl: 'https://5c7b683162943.streamlock.net/live/ngrp:radio-106-1_all/playlist.m3u8', country: 'Bahrain', countryCode: 'BH', category: 'quran', isOfficial: true),
    RadioStation(id: 'live_jordan', nameAr: 'إذاعة القرآن الكريم من الأردن', nameEn: 'Jordan Holy Quran Radio', streamUrl: 'https://jrtv-live.ercdn.net/jrradio/quranradio.m3u8', country: 'Jordan', countryCode: 'JO', category: 'quran', isOfficial: true),
    RadioStation(id: 'live_oman', nameAr: 'إذاعة القرآن الكريم من سلطنة عُمان', nameEn: 'Oman Holy Quran Radio', streamUrl: 'https://partwota.cdn.mgmlcdn.com/quranrdoorg/quranrdo.stream_aac/chunklist.m3u8', country: 'Oman', countryCode: 'OM', category: 'quran', isOfficial: true),
  ];

  Future<bool> _probeLiveStream(RadioStation station) async {
    if (!RadioStation.isSecureUrl(station.streamUrl)) return false;
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(station.streamUrl))
        ..headers['Range'] = 'bytes=0-1023'
        ..headers['User-Agent'] = 'Wirdi/1.0 radio stream probe';
      final response = await client.send(request).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>().timeout(const Duration(seconds: 1), onTimeout: () {});
        return false;
      }

      final contentType = (response.headers['content-type'] ?? '').toLowerCase();
      final iterator = StreamIterator<List<int>>(response.stream);
      final bytes = <int>[];
      try {
        while (bytes.length < 1024 && await iterator.moveNext().timeout(const Duration(seconds: 5))) {
          bytes.addAll(iterator.current);
        }
      } finally {
        await iterator.cancel();
      }
      if (bytes.isEmpty) return false;
      final prefix = String.fromCharCodes(bytes.take(512)).trimLeft().toLowerCase();
      if (prefix.startsWith('#extm3u')) {
        return prefix.contains('#extinf') || prefix.contains('#ext-x-stream-inf') ||
            prefix.contains('#ext-x-targetduration') || prefix.contains('#ext-x-media');
      }
      if (contentType.contains('mpegurl') || contentType.contains('vnd.apple')) return false;
      if (contentType.startsWith('audio/') || contentType.contains('octet-stream')) {
        // Reject common HTML/JSON error payloads even when served with a
        // misleading audio/octet-stream content type.
        return !prefix.startsWith('<!doctype html') &&
            !prefix.startsWith('<html') &&
            !prefix.startsWith('{') &&
            !prefix.startsWith('[') &&
            bytes.length >= 128;
      }
      return false;
    } catch (e) {
      debugPrint('[Radio] Stream probe failed for ${station.id}: $e');
      return false;
    } finally {
      client.close();
    }
  }

  Future<List<RadioStation>> _fetchVerifiedCuratedStreams() async {
    final results = await Future.wait(
      _curatedStreamCandidates.map((station) async {
        final ok = await _probeLiveStream(station);
        debugPrint('[Radio] ${station.id}: ${ok ? "verified" : "disabled (stream probe failed)"}');
        return ok ? station : null;
      }),
    );
    return results.whereType<RadioStation>().toList();
  }

  // ── Init ─────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFavorites();

    _player.onPlayerStateChanged.listen((ps) {
      if (ps == PlayerState.playing) {
        _state = RadioState.playing;
      } else if (ps == PlayerState.stopped || ps == PlayerState.completed ||
                 ps == PlayerState.paused) {
        if (_state != RadioState.error) _state = RadioState.stopped;
      }
      notifyListeners();
    });

    // Stations already loaded from embedded list above.
    // Try to refresh from API in background (non-blocking).
    _refreshFromApiInBackground();
  }

  // ── Background API refresh ──────────────────────────────────────
  void _refreshFromApiInBackground() {
    // Fire and forget — does NOT block init or the UI
    Future.microtask(_doRefresh);
  }

  Future<void> refreshStations() => _doRefresh();

  /// ROOT CAUSE FIX (v105): v104 made mp3quran.net / Radio-Browser each
  /// a full-list "primary" source that REPLACED whatever list was
  /// already active. That silently dropped any station that only
  /// existed in the sources that got demoted (e.g. a specific "Egypt
  /// Quran Radio" station some users relied on). Switching which
  /// source is primary should never make a previously-available
  /// station disappear. Fix: fetch from ALL four sources independently
  /// and MERGE every station from every source that responded into one
  /// combined list, deduplicated by stream URL.
  Future<void> _doRefresh() async {
    _loadingLive = true;
    notifyListeners();

    final combined = <String, RadioStation>{};
    final succeededSources = <String>[];

    Future<void> mergeFrom(Future<List<RadioStation>> Function() fetch, String label) async {
      try {
        final list = await fetch();
        if (list.isEmpty) return;
        succeededSources.add(label);
        for (final s in list) {
          // HTTPS only: cleartext traffic is disabled app-wide, so http:// streams could never play.
          if (RadioStation.isSecureUrl(s.streamUrl)) combined[s.streamUrl] = s;
        }
      } catch (e) {
        debugPrint('[Radio] $label error: $e');
      }
    }

    await mergeFrom(_fetchMp3Quran, 'mp3quran.net');
    await mergeFrom(_fetchRadioBrowser, 'Radio-Browser');
    await mergeFrom(_fetchDataRosy, 'Data-Rosy');
    await mergeFrom(_fetchUthumany, 'Uthumany');
    await mergeFrom(_fetchIprd, 'IPRD');
    await mergeFrom(_fetchVerifiedCuratedStreams, 'verified curated Quran streams');
    // Keep the Cairo Quran station available even if an upstream catalog
    // temporarily omits it. This is the HTTPS stream documented by the
    // public Islamic-APIs radio endpoint.
    const cairo = RadioStation(
      id: 'official_cairo_quran',
      nameAr: 'إذاعة القرآن الكريم من القاهرة',
      nameEn: 'Quran Radio Cairo',
      streamUrl: 'https://stream.radiojar.com/8s5u5tpdtwzuv',
      country: 'Egypt',
      countryCode: 'EG',
      category: 'quran',
      isOfficial: true,
    );
    if (RadioStation.isSecureUrl(cairo.streamUrl)) {
      combined.putIfAbsent(cairo.streamUrl, () => cairo);
    }

    if (combined.isNotEmpty) {
      _liveStations = combined.values.toList();
      _activeSource = RadioSource.combined;
      _sourceLabel = _liveStations.length.toString() + ' stations from ' + succeededSources.join(' + ');
      debugPrint('[Radio] Combined ' + _liveStations.length.toString() + ' stations from: ' + succeededSources.join(', '));
    } else {
      debugPrint('[Radio] All station sources failed -- keeping the embedded fallback list.');
    }

    _loadingLive = false;
    notifyListeners();
  }


  Future<List<RadioStation>> _fetchDataRosy() async {
    final resp = await http
        .get(Uri.parse('https://data-rosy.vercel.app/radio.json'))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return const [];
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(RadioStation.fromDataRosy)
        .where((s) => s.streamUrl.isNotEmpty && RadioStation.isSecureUrl(s.streamUrl))
        .toList();
  }

  Future<List<RadioStation>> _fetchUthumany() async {
    final resp = await http
        .get(Uri.parse('https://raw.githubusercontent.com/uthumany/radio-api/main/client/public/api/stations.json'))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return const [];
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(RadioStation.fromUthumany)
        .where((s) => s.streamUrl.isNotEmpty && RadioStation.isSecureUrl(s.streamUrl))
        .toList();
  }


  Future<List<RadioStation>> _fetchIprd() async {
    final resp = await http
        .get(Uri.parse('https://iprd-org.github.io/iprd/site_data/metadata/catalog.json'))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return const [];
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final stations = decoded['stations'];
    if (stations is! List) return const [];

    const keywords = ['quran', 'koran', 'islamic', 'islam', 'religious', 'religion', 'tilawah'];
    final result = <RadioStation>[];
    for (final raw in stations.whereType<Map<String, dynamic>>()) {
      final text = [
        raw['name'],
        raw['language'],
        ...(raw['genres'] is List ? raw['genres'] : const []),
        ...(raw['tags'] is List ? raw['tags'] : const []),
      ].whereType<String>().join(' ').toLowerCase();
      if (!keywords.any(text.contains)) continue;
      final station = RadioStation.fromIprd(raw);
      if (station.streamUrl.isNotEmpty) result.add(station);
    }
    return result;
  }

  Future<List<RadioStation>> _fetchMp3Quran() async {
    final resp = await http
        .get(Uri.parse('https://mp3quran.net/api/v3/radios?language=ar'))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return const [];
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final radios = decoded['radios'] as List<dynamic>? ?? const [];
    return radios
        .whereType<Map<String, dynamic>>()
        .map(RadioStation.fromMp3Quran)
        .where((s) => s.streamUrl.isNotEmpty)
        .toList();
  }

  /// BROADENED (was 'quran' only): Radio-Browser is a community-maintained
  /// directory that already does its OWN server-side health checking
  /// (hidebroken=true strips out streams it has detected as dead) --
  /// that makes it the one source here we can safely broaden without
  /// fabricating anything, since every result it returns is at least
  /// nominally live-checked by Radio-Browser itself, not guessed by us.
  /// Querying only the single tag 'quran' misses many real, working
  /// stations tagged under closely related terms instead (an Arabic
  /// broadcaster might be tagged 'islam' or 'islamic', a Quran-focused
  /// French/Spanish-language station 'coran'/'coran' etc, a recitation-
  /// only station 'tilawah'/'quran radio'). Querying each tag and
  /// merging -- deduplicated by stationuuid, same pattern _doRefresh()
  /// already uses across whole SOURCES -- multiplies the real, verified
  /// catalog size using only the existing trusted mechanism.
  // Generic tags ('islam', 'islamic') were dropped in v1.54: they returned unmoderated, non-Quran content.
  static const _radioBrowserTags = ['quran', 'coran', 'tilawah', 'quran radio'];

  Future<List<RadioStation>> _fetchRadioBrowser() async {
    final merged = <String, RadioStation>{};
    for (final tag in _radioBrowserTags) {
      try {
        final resp = await http.get(
          Uri.parse('https://de1.api.radio-browser.info/json/stations/bytag/${Uri.encodeComponent(tag)}?limit=100&hidebroken=true'),
          headers: {'User-Agent': 'WirdiApp/1.52 (Islamic companion app)'},
        ).timeout(const Duration(seconds: 10));
        if (resp.statusCode != 200) continue;
        final List<dynamic> data = jsonDecode(resp.body);
        for (final j in data.whereType<Map<String, dynamic>>()) {
          final station = RadioStation.fromRadioBrowser(j);
          if (station.streamUrl.isEmpty) continue;
          merged[station.stationUuid ?? station.streamUrl] = station;
        }
      } catch (e) {
        debugPrint('[Radio] Radio-Browser tag \'' + tag + '\' error: ' + e.toString());
      }
    }
    return merged.values.toList();
  }

  // ── Playback ─────────────────────────────────────────────────────
  Future<void> play(RadioStation station) async {
    try {
      if (_currentStation?.id == station.id && isPlaying) return;
      await PlaybackCoordinator.stopQuranForRadio();
      _state = RadioState.loading;
      _currentStation = station;
      _errorMessage = null;
      notifyListeners();
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(UrlSource(station.streamUrl));
    } catch (e) {
      debugPrint('[Radio] play error: ' + e.toString());
      _state = RadioState.error;
      _errorMessage = 'Could not connect to this station. Please try another station or check your connection.';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try { await _player.stop(); } catch (e) {
      debugPrint('[Radio] play error: ' + e.toString());
    }
    _state = RadioState.stopped;
    _currentStation = null;
    cancelSleepTimer();
    notifyListeners();
  }

  /// Pauses the current station without forgetting it -- unlike [stop],
  /// [_currentStation] stays set so the system media notification (and
  /// any UI reflecting "now playing") can still show which station is
  /// paused and offer a Play button that reconnects to it. Live streams
  /// don't have a meaningful buffered position to truly resume from, so
  /// resuming re-fetches the stream fresh via [play].
  Future<void> pause() async {
    try { await _player.stop(); } catch (e) {
      debugPrint('[Radio] pause error: ' + e.toString());
    }
    if (_state != RadioState.error) _state = RadioState.stopped;
    notifyListeners();
  }

  Future<void> togglePlay(RadioStation station) async {
    if (_currentStation?.id == station.id && isPlaying) {
      await pause();
    } else {
      await play(station);
    }
  }

  /// Plays the station right after the current one in [allStations],
  /// wrapping around to the first station after the last. No-op if
  /// nothing is currently selected or the list has fewer than 2 items.
  Future<void> playNext() async {
    if (_currentStation == null || _liveStations.length < 2) return;
    final idx = _liveStations.indexWhere((s) => s.id == _currentStation!.id);
    if (idx == -1) return;
    final nextIdx = (idx + 1) % _liveStations.length;
    await play(_liveStations[nextIdx]);
  }

  /// Plays the station right before the current one in [allStations],
  /// wrapping around to the last station before the first. No-op if
  /// nothing is currently selected or the list has fewer than 2 items.
  Future<void> playPrevious() async {
    if (_currentStation == null || _liveStations.length < 2) return;
    final idx = _liveStations.indexWhere((s) => s.id == _currentStation!.id);
    if (idx == -1) return;
    final prevIdx = (idx - 1 + _liveStations.length) % _liveStations.length;
    await play(_liveStations[prevIdx]);
  }

  // ── Sleep Timer ──────────────────────────────────────────────────
  void setSleepTimer(int minutes) {
    cancelSleepTimer();
    _sleepMinutesRemaining = minutes;
    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      await stop();
      _sleepMinutesRemaining = null;
      notifyListeners();
    });
    _sleepCountdown = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_sleepMinutesRemaining != null && _sleepMinutesRemaining! > 0) {
        _sleepMinutesRemaining = _sleepMinutesRemaining! - 1;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    _sleepTimer = null;
    _sleepCountdown = null;
    _sleepMinutesRemaining = null;
  }

  // ── Favorites ────────────────────────────────────────────────────
  Future<void> toggleFavorite(String stationId) async {
    if (_favoriteIds.contains(stationId)) {
      _favoriteIds.remove(stationId);
    } else {
      _favoriteIds.add(stationId);
    }
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> _loadFavorites() async {
    final p = await SharedPreferences.getInstance();
    _favoriteIds = (p.getStringList(_favsKey) ?? []).toSet();
  }

  Future<void> _saveFavorites() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_favsKey, _favoriteIds.toList());
  }
}
