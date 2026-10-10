# Wirdi Quran Experience — Feature Inventory & Integration Plan

Status date: 2026-10-10  
Scope: compare the currently visible Wirdi implementation with the feature groups publicly described for Way2Quran, then close the gaps in Wirdi-native screens. This is a code-level inventory, not a claim that every feature has passed device testing.

## Current implementation confirmed in source

| Feature area | Current evidence | Status | Next action |
|---|---|---|---|
| Reciter discovery and profiles | `lib/features/way2quran/way2quran_home_screen.dart`, `way2quran_repository.dart` | Implemented in code; runtime/API behavior still needs smoke testing | Test search, profile, pagination, empty/error states |
| Recitations and surah lookup | Repository exposes recitations, global search, reciter and surah endpoints | Implemented in code | Verify endpoint payload variants and all navigation paths |
| Read/listen experience | Home screen links to native read/listen and mushaf screens | Implemented in code | Test reader/audio handoff, background playback and resume |
| Favorites | Favorites feature/storage files are imported by the Wirdi home experience | Partial/needs behavior audit | Verify persistence, remove/add, and whether favorite audio can start |
| Downloads/offline | Downloads screen and local storage/path-provider dependencies exist | Partial/needs device verification | Test download completion, cancellation, storage permissions, offline playback and cleanup |
| Playlists | Playlist screen is present | Partial/needs behavior audit | Verify create/rename/delete, add/remove tracks, ordering and persistence |
| Ten Qira’at / twenty Riwayat | Native directory screens and `QiraatScreen` exist; source discovery is explicit | Implemented in code; source coverage varies | Verify every displayed source, and ensure no silent fallback to Hafs |
| Mushaf | Native mushaf screen and existing Quran reader are present | Implemented in code; feature parity not yet established | Compare navigation, page/ayah selection, audio sync and bookmarks |
| Website-only features | `way2quran_web_screen.dart` explicitly embeds website pages in a WebView | Known gap: not fully Wirdi-native | Find every call site and replace feature-by-feature with native screens/API-backed services |
| Radio / continuous listening | Public Way2Quran feature descriptions include radio; no native Wirdi implementation has yet been confirmed by this pass | Unverified / likely gap | Search repository and API for station/stream contracts; implement native radio only if a stable source is available |
| Khatma / reading progress | Wirdi has Quran progress and separate group-khatma work in the repository | Partial; not yet proven equivalent to the target experience | Keep individual progress separate from group assignment/claims; test leave/rejoin and completed history |
| Localization and Wirdi identity | Wirdi Arabic/English labels are visible in native home screen | Partial | Remove exposed third-party page branding from native UI; retain appropriate source/license notices where legally required |

## Definition of done

- All user-facing journeys start and remain inside Wirdi's own navigation and design system; no unexplained third-party WebView page is used for a feature marked native.
- Arabic and English layouts work, including RTL, loading, empty, offline and error states.
- Audio source selection is explicit and accurate; never substitute another riwayah silently.
- Downloads are playable offline and have reliable progress, cancellation, deletion and error recovery.
- Favorites and playlists survive app restarts and have clear persistence behavior.
- Mushaf/read-listen navigation preserves the selected surah/ayah and playback state where appropriate.
- Radio is either implemented with a verified source or clearly marked unavailable; do not invent a stream.
- Khatma exit/rejoin logic preserves completed work and releases only unfinished claims.
- Automated tests and a successful Android build are recorded for the final integration; source inspection alone does not count as verification.

## Execution batches

1. **Inventory (this commit):** establish a feature-by-feature baseline and explicit acceptance criteria.
2. **Navigation and WebView audit:** locate every WebView entry point and map each one to a native screen/API contract.
3. **Native parity batch:** prioritize missing high-value flows (radio if supported, complete favorites/downloads/playlists, reader/audio continuity).
4. **Reliability batch:** fix API parsing, offline/error handling, state persistence, and qiraat-source accuracy.
5. **Verification batch:** targeted tests, full Flutter tests, Android build, and a final manual smoke-test checklist.

## Important limitations

- A screen/file existing does not prove the feature works end-to-end.
- The current WebView implementation confirms that at least some website-only features are not yet native.
- Public feature descriptions are used as a checklist, not as proof of API availability or permission to reuse protected assets/content. Keep Wirdi's own UI and respect applicable content, API and attribution terms.
