import 'dart:html' as html;
import 'dart:typed_data';

class WebDownloadService {
  static void downloadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}