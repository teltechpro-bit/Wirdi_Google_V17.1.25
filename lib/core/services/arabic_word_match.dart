/// Helpers for comparing Quranic words (with full tashkeel / Uthmani marks)
/// against plain Arabic text, e.g. speech-recognition output.
class ArabicWordMatch {
  ArabicWordMatch._();

  static final RegExp _diacritics = RegExp('[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]');
  static final RegExp _nonLetters = RegExp('[^\u0621-\u064A]');

  /// Strips diacritics and unifies letter variants so spelling differences
  /// between the Uthmani script and ordinary writing do not matter.
  static String normalizeWord(String word) {
    var t = word.replaceAll(_diacritics, '');
    t = t
        .replaceAll('ٱ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ء', '');
    return t.replaceAll(_nonLetters, '');
  }

  /// Splits [text] into (original, normalized) word pairs, dropping tokens that
  /// contain no letters at all (verse-end signs, pause marks, ...).
  static List<MapEntry<String, String>> tokens(String text) {
    final out = <MapEntry<String, String>>[];
    for (final raw in text.split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      final n = normalizeWord(raw);
      if (n.isEmpty) continue;
      out.add(MapEntry(raw, n));
    }
    return out;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final del = prev[j] + 1;
        final ins = cur[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        var best = del < ins ? del : ins;
        if (sub < best) best = sub;
        cur[j] = best;
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// True when two normalized words are the same or very close.
  static bool similar(String a, String b) {
    if (a == b) return true;
    final longest = a.length > b.length ? a.length : b.length;
    if (longest <= 3) return false;
    final d = _levenshtein(a, b);
    return 1 - d / longest >= 0.7;
  }

  /// Longest-common-subsequence flags: for each word of [a] whether it is part
  /// of the common subsequence with [b] (exact normalized equality).
  static List<bool> commonFlags(List<String> a, List<String> b) {
    final n = a.length;
    final m = b.length;
    final dp = List<List<int>>.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        if (a[i] == b[j]) {
          dp[i][j] = dp[i + 1][j + 1] + 1;
        } else {
          dp[i][j] = dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
        }
      }
    }
    final flags = List<bool>.filled(n, false);
    var i = 0;
    var j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        flags[i] = true;
        i++;
        j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        i++;
      } else {
        j++;
      }
    }
    return flags;
  }
}
