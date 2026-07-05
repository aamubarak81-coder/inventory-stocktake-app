-- إصلاح RLS على org_settings و تنظيف products
-- المشكلة: الـ policies القديمة كانت تعتمد على auth.jwt() ->> 'org_id'
-- لكن التطبيق لا يضع org_id في الـ JWT إطلاقاً (auth_service.dart يجيبه من
-- جدول employees ويخزنه محلياً على الجهاز فقط). لذلك هذه الشروط كانت
-- تُقيَّم دائماً NULL = NULL => false، يعني:
--   - org_settings: SELECT/UPDATE معطّلين فعلياً لأي مستخدم
--   - products: نفس القصة لـ policy "product_isolation_policy" و "product_isolation"
--     (بقيت الجداول تعمل فقط بسبب policies أخرى موجودة تعتمد على employees)

begin;

-- =========================================================
-- 1) org_settings: حذف الـ policies الميتة وإعادة بنائها
--    بنفس النمط الصحيح المستخدم في products (employees + auth.uid())
-- =========================================================

drop policy if exists "org members can view their settings" on org_settings;
drop policy if exists "org admins can update their settings" on org_settings;

-- SELECT: أي موظف بنفس المنظمة يقدر يشوف إعدادات منظمته
create policy "org members can view their settings"
on org_settings
for select
using (
  org_id in (
    select employees.org_id
    from employees
    where employees.id = auth.uid()
  )
);

-- UPDATE: فقط admin أو super_admin بنفس المنظمة يقدر يعدّل
create policy "org admins can update their settings"
on org_settings
for update
using (
  org_id in (
    select employees.org_id
    from employees
    where employees.id = auth.uid()
      and (employees.is_super_admin = true or employees.role = 'admin')
  )
)
with check (
  org_id in (
    select employees.org_id
    from employees
    where employees.id = auth.uid()
      and (employees.is_super_admin = true or employees.role = 'admin')
  )
);

-- INSERT: كانت مفقودة بالكامل. فقط admin/super_admin يقدر ينشئ صف إعدادات
-- لمنظمته هو (مو لأي منظمة تانية)
create policy "org admins can create their settings"
on org_settings
for insert
with check (
  org_id in (
    select employees.org_id
    from employees
    where employees.id = auth.uid()
      and (employees.is_super_admin = true or employees.role = 'admin')
  )
);

-- =========================================================
-- 2) products: حذف policies الميتة (كانت تعتمد على auth.jwt())
--    القرار: نُبقي فقط الـ policies المبنية على employees، وهي الوحيدة
--    الشغالة فعلياً، لتفادي أي غموض أو تضارب مستقبلي
-- =========================================================

drop policy if exists "product_isolation_policy" on products;
drop policy if exists "product_isolation" on products;

-- الـ policies المتبقية على products بعد هذا التنظيف:
--   - "Enable read access for employees of the same org" (SELECT)
--   - "Enable write access for employees of the same org" (INSERT)
--   - "Super admin can view all products" (SELECT)
--   - "Allow postgres role to view all products" (SELECT, role postgres)
-- ملاحظة: لا يوجد UPDATE/DELETE policy صريحة على products بعد هذا التنظيف.
-- إذا كان التطبيق يحتاج تعديل/حذف منتجات، لازم نضيف policies لهم بشكل منفصل
-- (راجعنا هذا لاحقاً كخطوة تالية منفصلة، تفادياً لفتح صلاحيات غير مقصودة الآن).

commit;
