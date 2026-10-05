import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Renders a single ayah as a styled, shareable image card -- Arabic
/// text, optional translation, Surah/Ayah reference, and Wirdi
/// branding -- captured via [RepaintBoundary] and handed to the OS
/// share sheet (WhatsApp, Instagram, Telegram, etc. all pick it up
/// automatically as an image attachment, no per-app integration needed).
class AyahShareScreen extends StatefulWidget {
  final String arabicText;
  final String? translationText;
  final String surahNameArabic;
  final String surahNameLocalized;
  final int surahNumber;
  final int ayahNumber;

  const AyahShareScreen({
    super.key,
    required this.arabicText,
    required this.translationText,
    required this.surahNameArabic,
    required this.surahNameLocalized,
    required this.surahNumber,
    required this.ayahNumber,
  });

  @override
  State<AyahShareScreen> createState() => _AyahShareScreenState();
}

class _AyahShareScreenState extends State<AyahShareScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _showTranslation = true;
  bool _isSharing = false;
  int _templateIndex = 0;

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/wirdi_ayah_${widget.surahNumber}_${widget.ayahNumber}.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)]);
    } catch (_) {
      // Sharing is best-effort -- the user can simply try again.
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ayahShareTitle), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
                child: RepaintBoundary(
                  key: _cardKey,
                  child: _AyahCard(
                    arabicText: widget.arabicText,
                    translationText: _showTranslation ? widget.translationText : null,
                    surahNameArabic: widget.surahNameArabic,
                    ayahNumber: widget.ayahNumber,
                    template: _kShareTemplates[_templateIndex],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _kShareTemplates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final t = _kShareTemplates[i];
                        return GestureDetector(
                          onTap: () => setState(() => _templateIndex = i),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: t.resolve(), begin: Alignment.topLeft, end: Alignment.bottomRight),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: i == _templateIndex ? AppColors.goldAccent : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.translationText != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.ayahShareIncludeTranslation),
                      value: _showTranslation,
                      activeTrackColor: AppColors.primaryEmerald,
                      onChanged: (value) => setState(() => _showTranslation = value),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSharing ? null : _share,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.share),
                      label: Text(l10n.ayahShareButton),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual style of the shareable card. `colors` may be empty for the
/// first template, which follows the app's current color theme.
class _ShareTemplate {
  final List<Color> colors;
  final Color text;
  final Color accent;
  const _ShareTemplate(this.colors, this.text, this.accent);

  List<Color> resolve() => colors.isEmpty ? [AppColors.primaryEmerald, const Color(0xFF0B3D36)] : colors;
}

const List<_ShareTemplate> _kShareTemplates = [
  _ShareTemplate(<Color>[], Colors.white, Color(0xFFE0B84C)),
  _ShareTemplate(<Color>[Color(0xFF0D1B3D), Color(0xFF1F3B73)], Colors.white, Color(0xFFF5D76E)),
  _ShareTemplate(<Color>[Color(0xFF3B1C32), Color(0xFF6B2D5C)], Colors.white, Color(0xFFF2C6DE)),
  _ShareTemplate(<Color>[Color(0xFFF6EFE0), Color(0xFFE8D9B5)], Color(0xFF3A2E1A), Color(0xFF8A6D1E)),
  _ShareTemplate(<Color>[Color(0xFF000000), Color(0xFF1B1B1B)], Colors.white, Color(0xFFD4AF37)),
  _ShareTemplate(<Color>[Color(0xFF134E4A), Color(0xFF2A9D8F)], Colors.white, Color(0xFFFFE9A8)),
];

class _AyahCard extends StatelessWidget {
  final String arabicText;
  final String? translationText;
  final String surahNameArabic;
  final int ayahNumber;
  final _ShareTemplate template;

  const _AyahCard({
    required this.arabicText,
    required this.translationText,
    required this.surahNameArabic,
    required this.ayahNumber,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: template.resolve(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.format_quote, color: template.accent, size: 28),
          const SizedBox(height: 16),
          Text(
            arabicText,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 24,
              height: 1.9,
              color: template.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (translationText != null) ...[
            const SizedBox(height: 20),
            Container(height: 1, width: 60, color: template.accent.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            Text(
              translationText!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: template.text.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            '$surahNameArabic • $ayahNumber',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: template.accent, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mosque, size: 16, color: template.text.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(
                'Wirdi',
                style: TextStyle(fontSize: 13, color: template.text.withValues(alpha: 0.7), fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
