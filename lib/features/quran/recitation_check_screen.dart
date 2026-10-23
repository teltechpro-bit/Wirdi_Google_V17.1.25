
import 'dart:async';

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
  stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechInitializationAttempted = false;

  List<SurahModel> _surahs = const <SurahModel>[];
  bool _loadingData = true;
  bool _speechReady = false;
  bool _speechUnavailable = false;
  bool _microphonePermissionIssue = false;
  String? _localeId;

  int _surahNumber = 1;
  int _fromAyah = 1;
  int _toAyah = 7;

  bool _session = false; // the user pressed "start" and has not pressed "stop"
  bool _listening = false;
  bool _starting = false;
  int _emptyRecognitionRestarts = 0;
  bool _recognizedWordsThisCycle = false;
  bool _cycleCounted = false;
  bool _restartScheduled = false;
  String? _lastError;
  Completer<void>? _finalResultWaiter;

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

    // speech_to_text caches its first initialize() result for an instance.
    // If the service/permission was unavailable on the first attempt, replace
    // the failed instance before allowing a genuine retry.
    if (_speechInitializationAttempted) {
      try { await _speech.cancel(); } catch (_) {}
      _speech = stt.SpeechToText();
      _speechInitializationAttempted = false;
    }
    _speechInitializationAttempted = true;

    try {
      final ok = await _speech.initialize(
        debugLogging: true,
        onError: (error) {
          final message = error.errorMsg;
          final normalized = message.toLowerCase();
          final permissionIssue = normalized.contains('permission') ||
              normalized.contains('not authorized') ||
              normalized.contains('not_authorized') ||
              normalized.contains('not allowed') ||
              normalized.contains('not_allowed') ||
              normalized.contains('denied');
          final noMatchOrTimeout = normalized.contains('no_match') ||
              normalized.contains('no match') ||
              normalized.contains('speech_timeout') ||
              normalized.contains('speech timeout');
          if (!mounted) return;
          setState(() {
            _lastError = message;
            _microphonePermissionIssue = permissionIssue;
            _speechUnavailable = !noMatchOrTimeout;
            if (!noMatchOrTimeout) {
              _speechReady = false;
              _session = false;
              _listening = false;
            }
          });
        },
        onStatus: _onStatus,
        finalTimeout: const Duration(seconds: 5),
      );

      if (!ok) {
        final permissionGranted = _speech.hasPermission;
        if (mounted) {
          setState(() {
            _speechReady = false;
            _speechUnavailable = true;
            _microphonePermissionIssue = !permissionGranted;
            _lastError = !permissionGranted
                ? 'لم يمنح النظام صلاحية الميكروفون للتطبيق. افتح إعدادات التطبيق وتأكد من السماح بالميكروفون.'
                : 'خدمة التعرف على الكلام غير متاحة. تأكد من تثبيت/تفعيل تطبيق Google أو خدمة Speech Recognition وتحديثها.';
          });
        }
        return false;
      }

      final locales = await _speech.locales();
      String? pick;
      // Prefer Egyptian Arabic for the user's Quran recitation, then Saudi,
      // then any Arabic locale installed on the device.
      for (final l in locales) {
        final id = l.localeId.toLowerCase().replaceAll('-', '_');
        if (id == 'ar_eg') { pick = l.localeId; break; }
      }
      if (pick == null) {
        for (final l in locales) {
          final id = l.localeId.toLowerCase().replaceAll('-', '_');
          if (id == 'ar_sa') { pick = l.localeId; break; }
        }
      }
      if (pick == null) {
        for (final l in locales) {
          if (l.localeId.toLowerCase().startsWith('ar')) {
            pick = l.localeId;
            break;
          }
        }
      }
      // Some speech services don't enumerate downloaded locales reliably.
      // Try Arabic Egypt explicitly rather than blocking the user at setup.
      pick ??= 'ar-EG';

      if (mounted) {
        setState(() {
          _speechReady = true;
          _speechUnavailable = false;
          _microphonePermissionIssue = false;
          _localeId = pick;
          _lastError = locales.any((l) => l.localeId.toLowerCase().startsWith('ar'))
              ? null
              : 'لم تعرض الخدمة حزم العربية ضمن اللغات المثبتة؛ سنجرب العربية المصرية. إذا لم يظهر نص، ثبّت حزمة العربية من إعدادات خدمة Google الصوتية.';
        });
      }
      return true;
    } catch (error) {
      final message = error.toString();
      final normalized = message.toLowerCase();
      final permissionIssue = normalized.contains('permission') ||
          normalized.contains('not authorized') ||
          normalized.contains('not_authorized') ||
          normalized.contains('not allowed') ||
          normalized.contains('not_allowed') ||
          normalized.contains('denied');
      if (mounted) {
        setState(() {
          _speechUnavailable = true;
          _microphonePermissionIssue = permissionIssue;
          _lastError = message;
          _speechReady = false;
          _session = false;
          _listening = false;
        });
      }
      return false;
    }
  }

  void _onStatus(String status) {
    if (!mounted) return;
    final nowListening = status == 'listening';
    if (nowListening) {
      _recognizedWordsThisCycle = false;
      _cycleCounted = false;
      _restartScheduled = false;
    }
    if (_listening != nowListening) setState(() => _listening = nowListening);

    // Android may emit both "done" and "notListening" for one cycle. Count
    // that cycle once, but allow the later status to restart if the first
    // delayed check runs before the recognizer fully stops.
    if ((status == 'done' || status == 'notListening') && _session) {
      if (!_cycleCounted) {
        _cycleCounted = true;
        if (_recognizedWordsThisCycle) {
          _emptyRecognitionRestarts = 0;
        } else {
          _emptyRecognitionRestarts++;
        }
        if (_emptyRecognitionRestarts >= 3) {
          setState(() {
            _session = false;
            _listening = false;
            _speechUnavailable = false;
            _lastError =
                'لم يتم التقاط كلام بعد عدة محاولات. تحدث بوضوح قرب الميكروفون ثم ابدأ المحاولة مرة أخرى.';
          });
          return;
        }
      }
      if (_restartScheduled) return;
      _restartScheduled = true;
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!mounted || !_session) return;
        if (_speech.isListening) {
          _restartScheduled = false;
          return;
        }
        _listen();
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
        _speechUnavailable = false;
        _microphonePermissionIssue = false;
        _emptyRecognitionRestarts = 0;
        _recognizedWordsThisCycle = false;
        _cycleCounted = false;
        _restartScheduled = false;
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
        // Android recognizers commonly stop near 45-60 seconds regardless
        // of longer listenFor values; _onStatus restarts short sessions safely.
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 4),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastError = e.toString();
        _session = false;
        _listening = false;
      });
    }
  }

  Future<void> _stop() async {
    setState(() => _session = false);
    _finalResultWaiter = Completer<void>();
    try {
      await _speech.stop();
      await Future.any<void>([
        _finalResultWaiter!.future,
        Future<void>.delayed(const Duration(milliseconds: 1200)),
      ]);
    } finally {
      _finalResultWaiter = null;
    }
    // Some Android recognizers stop without delivering a separate final
    // callback. Promote the latest partial transcript instead of silently
    // doing nothing.
    if (_finalWords.isEmpty && _partialWords.isNotEmpty) {
      _finalWords.addAll(_partialWords);
      _partialWords = const <String>[];
    }
    if (!mounted) return;
    if (_finalWords.isEmpty) {
      // Silence/no recognized words is not evidence that the speech service
      // is unavailable or that microphone permission was denied.
      setState(() {
        _lastError = 'لم يتم التقاط كلام. جرّب التحدث بوضوح بالقرب من الميكروفون ثم أعد المحاولة.';
        _speechUnavailable = false;
        _listening = false;
      });
      return;
    }
    _align(finalizing: true);
  }

  void _onResult(stt.SpeechRecognitionResult result) {
    final words = ArabicWordMatch.tokens(result.recognizedWords).map((e) => e.value).toList();
    if (words.isNotEmpty) {
      _recognizedWordsThisCycle = true;
      _emptyRecognitionRestarts = 0;
    }
    if (result.finalResult) {
      _finalWords.addAll(words);
      _partialWords = const <String>[];
      _finalResultWaiter?.complete();
      _finalResultWaiter = null;
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
                    if (!_session && _finalWords.isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            bi(context, 'انتهى التصحيح. راجع الكلمات المعلّمة بالأخضر والأحمر.', 'Correction finished. Review the words marked green and red.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
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
                        _microphonePermissionIssue
                            ? bi(
                                context,
                                'تم رفض إذن الميكروفون. راجع إعدادات أندرويد > التطبيقات > وردي > الأذونات، وتأكد أيضًا أن مفتاح الوصول إلى الميكروفون العام في إعدادات الخصوصية مفعّل.',
                                'Microphone permission was denied. Check Android Settings > Apps > Wirdi > Permissions, and make sure the device-wide Microphone access toggle is enabled.',
                              )
                            : bi(
                                context,
                                'خدمة التعرف على الكلام لم تبدأ بنجاح. هذا لا يعني بالضرورة أن إذن الميكروفون متوقف؛ تحقق من خدمة التعرف على الكلام على الهاتف وتوفر العربية، ثم أعد المحاولة.',
                                'Speech recognition failed to start. This does not necessarily mean microphone permission is disabled; check the phone speech-recognition service and Arabic support, then retry.',
                              ),
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    if (_lastError != null)
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
