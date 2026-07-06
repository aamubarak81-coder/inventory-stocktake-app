import 'dart:typed_data';

// نسخة بديلة (stub) بنفس اسم الكلاس والتوقيع تماماً مثل WebDownloadService
// الحقيقية (التي تستخدم package:web). هذا الملف يُستخدم فقط عند البناء لمنصات
// غير الويب (موبايل/ديسكتوب)، حيث مكتبات الويب (package:web) غير مناسبة.
// لا يُستدعى فعلياً في أي وقت لأن الكود المستدعي دائماً يتحقق من kIsWeb أولاً.
class WebDownloadService {
  static void downloadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    throw UnsupportedError(
      'WebDownloadService.downloadFile متاحة فقط عند التشغيل على الويب',
    );
  }
}
