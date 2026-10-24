import 'package:audio_service/audio_service.dart';

import '../models/quran_models.dart';
import 'app_logger.dart';
import 'quran_audio_service.dart';
import 'settings_service.dart';
import 'voice_search_resolver.dart';
import 'wirdi_browse_ids.dart';
import 'wirdi_browse_text.dart';
import 'quran_repository.dart';
import 'radio_service.dart';

/// Bridges Wirdi's existing Radio + Quran audio playback into the
/// OS-level media session: lock-screen controls and the persistent
/// notification-shade "now playing" card with Play/Pause/Stop.
///
/// This does NOT own audio playback itself -- RadioService and
/// QuranAudioService remain the single source of truth for what's
/// actually playing. This handler only listens to them (they're already
/// ChangeNotifiers) and mirrors their state into the system media
/// session, and forwards system button taps back into whichever service
/// is currently active.
class WirdiAudioHandler extends BaseAudioHandler {
  WirdiAudioHandler() {
    RadioService.instance.addListener(_onRadioChanged);
    quranAudio.addListener(_onQuranChanged);
    _publishIdle();
  }

  bool get _radioActive => RadioService.instance.currentStation != null;
  bool get _quranActive => quranAudio.playingAyah != null || quranAudio.externalUrl != null;

  void _onRadioChanged() {
    if (_radioActive) {
      _publishRadioState();
    } else if (!_quranActive) {
      _publishIdle();
    }
  }

  /// Last state published for Quran playback. Position ticks arrive several
  /// times a second; the OS media session extrapolates the position itself, so
  /// only real state changes (ayah, pause, speed, total) are republished.
  String? _lastQuranKey;

  void _onQuranChanged() {
    if (quranAudio.externalUrl != null) {
      final key = 'external|${quranAudio.externalUrl}|${quranAudio.externalTitle}|'
          '${quranAudio.isPaused}|${quranAudio.isBuffering}|'
          '${quranAudio.playbackRate}|${quranAudio.duration.inMilliseconds}';
      if (key == _lastQuranKey) return;
      _lastQuranKey = key;
      _publishExternalState();
    } else if (quranAudio.playingAyah != null) {
      final key = '${quranAudio.currentSurahNumber}|${quranAudio.playingAyah}|${quranAudio.isPaused}|'
          '${quranAudio.isBuffering}|${quranAudio.playbackRate}|${quranAudio.surahEstimatedTotal.inSeconds}';
      if (key == _lastQuranKey) return;
      _lastQuranKey = key;
      _publishQuranState();
    } else {
      _lastQuranKey = null;
      if (!_radioActive) _publishIdle();
    }
  }

  void _publishExternalState() {
    final q = quranAudio;
    final url = q.externalUrl;
    if (url == null) return;
    mediaItem.add(MediaItem(
      id: url,
      title: (q.externalTitle ?? '').trim().isNotEmpty
          ? q.externalTitle!.trim()
          : 'Quran recitation',
      artist: 'Wirdi',
      duration: q.duration > Duration.zero ? q.duration : null,
    ));
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.stop,
        q.isPaused ? MediaControl.play : MediaControl.pause,
      ],
      systemActions: {
        ..._browseActions,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.seek,
      },
      androidCompactActionIndices: const [0, 1],
      processingState: q.isBuffering
          ? AudioProcessingState.loading
          : AudioProcessingState.ready,
      playing: !q.isPaused && !q.isBuffering,
      updatePosition: q.position,
      bufferedPosition: q.position,
      speed: q.playbackRate,
    ));
  }

  void _publishRadioState() {
    final r = RadioService.instance;
    final station = r.currentStation;
    if (station == null) return;

    mediaItem.add(MediaItem(
      id: 'radio_${station.id}',
      title: station.nameEn.isNotEmpty ? station.nameEn : station.nameAr,
      artist: 'Wirdi Radio',
      album: r.sourceLabel,
    ));

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        r.isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: {
        ..._browseActions,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: r.isLoading
          ? AudioProcessingState.loading
          : AudioProcessingState.ready,
      playing: r.isPlaying,
    ));
  }

  void _publishQuranState() {
    final q = quranAudio;
    final ayah = q.playingAyah;
    if (ayah == null) return;

    final total = q.totalAyahsInSurah;
    mediaItem.add(MediaItem(
      id: 'quran_surah_${q.currentSurahNumber ?? 0}',
      title: q.currentSurahName ?? 'Quran',
      artist: total > 0 ? 'Ayah $ayah / $total  -  Wirdi' : 'Ayah $ayah  -  Wirdi',
      // Surah-level length (an estimate until every ayah has been measured).
      duration: q.surahEstimatedTotal > Duration.zero ? q.surahEstimatedTotal : null,
    ));

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.stop,
        q.isPaused ? MediaControl.play : MediaControl.pause,
      ],
      systemActions: {
        ..._browseActions,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1],
      processingState: q.isBuffering
          ? AudioProcessingState.loading
          : AudioProcessingState.ready,
      playing: !q.isPaused,
      updatePosition: q.surahElapsed,
      speed: q.playbackRate,
    ));
  }

  void _publishIdle() {
    mediaItem.add(null);
    playbackState.add(PlaybackState(
      controls: const [],
      systemActions: _browseActions,
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  static const Set<MediaAction> _browseActions = {
    MediaAction.playFromMediaId,
    MediaAction.playFromSearch,
  };

  WirdiBrowseText get _text =>
      WirdiBrowseText(arabic: appSettings.locale.languageCode == 'ar');

  /// Android Auto browsable root. Folder items are represented as non-playable
  /// MediaItems; the platform maps these to browsable media-browser entries.
  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [Map<String, dynamic>? options]
  ) async {
    try {
      if (parentMediaId == AudioService.browsableRootId || parentMediaId == 'root') {
        return [
          MediaItem(id: WirdiBrowseIds.surahs, title: _text.surahsFolder, playable: false),
          MediaItem(id: WirdiBrowseIds.radio, title: _text.radioFolder, playable: false),
        ];
      }

      if (parentMediaId == WirdiBrowseIds.surahs) {
        final surahs = await QuranRepository.load();
        return surahs.map((SurahModel surah) => MediaItem(
          id: WirdiBrowseIds.surah(surah.number),
          title: _text.surahTitle(surah.name, surah.englishName),
          artist: _text.surahSubtitle(surah.name, surah.englishName),
          album: _text.quranAlbum,
          playable: true,
        )).toList(growable: false);
      }

      if (parentMediaId == WirdiBrowseIds.radio) {
        // The car can open the browse tree before the app UI ever ran; make
        // sure favourites/catalogue state is initialised (idempotent).
        await RadioService.instance.init();
        return RadioService.instance.stations.map((station) => MediaItem(
          id: WirdiBrowseIds.station(station.id),
          title: _text.stationTitle(station.nameAr, station.nameEn),
          artist: _text.stationSubtitle(station.nameAr, station.nameEn),
          album: station.country,
          playable: true,
          isLive: true,
        )).toList(growable: false);
      }
    } catch (e, st) {
      // A failure here must show an empty folder, never crash the media session.
      AppLogger.error('Android Auto browse failed for $parentMediaId', error: e, stackTrace: st);
    }
    return const <MediaItem>[];
  }

  Future<bool> _playSurahNumber(int number) async {
    final surahs = await QuranRepository.load();
    for (final surah in surahs) {
      if (surah.number == number) {
        await quranAudio.playWholeSurah(surah, surahs);
        return true;
      }
    }
    return false;
  }

  Future<bool> _playStationId(String stationId) async {
    await RadioService.instance.init();
    for (final station in RadioService.instance.stations) {
      if (station.id == stationId) {
        await RadioService.instance.play(station);
        return true;
      }
    }
    return false;
  }

  /// Start playback through Wirdi's existing engines. No second player is
  /// created, and RadioService/QuranAudioService keep their coordinator rules.
  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    try {
      final number = WirdiBrowseIds.parseSurah(mediaId);
      if (number != null) {
        await _playSurahNumber(number);
        return;
      }
      final stationId = WirdiBrowseIds.parseStation(mediaId);
      if (stationId != null) await _playStationId(stationId);
    } catch (e, st) {
      AppLogger.error('Android Auto playback request failed for $mediaId', error: e, stackTrace: st);
    }
  }

  /// Voice requests from Google Assistant / Android Auto, e.g. "Play Surah
  /// Al-Baqarah on Wirdi" or "شغّل سورة الكهف". Unrecognised queries never
  /// start random audio; an empty query simply resumes playback.
  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) async {
    try {
      final surahs = await QuranRepository.load();
      await RadioService.instance.init();
      final result = VoiceSearchResolver.resolve(
        query,
        surahs: surahs.map((s) => VoiceSurahEntry(s.number, s.name, s.englishName)).toList(growable: false),
        stations: RadioService.instance.stations
            .map((s) => VoiceStationEntry(s.id, s.nameAr, s.nameEn, s.country))
            .toList(growable: false),
      );
      switch (result.target) {
        case VoiceTarget.surah:
          await _playSurahNumber(result.surah!);
          break;
        case VoiceTarget.station:
          await _playStationId(result.stationId!);
          break;
        case VoiceTarget.none:
          if (VoiceSearchResolver.normalize(query).isEmpty) {
            await play();
          } else {
            AppLogger.info('Voice search matched nothing: "$query"');
          }
          break;
      }
    } catch (e, st) {
      AppLogger.error('Android Auto voice search failed for "$query"', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> play() async {
    if (_radioActive) {
      final station = RadioService.instance.currentStation;
      if (station != null) await RadioService.instance.play(station);
    } else if (_quranActive) {
      await quranAudio.resume();
    }
  }

  @override
  Future<void> pause() async {
    if (_radioActive) {
      await RadioService.instance.pause();
    } else if (_quranActive) {
      await quranAudio.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_quranActive && !_radioActive) {
      await quranAudio.seek(position);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_radioActive) {
      await RadioService.instance.playNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_radioActive) {
      await RadioService.instance.playPrevious();
    }
  }

  @override
  Future<void> stop() async {
    await RadioService.instance.stop();
    await quranAudio.stop();
    await super.stop();
  }
}

/// Set once in main() right after AudioService.init(). Nothing else needs
/// to reach into this directly during normal use -- Radio and Quran
/// screens keep talking to their own services exactly as before -- but
/// it's exposed for completeness.
late WirdiAudioHandler wirdiAudioHandler;

/// Set if AudioService.init() failed in main() -- previously this was
/// only ever written to debugPrint, which nobody watching the running
/// app could ever see. Exposed so the UI can surface it directly.
String? audioServiceInitError;
