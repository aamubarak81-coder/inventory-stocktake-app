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

- جدول `stocktakes` فيه سياسة اسمها `"allow all"` بشرط `true` مطلق — أي مستخدم مسجّل دخول يقدر نظرياً يقرأ/يكتب بيانات أي منظمة، بغض النظر عن `org_id` الخاص فيه. **لم يُحل بعد.**
- ✅ **تم حل مشكلة `discrepancy_alerts` (2026-07-05):** استُبدلت سياسة `"allow all"` المؤقتة بسياسة حقيقية تتحقق من `org_id` عبر جدول `employees` مباشرة باستخدام `auth.uid()` (نفس الآلية الفعلية التي يعتمدها `AuthService.login()` بالتطبيق):
  ```sql
  create policy "employees can access their own org alerts"
    on discrepancy_alerts for all
    using (org_id = (select org_id from employees where id = auth.uid()))
    with check (org_id = (select org_id from employees where id = auth.uid()));
  ```
  تم اختباره فعلياً وتأكيد أنه يسمح بالإدراج الصحيح للموظف بمنظمته، دون فتح الوصول لبيانات منظمات أخرى.
- ما زال يوجد نمطين مختلفين وغير متطابقين للتحقق من `org_id` عبر باقي الجداول (`auth.jwt() ->> 'org_id'` مقابل `current_setting('app.current_org_id')`)، ولا واحد منهم متوافق فعلياً مع آلية المصادقة الحالية بالتطبيق. **الحل الصحيح المُثبت أعلاه (عبر جدول `employees` و`auth.uid()`) هو النمط الذي يجب اعتماده لأي جدول آخر يحتاج نفس النوع من العزل.**

**قبل إطلاق أي نسخة Beta لعميل حقيقي، ما زال يجب:**
1. تطبيق نفس نمط `employees` + `auth.uid()` على جدول `stocktakes` (لا يزال يستخدم `"allow all"`)
2. مراجعة شاملة لكل الجداول الأخرى (`products`, `org_settings`, إلخ) للتأكد من استخدام نفس النمط الموحّد والصحيح
3. حذف أو إصلاح السياسات القديمة غير المستخدمة (`stocktake_isolation_policy`, `stocktake_isolation`) على الجداول القديمة لتفادي الالتباس مستقبلاً

