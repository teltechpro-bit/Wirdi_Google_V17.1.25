import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Way2QuranWebViewScreen extends StatefulWidget {
  const Way2QuranWebViewScreen({super.key});

  @override
  State<Way2QuranWebViewScreen> createState() => _Way2QuranWebViewScreenState();
}

class _Way2QuranWebViewScreenState extends State<Way2QuranWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Theme.of(context).scaffoldBackgroundColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _progress = 0);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 100);
          },
        ),
      )
      ..loadRequest(
        Uri.parse(
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'https://way2quran.com/ar'
              : 'https://way2quran.com/en',
        ),
      );
  }

  Future<bool> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _goBack() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Way2Quran'),
          actions: [
            IconButton(
              tooltip: ar ? 'رجوع' : 'Back',
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () async {
                if (!await _controller.canGoBack() && context.mounted) {
                  Navigator.of(context).pop();
                  return;
                }
                await _controller.goBack();
              },
            ),
            IconButton(
              tooltip: ar ? 'تقدم' : 'Forward',
              icon: const Icon(Icons.arrow_forward_ios_rounded),
              onPressed: () async {
                if (await _controller.canGoForward()) {
                  await _controller.goForward();
                }
              },
            ),
            IconButton(
              tooltip: ar ? 'تحديث' : 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller.reload(),
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: _progress / 100),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
