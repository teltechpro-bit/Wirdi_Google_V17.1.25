
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/models/quran_models.dart';
import '../../core/services/arabic_word_match.dart';
import '../../core/services/quran_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/bi.dart';

enum _WordState { pending, matched, missed }

/// Recite from memory (or from the mushaf) and let the phone follow along:
/// words you said correctly turn green, skipped / mispronounced words turn red.
///
/// This uses the phone's own speech recognizer (Android: Google speech
/// services). It is a helpful practice aid, NOT a replacement for a teacher -
/// it cannot judge tajweed, only whether the right words were recognized.
class RecitationCheckScreen extends StatefulWidget {
  const RecitationCheckScreen({super.key});

  @override
  State<RecitationCheckScreen> createState() => _RecitationCheckScreenState();
}

class _RecitationCheckScreenState extends State<RecitationCheckScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<SurahModel> _surahs = const <SurahModel>[];
  bool _loadingData = true;
  bool _speechReady = false;
  bool _speechUnavailable = false;
  String? _localeId;

  int _surahNumber = 1;
  int _fromAyah = 1;
  int _toAyah = 7;

  bool _session = false; // the user pressed "start" and has not pressed "stop"
  bool _listening = false;
  bool _starting = false;
  String? _lastError;

  List<MapEntry<String, String>> _expected = const <MapEntry<String, String>>[];
  List<_WordState> _states = const <_WordState>[];
  final List<String> _finalWords = <String>[];
  List<String> _partialWords = const <String>[];

  SurahModel get _surah => _surahs[_surahNumber - 1];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _session = false;
    _speech.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final surahs = await QuranRepository.load();
      if (!mounted) return;
      setState(() {
        _surahs = surahs;
        _loadingData = false;
      });
      _rebuildExpected();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingData = false);
    }
  }

  void _rebuildExpected() {
    if (_surahs.isEmpty) return;
    final surah = _surah;
    final to = _toAyah.clamp(1, surah.ayahs.length).toInt();
    final from = _fromAyah.clamp(1, to).toInt();
    final buffer = StringBuffer();
    for (var a = from; a <= to; a++) {
      buffer.write('${surah.ayahs[a - 1].text} ');
    }
    final tokens = ArabicWordMatch.tokens(buffer.toString());
    setState(() {
      _expected = tokens;
      _states = List<_WordState>.filled(tokens.length, _WordState.pending);
      _finalWords.clear();
      _partialWords = const <String>[];
    });
  }

  Future<bool> _ensureSpeech() async {
    if (_speechReady) return true;
    try {
      final ok = await _speech.initialize(
        onError: (error) {
          if (!mounted) return;
          setState(() => _lastError = error.errorMsg);
        },
        onStatus: _onStatus,
      );
      if (!ok) {
        if (mounted) setState(() => _speechUnavailable = true);
        return false;
      }
      final locales = await _speech.locales();
      String? pick;
      for (final l in locales) {
        if (l.localeId.toLowerCase().replaceAll('-', '_') == 'ar_sa') pick = l.localeId;
      }
      if (pick == null) {
        for (final l in locales) {
          if (l.localeId.toLowerCase().startsWith('ar')) {
            pick = l.localeId;
            break;
          }
        }
      }
      if (mounted) {
        setState(() {
          _speechReady = true;
          _localeId = pick;
        });
      }
      return true;
    } catch (_) {
      if (mounted) setState(() => _speechUnavailable = true);
      return false;
    }
  }

  void _onStatus(String status) {
    if (!mounted) return;
    final nowListening = status == 'listening';
    if (_listening != nowListening) setState(() => _listening = nowListening);
    // Android ends a recognition session after a short silence; keep going
    // until the user presses stop.
    if ((status == 'done' || status == 'notListening') && _session) {
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _session && !_speech.isListening) _listen();
      });
    }
  }

  Future<void> _start() async {
    if (_starting || _expected.isEmpty) return;
    _starting = true;
    try {
      final ok = await _ensureSpeech();
      if (!ok || !mounted) return;
      setState(() {
        _session = true;
        _lastError = null;
        _states = List<_WordState>.filled(_expected.length, _WordState.pending);
        _finalWords.clear();
        _partialWords = const <String>[];
      });
      await _listen();
    } finally {
      _starting = false;
    }
  }

  Future<void> _listen() async {
    try {
      await _speech.listen(
        onResult: _onResult,
        localeId: _localeId,
        listenFor: const Duration(minutes: 3),
        pauseFor: const Duration(seconds: 8),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _lastError = e.toString());
    }
  }

  Future<void> _stop() async {
    setState(() => _session = false);
    await _speech.stop();
    if (!mounted) return;
    _align(finalizing: true);
  }

  void _onResult(stt.SpeechRecognitionResult result) {
    final words = ArabicWordMatch.tokens(result.recognizedWords).map((e) => e.value).toList();
    if (result.finalResult) {
      _finalWords.addAll(words);
      _partialWords = const <String>[];
    } else {
      _partialWords = words;
    }
    _align(finalizing: false);
  }

  /// Greedy in-order alignment of what was heard against the expected words.
  void _align({required bool finalizing}) {
    final heard = <String>[..._finalWords, ..._partialWords];
    final states = List<_WordState>.filled(_expected.length, _WordState.pending);
    var p = 0;
    for (final h in heard) {
      var found = -1;
      final limit = (p + 4) < _expected.length ? p + 4 : _expected.length;
      for (var k = p; k < limit; k++) {
        if (ArabicWordMatch.similar(_expected[k].value, h)) {
          found = k;
          break;
        }
      }
      if (found >= 0) {
        for (var k = p; k < found; k++) {
          states[k] = _WordState.missed;
        }
        states[found] = _WordState.matched;
        p = found + 1;
      }
    }
    if (finalizing && heard.isNotEmpty) {
      for (var k = p; k < states.length; k++) {
        states[k] = _WordState.missed;
      }
    }
    if (!mounted) return;
    setState(() => _states = states);
  }

  Color _colorFor(_WordState s) => switch (s) {
        _WordState.matched => Colors.green.shade700,
        _WordState.missed => Colors.red.shade600,
        _WordState.pending => Colors.grey.shade500,
      };

  @override
  Widget build(BuildContext context) {
    final matched = _states.where((s) => s == _WordState.matched).length;
    final missed = _states.where((s) => s == _WordState.missed).length;
    final total = _states.length;
    final judged = matched + missed;

    return Scaffold(
      appBar: AppBar(title: Text(bi(context, 'تصحيح التلاوة بالصوت', 'Recitation Check')), centerTitle: true),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : _surahs.isEmpty
              ? Center(child: Text(bi(context, 'تعذّر تحميل المصحف', 'Could not load the Quran')))
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                  children: [
                    _picker(context),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _expected.isEmpty
                            ? const SizedBox.shrink()
                            : RichText(
                                textDirection: TextDirection.rtl,
                                text: TextSpan(
                                  children: [
                                    for (var i = 0; i < _expected.length; i++)
                                      TextSpan(
                                        text: '${_expected[i].key} ',
                                        style: TextStyle(
                                          fontFamily: 'AmiriQuran',
                                          fontSize: 24,
                                          height: 2.1,
                                          color: _colorFor(_states[i]),
                                          fontWeight: _states[i] == _WordState.pending ? FontWeight.w500 : FontWeight.w800,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (total > 0 && judged > 0)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _stat(context, '$matched', bi(context, 'صحيحة', 'Correct'), Colors.green.shade700),
                              _stat(context, '$missed', bi(context, 'فاتتك', 'Missed'), Colors.red.shade600),
                              _stat(context, '${(matched * 100 / (judged == 0 ? 1 : judged)).round()}%', bi(context, 'الدقة', 'Accuracy'), AppColors.primaryEmerald),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_speechUnavailable)
                      Text(
                        bi(
                          context,
                          'التعرّف على الصوت غير متاح على هذا الجهاز أو لم تُمنح صلاحية الميكروفون.',
                          'Speech recognition is not available on this device, or microphone permission was not granted.',
                        ),
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    if (_lastError != null && !_speechUnavailable)
                      Text(
                        bi(context, 'ملاحظة: $_lastError', 'Note: $_lastError'),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _expected.isEmpty ? null : (_session ? _stop : _start),
                        style: FilledButton.styleFrom(
                          backgroundColor: _session ? Colors.red.shade600 : AppColors.primaryEmerald,
                        ),
                        icon: Icon(_session ? Icons.stop_rounded : Icons.mic_rounded),
                        label: Text(
                          _session
                              ? (_listening
                                  ? bi(context, 'أستمع إليك… اضغط للإيقاف', 'Listening… tap to stop')
                                  : bi(context, 'إيقاف', 'Stop'))
                              : bi(context, 'ابدأ التلاوة', 'Start reciting'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      bi(
                        context,
                        'تنبيه: يعتمد هذا على خدمة التعرّف على الصوت في هاتفك (على أندرويد: خدمات Google)، وقد يُرسَل الصوت إلى خوادمها ما لم تُنزّل الحزمة العربية للعمل دون اتصال. تتحقق الأداة من الكلمات فقط ولا تحكم على أحكام التجويد؛ فلا تغني عن المعلّم.',
                        'Note: this relies on your phone’s speech recognition (on Android, Google services); audio may be sent to its servers unless the Arabic offline pack is installed. It checks the words only, not tajweed rules, and is no substitute for a teacher.',
                      ),
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.5),
                    ),
                  ],
                ),
    );
  }

  Widget _stat(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _picker(BuildContext context) {
    final maxAyah = _surah.ayahs.length;
    final disabled = _session;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: _surahNumber,
              isExpanded: true,
              decoration: InputDecoration(labelText: bi(context, 'السورة', 'Surah')),
              items: [
                for (final s in _surahs)
                  DropdownMenuItem<int>(
                    value: s.number,
                    child: Text('${s.number}. ${isArabic(context) ? s.name : s.englishName}'),
                  ),
              ],
              onChanged: disabled
                  ? null
                  : (v) {
                      if (v == null) return;
                      _surahNumber = v;
                      _fromAyah = 1;
                      final n = _surahs[v - 1].ayahs.length;
                      _toAyah = n < 7 ? n : 7;
                      _rebuildExpected();
                    },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _fromAyah.clamp(1, maxAyah).toInt(),
                    isExpanded: true,
                    decoration: InputDecoration(labelText: bi(context, 'من آية', 'From ayah')),
                    items: [for (var a = 1; a <= maxAyah; a++) DropdownMenuItem<int>(value: a, child: Text('$a'))],
                    onChanged: disabled
                        ? null
                        : (v) {
                            if (v == null) return;
                            _fromAyah = v;
                            if (_toAyah < v) _toAyah = v;
                            _rebuildExpected();
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _toAyah.clamp(_fromAyah, maxAyah).toInt(),
                    isExpanded: true,
                    decoration: InputDecoration(labelText: bi(context, 'إلى آية', 'To ayah')),
                    items: [for (var a = _fromAyah; a <= maxAyah; a++) DropdownMenuItem<int>(value: a, child: Text('$a'))],
                    onChanged: disabled
                        ? null
                        : (v) {
                            if (v == null) return;
                            _toAyah = v;
                            _rebuildExpected();
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
