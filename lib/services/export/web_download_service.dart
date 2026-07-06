// يستخدم فقط عند البناء لمنصة الويب (يُختار تلقائياً عبر conditional import
// بدلاً من web_download_stub.dart). package:web + dart:js_interop هما البديل
// الرسمي الموصى به من فريق Dart بدلاً من dart:html المهجورة.
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class WebDownloadService {
  static void downloadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    final blobParts = <JSAny>[bytes.toJS].toJS;
    final blob = web.Blob(blobParts, web.BlobPropertyBag(type: mimeType));
    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..style.display = 'none';

    // لازم نلحقه بالـ body عشان click() يشتغل بثبات على كل المتصفحات
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();

    web.URL.revokeObjectURL(url);
  }
}
