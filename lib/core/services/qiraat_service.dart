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

  String _selectedRiwayahId = 'hafs';
  Map<String, String>? _surahServers;
  Map<String, List<RiwayahReader>>? _readers;
  Map<String, String>? _selectedReaderIds;
  Future<Map<String, List<RiwayahReader>>>? _readersFuture;
  Future<Map<String, String>>? _catalogFuture;

  String get selectedRiwayahId => _selectedRiwayahId;
  RiwayahOption get selectedRiwayah => QiraatCatalog.byId(_selectedRiwayahId);
  bool get isHafs => _selectedRiwayahId == 'hafs';
  bool get isWarsh => _selectedRiwayahId == 'warsh';

  List<RiwayahReader> readersForSelectedRiwayah() => _readers?[_selectedRiwayahId] ?? const [];

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
    return reader?.hasAyahAudio ?? selectedRiwayah.hasVerifiedAyahAudio;
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
    switch (_selectedRiwayahId) {
      case 'hafs':
        return 'https://cdn.islamic.network/quran/audio/128/$hafsEdition/$globalAyahNumber.mp3';
      case 'warsh':
        final reader = selectedReaderFor('warsh') ?? defaultReaderFor('warsh');
        if (reader == null || !reader.hasAyahAudio) return null;
        final s = surahNumber.toString().padLeft(3, '0');
        final a = ayahNumber.toString().padLeft(3, '0');
        return reader.server + s + a + '.mp3';
      default:
        return null;
    }
  }

  Future<String?> surahAudioUrl(int surahNumber) async {
    final selectedReader = selectedReaderFor(_selectedRiwayahId);
    if (_selectedRiwayahId == 'hafs' && selectedReader == null) return null;
    final servers = await _loadSurahServers();
    final reader = selectedReader ?? defaultReaderFor(_selectedRiwayahId);
    final server = reader?.server ?? servers[_selectedRiwayahId];
    if (server == null) return null;
    return server + surahNumber.toString().padLeft(3, '0') + '.mp3';
  }

    static const Map<String, int> _mp3QuranRiwayahIds = {
    'hafs': 1,
    'qalun': 5,
    'warsh': 10,
    'al_bazzi': 11,
    'qunbul': 11,
    'al_duri_kisai': 12,
  };

  Future<Map<String, List<RiwayahReader>>> _fetchReaders() async {
    try {
      final result = <String, List<RiwayahReader>>{};
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
          await _fetchReadersFromUri(
            uri,
            result,
            onlyRiwayat: {entry.key},
          );
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
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
          );
          final list = result.putIfAbsent(riwayahId, () => <RiwayahReader>[]);
          if (!list.any((r) => r.id == reader.id)) list.add(reader);
        }
      }
    }
  }
  Future<Map<String, String>> _loadSurahServers() {
    final cached = _surahServers;
    if (cached != null) return Future.value(cached);
    final inFlight = _catalogFuture;
    if (inFlight != null) return inFlight;
    final future = _fetchSurahServers();
    _catalogFuture = future;
    future.then((value) {
      _surahServers = value;
      _catalogFuture = null;
    }, onError: (_) {
      _catalogFuture = null;
    });
    return future;
  }

  Future<Map<String, String>> _fetchSurahServers() async {
    try {
      final response = await http.get(Uri.parse(_catalogUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return const {};
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return const {};
      final reciters = json['reciters'];
      if (reciters is! List) return const {};
      final result = <String, String>{};
      for (final item in reciters) {
        if (item is! Map) continue;
        final moshaf = item['moshaf'];
        if (moshaf is! List) continue;
        for (final read in moshaf) {
          if (read is! Map) continue;
          final name = (read['name'] ?? '').toString().toLowerCase();
          final server = (read['server'] ?? '').toString();
          final surahTotal = int.tryParse('${read['surah_total'] ?? 0}') ?? 0;
          if (server.isEmpty || surahTotal < 114) continue;
          for (final match in _matches(name)) {
            result.putIfAbsent(match, () => server.endsWith('/') ? server : '$server/');
          }
        }
      }
      return result;
    } catch (_) {
      return const {};
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
    if (hasAny(['albizi', 'albazzi', 'bazzi'])) ids.add('al_bazzi');
    if (hasAny(['qunbol', 'qunbul'])) ids.add('qunbul');
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
    if (r.hasVerifiedAyahAudio) {
      return languageCode == 'ar' ? 'صوت آية-بآية متحقق' : 'Verified verse-by-verse audio';
    }
    if (r.hasSurahAudio) {
      return languageCode == 'ar' ? 'صوت السورة من مصدر الرواية متحقق' : 'Verified full-surah riwayah audio';
    }
    return languageCode == 'ar' ? 'مصدر صوتي موثّق غير متوفر حاليًا' : 'Verified audio source not available yet';
  }
}