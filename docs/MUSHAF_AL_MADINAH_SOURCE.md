# Official Mushaf Al-Madinah source and integration constraints

## Selected source

- Publisher: King Fahd Glorious Quran Printing Complex (KFGQPC), Al-Madinah.
- Edition: Mushaf Al-Madinah, Hafs 'an Asim, vector edition.
- Public source mirror: https://github.com/MushafAlMadinahVector/MushafAlMadinahVector
- Official usage-rights page: https://dm.qurancomplex.gov.sa/rights/
- Source license notice: files remain the intellectual property of KFGQPC; the published rights permit digital/software use and redistribution, provided the Quran text is not modified.

## Integration requirements

Do not replace the current reader until the official page assets can be rendered and verified in-app.

1. Convert the supplied AI pages to an Android/iOS-supported local format (prefer SVG only after validating renderer support, otherwise use optimized PNG/WebP).
2. Bundle the converted pages locally so reading works offline; do not depend on a live GitHub/raw URL at runtime.
3. Verify page numbering and map each page to the existing surah/ayah references.
4. Preserve the existing Hafs Quran data, audio service, current-ayah tracking, reciter selection, continuous-scroll/page-flip controls, and navigation.
5. Do not claim that image pages support per-ayah playback highlighting or Tajweed colors unless accurate per-ayah geometry/word mapping is available and verified. If geometry is unavailable, keep the current text-rendered reader as the fully featured mode and do not silently remove its features.
6. Keep the source attribution and license notice in the app/repository. Never alter the Quran text.

## Current status

This document records the selected source and the technical acceptance criteria. It does not itself add official page assets or change the reader to image pages. The existing bundled page-to-ayah JSON remains the current reader's page mapping until the new assets and overlay mapping are validated.
