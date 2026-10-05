import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/models/quran_models.dart';
import '../../core/services/quran_audio_service.dart';
import '../../core/services/quran_repository.dart';
import '../../core/utils/bi.dart';

/// Driving mode: a dark, high-contrast screen with very large controls for
/// listening to a surah without looking closely at the phone.
class CarModeScreen extends StatefulWidget {
  const CarModeScreen({super.key});

  @override
  State<CarModeScreen> createState() => _CarModeScreenState();
}

class _CarModeScreenState extends State<CarModeScreen> {
  static const String _kLastSurah = 'car_mode_last_surah';
  static const List<double> _speeds = [0.75, 1.0, 1.25, 1.5];

  List<SurahModel> _surahs = const <SurahModel>[];
  int _surahNumber = 1;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    quranAudio.addListener(_onAudio);
    _load();
    try {
      WakelockPlus.enable();
    } catch (_) {}
  }

  @override
  void dispose() {
    quranAudio.removeListener(_onAudio);
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  void _onAudio() {
    if (!mounted) return;
    final current = quranAudio.currentSurahNumber;
    if (current != null && current != _surahNumber) {
      _surahNumber = current;
    }
    setState(() {});
  }

  Future<void> _load() async {
    try {
      final surahs = await QuranRepository.load();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_kLastSurah) ?? 1;
      if (!mounted) return;
      setState(() {
        _surahs = surahs;
        _surahNumber = (quranAudio.currentSurahNumber ?? saved).clamp(1, surahs.length).toInt();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  SurahModel get _surah => _surahs[_surahNumber - 1];

  bool get _isThisSurahActive => quranAudio.isSurahActive(_surahNumber) && quranAudio.playingAyah != null;
  bool get _isPlaying => _isThisSurahActive && !quranAudio.isPaused;

  Future<void> _playSurah(int number) async {
    final n = ((number - 1) % _surahs.length + _surahs.length) % _surahs.length + 1;
    setState(() => _surahNumber = n);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastSurah, n);
    await quranAudio.playWholeSurah(_surahs[n - 1], _surahs);
  }

  Future<void> _toggle() async {
    if (_isThisSurahActive) {
      if (quranAudio.isPaused) {
        await quranAudio.resume();
      } else {
        await quranAudio.pause();
      }
    } else {
      await _playSurah(_surahNumber);
    }
  }

  Future<void> _cycleSpeed() async {
    final i = _speeds.indexWhere((s) => (s - quranAudio.playbackRate).abs() < 0.01);
    final next = _speeds[(i + 1) % _speeds.length];
    await quranAudio.setSpeed(next);
  }

  Widget _big({required IconData icon, required VoidCallback onTap, double size = 84, bool filled = false, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: filled ? Colors.amber.shade600 : Colors.white12,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(icon, size: size * 0.55, color: filled ? Colors.black : Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(bi(context, 'وضع السيارة', 'Car Mode')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
                ? Center(
                    child: Text(bi(context, 'تعذّر تحميل المصحف', 'Could not load the Quran'), style: const TextStyle(color: Colors.white)),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Spacer(),
                        Text(
                          _surah.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 52, color: Colors.white, height: 1.4),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_surahNumber  •  ${_surah.ayahs.length} ${bi(context, 'آية', 'ayahs')}',
                          style: const TextStyle(color: Colors.white70, fontSize: 20),
                        ),
                        if (_isThisSurahActive && quranAudio.playingAyah != null) ...[
                          const SizedBox(height: 14),
                          LinearProgressIndicator(
                            value: quranAudio.surahProgress.clamp(0.0, 1.0).toDouble(),
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.amber.shade600,
                            backgroundColor: Colors.white12,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${bi(context, 'الآية', 'Ayah')} ${quranAudio.playingAyah}',
                            style: const TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                        ],
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _big(
                              icon: Icons.skip_next_rounded,
                              tooltip: bi(context, 'السورة التالية', 'Next surah'),
                              onTap: () => _playSurah(_surahNumber + 1),
                            ),
                            _big(
                              icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 130,
                              filled: true,
                              tooltip: _isPlaying ? bi(context, 'إيقاف مؤقت', 'Pause') : bi(context, 'تشغيل', 'Play'),
                              onTap: _toggle,
                            ),
                            _big(
                              icon: Icons.skip_previous_rounded,
                              tooltip: bi(context, 'السورة السابقة', 'Previous surah'),
                              onTap: () => _playSurah(_surahNumber - 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            onPressed: _cycleSpeed,
                            child: Text(
                              '${bi(context, 'السرعة', 'Speed')}  ${quranAudio.playbackRate}x',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          bi(context, 'ركّز على الطريق — استمع فقط.', 'Keep your eyes on the road — just listen.'),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
