import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A silhouette (mosque + minarets + crescent) drawn on a night-sky gradient,
/// in the app's emerald/gold identity colors -- an ORIGINAL vector
/// illustration, not a photo. This is the visual-identity asset requested to
/// go alongside the color palette: since no photo-generation tool is
/// available in this environment, hand-drawn vector art is the safe
/// alternative (no license/attribution risk, tiny file size, looks correct at
/// any size or pixel density, and already matches the app's color system
/// exactly because it's painted with [AppColors] rather than a fixed image).
///
/// Used as a drop-in background behind an AppBar's `flexibleSpace`, or as a
/// full-bleed hero (see [WirdiIdentityBackground.hero]), for any screen that
/// wants the "night skyline" identity look from the design brief. Purely
/// decorative -- it paints behind [child] and never intercepts touches, so
/// dropping it in never changes a screen's behavior.
class WirdiIdentityBackground extends StatelessWidget {
  const WirdiIdentityBackground({
    super.key,
    this.child,
    this.variant = WirdiSkylineVariant.night,
    this.showCrescent = true,
    this.silhouetteOpacity = 0.9,
  })  : photo = null,
        scrimOpacity = 0.55;

  /// Convenience for a full-screen hero section (e.g. behind a Stack at the
  /// top of a screen's body), a bit taller and with the crescent higher up.
  const WirdiIdentityBackground.hero({
    super.key,
    this.child,
    this.variant = WirdiSkylineVariant.night,
  })  : showCrescent = true,
        silhouetteOpacity = 1.0,
        photo = null,
        scrimOpacity = 0.55;

  final Widget? child;
  final WirdiSkylineVariant variant;
  final bool showCrescent;
  final double silhouetteOpacity;

  /// A real bundled photo instead of the vector skyline (see
  /// [WirdiIdentityBackground.photo]). When set, [variant]/[showCrescent]/
  /// [silhouetteOpacity] are ignored.
  final WirdiIdentityPhoto? photo;

  /// Uses one of the app's own bundled scenic photos (see
  /// [WirdiIdentityPhoto]) instead of the vector illustration -- for screens
  /// that want the same photographic hero look as the visual-identity brief's
  /// mock-ups. The photo is covered by a gradient scrim so foreground text
  /// stays legible, matching the dark-hero screens in the brief (Home,
  /// Qibla, Radio, Moon).
  const WirdiIdentityBackground.photo({
    super.key,
    required this.photo,
    this.child,
    this.scrimOpacity = 0.55,
  })  : variant = WirdiSkylineVariant.night,
        showCrescent = false,
        silhouetteOpacity = 0.0;

  /// Scrim darkness (0.0-1.0) over a [photo] background; ignored for the
  /// vector variants.
  final double scrimOpacity;

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(photo!.asset, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.darkBackground.withValues(alpha: scrimOpacity * 0.7),
                  AppColors.darkBackground.withValues(alpha: scrimOpacity),
                ],
              ),
            ),
          ),
          if (child != null) child!,
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(gradient: _skyGradient(variant)),
      child: CustomPaint(
        painter: _SkylinePainter(
          silhouetteColor: AppColors.darkBackground.withValues(alpha: silhouetteOpacity),
          accentColor: AppColors.goldAccent,
          showCrescent: showCrescent,
        ),
        child: child ?? const SizedBox.expand(),
      ),
    );
  }

  static LinearGradient _skyGradient(WirdiSkylineVariant variant) {
    switch (variant) {
      case WirdiSkylineVariant.night:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.darkBackground, AppColors.primaryEmerald.withValues(alpha: 0.55), AppColors.darkBackground],
        );
      case WirdiSkylineVariant.sunset:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryEmerald, AppColors.goldAccent.withValues(alpha: 0.45), AppColors.darkBackground],
        );
    }
  }
}

enum WirdiSkylineVariant { night, sunset }

/// The app's own bundled scenic photos (`assets/images/identity/`), restored
/// from the original project's design-brief renders and cropped clean of the
/// mock-up chrome they originally had baked into them (fake back buttons,
/// titles, a date stamp, placeholder cards) so they're safe to use as real
/// in-app backgrounds instead of only reference art.
enum WirdiIdentityPhoto {
  homeScenery('assets/images/identity/home_scenery.webp'),
  kaabaNight('assets/images/identity/kaaba_night.webp'),
  mosqueSunset('assets/images/identity/mosque_sunset.webp'),
  moonNight('assets/images/identity/moon_night.webp'),
  quranMosque('assets/images/identity/quran_mosque.webp'),
  lanternSunset('assets/images/identity/lantern_sunset.webp');

  final String asset;
  const WirdiIdentityPhoto(this.asset);
}

/// Paints a simple domed-mosque + two minarets + crescent silhouette,
/// anchored to the bottom of the available area, plus a few star dots.
/// Deliberately simple geometry (arcs and triangles) so it reads clearly at
/// small header heights as well as a full-screen hero.
class _SkylinePainter extends CustomPainter {
  _SkylinePainter({required this.silhouetteColor, required this.accentColor, required this.showCrescent});

  final Color silhouetteColor;
  final Color accentColor;
  final bool showCrescent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // The skyline is a band of fixed proportions relative to WIDTH, anchored
    // to the bottom -- not stretched across the full height. A first version
    // scaled every shape to `h` directly, which looked right in a short
    // AppBar strip but badly distorted (minarets stretched paper-thin, dome
    // floating in empty space) in a tall full-screen hero. Verified by
    // rendering both proportions before wiring this into any screen.
    final bandH = math.min(h * 0.62, w * 0.85);
    final baseY = h;
    final groundY = h - bandH * 0.18;
    final domeCenterX = w / 2;
    final domeRadius = w * 0.16;
    final domeTopY = groundY - bandH * 0.62;
    final bodyTop = domeTopY + domeRadius * 0.65;

    final paint = Paint()..color = silhouetteColor;
    final path = Path()
      ..moveTo(0, baseY)
      ..lineTo(0, groundY)
      ..lineTo(domeCenterX - domeRadius * 2.1, groundY)
      ..lineTo(domeCenterX - domeRadius * 2.1, bodyTop)
      ..arcTo(
        Rect.fromCircle(center: Offset(domeCenterX, domeTopY), radius: domeRadius),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(domeCenterX + domeRadius * 2.1, bodyTop)
      ..lineTo(domeCenterX + domeRadius * 2.1, groundY)
      ..lineTo(w, groundY)
      ..lineTo(w, baseY)
      ..close();
    canvas.drawPath(path, paint);

    // Small finial on the dome.
    canvas.drawLine(
      Offset(domeCenterX, domeTopY - domeRadius),
      Offset(domeCenterX, domeTopY - domeRadius - bandH * 0.09),
      Paint()
        ..color = silhouetteColor
        ..strokeWidth = math.max(1.5, w * 0.004),
    );

    // Two flanking minarets, sized off the same band height so they stay in
    // proportion at any container height.
    _minaret(canvas, x: w * 0.13, groundY: groundY, minaretH: bandH * 0.72, halfW: w * 0.022, paint: paint);
    _minaret(canvas, x: w * 0.87, groundY: groundY, minaretH: bandH * 0.72, halfW: w * 0.022, paint: paint);

    if (showCrescent) {
      // Positioned relative to the sky area ABOVE the skyline band, so it
      // sits near the top of a short header and near the top of a tall hero
      // alike, instead of drifting based on total height.
      final skyH = groundY;
      final center = Offset(w * 0.78, math.min(skyH * 0.42, bandH * 0.9));
      final r = math.max(10.0, math.min(w, bandH) * 0.09);
      // Isolated in its own layer: BlendMode.clear applied directly to the
      // main canvas (no saveLayer) would punch through whatever is painted
      // BENEATH this whole CustomPaint too (the sky gradient), not just the
      // circle drawn a moment ago -- saveLayer scopes the "cut" to this
      // crescent shape only.
      final bounds = Rect.fromCircle(center: center, radius: r * 1.6);
      canvas.saveLayer(bounds, Paint());
      canvas.drawCircle(center, r, Paint()..color = accentColor.withValues(alpha: 0.9));
      canvas.drawCircle(
        Offset(center.dx + r * 0.55, center.dy - r * 0.25),
        r * 0.92,
        Paint()..blendMode = BlendMode.clear,
      );
      canvas.restore();
    }

    // A handful of fixed-position "stars" in the sky area above the skyline,
    // so the paint is deterministic (no random seed drift between
    // rebuilds/hot reloads).
    const starFractions = [
      (0.10, 0.30), (0.22, 0.55), (0.35, 0.20), (0.55, 0.40),
      (0.62, 0.15), (0.30, 0.60), (0.46, 0.25), (0.18, 0.12),
    ];
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final skyH = groundY;
    for (final (fx, fy) in starFractions) {
      canvas.drawCircle(Offset(w * fx, skyH * fy), math.max(1.0, w * 0.0025), starPaint);
    }
  }

  void _minaret(Canvas canvas, {required double x, required double groundY, required double minaretH, required double halfW, required Paint paint}) {
    final topY = groundY - minaretH;
    final path = Path()
      ..moveTo(x - halfW, groundY)
      ..lineTo(x - halfW, topY + halfW * 3)
      ..lineTo(x, topY)
      ..lineTo(x + halfW, topY + halfW * 3)
      ..lineTo(x + halfW, groundY)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(x, topY - halfW), halfW * 0.9, paint);
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) =>
      oldDelegate.silhouetteColor != silhouetteColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.showCrescent != showCrescent;
}
