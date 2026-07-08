-- إضافة صلاحية UPDATE المفقودة على products
--
-- السياق: لما نضّفنا RLS على products سابقاً (migration
-- 20260705222304)، أبقينا فقط SELECT وINSERT (وهما الوحيدتان
-- الشغالتان وقتها)، وسجّلنا وقتها ملاحظة إنه ما في UPDATE/DELETE
-- صريحة، وإنه لازم تُضاف لاحقاً كخطوة منفصلة عند الحاجة.
--
-- الحاجة صارت الآن: ميزة "استيراد المنتجات" الجديدة تعتمد على
-- upsert (تحديث المنتج الموجود لو نفس الـ id، أو إدراجه لو جديد) -
-- عملية upsert على صف موجود فعلياً تحتاج صلاحية UPDATE، وإلا الجزء
-- الخاص بتحديث المنتجات الموجودة (مثلاً إعادة رفع كتالوج بكميات
-- محدّثة) هيُرفض من RLS بصمت.

begin;

create policy "Enable update access for employees of the same org"
on products
for update
using (
  auth.uid() in (
    select employees.id
    from employees
    where employees.org_id = products.org_id
  )
)
with check (
  auth.uid() in (
    select employees.id
    from employees
    where employees.org_id = products.org_id
  )
);

commit;
