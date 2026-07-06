import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// يحتفظ بآخر موقع GPS معروف، ويحدّثه بالخلفية كل 5 دقائق بدل ما يجيبه
/// فرش (fresh) بكل مرة يُحفظ فيها جرد. الهدف: يخلي زر "حفظ" فوري تماماً
/// (بيقرأ آخر موقع محفوظ فقط، بدون أي انتظار شبكة/GPS/صلاحيات)، مقابل
/// دقة موقع "شبه لحظية" (بحدود 5 دقائق) بدل لحظية 100% - مقايضة معقولة
/// بما إنه الموقع بيانات مرافقة اختيارية، مش جزء أساسي من الجرد نفسه.
class LocationCacheService {
  static Position? _lastKnownPosition;
  static Timer? _timer;

  static Position? get lastKnownPosition => _lastKnownPosition;

  /// يبدأ التحديث الدوري. يُستدعى مرة عند فتح شاشة الجرد.
  static void start() {
    _refresh(); // محاولة فورية أولى (بدون انتظارها) عشان يكون عندنا موقع
                // بأسرع وقت ممكن قبل أول عملية حفظ، بدون ما نؤخر فتح الشاشة
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _refresh());
  }

  /// يوقف التحديث الدوري. يُستدعى عند إغلاق شاشة الجرد (dispose) لتوفير
  /// البطارية وتفادي أي تسريب موارد.
  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _refresh() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));

      _lastKnownPosition = position;
    } catch (_) {
      // فشلت هالمحاولة (GPS مقفول، صلاحية مرفوضة، انتهاء وقت...) - نبقي
      // آخر موقع معروف كما هو (ولو null لو أول محاولة)، ونحاول تاني
      // تلقائياً بعد 5 دقائق.
    }
  }
}
