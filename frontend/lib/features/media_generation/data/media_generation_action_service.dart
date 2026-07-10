import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaGenerationActionService {
  Future<void> openArtifact(String url) async {
    final uri = _parseUri(url);

    final openedInApp = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (openedInApp) {
      return;
    }

    final openedExternally = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!openedExternally) {
      throw Exception('Could not open generated artifact.');
    }
  }

  Future<void> downloadArtifact(String url) async {
    final uri = _parseUri(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      throw Exception('Could not start generated artifact download.');
    }
  }

  Future<void> shareArtifact({
    required String title,
    required String url,
    String? summary,
  }) async {
    final uri = _parseUri(url);
    final content = [
      title.trim(),
      if (summary != null && summary.trim().isNotEmpty) summary.trim(),
      uri.toString(),
    ].where((part) => part.isNotEmpty).join('\n\n');

    await Share.share(content, subject: title.trim().isEmpty ? null : title.trim());
  }

  Uri _parseUri(String rawUrl) {
    final normalized = rawUrl.trim();
    final uri = Uri.tryParse(normalized);

    if (normalized.isEmpty || uri == null || !uri.hasScheme) {
      throw FormatException('Invalid generated artifact URL.');
    }

    return uri;
  }
}