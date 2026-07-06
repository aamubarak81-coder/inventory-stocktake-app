import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// يحمّل خط Amiri (عربي، مرخّص Open Font License) مرة واحدة ويوفره كـ
/// pw.ThemeData جاهز للاستخدام مع أي pw.Document، حتى ترتسم الحروف العربية
/// صح بدل مربعات فارغة (tofu) — المكتبة الأساسية pdf ما فيها خط افتراضي
/// يدعم العربي.
class PdfFontService {
  static pw.ThemeData? _cachedTheme;

  static Future<pw.ThemeData> getArabicTheme() async {
    if (_cachedTheme != null) return _cachedTheme!;

    final regularBytes = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final boldBytes = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');

    final regularFont = pw.Font.ttf(regularBytes);
    final boldFont = pw.Font.ttf(boldBytes);

    _cachedTheme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );
    return _cachedTheme!;
  }
}
