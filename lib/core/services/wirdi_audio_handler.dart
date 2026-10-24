import 'package:audio_service/audio_service.dart';

import '../models/quran_models.dart';
import 'quran_repository.dart';

import 'quran_audio_service.dart';
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
      systemActions: const {
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
      systemActions: const {
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
      systemActions: const {
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
      systemActions: const {},
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }


  /// Android Auto browsable root. The tree is intentionally shallow and
  /// focused on audio choices that can be selected safely while driving.
  @override
  Future<MediaItem?> getRoot([Map<String, dynamic>? rootHints]) async {
    return const MediaItem(
      id: 'wirdi_root',
      title: 'وِرْدِي',
      browsable: true,
      playable: false,
    );
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    if (parentMediaId == 'wirdi_root') {
      return const [
        MediaItem(id: 'category_surahs', title: 'Quran Surahs', browsable: true, playable: false),
        MediaItem(id: 'category_radio', title: 'Quran Radio', browsable: true, playable: false),
      ];
    }

    if (parentMediaId == 'category_surahs') {
      final surahs = await QuranRepository.load();
      return surahs.map((surah) => MediaItem(
        id: 'wirdi_surah_${surah.number}',
        title: surah.englishName.isNotEmpty ? surah.englishName : surah.name,
        artist: surah.name,
        album: 'Quran',
        playable: true,
        browsable: false,
      )).toList(growable: false);
    }

    if (parentMediaId == 'category_radio') {
      final stations = RadioService.instance.allStations;
      return stations.map((station) => MediaItem(
        id: 'wirdi_radio_${Uri.encodeComponent(station.id)}',
        title: station.nameEn.isNotEmpty ? station.nameEn : station.nameAr,
        artist: station.nameAr,
        album: station.country,
        playable: true,
        browsable: false,
      )).toList(growable: false);
    }

    return const <MediaItem>[];
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    if (mediaId.startsWith('wirdi_radio_')) {
      final id = Uri.decodeComponent(mediaId.substring('wirdi_radio_'.length));
      final station = RadioService.instance.allStations
          .where((item) => item.id == id)
          .firstOrNull;
      if (station == null) return;
      await RadioService.instance.play(station);
      return;
    }

    if (mediaId.startsWith('wirdi_surah_')) {
      final number = int.tryParse(mediaId.substring('wirdi_surah_'.length));
      if (number == null || number < 1 || number > 114) return;
      final surahs = await QuranRepository.load();
      final surah = surahs.where((item) => item.number == number).firstOrNull;
      if (surah == null) return;
      await quranAudio.playWholeSurah(surah, surahs);
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
