/// Pure-Dart resolver for voice requests such as "شغّل سورة البقرة",
/// "play Surah Al-Kahf" or "play Egypt Quran radio" (Android Auto / Assistant
/// delivers these as a plain search string). No Flutter or audio imports, so it
/// is fully unit-testable.
class VoiceSurahEntry {
  final int number;
  final String arabic;
  final String english;
  const VoiceSurahEntry(this.number, this.arabic, this.english);
}

class VoiceStationEntry {
  final String id;
  final String nameAr;
  final String nameEn;
  final String country;
  const VoiceStationEntry(this.id, this.nameAr, this.nameEn, this.country);
}

enum VoiceTarget { surah, station, none }

class VoiceSearchResult {
  final VoiceTarget target;
  final int? surah;
  final String? stationId;
  const VoiceSearchResult._(this.target, this.surah, this.stationId);
  const VoiceSearchResult.none() : this._(VoiceTarget.none, null, null);
  const VoiceSearchResult.surah(int number) : this._(VoiceTarget.surah, number, null);
  const VoiceSearchResult.station(String id) : this._(VoiceTarget.station, null, id);
}

class VoiceSearchResolver {
  VoiceSearchResolver._();

  static final RegExp _diacritics = RegExp('[ً-ٰٟـ]');
  static final RegExp _nonWord = RegExp(r"[^a-z0-9ء-ي ]");

  static String normalize(String input) {
    var s = input.toLowerCase();
    s = s.replaceAll(_diacritics, '');
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < arabicDigits.length; i++) {
      s = s.replaceAll(arabicDigits[i], '$i');
    }
    s = s
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp("['’`ʿʾ]"), '')
        .replaceAll(RegExp(r'[-_]'), ' ');
    s = s.replaceAll(_nonWord, ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const Set<String> _commandWords = {
    'شغل', 'شغلي', 'شغلها', 'تشغيل', 'اسمع', 'استمع', 'اريد', 'عايز', 'عاوز',
    'ابي', 'ابغي', 'لي', 'من', 'في', 'علي', 'على', 'وردي', 'تطبيق', 'لو', 'سمحت',
    'قراءه', 'تلاوه',
    'play', 'listen', 'to', 'the', 'on', 'in', 'from', 'wirdi', 'please', 'me',
    'some', 'open', 'start',
  };

  static const Set<String> _surahWords = {'سوره', 'سورت', 'surah', 'sura', 'surat', 'chapter'};
  static const Set<String> _radioWords = {'اذاعه', 'راديو', 'radio', 'station'};
  static const Set<String> _latinArticles = {'al', 'an', 'ar', 'as', 'ash', 'at', 'az', 'ad', 'adh', 'ath'};

  static const Map<int, List<String>> _aliases = {
    1: ['فاتحه', 'ام الكتاب', 'fatiha', 'fatihah'],
    2: ['baqara', 'baqarah'],
    3: ['ال عمران', 'al imran', 'aal imran', 'ali imran', 'imran'],
    36: ['ياسين', 'يس', 'ya sin', 'yasin', 'yaseen'],
    55: ['rahman', 'rehman'],
    112: ['قل هو الله احد', 'اخلاص', 'ikhlas', 'ikhlaas'],
    113: ['فلق', 'falaq'],
    114: ['ناس', 'nas', 'naas'],
    18: ['كهف', 'kahf'],
    67: ['ملك', 'mulk', 'tabarak', 'تبارك'],
    32: ['سجده', 'sajdah', 'sajda', 'as sajdah'],
  };

  static List<String> _tokens(String normalized) =>
      normalized.isEmpty ? <String>[] : normalized.split(' ');

  static String _key(String text) {
    final out = <String>[];
    final tokens = _tokens(normalize(text));
    for (var i = 0; i < tokens.length; i++) {
      var t = tokens[i];
      if (_latinArticles.contains(t) && tokens.length > 1) continue;
      if (t == 'ال') continue;
      if (t.length > 3 && t.startsWith('ال')) t = t.substring(2);
      out.add(t);
    }
    return out.join('');
  }

  static int _distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  static int _allowedDistance(int length) => length <= 4 ? 0 : (length <= 7 ? 1 : 2);

  static VoiceSearchResult resolve(
    String query, {
    required List<VoiceSurahEntry> surahs,
    required List<VoiceStationEntry> stations,
  }) {
    final raw = _tokens(normalize(query));
    final wantsRadio = raw.any(_radioWords.contains);
    final content = raw.where((t) => !_commandWords.contains(t)).toList();
    final withoutTypes = content.where((t) => !_surahWords.contains(t) && !_radioWords.contains(t)).toList();
    if (withoutTypes.isEmpty) return const VoiceSearchResult.none();

    if (!wantsRadio) {
      final n = matchSurah(withoutTypes.join(' '), surahs);
      if (n != null) return VoiceSearchResult.surah(n);
    }
    final id = matchStation(withoutTypes, stations);
    if (id != null) return VoiceSearchResult.station(id);
    return const VoiceSearchResult.none();
  }

  static int? matchSurah(String fragment, List<VoiceSurahEntry> surahs) {
    final digits = int.tryParse(fragment.trim());
    if (digits != null) return (digits >= 1 && digits <= 114) ? digits : null;
    final q = _key(fragment);
    if (q.isEmpty) return null;

    int? bestNumber;
    var bestDistance = 1 << 30;
    var tied = false;
    for (final s in surahs) {
      final keys = <String>{
        _key(s.arabic),
        _key(s.english),
        for (final a in _aliases[s.number] ?? const <String>[]) _key(a),
      }..remove('');
      var d = 1 << 30;
      for (final k in keys) {
        final dist = _distance(q, k);
        final limit = _allowedDistance(k.length < q.length ? k.length : q.length);
        if (dist <= limit && dist < d) d = dist;
      }
      if (d == 1 << 30) continue;
      if (d < bestDistance) {
        bestDistance = d;
        bestNumber = s.number;
        tied = false;
      } else if (d == bestDistance && bestNumber != s.number) {
        tied = true;
      }
    }
    if (bestNumber == null) return null;
    if (tied && bestDistance > 0) return null;
    return bestNumber;
  }

  static String? matchStation(List<String> queryTokens, List<VoiceStationEntry> stations) {
    final q = queryTokens.map((t) => t.startsWith('ال') && t.length > 3 ? t.substring(2) : t).where((t) => t.length >= 2).toList();
    if (q.isEmpty) return null;
    String? best;
    var bestScore = 0.0;
    for (final s in stations) {
      final hay = <String>{
        ..._tokens(normalize('${s.nameAr} ${s.nameEn} ${s.country}')).map((t) => t.startsWith('ال') && t.length > 3 ? t.substring(2) : t),
      };
      var hits = 0;
      for (final t in q) {
        if (hay.any((h) => h == t || (t.length >= 5 && _distance(h, t) <= 1))) hits++;
      }
      final score = hits / q.length;
      if (score > bestScore) {
        bestScore = score;
        best = s.id;
      }
    }
    return bestScore >= 0.6 ? best : null;
  }
}