import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/qiraat_catalog.dart';

class QiraatService {
  QiraatService._();
  static final QiraatService instance = QiraatService._();

  static const _riwayahKey = 'qiraat_selected_riwayah';
  static const _catalogUrl = 'https://mp3quran.net/api/v3/reciters?language=eng';

  String _selectedRiwayahId = 'hafs';
  Map<String, String>? _surahServers;
  Future<Map<String, String>>? _catalogFuture;

  String get selectedRiwayahId => _selectedRiwayahId;
  RiwayahOption get selectedRiwayah => QiraatCatalog.byId(_selectedRiwayahId);
  bool get isHafs => _selectedRiwayahId == 'hafs';
  bool get isWarsh => _selectedRiwayahId == 'warsh';

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
        final s = surahNumber.toString().padLeft(3, '0');
        final a = ayahNumber.toString().padLeft(3, '0');
        return 'https://everyayah.com/data/warsh/warsh_ibrahim_aldosary_128kbps/$s$a.mp3';
      default:
        return null;
    }
  }

  Future<String?> surahAudioUrl(int surahNumber) async {
    if (_selectedRiwayahId == 'hafs') return null;
    final servers = await _loadSurahServers();
    final server = servers[_selectedRiwayahId];
    if (server == null) return null;
    return server + surahNumber.toString().padLeft(3, '0') + '.mp3';
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
            result.putIfAbsent(match, () => server.endsWith('/') ? server : server + '/');
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
    return languageCode == 'ar' ? 'صوت السورة من مصدر الرواية متحقق' : 'Full-surah riwayah audio source verified';
  }
}