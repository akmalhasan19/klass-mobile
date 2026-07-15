import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Full-screen preview screen that loads a self-contained HTML artifact
/// (marp preview) inside an ``InAppWebView``.
///
/// The preview is a self-contained HTML file served via signed URL from the
/// media generator service.  No CORS issues, no external network requests —
/// the browser engine renders it in-place.
class MediaPreviewScreen extends StatefulWidget {
  const MediaPreviewScreen({
    super.key,
    required this.previewUrl,
    this.title,
  });

  /// Signed URL for the self-contained HTML preview.
  final String previewUrl;

  /// Optional display title (shown in the app bar).
  final String? title;

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? 'Preview',
          style: const TextStyle(
            fontFamily: 'Mona_Sans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0E4C5C),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: _progress < 1.0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              )
            : null,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(widget.previewUrl),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          verticalScrollBarEnabled: true,
          horizontalScrollBarEnabled: false,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          // The marp HTML is self-contained, but these settings ensure it
          // can load any embedded images or fonts from the same origin.
        ),
        onWebViewCreated: (_) {
          // Controller stored for potential future use (e.g. JS injection).
        },
        onProgressChanged: (controller, progress) {
          setState(() {
            _progress = progress / 100.0;
          });
        },
        onConsoleMessage: (controller, message) {
          // Forward any JavaScript console messages for debugging.
          debugPrint('InAppWebView console: [${message.messageLevel}] ${message.message}');
        },
      ),
    );
  }
}
