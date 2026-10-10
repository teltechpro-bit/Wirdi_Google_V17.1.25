import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'qiraat_service.dart';
import '../models/quran_models.dart';
import 'app_logger.dart';
import 'audio_download_service.dart';
import 'playback_coordinator.dart';
import 'settings_service.dart';
import 'surah_progress_model.dart';

/// App-wide Quran playback.
///
/// The previous implementation used two independent `audioplayers` instances:
/// one active player and one preloaded player. That reduced network latency, but
/// every ayah still ended one native player and resumed another one. This can
/// create a small audible hole between ayahs.
///
/// This implementation uses ONE just_audio playlist. just_audio is designed for
/// gapless playlist playback and keeps the next item in the same native player
/// pipeline, while still allowing us to highlight the current ayah from the
/// playlist index.
class QuranAudioService extends ChangeNotifier {
  QuranAudioService._() {
    _bindPlayer();
  }

  static final QuranAudioService instance = QuranAudioService._();

  final ja.AudioPlayer _player = ja.AudioPlayer(
    // Let just_audio prepare upcoming playlist items as needed.
    useLazyPreparation: true,
    handleInterruptions: true,
    androidApplyAudioAttributes: true,
    handleAudioSessionActivation: true,
  );

  StreamSubscription<int?>? _indexSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<ja.PlayerState>? _stateSub;
  StreamSubscription<ja.PositionDiscontinuity>? _discontinuitySub;
  StreamSubscription<ja.PlayerException>? _errorSub;

  bool _bound = false;
  bool _stopping = false;
  bool _wakelockEnabled = false;

  Future<void> _setQuranWakelock(bool enabled) async {
    if (_wakelockEnabled == enabled) return;
    _wakelockEnabled = enabled;
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e, st) {
      AppLogger.error('Failed to update Quran screen wakelock', error: e, stackTrace: st);
    }
  }
  int _playToken = 0;

  int? _surahNumber;
  String? _surahName;
  int _surahAyahOffset = 0;
  int _totalAyahsInSurah = 0;
  int? _rangeStartAyah;
  int? _rangeEndAyah;
  int _playlistStartAyah = 1;
  int _playlistEndAyah = 1;
  bool _fullSurahOnly = false;
  bool _externalPlaylistMode = false;
  List<String> _externalPlaylistTitles = const <String>[];
  Map<int, ({int startMs, int endMs})> _fullSurahTimings = const <int, ({int startMs, int endMs})>{};

  int? playingAyah;
  bool playingWholeSurah = false;
  bool repeatCurrent = false;
  int? repeatCreditsRemaining;
  bool isBuffering = false;
  bool isPaused = false;
  double playbackRate = 1.0;
  bool repeatSurah = false;
  String? externalTitle;
  String? externalUrl;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  final SurahProgressModel _progress = SurahProgressModel();
  int? _durationsSurah;
  String? _durationsReciter;

  int get totalAyahsInSurah => _totalAyahsInSurah;
  int? get currentSurahNumber => _surahNumber;
  String? get currentSurahName => _surahName;

  bool isPlayingFor(int surahNumber, int ayahNumber) =>
      _surahNumber == surahNumber && playingAyah == ayahNumber;

  bool isSurahActive(int surahNumber) => _surahNumber == surahNumber;

  double get surahProgress {
    if (_fullSurahOnly && duration > Duration.zero) {
      return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    }
    final ayah = playingAyah;
    if (ayah == null || _progress.isEmpty) return 0.0;
    return _progress.progress(
      ayah: ayah,
      position: position,
      duration: duration,
    );
  }

  Duration get surahElapsed {
    if (_fullSurahOnly) return position;
    final ayah = playingAyah;
    if (ayah == null || _progress.isEmpty) return Duration.zero;
    return _progress.elapsed(
      ayah: ayah,
      position: position,
      duration: duration,
    );
  }

  Duration get surahEstimatedTotal =>
      _fullSurahOnly && duration > Duration.zero
          ? duration
          : (_progress.isEmpty ? Duration.zero : _progress.estimatedTotal);

  bool get isSurahTotalExact =>
      _fullSurahOnly ? duration > Duration.zero : (!_progress.isEmpty && _progress.isTotalExact);

  int ayahAtSurahProgress(double fraction) => _progress.isEmpty ? (playingAyah ?? 1) : _progress.locate(fraction).ayah;

  int _ayahForFullSurahPosition(Duration value) {
    if (_fullSurahTimings.isNotEmpty) {
      final ms = value.inMilliseconds;
      final ordered = _fullSurahTimings.entries.toList()..sort((a, b) => a.value.startMs.compareTo(b.value.startMs));
      for (final entry in ordered) {
        if (ms >= entry.value.startMs && ms < entry.value.endMs) return entry.key;
      }
      if (ms >= ordered.last.value.endMs) return ordered.last.key;
      return ordered.first.key;
    }
    if (duration <= Duration.zero || _progress.isEmpty) return playingAyah ?? 1;
    return _progress.locate((value.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)).ayah;
  }

  Future<void> seekToSurahProgress(double fraction) async {
    final current = playingAyah;
    if (current == null || _progress.isEmpty) return;

    if (_fullSurahOnly && duration > Duration.zero) {
      final targetPosition = Duration(
        milliseconds: (duration.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
      );
      try {
        await _player.seek(targetPosition, index: 0);
        position = targetPosition;
        playingAyah = _ayahForFullSurahPosition(targetPosition);
        notifyListeners();
      } catch (e, st) {
        AppLogger.error('Failed to seek full-surah riwayah audio', error: e, stackTrace: st);
      }
      return;
    }

    final target = _progress.locate(fraction);
    if (target.ayah == current) {
      if (duration > Duration.zero) {
        await seek(Duration(
          milliseconds: (duration.inMilliseconds * target.within).round(),
        ));
      }
      return;
    }

    final wasWhole = playingWholeSurah;
    if (target.ayah < _playlistStartAyah ||
        target.ayah > _playlistEndAyah) {
      return;
    }

    isPaused = false;
    final index = target.ayah - _playlistStartAyah;
    try {
      await _player.seek(
        Duration(
          milliseconds:
              target.ayah == current && duration > Duration.zero
                  ? (duration.inMilliseconds * target.within).round()
                  : 0,
        ),
        index: index,
      );
      playingAyah = target.ayah;
      position = Duration.zero;
      duration = _player.duration ?? Duration.zero;
      if (!wasWhole) {
        playingWholeSurah = false;
      }
      unawaited(_player.play());
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
        'Failed to seek Quran surah progress',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _bindPlayer() {
    if (_bound) return;
    _bound = true;

    _indexSub = _player.currentIndexStream.listen((index) {
      if (_stopping || index == null) return;
      if (_externalPlaylistMode) {
        position = _player.position;
        duration = _player.duration ?? Duration.zero;
        if (index >= 0 && index < _externalPlaylistTitles.length) {
          externalTitle = _externalPlaylistTitles[index];
        }
        isBuffering = _player.processingState == ja.ProcessingState.loading ||
            _player.processingState == ja.ProcessingState.buffering;
        notifyListeners();
        return;
      }

      final ayah = _fullSurahOnly ? _ayahForFullSurahPosition(_player.position) : (_playlistStartAyah + index);
      if (!_fullSurahOnly && (ayah < _playlistStartAyah || ayah > _playlistEndAyah)) return;

      playingAyah = ayah;
      position = _player.position;
      duration = _player.duration ?? Duration.zero;
      isBuffering = _player.processingState == ja.ProcessingState.loading ||
          _player.processingState == ja.ProcessingState.buffering;

      if (!_fullSurahOnly && duration > Duration.zero) {
        _progress.setKnownDuration(ayah, duration);
      }
      notifyListeners();
    });

    _positionSub = _player.positionStream.listen((p) {
      if (_stopping) return;
      position = p;
      if (_externalPlaylistMode) {
        duration = _player.duration ?? Duration.zero;
        notifyListeners();
        return;
      }
      final ayah = playingAyah;
      if (_fullSurahOnly) {
        playingAyah = _ayahForFullSurahPosition(p);
      } else if (ayah != null && duration > Duration.zero) {
        _progress.setKnownDuration(ayah, duration);
      }
      notifyListeners();
    });

    _durationSub = _player.durationStream.listen((d) {
      if (_stopping || d == null || d <= Duration.zero) return;
      duration = d;
      if (_externalPlaylistMode) {
        notifyListeners();
        return;
      }
      final ayah = playingAyah;
      if (!_fullSurahOnly && ayah != null) {
        _progress.setKnownDuration(ayah, d);
      }
      notifyListeners();
    });

    _stateSub = _player.playerStateStream.listen((state) {
      if (_stopping) return;

      isPaused = !state.playing &&
          state.processingState != ja.ProcessingState.completed;
      unawaited(_setQuranWakelock(state.playing));
      isBuffering = state.processingState == ja.ProcessingState.loading ||
          state.processingState == ja.ProcessingState.buffering;

      if (state.processingState == ja.ProcessingState.completed) {
        unawaited(_setQuranWakelock(false));
        _externalPlaylistMode = false;
        _externalPlaylistTitles = const <String>[];
        playingAyah = null;
        playingWholeSurah = false;
        position = Duration.zero;
        duration = Duration.zero;
        isBuffering = false;
      }
      notifyListeners();
    });

    _discontinuitySub = _player.positionDiscontinuityStream.listen((event) {
      if (_stopping ||
          event.reason != ja.PositionDiscontinuityReason.autoAdvance) {
        return;
      }

      // When finite "repeat current ayah" is requested, just_audio's LOOP_ONE
      // repeats the same item without rebuilding the source. Consume one credit
      // at each automatic loop. When credits are exhausted, switch back to
      // normal playlist progression.
      if (repeatCurrent && repeatCreditsRemaining != null) {
        if (_consumeRepeatCredit()) {
          return;
        }
        repeatCurrent = false;
        unawaited(_player.setLoopMode(
          playingWholeSurah ? ja.LoopMode.all : ja.LoopMode.off,
        ));
        notifyListeners();
      }
    });

    _errorSub = _player.errorStream.listen((error) {
      AppLogger.error(
        'Quran audio player error',
        error: error,
      );
      isBuffering = false;
      notifyListeners();
    });
  }

  void _loadSurahContext(
    SurahModel surah,
    List<SurahModel> allSurahs,
  ) {
    _surahNumber = surah.number;
    _surahName = surah.name;
    _totalAyahsInSurah = surah.ayahs.length;

    _surahAyahOffset = allSurahs
        .where((s) => s.number < surah.number)
        .fold(0, (sum, s) => sum + s.ayahs.length);

    final reciter = appSettings.reciterId;
    if (_durationsSurah != surah.number ||
        _durationsReciter != reciter ||
        _progress.ayahCount != surah.ayahs.length) {
      _progress.reset(
        surah.ayahs
            .map((a) => SurahProgressModel.weightOfText(a.text))
            .toList(),
      );
      _durationsSurah = surah.number;
      _durationsReciter = reciter;
    }

    _progress.setScope(
      start: _rangeStartAyah,
      end: _rangeEndAyah,
    );
    _fullSurahOnly = false;
    _fullSurahTimings = const <int, ({int startMs, int endMs})>{};
  }

  Future<void> playAyah(
    SurahModel surah,
    List<SurahModel> allSurahs,
    int ayahNumber, {
    bool keepRepeat = false,
  }) async {
    await PlaybackCoordinator.stopRadioForQuran();
    _rangeStartAyah = null;
    _rangeEndAyah = null;
    _loadSurahContext(surah, allSurahs);

    playingWholeSurah = false;
    isPaused = false;
    position = Duration.zero;
    duration = Duration.zero;
    if (!keepRepeat) {
      repeatCurrent = false;
      repeatCreditsRemaining = null;
    }

    notifyListeners();
    await _loadAndPlay(
      startAyah: ayahNumber,
      endAyah: ayahNumber,
    );
  }

  Future<void> playWholeSurah(
    SurahModel surah,
    List<SurahModel> allSurahs,
  ) async {
    await PlaybackCoordinator.stopRadioForQuran();
    _rangeStartAyah = null;
    _rangeEndAyah = null;
    _loadSurahContext(surah, allSurahs);

    playingWholeSurah = true;
    repeatCurrent = false;
    repeatCreditsRemaining = null;
    isPaused = false;
    position = Duration.zero;
    duration = Duration.zero;

    notifyListeners();
    await _loadAndPlay(
      startAyah: 1,
      endAyah: _totalAyahsInSurah,
    );
  }

  Future<void> playRange(
    SurahModel surah,
    List<SurahModel> allSurahs,
    int startAyah,
    int endAyah,
  ) async {
    if (startAyah < 1 ||
        endAyah < startAyah ||
        endAyah > surah.ayahs.length) {
      throw ArgumentError('Invalid Quran ayah range');
    }

    await PlaybackCoordinator.stopRadioForQuran();
    _rangeStartAyah = startAyah;
    _rangeEndAyah = endAyah;
    _loadSurahContext(surah, allSurahs);

    playingWholeSurah = true;
    repeatCurrent = false;
    repeatCreditsRemaining = null;
    isPaused = false;
    position = Duration.zero;
    duration = Duration.zero;

    notifyListeners();
    await _loadAndPlay(
      startAyah: startAyah,
      endAyah: endAyah,
    );
  }

  Future<void> _loadAndPlay({
    required int startAyah,
    required int endAyah,
    Duration initialPosition = Duration.zero,
  }) async {
    final token = ++_playToken;
    _stopping = false;

    final qiraat = QiraatService.instance;
    await qiraat.loadReaders();
    final hasAyahAudio = qiraat.selectedReaderHasAyahAudio();
    final fullSurahOnly = !hasAyahAudio;


    _fullSurahOnly = fullSurahOnly;
    _playlistStartAyah = fullSurahOnly ? 1 : startAyah;
    _playlistEndAyah = fullSurahOnly ? _totalAyahsInSurah : endAyah;
    _fullSurahTimings = fullSurahOnly ? await qiraat.ayahTimings(_surahNumber ?? 1) : const <int, ({int startMs, int endMs})>{};
    playingAyah = fullSurahOnly ? startAyah : startAyah;
    isBuffering = true;
    position = initialPosition;
    duration = Duration.zero;

    await _player.stop();

    // Resolve local files in parallel. This is important for long surahs:
    // localPathFor() may touch the filesystem, and doing 286 awaits serially
    // would introduce an unnecessary delay before the first ayah starts.
    final ayahs = List<int>.generate(
      endAyah - startAyah + 1,
      (index) => startAyah + index,
    );

    final localPaths = hasAyahAudio && qiraat.selectedRiwayahId == 'hafs'
        ? await Future.wait(
            ayahs.map(
              (ayah) => AudioDownloadService.localPathFor(
                appSettings.reciterId,
                _surahAyahOffset + ayah,
              ),
            ),
          )
        : List<String?>.filled(ayahs.length, null);

    if (token != _playToken) return;

    final sources = <ja.AudioSource>[];
    if (fullSurahOnly) {
      final url = await qiraat.surahAudioUrl(_surahNumber ?? 1);
      if (url != null) {
        sources.add(ja.AudioSource.uri(Uri.parse(url)));
      }
    } else {
      for (var i = 0; i < ayahs.length; i++) {
        final globalNumber = _surahAyahOffset + ayahs[i];
        final localPath = localPaths[i];
        final url = qiraat.ayahAudioUrl(
          _surahNumber ?? 1,
          ayahs[i],
          globalNumber,
          hafsEdition: appSettings.reciterId,
        );

        if (localPath != null) {
          sources.add(ja.AudioSource.file(localPath));
        } else if (url != null) {
          sources.add(ja.AudioSource.uri(Uri.parse(url)));
        } else {
          AppLogger.error(
            'No verified audio mapping for selected riwayah; refusing Hafs fallback.',
          );
          isBuffering = false;
          playingAyah = null;
          notifyListeners();
          return;
        }
      }
    }

    if (sources.isEmpty || token != _playToken) {
      isBuffering = false;
      playingAyah = null;
      AppLogger.error(
        'No audio source found for selected riwayah ' +
            qiraat.selectedRiwayahId +
            '; refusing Hafs fallback.',
      );
      notifyListeners();
      return;
    }

    try {
      await _player.setLoopMode(
        _loopModeForCurrentSettings(),
      );

      await _player.setAudioSources(
        sources,
        preload: true,
        initialIndex: 0,
        initialPosition: fullSurahOnly ? Duration.zero : initialPosition,
      );

      if (fullSurahOnly) {
        final total = _player.duration ?? Duration.zero;
        duration = total;
        var target = Duration.zero;
        if (startAyah > 1) {
          final timing = _fullSurahTimings[startAyah];
          if (timing != null) {
            target = Duration(milliseconds: timing.startMs);
          } else if (total > Duration.zero) {
            var weightBefore = 0.0;
            final totalWeight = _progress.totalWeight;
            for (var a = 1; a < startAyah; a++) {
              weightBefore += _progress.weightOf(a);
            }
            final ratio = totalWeight > 0 ? weightBefore / totalWeight : 0.0;
            target = Duration(milliseconds: (total.inMilliseconds * ratio).round());
          }
        }
        if (initialPosition > Duration.zero) {
          target += initialPosition;
          if (total > Duration.zero && target > total) target = total;
        }
        if (target > Duration.zero) {
          await _player.seek(target, index: 0);
        }
        position = target;
        playingAyah = _ayahForFullSurahPosition(target);
      }

      if (token != _playToken) return;

      await _player.setSpeed(playbackRate);
      unawaited(_player.play());

      isBuffering = false;
      isPaused = false;
      duration = _player.duration ?? Duration.zero;
      notifyListeners();
    } catch (e, st) {
      if (token == _playToken) {
        isBuffering = false;
        playingAyah = null;
        playingWholeSurah = false;
        AppLogger.error(
          'Failed to start Quran playlist',
          error: e,
          stackTrace: st,
        );
        notifyListeners();
      }
    }
  }

  ja.LoopMode _loopModeForCurrentSettings() {
    if (repeatCurrent) return ja.LoopMode.one;
    if (repeatSurah && playingWholeSurah) return ja.LoopMode.all;
    return ja.LoopMode.off;
  }

  /// Plays a local queue in order through the shared Quran audio player.
  /// The queue is kept separate from Quran ayah-index tracking.
  Future<void> playExternalFiles(
    List<String> paths, {
    required List<String> titles,
  }) async {
    if (paths.isEmpty) return;
    if (paths.length != titles.length) {
      throw ArgumentError('Every audio path must have a matching title');
    }
    await PlaybackCoordinator.stopRadioForQuran();
    _playToken++;
    _stopping = false;
    _externalPlaylistMode = true;
    _externalPlaylistTitles = List<String>.unmodifiable(titles);
    _rangeStartAyah = null;
    _rangeEndAyah = null;
    _fullSurahOnly = false;
    _fullSurahTimings = const <int, ({int startMs, int endMs})>{};
    playingAyah = null;
    playingWholeSurah = false;
    externalUrl = paths.first;
    externalTitle = titles.first;
    isPaused = false;
    isBuffering = true;
    position = Duration.zero;
    duration = Duration.zero;
    repeatCurrent = false;
    repeatCreditsRemaining = null;
    notifyListeners();
    try {
      await _player.stop();
      await _player.setLoopMode(ja.LoopMode.off);
      await _player.setAudioSources(
        paths.map((path) => ja.AudioSource.file(path)).toList(),
        preload: true,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      await _player.setSpeed(playbackRate);
      unawaited(_player.play());
      isBuffering = false;
      duration = _player.duration ?? Duration.zero;
      notifyListeners();
    } catch (e, st) {
      _externalPlaylistMode = false;
      _externalPlaylistTitles = const <String>[];
      isBuffering = false;
      externalUrl = null;
      externalTitle = null;
      AppLogger.error('Failed to start local audio queue', error: e, stackTrace: st);
      notifyListeners();
    }
  }

  Future<void> playExternalFile(String path, {String? title}) async {
    if (path.isEmpty) return;
    _externalPlaylistMode = false;
    _externalPlaylistTitles = const <String>[];
    _rangeStartAyah = null;
    _rangeEndAyah = null;
    _fullSurahOnly = false;
    _fullSurahTimings = const <int, ({int startMs, int endMs})>{};
    await PlaybackCoordinator.stopRadioForQuran();
    _playToken++;
    _stopping = false;
    playingAyah = null;
    playingWholeSurah = false;
    externalUrl = path;
    externalTitle = title;
    isPaused = false;
    isBuffering = true;
    position = Duration.zero;
    duration = Duration.zero;
    notifyListeners();
    try {
      await _player.stop();
      await _player.setLoopMode(ja.LoopMode.off);
      await _player.setAudioSource(ja.AudioSource.file(path));
      await _player.setSpeed(playbackRate);
      unawaited(_player.play());
      isBuffering = false;
      duration = _player.duration ?? Duration.zero;
      notifyListeners();
    } catch (e, st) {
      isBuffering = false;
      externalUrl = null;
      externalTitle = null;
      AppLogger.error('Failed to start local Way2Quran audio', error: e, stackTrace: st);
      notifyListeners();
    }
  }

  Future<void> playExternalUrl(String url, {String? title}) async {
    if (url.isEmpty) return;
    _externalPlaylistMode = false;
    _externalPlaylistTitles = const <String>[];
    await PlaybackCoordinator.stopRadioForQuran();
    _playToken++;
    _stopping = false;
    _rangeStartAyah = null;
    _rangeEndAyah = null;
    _fullSurahOnly = false;
    _fullSurahTimings = const <int, ({int startMs, int endMs})>{};
    playingAyah = null;
    playingWholeSurah = false;
    externalUrl = url;
    externalTitle = title;
    isPaused = false;
    isBuffering = true;
    position = Duration.zero;
    duration = Duration.zero;
    notifyListeners();
    try {
      await _player.stop();
      await _player.setLoopMode(ja.LoopMode.off);
      await _player.setAudioSource(ja.AudioSource.uri(Uri.parse(url)));
      await _player.setSpeed(playbackRate);
      unawaited(_player.play());
      isBuffering = false;
      duration = _player.duration ?? Duration.zero;
      notifyListeners();
    } catch (e, st) {
      isBuffering = false;
      externalUrl = null;
      externalTitle = null;
      AppLogger.error('Failed to start external Quran audio', error: e, stackTrace: st);
      notifyListeners();
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      await _setQuranWakelock(false);
      isPaused = true;
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
        'Failed to pause Quran audio',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> resume() async {
    try {
      await _player.play();
      await _setQuranWakelock(true);
      isPaused = false;
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
        'Failed to resume Quran audio',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> seek(Duration target) async {
    try {
      await _player.seek(target);
      position = target;
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
        'Failed to seek Quran audio',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> changeReciter(
    String reciterId, {
    required SurahModel surah,
    required List<SurahModel> allSurahs,
  }) async {
    if (reciterId == appSettings.reciterId) return;

    final wasPlaying = playingAyah != null;
    final savedAyah = playingAyah;
    final savedPosition = position;
    final savedWhole = playingWholeSurah;
    final savedPaused = isPaused;
    final savedRepeatCurrent = repeatCurrent;
    final savedRepeatSurah = repeatSurah;
    final savedRepeatCredits = repeatCreditsRemaining;
    final savedRangeStart = _rangeStartAyah;
    final savedRangeEnd = _rangeEndAyah;

    await stop();
    await appSettings.setReciterId(reciterId);

    if (!wasPlaying || savedAyah == null) return;

    _rangeStartAyah = savedRangeStart;
    _rangeEndAyah = savedRangeEnd;
    _loadSurahContext(surah, allSurahs);

    playingWholeSurah = savedWhole;
    repeatCurrent = savedRepeatCurrent;
    repeatSurah = savedRepeatSurah;
    repeatCreditsRemaining = savedRepeatCredits;
    isPaused = false;

    final endAyah = savedWhole
        ? (savedRangeEnd ?? _totalAyahsInSurah)
        : savedAyah;

    await _loadAndPlay(
      startAyah: savedAyah,
      endAyah: endAyah,
      initialPosition: savedPosition,
    );

    if (savedPaused) {
      await _player.pause();
      await _setQuranWakelock(false);
      isPaused = true;
      notifyListeners();
    }
  }

  Future<void> setSpeed(double rate) async {
    if (rate <= 0) return;
    playbackRate = rate;
    try {
      await _player.setSpeed(rate);
    } catch (e, st) {
      AppLogger.error(
        'Failed to set Quran playback speed',
        error: e,
        stackTrace: st,
      );
    }
    notifyListeners();
  }

  void toggleRepeat() {
    repeatCurrent = !repeatCurrent;
    if (repeatCurrent) {
      repeatCreditsRemaining ??= null;
    } else {
      repeatCreditsRemaining = null;
    }
    unawaited(_player.setLoopMode(_loopModeForCurrentSettings()));
    notifyListeners();
  }

  void toggleRepeatSurah() {
    repeatSurah = !repeatSurah;
    unawaited(_player.setLoopMode(_loopModeForCurrentSettings()));
    notifyListeners();
  }

  void setRepeatCount(int? count) {
    repeatCreditsRemaining = count;
    if (count != null && count <= 0) {
      repeatCurrent = false;
      unawaited(_player.setLoopMode(_loopModeForCurrentSettings()));
    } else if (repeatCurrent) {
      unawaited(_player.setLoopMode(ja.LoopMode.one));
    }
    notifyListeners();
  }

  bool _consumeRepeatCredit() {
    if (repeatCreditsRemaining == null) return true;
    if (repeatCreditsRemaining! <= 0) return false;
    repeatCreditsRemaining = repeatCreditsRemaining! - 1;
    return true;
  }

  Future<void> stop() async {
    await _setQuranWakelock(false);
    _stopping = true;
    _playToken++;

    try {
      await _player.stop();
    } catch (_) {}

    playingAyah = null;
    playingWholeSurah = false;
    externalUrl = null;
    externalTitle = null;
    _fullSurahOnly = false;
    _fullSurahTimings = const <int, ({int startMs, int endMs})>{};
    isPaused = false;
    isBuffering = false;
    _rangeStartAyah = null;
    _rangeEndAyah = null;
    _progress.setScope();
    position = Duration.zero;
    duration = Duration.zero;
    notifyListeners();

    _stopping = false;
  }

  @override
  void dispose() {
    _indexSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _discontinuitySub?.cancel();
    _errorSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }
}

final QuranAudioService quranAudio = QuranAudioService.instance;
