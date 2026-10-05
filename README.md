# Wirdi deep-link navigation fix

Replace only:
`lib/features/quran/quran_screen.dart`

Fixes deep links to a specific ayah after the cacheExtent optimization.
Examples:
- Home -> Ayah of the Day -> opens the correct ayah, not ayah 1.
- Quran -> Juz -> Juz 2 -> opens Al-Baqarah 142, not Al-Baqarah 1.
- Quran search/favorites -> opens the selected ayah.

The fix keeps `cacheExtent: 900` for fast normal surah opening. For a deep link, it estimates the target scroll position from the list's total extent, jumps near the target so Flutter builds the ayah widget, then uses `Scrollable.ensureVisible` for exact positioning.

No audio code was changed.
