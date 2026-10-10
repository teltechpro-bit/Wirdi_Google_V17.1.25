import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts official Way2Quran pages inside Wirdi for website features that do
/// not yet have a native API-backed screen in the app.
class Way2QuranWebScreen extends StatefulWidget {
  final String title;
  final String url;

  const Way2QuranWebScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<Way2QuranWebScreen> createState() => _Way2QuranWebScreenState();
}

class _Way2QuranWebScreenState extends State<Way2QuranWebScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _progress = progress;
                if (progress > 0) _loadFailed = false;
              });
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _loadFailed = true);
            }
          },
        ),
      )
      ;
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final uri = Uri.parse(widget.url);
      if ((uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
        throw const FormatException('Invalid embedded page URL');
      }
      await _controller.loadRequest(uri);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _loadFailed = false;
      _progress = 0;
    });
    try {
      await _controller.reload();
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: ar ? 'تحديث' : 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loadFailed)
            Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        ar ? 'تعذر تحميل صفحة Way2Quran' : 'Could not load this Way2Quran page',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(ar ? 'إعادة المحاولة' : 'Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
