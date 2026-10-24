import 'package:audio_service/audio_service.dart';

import '../models/quran_models.dart';
import 'quran_audio_service.dart';
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

  /// Android Auto browsable root. Folder items are represented as non-playable
  /// MediaItems; the platform maps these to browsable media-browser entries.
  static const String _browseSurahs = 'wirdi:browse:surahs';
  static const String _browseRadio = 'wirdi:browse:radio';
  static const String _surahPrefix = 'wirdi:surah:';
  static const String _radioPrefix = 'wirdi:radio:';

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [Map<String, dynamic>? options]
  ) async {
    if (parentMediaId == AudioService.browsableRootId || parentMediaId == 'root') {
      return const [
        MediaItem(id: _browseSurahs, title: 'سور القرآن الكريم', playable: false),
        MediaItem(id: _browseRadio, title: 'إذاعات القرآن الكريم', playable: false),
      ];
    }

    if (parentMediaId == _browseSurahs) {
      final surahs = await QuranRepository.load();
      return surahs.map((SurahModel surah) => MediaItem(
        id: '$_surahPrefix${surah.number}',
        title: surah.name,
        artist: surah.englishName,
        album: 'القرآن الكريم',
        playable: true,
      )).toList(growable: false);
    }

    if (parentMediaId == _browseRadio) {
      final stations = RadioService.instance.stations;
      return stations.map((station) => MediaItem(
        id: '$_radioPrefix${station.id}',
        title: station.nameAr.isNotEmpty ? station.nameAr : station.nameEn,
        artist: station.nameEn,
        album: station.country,
        playable: true,
        isLive: true,
      )).toList(growable: false);
    }

    return const <MediaItem>[];
  }

  /// Start playback through Wirdi's existing engines. No second player is
  /// created, and RadioService/QuranAudioService keep their coordinator rules.
  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    if (mediaId.startsWith(_surahPrefix)) {
      final number = int.tryParse(mediaId.substring(_surahPrefix.length));
      if (number == null || number < 1 || number > 114) return;
      final surahs = await QuranRepository.load();
      SurahModel? selected;
      for (final surah in surahs) {
        if (surah.number == number) { selected = surah; break; }
      }
      if (selected != null) await quranAudio.playWholeSurah(selected, surahs);
      return;
    }
    if (mediaId.startsWith(_radioPrefix)) {
      final id = mediaId.substring(_radioPrefix.length);
      for (final station in RadioService.instance.stations) {
        if (station.id == id) {
          await RadioService.instance.play(station);
          return;
        }
      }
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
