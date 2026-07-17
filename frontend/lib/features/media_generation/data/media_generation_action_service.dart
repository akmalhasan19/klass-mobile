import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadProgress {
  const DownloadProgress({
    required this.bytesReceived,
    this.totalBytes,
    this.isComplete = false,
  });

  final int bytesReceived;
  final int? totalBytes;
  final bool isComplete;

  double? get percentage =>
      totalBytes != null && totalBytes! > 0 ? bytesReceived / totalBytes! : null;
}

class MediaGenerationActionService {
  MediaGenerationActionService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

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

  Future<void> downloadArtifact(
    String url, {
    void Function(DownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final uri = _parseUri(url);
    final fileName = _extractFileName(uri);
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$fileName';
    final tempFilePath = '$filePath.tmp';

    final tempFile = File(tempFilePath);
    int existingBytes = 0;

    if (await tempFile.exists()) {
      existingBytes = await tempFile.length();
    }

    final headers = <String, String>{};
    if (existingBytes > 0) {
      headers[HttpHeaders.rangeHeader] = 'bytes=$existingBytes-';
    }

    final response = await _dio.get<ResponseBody>(
      uri.toString(),
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        receiveTimeout: const Duration(minutes: 10),
      ),
      cancelToken: cancelToken,
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 200) {
      existingBytes = 0;
      final sink = tempFile.openWrite(mode: FileMode.write);
      await sink.close();
    }

    final contentLength = int.tryParse(
      response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
    );

    final stream = response.data!.stream;
    final raf = await tempFile.open(mode: FileMode.writeOnlyAppend);
    int totalReceived = 0;

    try {
      await for (final chunk in stream) {
        await raf.writeFrom(chunk);
        totalReceived += chunk.length;

        final totalBytes =
            contentLength != null ? existingBytes + contentLength : null;

        onProgress?.call(DownloadProgress(
          bytesReceived: existingBytes + totalReceived,
          totalBytes: totalBytes,
        ));
      }
    } finally {
      await raf.close();
    }

    final finalFile = File(filePath);
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    await tempFile.rename(finalFile.path);

    onProgress?.call(DownloadProgress(
      bytesReceived: await finalFile.length(),
      totalBytes: await finalFile.length(),
      isComplete: true,
    ));

    final result = await OpenFilex.open(finalFile.path);
    if (result.type != ResultType.done) {
      throw Exception('Could not open downloaded file: ${result.message}');
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

  String _extractFileName(Uri uri) {
    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) return 'download';

    final lastSegment = pathSegments.last;
    if (lastSegment.isEmpty) return 'download';

    final decoded = Uri.decodeComponent(lastSegment);
    return decoded.isNotEmpty ? decoded : 'download';
  }
}
