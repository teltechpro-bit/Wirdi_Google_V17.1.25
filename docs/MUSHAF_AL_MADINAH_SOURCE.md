# Official Mushaf Al-Madinah source and lightweight integration decision

## Decision: do not bundle the 604 original page files

- Publisher: King Fahd Glorious Quran Printing Complex (KFGQPC), Al-Madinah.
- Edition under consideration: Mushaf Al-Madinah, Hafs 'an Asim.
- Public source mirror: https://github.com/MushafAlMadinahVector/MushafAlMadinahVector
- Official usage-rights page: https://dm.qurancomplex.gov.sa/rights/
- The source mirror contains 604 original AI page files totalling approximately 769 MB.
- **Do not add those original files, or a full set of converted page images, to the Wirdi app bundle without measured evidence that the final size is acceptable.** No source page assets have been imported by this change.

## Preferred lightweight direction

First reuse and evaluate Wirdi's existing text-based Mushaf renderer and already bundled Quran fonts. The current renderer has the existing Hafs data, page-to-ayah mapping, playback tracking/highlighting, Tajweed coloring, zoom, navigation, and offline behavior. A font/style choice is much smaller in concept than shipping hundreds of page images, and does not inherently require replacing that pipeline.

The repository also contains a local `packages/qcf_quran` package with a compressed QCF font archive. Before integrating it, inspect the actual archive size, licensing of its bundled fonts, compatibility with this app's Flutter/Dart versions, and whether its per-page font approach can preserve accurate ayah playback highlighting and Tajweed coloring. Its presence alone is not proof that it is smaller, license-cleared, or compatible.

## Acceptance criteria before adding another Mushaf style

1. Measure the actual added release-bundle size; set an explicit size budget before considering new assets.
2. Prefer reusing already-bundled fonts and rendering text natively over adding hundreds of page images.
3. Keep the existing Hafs reader as the default and preserve audio, current-ayah highlighting, Tajweed colors, navigation, zoom, and offline reading.
4. Do not show a page-image mode as feature-equivalent unless accurate page/ayah/word geometry is available and verified.
5. Verify font and source licenses before distributing any additional assets. Keep attribution and applicable notices, and never modify Quran text.
6. Run Flutter analysis, tests, and an Android release build, and compare bundle sizes before proposing merge.

## Current status

This is a design constraint and evaluation plan, not a completed integration. The official 604-page AI collection has not been added or converted. The existing reader remains the feature-preserving baseline. The font choices in PR #44 change typography only; they do not yet provide distinct printed-page layouts.
