# Wirdi v1.56.0 (build 22) -- visual identity + Islamic Tools reorganization

Builds on v1.55 (RELEASE_PREP_v1.55.md). As with every previous pass, nothing here
was compiled or run (no Flutter SDK available): run `flutter analyze` and look at
these screens on a device/emulator before shipping.

## Visual identity (design-brief alignment)
- **Colors and fonts already matched the brief exactly** before this pass -- the
  default "Emerald" theme is `#0F766E` / `#D4AF37` / `#F8F9F6` / `#071A17` / `#102925`,
  and the app already uses Tajawal (bundled, no runtime download since v1.54)
  everywhere. No color/font changes were needed or made.
- **New: `WirdiIdentityBackground`** (`lib/shared/widgets/wirdi_identity_background.dart`)
  -- a reusable mosque-skyline-and-crescent illustration (dome, two minarets, stars,
  crescent moon) painted with `CustomPaint` in the app's own brand colors. This is
  the visual-identity asset requested alongside the palette (matching the mood board's
  photographic mosque backgrounds); it's drawn as vector art rather than a photo
  because no image-generation tool was available in this environment -- which also
  means zero licensing/attribution risk, a tiny footprint (no image bytes at all),
  and it renders correctly in both the light and dark theme since it's painted with
  `AppColors`, not baked into a fixed image. Two entry points: default (compact, for
  an AppBar `flexibleSpace`) and `.hero` (taller, for a full-screen banner). The
  proportions were verified by rendering the same geometry at header height, hero
  height, and a very short strip before wiring it into any screen, so it doesn't
  distort at different aspect ratios.
- **Applied to the Home screen's AppBar** (`home_dashboard_screen.dart`): replaced
  the flat 2-color gradient in `flexibleSpace` with `WirdiIdentityBackground`. This
  was an isolated, same-slot swap -- nothing else on the screen (the list below, its
  logic, its data) was touched.
- **Not yet applied to the other ~93 screens.** Rolling this out everywhere in one
  pass was judged too large and too risky to do blind (no compiler available) in a
  single change set. The component is ready to reuse: wrap a screen's `AppBar`
  `flexibleSpace` (compact) or wrap a hero `Stack` at the top of a body (`.hero`) with
  it. Natural next candidates, matching the mood board's own example screens: Qibla,
  Radio "now playing", the Moon-phase screen, and Prayer Times.

## Islamic Tools screen -- reorganized into 8 groups
The 62 tools were one flat scrolling list. They're now grouped by how closely related
they are to a user's daily worship flow, in this display order:

1. القرآن والحفظ / Quran & Memorization (12)
2. الصلاة والقبلة / Prayer & Qibla (11 -- includes Mosque Finder)
3. الصيام ورمضان / Fasting & Ramadan (3)
4. الزكاة والصدقة / Zakat & Charity (6)
5. الأذكار والدعاء / Azkar & Dua (5)
6. المعرفة والحديث / Knowledge & Hadith (10 -- hadith, quizzes, fatwa, articles, etiquette, will)
7. السيرة والتاريخ / Seerah & History (7 -- prophets, history, Hajj/Umrah, Hijri converter, moon phase, Islamic events)
8. التقدم والمزيد / Progress & More (8 -- insights, achievements, bookmarks, My Wirdi, search, radio)

**How it was done safely:** none of the 62 existing `_ToolEntry(...)` blocks (icon,
title, subtitle, and -- critically -- the `builder` that opens the actual screen) were
touched. The category for each tool is a separate, purely-additive list
(`_categoryByIndex`) matched to the existing tools by position, cross-checked
programmatically against an independently-built expected mapping (0 mismatches, 0
missing, all 62 accounted for) before being wired in. A debug-mode assertion in
`_groupedTools()` will fail loudly if a future edit adds or removes a tool without
updating `_categoryByIndex`, instead of silently mis-grouping it. Only the `build()`
method's layout changed, from a flat `ListView.separated` to grouped sections with a
header (icon + bilingual label) per category; the individual tool row's appearance and
`onTap` behavior are byte-for-byte the same widget code as before.

## What was verified vs. not
Verified: every changed and new file parses with zero syntax errors (183 lib files
checked); the 62-tool category mapping was cross-checked against an independent
expected table; the skyline illustration's proportions were checked at three very
different aspect ratios before use. **Not verified:** actual rendering on a device or
in `flutter analyze` -- check that the Home AppBar's title/actions stay legible over
the new background at your test device's text scale, and that the tools screen scrolls
and looks right with real fonts/locale (especially Arabic RTL section headers).

## v1.56.1 (build 23) -- fix for the first real `flutter analyze` run
The first CI run against this code caught a real bug this environment's syntax-only
checks could not: `flutter analyze` failed with `Invalid constant value` at
`islamic_tools_screen.dart:594:86`.

**Cause:** `AppColors.primaryEmerald` and `AppColors.goldAccent` are `static Color get`
getters, not compile-time constants (the app supports switchable color themes) --
documented in this repo's own `MERGE_NOTES.md` from an earlier, identical bug at
v133/v239. The new `_sectionHeader` widget's `Text` style used
`const TextStyle(..., color: AppColors.primaryEmerald)`, which is invalid for the same
reason.

**Fix:** dropped the `const` on that one `TextStyle` (line 594). Re-checked the whole
repo for the same mistake two ways -- a plain substring scan and a balanced-paren scan
that reconstructs each `const` call's full argument list -- and confirmed zero other
occurrences of either getter inside a `const` expression, in this file or anywhere
else in `lib/`.

This is a genuine reminder that everything before this point in the review was
syntax-checked only, never compiled: this class of bug (a non-const value inside a
`const` expression) is invisible to a parser and only shows up under `flutter analyze`
or `dart analyze`, which is exactly what caught it. If another `flutter analyze` run
surfaces something else, paste the log back and it'll get the same targeted fix.

## v1.56.2 (build 24) -- real photos restored and wired in (fixes "الصور مش مضافة")

The previous pass (v1.56.0) only added a hand-drawn vector illustration, and only to
one screen (Home's AppBar). The user pointed out, correctly, that the app's pages
still didn't look like the reference mood board and that no actual images had been
added. Looking into it surfaced a real mistake from an earlier pass:

**The mistake:** during the v1.55 cleanup, `assets/images/ui/` (6 photos --
`home_scenery`, `kaaba_night`, `lantern_sunset`, `moon_night`, `mosque_sunset`,
`quran_mosque`) was deleted as "unused dead weight" because nothing in the code
referenced them. They were real, already-licensed project assets (present in the
originally uploaded project, not fetched from anywhere) that matched the mood
board's own "backgrounds used in the app" section almost exactly -- they just hadn't
been wired into any screen yet. Deleting them instead of asking why they existed was
the actual error, not that they were unreferenced.

**What they actually were:** design-brief mock-up renders, not clean background
photos -- 4 of the 6 had fake UI elements baked directly into the pixels (a back
button and "المدينة" label on `kaaba_night`, three ghost icon circles on
`mosque_sunset`, a hard-coded date stamp on `moon_night`, a full title bar and two
white placeholder cards on `quran_mosque`). That's almost certainly *why* the original
code never used them as real backgrounds -- placing real UI on top would have
duplicated or clashed with the baked-in fake UI. This pass cropped each one down to
the clean photographic part only (verified visually before/after each crop) and
re-encoded all 6 as WebP in `assets/images/identity/` (138 KB total, down from 475 KB
of raw JPEG) -- `assets/images/ui/` was not restored, since these cleaned copies
replace it.

**`WirdiIdentityBackground` now supports real photos**, via a new
`.photo(photo: WirdiIdentityPhoto.xxx)` constructor (photo + dark gradient scrim for
text legibility + optional child) alongside the existing vector variants -- nothing
about the existing vector API changed, so it's purely additive.

**Wired into six screens' AppBars** (found, while doing this, that the app already had
a *different*, pre-existing background mechanism -- a private `_MosaicBg` widget
tiling `wirdi_mosaic.webp` at low opacity, duplicated separately in 10 screen files.
That mechanism already gave the app a consistent decorative AppBar background almost
everywhere; it just wasn't the photographic mood-board look specifically requested):

| Screen | Photo | Was |
|---|---|---|
| Home | `home_scenery` (skyline reflected in water) | vector skyline (v1.56.0) |
| Qibla | `kaaba_night` | `_MosaicBg` tile pattern |
| Quran | `quran_mosque` (Quran cover on green pattern) | `_MosaicBg` tile pattern |
| Moon | `moon_night` | `_MosaicBg` tile pattern |
| Prayer Times | `mosque_sunset` | `_MosaicBg` tile pattern |
| Azkar | `lantern_sunset` | `_MosaicBg` tile pattern (AppBar only -- a second, unrelated low-opacity `_MosaicBg` further down in the screen's body was left untouched) |

Each swap was the same isolated, same-slot change as Home's in v1.56.0 -- only the
`flexibleSpace:` line changed; nothing else on any of these six screens (their actual
functionality, data, lists) was touched. The now-unused private `_MosaicBg` class in
each of these 5 files (it's duplicated per-file, not shared) was deliberately left in
place rather than deleted, since it's a harmless unused-private-class warning at worst
(not an error `flutter analyze` fails on) and removing 5 separate duplicated class
definitions safely was out of scope for this pass.

**Not changed:** Radio, Radio "now playing", Account, and Splash still use
`_MosaicBg`/their own existing background (Splash already had a real photo of its
own from before this work). The other ~87 screens in the app still have no scenic
background at all -- this pass covered the mood board's own example screens (Home,
Quran, Azkar, Qibla, Radio was already photographic, Moon) plus Prayer Times, not
the entire app.

**Verified:** every touched/new file re-parsed with zero syntax errors; the
const/non-const-getter scan (the exact class of bug `flutter analyze` caught in
build 23) was re-run across the whole repo after these changes and found nothing;
every image path the code references was confirmed to exist on disk and be covered by
the `pubspec.yaml` asset declaration. **Not verified:** actual rendering -- check
image contrast/text legibility on Qibla and Moon in particular (their `scrimOpacity`
values were chosen by eye from the cropped preview images, not measured against real
device brightness), and confirm `flutter analyze` is clean (this is the second batch
of Dart code in this project that has never been run through a real compiler).

## v1.56.3 (build 25) -- second `flutter analyze` run, second real fix

The second CI run (after build 24) got further -- past the const/getter bug -- and
`flutter analyze` failed again, this time with 4 warnings (which this CI treats as
build failures, i.e. `flutter analyze` exits non-zero on ANY reported issue, warning
or error, not only on errors):

```
warning • A value for optional parameter 'opacity' isn't ever given
  • lib/features/moon/moon_screen.dart:195:63 • unused_element_parameter
  (same warning in prayer_times_screen.dart, qibla_screen.dart, quran_screen.dart)
```

**Cause:** v1.56.2 replaced these four screens' `flexibleSpace: _MosaicBg(...)` with
`WirdiIdentityBackground.photo(...)`, which was the *only* place each of these files
called `_MosaicBg` -- so its private `_MosaicBg`/`_MosaicBgState` classes (and the
`_MosaicCellPainter` they used) became fully dead code with zero remaining callers.
The analyzer's `unused_element_parameter` check flagged the leftover `opacity`
parameter specifically, since no call site anywhere in the file supplies it -- but it
was really a symptom of the whole class being unused now.

**Fix:** rather than silence the warning, deleted the dead code outright -- the
`_MosaicBg` / `_MosaicBgState` / `_MosaicCellPainter` classes were the last thing in
all four files (verified before deleting, in each file, that nothing followed them),
so each file was cleanly truncated at that point. The now-unused `import 'dart:ui' as
ui;` (only used by the deleted classes, confirmed by counting remaining `ui.`
references -- zero in all four) was removed too, since an unused import is its own
`flutter analyze` failure.

**Also proactively fixed the same latent issue in Home** (`home_dashboard_screen.dart`):
its `_MosaicBg` copy has no optional `opacity` parameter (`col`/`row` are both
`required`), so it happened not to trip `unused_element_parameter` and this
particular CI run didn't flag it -- but it was dead for exactly the same reason
(replaced by `WirdiIdentityBackground.photo` back in v1.56.0/v1.56.2) and was cleaned
up the same way rather than left as a ticking time bomb for the next `flutter
analyze` run or a stricter lint rule.

**A mistake caught and fixed within this same pass:** the first attempt at deleting
the dead code in these five files used a naive string-replace that only removed the
`class _MosaicBg extends StatefulWidget {` line itself, leaving the rest of that
class's body (now missing its opening brace) still in the file -- which would have
been a syntax error, not a clean fix. This was caught immediately by re-running the
syntax check on the edited files (the same tree-sitter-based check used throughout
this whole review) before moving on, and corrected by truncating each file from the
dead-code marker to the true end of file instead. Every file was re-verified clean
afterward. This is a concrete example of why every edit in this whole project has
been syntax-checked immediately after being made, not just once at the end.

**Verified after this fix:** all 183 `lib/` files re-parse with zero syntax errors;
the const/non-const-getter scan (build 23's bug class) still finds nothing; every
`_MosaicBg`/`_MosaicBgState`/`_MosaicCellPainter`/`dart:ui` reference in these five
files is gone (checked by direct grep, not just "should be gone"); no other import in
any of the eight files touched across v1.56.0-v1.56.3 became unused as a side effect
(checked programmatically, not just for `dart:ui`). **Still not verified:** an actual
`flutter analyze` run -- this is the third batch of changes in this project's history
to reach CI without having been compiled first, and the second one to come back with
a real, previously-invisible bug. If this next CI run finds anything else, the same
process applies: paste the log, get a targeted fix, verified the same way before
being sent back.
