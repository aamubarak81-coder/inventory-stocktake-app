# inventory_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## ملاحظات قاعدة البيانات (Supabase) — مهم قبل أي عمل مستقبلي

### Triggers على جدول `stocktakes` — الحالة الحالية

| Trigger | الدالة | الحالة | السبب |
|---|---|---|---|
| `trg_last_in_wins` | `handle_stocktake_insert` | ✅ فعّال (تم إصلاحه) | كان بيدوّر على عمود `warehouse_id` غير موجود بجدول `stocktakes`، فكان يفشّل أي رفع جرد. تم تصحيحه بحذف شرط `warehouse_id` من شرط المطابقة (2026-07-05). |
| `trg_auto_discrepancy` | `calculate_stocktake_discrepancy` | ❌ **معطّل عمداً** | نظام حساب فروقات قديم يكتب لجدول `discrepancies` (مختلف عن نظامنا الحالي). معطّل بأمر `alter table stocktakes disable trigger trg_auto_discrepancy;` |
| `trg_after_stocktake_sync` | (نفس الغرض السابق) | ❌ **معطّل عمداً** | نفس السبب - جزء من النظام القديم غير المكتمل. |
| `trg_audit_stocktake` | `audit_stocktake_changes` | ❌ **معطّل عمداً** | يكتب لجدول `audit_log`، لكن RLS على هذا الجدول مكسور بنفس مشكلة `discrepancies` (شرطين متضاربين لا يطابقان آلية تسجيل الدخول الفعلية بالتطبيق). عطّلناه مؤقتاً بدل ما يفشّل كل مزامنة. **مطلوب لاحقاً:** إصلاح RLS الخاص بـ `audit_log` وإعادة تفعيله إذا رغبنا بسجل تدقيق فعلي.

### نظام الفروقات الحالي (المُعتمد)

النظام الفعلي المستخدم الآن هو: `DiscrepancyCalculator` (منطق Dart) + جدول `org_settings` (الحدود المسموحة) + جدول `discrepancy_alerts` (التخزين)، ويعمل عبر `DiscrepancyAlertService` بعد كل مزامنة ناجحة للجرد. **لا علاقة له بجداول `discrepancies` أو `audit_log` القديمة.**

### ⚠️ دين تقني أمني (Security Debt) - يجب حله قبل الـ Beta

اكتُشف أثناء التشخيص أن عدة جداول (`stocktakes`, `discrepancy_alerts`, `discrepancies`, `audit_log`) تحتوي سياسات RLS متضاربة أو مفتوحة بالكامل:

- جدول `stocktakes` فيه سياسة اسمها `"allow all"` بشرط `true` مطلق — أي مستخدم مسجّل دخول يقدر نظرياً يقرأ/يكتب بيانات أي منظمة، بغض النظر عن `org_id` الخاص فيه.
- أضفنا نفس نمط `"allow all"` على `discrepancy_alerts` مؤقتاً لجعل الاختبار يعمل (2026-07-05) — **هذا حل مؤقت غير آمن للإنتاج.**
- في نمطين مختلفين وغير متطابقين للتحقق من `org_id` عبر الجداول (`auth.jwt() ->> 'org_id'` مقابل `current_setting('app.current_org_id')`)، ولا واحد منهم يبدو متوافقاً فعلياً مع آلية المصادقة الحالية بالتطبيق (`AuthService`).

**قبل إطلاق أي نسخة Beta لعميل حقيقي، يجب:**
1. تحديد آلية واحدة موحّدة للتحقق من `org_id` بكل الـ RLS policies
2. استبدال كل سياسات `"allow all"` بسياسات فعلية تعزل بيانات كل منظمة عن الأخرى
3. مراجعة شاملة لكل الجداول (ليس فقط الأربعة المذكورة) للتأكد من عدم وجود سياسات مماثلة منسية

