-- =====================================================================
-- 📑 ملف إعداد قاعدة البيانات الموحد والمحدث - الإصدار الفائق (V3.2_Final)
-- تم التطوير وبناء القيود بناءً على مراجعة السلامة الهندسية الكاملة
-- =====================================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- 1. جدول الباقات
create table plans (
    id uuid primary key default gen_random_uuid(),
    plan_name text not null unique,
    max_items int not null check (max_items > 0),
    max_users int not null check (max_users > 0),
    log_retention_days int not null check (log_retention_days > 0),
    price numeric(10, 2) default 0.00 not null check (price >= 0)
);

insert into plans (plan_name, max_items, max_users, log_retention_days, price) values
('Standard', 2000, 1, 30, 0.00),
('Pro', 10000, 5, 90, 0.00),
('Business', 999999, 999, 999, 0.00)
on conflict (plan_name) do nothing;

-- 2. جدول المؤسسات والشركات
create table organizations (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    plan_id uuid references plans(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. جدول الاشتراكات ومتابعة الصلاحية
create table subscriptions (
    id uuid primary key default gen_random_uuid(),
    org_id uuid not null references organizations(id) on delete cascade,
    is_active boolean default true not null,
    expires_at timestamp with time zone not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. جدول المستودعات والفروع
create table warehouses (
    id uuid primary key default gen_random_uuid(),
    org_id uuid not null references organizations(id) on delete cascade,
    name text not null,
    location text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. جدول الموظفين والمناديب
create table employees (
    id uuid primary key references auth.users(id) on delete cascade,
    org_id uuid not null references organizations(id) on delete cascade,
    name text not null,
    role text not null check (role in ('admin', 'manager', 'driver')), 
    phone text unique,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 6. جدول المنتجات
create table products (
    id uuid primary key default gen_random_uuid(),
    org_id uuid not null references organizations(id) on delete cascade,
    barcode text not null,
    name text not null,
    system_quantity int default 0 not null,
    price numeric(10, 2) default 0.00 not null,
    warehouse_id uuid references warehouses(id) on delete set null,
    location_ref text, 
    is_frozen boolean default false, 
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    constraint unique_barcode_per_org unique (org_id, barcode)
);

-- 7. جدول عمليات الجرد الفعلي للمناديب (معرف نصي لدعم الأوفلاين)
create table stocktakes (
    id text primary key, 
    org_id uuid not null references organizations(id) on delete cascade,
    product_id uuid references products(id) on delete cascade not null,
    scanned_quantity int not null,
    expected_quantity int, 
    is_blind_count boolean default true, 
    latitude double precision, 
    longitude double precision, 
    scanned_by uuid references employees(id) on delete restrict not null, 
    scanned_at timestamp with time zone not null 
);

-- 8. جدول سجل الفروقات التلقائي
create table discrepancies (
    id uuid primary key default gen_random_uuid(),
    org_id uuid not null references organizations(id) on delete cascade,
    stocktake_id text references stocktakes(id) on delete cascade not null unique,
    product_id uuid references products(id) on delete cascade not null,
    system_qty int not null,
    scanned_qty int not null,
    discrepancy_qty int not null, 
    resolved boolean default false, 
    calculated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 9. جدول سجلات حركة المخزن
create table inventory_logs (
    id uuid primary key default gen_random_uuid(),
    org_id uuid not null references organizations(id) on delete cascade,
    product_id uuid references products(id) on delete cascade not null,
    action_type text not null check (action_type in ('stocktake', 'adjustment', 'transfer', 'sale', 'purchase')), 
    quantity_changed int not null,
    logged_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 10. جدول إعدادات الروبوت والأتمتة
create table automation_settings (
    id uuid primary key default gen_random_uuid(),
    org_id uuid not null unique references organizations(id) on delete cascade,
    owner_id uuid references employees(id) on delete cascade not null, 
    report_email text not null, 
    is_auto_report_enabled boolean default true, 
    report_frequency text default 'daily' 
);

-- 11. جدول الرقابة الصارمة Audit Log
create table audit_log (
    id uuid primary key default gen_random_uuid(),
    org_id uuid not null references organizations(id) on delete cascade,
    user_id uuid references employees(id) on delete set null, 
    product_id uuid references products(id) on delete cascade, 
    action_type text not null, 
    old_value text,
    new_value text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- الفهارس لتسريع استعلامات الـ 20 ألف صنف
create index idx_products_org_barcode on products(org_id, barcode);
create index idx_products_warehouse on products(warehouse_id);

-- =====================================================================
-- 🚀 محرك التريجر المطور والمعدل بالكامل
-- =====================================================================

create or replace function calculate_stocktake_discrepancy()
returns trigger as $$
declare
    current_system_qty int;
    discrepancy_total int;
    qty_diff int;
begin
    -- جلب الكمية النظامية للمنتج الحالي
    select system_quantity into current_system_qty from products where id = new.product_id;

    -- حساب الفرق الكلي الثابت للفروقات
    discrepancy_total := new.scanned_quantity - current_system_qty;

    -- حساب الفرق اللحظي لسجل الحركات المخزنية فقط لمنع التكرار والتكرار المضاعف
    if TG_OP = 'INSERT' then
        qty_diff := new.scanned_quantity - current_system_qty;
    elsif TG_OP = 'UPDATE' then
        qty_diff := new.scanned_quantity - old.scanned_quantity;
    end if;

    -- إدخل أو تحديث الفروقات الإجمالية بالقيم الصحيحة (UPSERT)
    insert into discrepancies (org_id, stocktake_id, product_id, system_qty, scanned_qty, discrepancy_qty)
    values (new.org_id, new.id, new.product_id, current_system_qty, new.scanned_quantity, discrepancy_total)
    on conflict (stocktake_id) do update set
        scanned_qty = excluded.scanned_qty,
        discrepancy_qty = excluded.discrepancy_qty,
        calculated_at = timezone('utc'::text, now());

    -- توثيق الحركة المخزنية بفرق التعديل الصافي فقط (لمنع تضخم العمليات)
    insert into inventory_logs (org_id, product_id, action_type, quantity_changed)
    values (new.org_id, new.product_id, 'stocktake', qty_diff);

    return new;
end;
$$ language plpgsql;

-- تشغيل التريجر في حالتي الإدخال والتعديل لضمان المزامنة المطلقة
create or replace trigger trg_after_stocktake_sync
after insert or update on stocktakes
for each row
execute function calculate_stocktake_discrepancy();

-- =====================================================================
-- 🔒 تفعيل وتأمين الـ Row Level Security لعزل الشركات
-- =====================================================================

alter table organizations enable row level security;
alter table warehouses enable row level security;
alter table employees enable row level security;
alter table products enable row level security;
alter table stocktakes enable row level security;
alter table discrepancies enable row level security;
alter table inventory_logs enable row level security;
alter table automation_settings enable row level security;
alter table audit_log enable row level security;

create policy org_isolation_policy on organizations for all using (id = (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid);
create policy warehouse_isolation_policy on warehouses for all using (org_id = (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid);
create policy employee_isolation_policy on employees for all using (org_id = (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid);
create policy product_isolation_policy on products for all using (org_id = (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid);
create policy stocktake_isolation_policy on stocktakes for all using (org_id = (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid);
create policy discrepancy_isolation_policy on discrepancies for all using (org_id = (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid);
create policy inventory_logs_isolation_policy on inventory_logs for all using (org_id = (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid);
create policy automation_settings_isolation_policy on automation_settings for all using (org_id = (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid);
create policy audit_log_isolation_policy on audit_log for all using (org_id = (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid);
create policy plans_read_policy on plans for select using (true);
