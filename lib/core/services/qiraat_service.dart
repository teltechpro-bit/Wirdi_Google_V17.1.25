import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/qiraat_catalog.dart';
import '../models/riwayah_reader.dart';

class QiraatService {
  QiraatService._();
  static final QiraatService instance = QiraatService._();

  static const _riwayahKey = 'qiraat_selected_riwayah';
  static const _catalogUrl = 'https://mp3quran.net/api/v3/reciters?language=eng';
  static const _qudCatalogUrl = 'https://audio.qud.dev/api/static/catalog.json';

  String _selectedRiwayahId = 'hafs';
  final Map<String, Map<int, ({int startMs, int endMs})>> _ayahTimingCache = <String, Map<int, ({int startMs, int endMs})>>{};
  Map<String, List<RiwayahReader>>? _readers;
  final Set<String> _healthyAudioServers = <String>{};
  final Set<String> _unhealthyAudioServers = <String>{};
  Map<String, String>? _selectedReaderIds;
  Future<Map<String, List<RiwayahReader>>>? _readersFuture;

  String get selectedRiwayahId => _selectedRiwayahId;
  RiwayahOption get selectedRiwayah => QiraatCatalog.byId(_selectedRiwayahId);
  bool get isHafs => _selectedRiwayahId == 'hafs';
  bool get isWarsh => _selectedRiwayahId == 'warsh';

  List<RiwayahReader> readersForSelectedRiwayah() => _readers?[_selectedRiwayahId] ?? const [];
  List<RiwayahReader> readersForRiwayah(String riwayahId) => _readers?[riwayahId] ?? const [];

  /// Number of riwayat with at least one complete reader source discovered at runtime.
  int get discoveredRiwayahCount {
    final readers = _readers;
    if (readers == null) return 0;
    return QiraatCatalog.allRiwayat
        .where((r) => (readers[r.id] ?? const []).isNotEmpty)
        .length;
  }

  bool hasRuntimeReaderSource(String riwayahId) {
    return (_readers?[riwayahId] ?? const []).isNotEmpty;
  }

  bool hasVerifiedRuntimeAyahAudio(String riwayahId) =>
      (_readers?[riwayahId] ?? const <RiwayahReader>[])
          .any((reader) => reader.hasAyahAudio);

  RiwayahReader? selectedReaderFor(String riwayahId) {
    final list = _readers?[riwayahId] ?? const [];
    final id = _selectedReaderIds?[riwayahId];
    if (id == null) return null;
    for (final reader in list) {
      if (reader.id == id) return reader;
    }
    return null;
  }

  RiwayahReader? defaultReaderFor(String riwayahId) {
    final list = _readers?[riwayahId] ?? const [];
    return list.isEmpty ? null : list.first;
  }

  bool selectedReaderHasAyahAudio() {
    final reader = selectedReaderFor(_selectedRiwayahId);
    return reader?.hasAyahAudio ?? false;
  }

  Future<void> loadReaders() async {
    if (_readers != null) return;
    final prefs = await SharedPreferences.getInstance();
    _selectedReaderIds = <String, String>{};
    for (final r in QiraatCatalog.allRiwayat) {
      final id = prefs.getString('qiraat_reader_${r.id}');
      if (id != null) _selectedReaderIds![r.id] = id;
    }
    final future = _readersFuture ??= _fetchReaders();
    _readers = await future;
    _readersFuture = null;

    // Establish an explicit initial reader for each discovered riwayah. This is
    // the initial pairing, not a playback fallback: once a user changes it,
    // playback must use that exact reader only.
    for (final entry in _readers!.entries) {
      if (entry.value.isEmpty) continue;
      final current = _selectedReaderIds![entry.key];
      if (current == null || !entry.value.any((reader) => reader.id == current)) {
        _selectedReaderIds![entry.key] = entry.value.first.id;
      }
    }
  }

  Future<void> setReader(String riwayahId, String readerId) async {
    await loadReaders();
    final exists = (_readers?[riwayahId] ?? const []).any((r) => r.id == readerId);
    if (!exists) return;
    _selectedReaderIds ??= <String, String>{};
    _selectedReaderIds![riwayahId] = readerId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qiraat_reader_$riwayahId', readerId);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_riwayahKey);
    if (stored != null && QiraatCatalog.allRiwayat.any((r) => r.id == stored)) {
      _selectedRiwayahId = stored;
    }
  }

  Future<void> setRiwayah(String id) async {
    if (!QiraatCatalog.allRiwayat.any((r) => r.id == id)) return;
    _selectedRiwayahId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_riwayahKey, id);
  }

  String? ayahAudioUrl(int surahNumber, int ayahNumber, int globalAyahNumber, {String hafsEdition = 'ar.alafasy'}) {
    final reader = selectedReaderFor(_selectedRiwayahId);
    if (reader == null || !reader.hasAyahAudio || reader.server.isEmpty) return null;
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return reader.server + s + a + '.mp3';
  }

  Future<String?> surahAudioUrl(int surahNumber) async {
    // Never substitute another reader or another riwayah. The selected reader
    // is the complete playback identity.
    final reader = selectedReaderFor(_selectedRiwayahId);
    if (reader == null) return null;
    final directUrl = reader.surahUrls[surahNumber];
    if (directUrl != null && await _isHealthyAudioUrl(directUrl)) return directUrl;
    if (reader.server.isEmpty || !await _isHealthyAudioServer(reader.server)) return null;
    return reader.server + surahNumber.toString().padLeft(3, '0') + '.mp3';
  }

  Future<bool> _isHealthyAudioUrl(String url) async {
    try {
      final head = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (head.statusCode >= 200 && head.statusCode < 400) return true;
      final ranged = await http.get(Uri.parse(url), headers: const {'Range': 'bytes=0-0'}).timeout(const Duration(seconds: 8));
      return ranged.statusCode == 200 || ranged.statusCode == 206;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isHealthyAudioServer(String server) async {
    if (_healthyAudioServers.contains(server)) return true;
    if (_unhealthyAudioServers.contains(server)) return false;

    final probeUrl = server + '001.mp3';
    try {
      final head = await http
          .head(Uri.parse(probeUrl))
          .timeout(const Duration(seconds: 8));
      if (head.statusCode >= 200 && head.statusCode < 400) {
        _healthyAudioServers.add(server);
        return true;
      }

      final ranged = await http
          .get(
            Uri.parse(probeUrl),
            headers: const {'Range': 'bytes=0-0'},
          )
          .timeout(const Duration(seconds: 8));
      if (ranged.statusCode == 200 || ranged.statusCode == 206) {
        _healthyAudioServers.add(server);
        return true;
      }
    } catch (_) {
      // A failed probe must never cause fallback to another riwayah.
    }

    _unhealthyAudioServers.add(server);
    return false;
  }

    static const Map<String, int> _mp3QuranRiwayahIds = {
    'hafs': 1,
    'qalun': 5,
    'warsh': 10,
    // Keep only unambiguous, well-established static IDs. Other riwayat
    // must be discovered by their exact names from the API catalog; guessing
    // an ID can expose another riwayah's audio under the wrong label.
    'al_bazzi': 11,
  };

  Future<Map<String, List<RiwayahReader>>> _fetchReaders() async {
    try {
      final result = <String, List<RiwayahReader>>{};
      await _fetchQudReaders(result);
      final dynamicIds = await _fetchMp3QuranRiwayahIds();
      final idsByRiwayah = <String, Set<int>>{};

      for (final entry in dynamicIds.entries) {
        for (final riwayahId in entry.value) {
          idsByRiwayah.putIfAbsent(riwayahId, () => <int>{}).add(entry.key);
        }
      }

      // Keep these documented IDs as a safety net if the riwayat catalog
      // endpoint is temporarily unavailable or changes shape.
      for (final entry in _mp3QuranRiwayahIds.entries) {
        idsByRiwayah.putIfAbsent(entry.key, () => <int>{}).add(entry.value);
      }

      for (final entry in idsByRiwayah.entries) {
        for (final apiId in entry.value) {
          final uri = Uri.parse(_catalogUrl).replace(
            queryParameters: <String, String>{
              'language': 'eng',
              'rewaya': apiId.toString(),
            },
          );
          // A single unavailable API projection must not discard sources
          // already discovered from QUD or earlier MP3Quran requests.
          try {
            await _fetchReadersFromUri(
              uri,
              result,
              onlyRiwayat: {entry.key},
            );
          } catch (_) {
            // Keep previously discovered readers and continue probing.
          }
        }
      }
      // Fetch the Arabic API projection as well so the same reader ID can
      // display a localized name without changing its audio source.
      final arabic = <String, List<RiwayahReader>>{};
      for (final entry in idsByRiwayah.entries) {
        for (final apiId in entry.value) {
          try {
            final uri = Uri.parse(_catalogUrl).replace(
              queryParameters: <String, String>{
                'language': 'ar',
                'rewaya': apiId.toString(),
              },
            );
            try {
              await _fetchReadersFromUri(uri, arabic, onlyRiwayat: {entry.key});
            } catch (_) {
              // Arabic display names are optional; audio sources remain valid.
            }
          } catch (_) {
            // Localization is optional; never discard the verified source.
          }
        }
      }
      for (final entry in result.entries) {
        for (var i = 0; i < entry.value.length; i++) {
          final reader = entry.value[i];
          final matches = arabic[entry.key] ?? const <RiwayahReader>[];
          RiwayahReader? localized;
          for (final candidate in matches) {
            if (candidate.id == reader.id) {
              localized = candidate;
              break;
            }
          }
          if (localized != null) {
            entry.value[i] = RiwayahReader(
              id: reader.id,
              name: reader.name,
              nameAr: localized.name,
              riwayahId: reader.riwayahId,
              source: reader.source,
              server: reader.server,
              surahs: reader.surahs,
              hasAyahAudio: reader.hasAyahAudio,
              surahUrls: reader.surahUrls,
              timingReadId: reader.timingReadId,
            );
          }
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _fetchQudReaders(
    Map<String, List<RiwayahReader>> result,
  ) async {
    try {
      final response = await http.get(Uri.parse(_qudCatalogUrl)).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return;
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return;
      final items = json['recitations'] ?? json['deliveries'];
      if (items is! List) return;
      for (final item in items) {
        if (item is! Map) continue;
        final riwayah = _qudRiwayahId('${item['riwayah'] ?? ''}');
        if (riwayah == null) continue;
        final urls = _qudSurahUrls(item);
        if (urls.length != 114) continue;
        final name = '${item['name'] ?? item['reciter'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        final slug = '${item['slug'] ?? item['id'] ?? name}';
        final reader = RiwayahReader(
          id: 'qud-$slug',
          name: name,
          riwayahId: riwayah,
          source: 'QUD',
          server: '',
          hasAyahAudio: false,
          surahs: urls.keys.toSet(),
          surahUrls: urls,
        );
        final list = result.putIfAbsent(riwayah, () => <RiwayahReader>[]);
        if (!list.any((r) => r.id == reader.id)) list.add(reader);
      }
    } catch (_) {
      // QUD is additive; existing verified sources remain usable.
    }
  }

  String? _qudRiwayahId(String raw) {
    final value = _normalize(raw);
    if (value.contains('warsh')) return 'warsh';
    if (value.contains('qalun') || value.contains('qaloon')) return 'qalun';
    if (value.contains('shubah') || value.contains('shobah')) return 'shuba';
    if (value.contains('hafs')) return 'hafs';
    if (value.contains('susi') || value.contains('soosi')) return 'al_susi';
    if (value.contains('duri') && value.contains('abuamr')) return 'al_duri_abu_amr';
    if (value.contains('khalaf') && value.contains('hamza')) return 'khalaf_hamza';
    return null;
  }

  Map<int, String> _qudSurahUrls(Map item) {
    final audio = item['audio'];
    final candidates = <dynamic>[
      item['chapter_urls'],
      item['surah_urls'],
      audio is Map ? audio['chapter_urls'] : null,
      audio is Map ? audio['chapters'] : null,
    ];
    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final urls = <int, String>{};
      candidate.forEach((key, value) {
        final surah = int.tryParse('$key');
        if (surah == null || surah < 1 || surah > 114) return;
        if (value is String && value.startsWith('http')) {
          urls[surah] = value;
        } else if (value is Map) {
          final url = '${value['url'] ?? ''}';
          if (url.startsWith('http')) urls[surah] = url;
        }
      });
      if (urls.length == 114) return urls;
    }
    return const <int, String>{};
  }

  Future<Map<int, Set<String>>> _fetchMp3QuranRiwayahIds() async {
    final result = <int, Set<String>>{};
    try {
      final uri = Uri.parse(
        'https://mp3quran.net/api/v3/riwayat?language=eng',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return result;
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic> || json['riwayat'] is! List) {
        return result;
      }
      for (final item in json['riwayat'] as List) {
        if (item is! Map) continue;
        final id = int.tryParse('${item['id'] ?? ''}');
        final name = '${item['name'] ?? ''}';
        if (id == null || name.isEmpty) continue;
        final matches = _matches(name)
            .where((localId) => QiraatCatalog.allRiwayat.any((r) => r.id == localId))
            .toSet();
        if (matches.isNotEmpty) {
          result[id] = matches;
        }
      }
    } catch (_) {
      // Static documented IDs remain available as fallback.
    }
    return result;
  }

  Future<void> _fetchReadersFromUri(
    Uri uri,
    Map<String, List<RiwayahReader>> result, {
    Set<String>? onlyRiwayat,
  }) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return;
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic> || json['reciters'] is! List) return;
    for (final item in json['reciters'] as List) {
      if (item is! Map) continue;
      final reciterId = '${item['id'] ?? ''}';
      final reciterName = '${item['name'] ?? ''}'.trim();
      final moshaf = item['moshaf'];
      if (reciterId.isEmpty || reciterName.isEmpty || moshaf is! List) continue;
      for (final read in moshaf) {
        if (read is! Map) continue;
        final name = _normalize('${read['name'] ?? ''}');
        final serverRaw = '${read['server'] ?? ''}';
        final total = int.tryParse('${read['surah_total'] ?? 0}') ?? 0;
        if (serverRaw.isEmpty || total < 114) continue;
        final server = serverRaw.endsWith('/') ? serverRaw : '$serverRaw/';
        var matches = _matches(name);
        if (onlyRiwayat != null) {
          matches = matches.where(onlyRiwayat.contains).toList(growable: false);
        }
        final surahList = '${read['surah_list'] ?? ''}'
            .split(',')
            .map(int.tryParse)
            .whereType<int>()
            .toSet();
        for (final riwayahId in matches) {
          final reader = RiwayahReader(
            id: '$reciterId-${read['id'] ?? riwayahId}',
            name: reciterName,
            riwayahId: riwayahId,
            source: 'MP3Quran',
            server: server,
            hasAyahAudio: false,
            surahs: surahList.isEmpty
                ? {for (var i = 1; i <= 114; i++) i}
                : surahList,
            timingReadId: int.tryParse('${read['id'] ?? ''}'),
          );
          final list = result.putIfAbsent(riwayahId, () => <RiwayahReader>[]);
          if (!list.any((r) => r.id == reader.id)) list.add(reader);
        }
      }
    }
  }
  Future<Map<int, ({int startMs, int endMs})>> ayahTimings(int surahNumber) async {
    final reader = selectedReaderFor(_selectedRiwayahId);
    final readId = reader?.timingReadId;
    if (reader == null || readId == null || reader.source != 'MP3Quran') {
      return const <int, ({int startMs, int endMs})>{};
    }
    final key = reader.id + ':' + surahNumber.toString();
    final cached = _ayahTimingCache[key];
    if (cached != null) return cached;
    try {
      final uri = Uri.parse('https://mp3quran.net/api/v3/ayat_timing').replace(
        queryParameters: <String, String>{'surah': surahNumber.toString(), 'read': readId.toString()},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const <int, ({int startMs, int endMs})>{};
      final json = jsonDecode(response.body);
      if (json is! List) return const <int, ({int startMs, int endMs})>{};
      final timings = <int, ({int startMs, int endMs})>{};
      for (final item in json) {
        if (item is! Map) continue;
        final ayah = int.tryParse('${item['ayah'] ?? ''}');
        final start = int.tryParse('${item['start_time'] ?? ''}');
        final end = int.tryParse('${item['end_time'] ?? ''}');
        if (ayah == null || ayah <= 0 || start == null || end == null || end <= start) continue;
        timings[ayah] = (startMs: start, endMs: end);
      }
      _ayahTimingCache[key] = timings;
      return timings;
    } catch (_) {
      return const <int, ({int startMs, int endMs})>{};
    }
  }
  List<String> _matches(String rawName) {
    final name = _normalize(rawName);
    final ids = <String>[];
    bool hasAny(List<String> values) => values.any(name.contains);
    bool hasAll(List<String> values) => values.every(name.contains);
    if (hasAny(['hafs'])) ids.add('hafs');
    if (hasAny(['warsh'])) ids.add('warsh');
    if (hasAny(['qalun', 'qaloon', 'qal'])) ids.add('qalun');
    final hasBazzi = hasAny(['albizi', 'albazzi', 'bazzi']);
    final hasQunbul = hasAny(['qunbol', 'qunbul']);
    if (hasBazzi && !hasQunbul) ids.add('al_bazzi');
    if (hasQunbul && !hasBazzi) ids.add('qunbul');
    if (hasAny(['assosi', 'susi'])) ids.add('al_susi');
    if (hasAny(['aldori', 'aldurri', 'dori']) && hasAny(['abiamr', 'abuamr'])) ids.add('al_duri_abu_amr');
    if (hasAny(['hisham', 'hesham'])) ids.add('hisham');
    if (hasAny(['ibnthakwan', 'ibndhakwan', 'dhakwan', 'thakwan'])) ids.add('ibn_dhakwan');
    if (hasAny(['shubah', 'shobah', 'shoba'])) ids.add('shuba');
    if (hasAll(['khalaf', 'hamzah']) || hasAll(['khalaf', 'hamza'])) ids.add('khalaf_hamza');
    if (hasAny(['aldorai', 'aldori', 'dori']) && hasAny(['alkisai', 'kisaai', 'kisai'])) ids.add('al_duri_kisai');
    if (hasAny(['khallad']) && hasAny(['hamzah', 'hamza'])) ids.add('khallad');
    if (hasAny(['abualharith', 'abialharith']) && hasAny(['kisai', 'kisaai', 'alkisai'])) {
      ids.add('abu_al_harith');
    }
    if (hasAny(['ibnwardan', 'ibnwerdan']) && hasAny(['abijafar', 'abujafar'])) {
      ids.add('ibn_wardan');
    }
    if (hasAny(['ibnjammaz']) && hasAny(['abijafar', 'abujafar'])) {
      ids.add('ibn_jammaz');
    }
    if (hasAny(['ishaq', 'ishak']) && hasAny(['abijafar', 'abujafar'])) {
      ids.add('ishaq');
    }
    if (hasAny(['idris']) && hasAny(['khalaf'])) ids.add('idris');
    if (hasAny(['ruways', 'rowais', 'ruweis'])) ids.add('ruways');
    if (hasAny(['rawh', 'rooh'])) ids.add('rawh');
    return ids;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r"[’'`\\-]"), '').replaceAll(RegExp(r"[^a-z0-9]+"), '');
  }

  String audioStatusFor(RiwayahOption r, String languageCode) {
    final runtimeReaders = _readers?[r.id] ?? const <RiwayahReader>[];
    if (runtimeReaders.any((reader) => reader.hasAyahAudio)) {
      return languageCode == 'ar'
          ? 'صوت آية-بآية متحقق'
          : 'Verified verse-by-verse audio';
    }
    if (runtimeReaders.isNotEmpty) {
      final count = runtimeReaders.length;
      return languageCode == 'ar'
          ? 'تم اكتشاف مصدر • ' + count.toString() + ' قارئ'
          : 'Source discovered • ' + count.toString() + ' reader' + (count == 1 ? '' : 's');
    }
    if (r.hasSurahAudio) {
      return languageCode == 'ar'
          ? 'مصدر الرواية مُعدّ، لكن لم يُكتشف قارئ متاح بعد'
          : 'Riwayah source configured; no runtime reader discovered yet';
    }
    return languageCode == 'ar'
        ? 'مصدر صوتي موثّق غير متوفر حاليًا'
        : 'Verified audio source not available yet';
  }
}