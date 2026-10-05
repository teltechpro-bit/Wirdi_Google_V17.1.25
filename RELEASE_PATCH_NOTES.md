# Wirdi Release Candidate patch

## Files
- `lib/features/prayer/prayer_times_screen.dart`
  - Adds a Qibla card to the Prayer Times page.
  - Opens the existing `QiblaScreen`; no Qibla calculation/service logic was changed.
- `lib/features/moon/moon_screen.dart`
  - Adds SafeArea and bottom system-bar padding so the final Moon Phase list item is not hidden behind the Android navigation area.
- `lib/core/services/settings_service.dart`
  - Persists all reminder keys used by `DailyReminderScheduler` (`tahajjud`, `weeklySummary`, `backupReminder`, `dailyQuote` were previously missing from the canonical list).
- `lib/core/services/sync_service.dart`
  - Account deletion now fails instead of deleting Firebase Auth when one or more cloud-data deletions fail.

## Intentionally NOT changed
Quran gapless audio, Quran deep-link navigation, Mushaf page tracking, login flow, radio service, notifications UI, and home dashboard.

## Build verification
Run:
`flutter clean`
`flutter pub get`
`flutter analyze`
`flutter test`
`flutter build appbundle --release`

Then test the release AAB through Play Console Internal Testing.
