# v17 - new features (version 1.2.0+3)

New tools (all appended to the end of the Tools list, so existing Home quick-action indices are unchanged):

| Tool | Files |
|---|---|
| Recitation check (speech) | `features/quran/recitation_check_screen.dart`, `core/services/arabic_word_match.dart` |
| Similar verses (mutashabihat) | `features/quran/mutashabihat_screen.dart`, `core/services/mutashabihat_repository.dart`, `assets/data/mutashabihat.json` |
| Car mode | `features/quran/car_mode_screen.dart` |
| Group khatma | `features/khatma/family_khatma_screen.dart`, `core/services/family_khatma_service.dart` |
| Azkar after prayer (+ reminders) | `features/azkar/post_prayer_azkar_screen.dart`, `core/services/extra_reminders_service.dart` |
| Prayer tracker | `features/prayer/prayer_tracker_screen.dart`, `core/services/prayer_log_service.dart` |
| Last third of the night (+ reminder) | `features/prayer/qiyam_night_screen.dart` |
| Silent during prayer (Android) | `features/prayer/prayer_silent_mode_screen.dart`, `core/services/prayer_silent_mode_service.dart`, `android_overrides/kotlin/com/wirdi/wirdi/PrayerSilentMode.kt` |
| Ayah share card templates | `features/quran/ayah_share_screen.dart` (6 colour templates) |

## Build / config changes
- `pubspec.yaml`: new dependency `speech_to_text: ^7.0.0`; version `1.2.0+3`.
- `patch_manifest.py`: adds `ACCESS_NOTIFICATION_POLICY`, `RECORD_AUDIO`, the `SilentModeReceiver`, and a `<queries>` entry for the speech recognizer.
- `patch_main_activity.py`: registers the silent-mode MethodChannel in `MainActivity.configureFlutterEngine`.
- `FIREBASE_SETUP.md`: new Firestore rules block for `family_khatmas` -- MUST be published for Group Khatma to work.
- `prayer_notification_scheduler.dart`: also (re)schedules the azkar / qiyam reminders and silent-mode windows.

## Not verified here
This environment has no Flutter/Dart SDK or Android toolchain, so the code was only syntax-checked (tree-sitter), not compiled or run. Run `flutter pub get && flutter analyze` first and fix anything it reports.

## Not included
- Asbab al-nuzul / i'rab: needs a licensed dataset.
- Warsh / Qalun readings: needs the matching Quran text data.
- Islamic books reader: needs book texts.
