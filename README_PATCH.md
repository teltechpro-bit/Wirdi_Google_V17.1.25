# Wirdi v1.56.3+26 — Quran gapless playback patch

## Files to replace
1. `pubspec.yaml`
2. `lib/core/services/quran_audio_service.dart`
3. `lib/core/services/quran_repository.dart`

## Additional required edits
Apply the exact changes in `REQUIRED_PATCHES.diff` to:
- `lib/core/services/settings_service.dart`
- `lib/core/services/sync_service.dart`

## Why the Quran audio changed
The old implementation used two independent `audioplayers` instances and manually handed off from one player to the other. That can leave an audible gap between ayahs.

The replacement uses one `just_audio` playlist. Each ayah is an item in the same native playlist, so transitions are handled by the audio engine instead of stopping one player and starting another.

## After copying
Run:
```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Commit the generated `pubspec.lock`.

## Important
This patch has not been compiled in this environment because a Flutter SDK/build environment is not available here. The code was reviewed against the current just_audio 0.10.6 API, but you should run the commands above and test on a real Android device.

## Audio test
Test:
- Al-Fatiha -> Al-Baqarah
- a long surah such as Al-Baqarah
- starting from ayah 20/50/100
- local downloaded ayahs
- streamed ayahs
- changing reciter while paused and while playing
- pause/resume
- seek between ayahs
- repeat ayah
- repeat surah
- playback speed 0.5x / 1x / 1.5x / 2x
- lock-screen/media controls
- phone call / Bluetooth interruption
