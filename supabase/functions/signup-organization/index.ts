// Supabase Edge Function: signup-organization
//
// نقطة الدخول العامة لتسجيل منظمة جديدة بالكامل بضغطة واحدة: منظمة +
// فرع افتراضي + مستودع افتراضي + حساب المدير الأول (admin +
// is_super_admin). لا تحتاج توكن مستخدم موجود مسبقاً (بعكس
// create-employee) لأنها نقطة الدخول لعملاء جدد بالكامل.
//
// تشتغل بمعاملة واحدة منطقياً: لو فشلت أي خطوة بعد إنشاء حساب
// المصادقة، يتم حذف كل شيء تم إنشاؤه (تنظيف) بدل ترك بيانات يتيمة.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const jsonResponse = (data: unknown, status: number) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  let createdOrgId: string | null = null;
  let createdUserId: string | null = null;

  try {
    const body = await req.json();
    const {
      orgName,
      adminName,
      adminEmail,
      adminPassword,
      adminPhone,
      branchName,
      warehouseName,
    } = body;

    if (!orgName || !adminName || !adminEmail || !adminPassword) {
      return jsonResponse(
        { error: 'بيانات ناقصة (اسم المنظمة/اسمك/البريد/كلمة السر مطلوبين)' },
        400,
      );
    }

    if (String(adminPassword).length < 6) {
      return jsonResponse({ error: 'كلمة السر لازم تكون 6 أحرف على الأقل' }, 400);
    }

    // 1) إنشاء المنظمة
    const { data: org, error: orgError } = await supabaseAdmin
      .from('organizations')
      .insert({ name: orgName })
      .select('id')
      .single();

    if (orgError || !org) {
      return jsonResponse(
        { error: orgError?.message ?? 'فشل إنشاء المنظمة' },
        400,
      );
    }
    createdOrgId = org.id;

    // 1.5) اشتراك افتراضي فعّال للمنظمة الجديدة - ضروري لأن نظام
    // الاشتراكات الجديد (أُضيف لاحقاً على قاعدة البيانات مباشرة) قد
    // يمنع إضافة أي موظف لمنظمة بدون اشتراك فعّال. نعطيها تجريبياً
    // 30 يوم بدون خطة محددة (plan_id = null => بدون حد أقصى للموظفين)
    const { error: subError } = await supabaseAdmin.from('subscriptions').insert({
      org_id: createdOrgId,
      is_active: true,
      expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    });

    if (subError) {
      await supabaseAdmin.from('organizations').delete().eq('id', createdOrgId);
      return jsonResponse(
        { error: subError.message ?? 'فشل إنشاء اشتراك تجريبي للمنظمة' },
        400,
      );
    }

    // 2) الفرع الافتراضي
    const { data: branch, error: branchError } = await supabaseAdmin
      .from('branches')
      .insert({
        name: branchName || 'الفرع الرئيسي',
        org_id: createdOrgId,
      })
      .select('id')
      .single();

    if (branchError || !branch) {
      await supabaseAdmin.from('subscriptions').delete().eq('org_id', createdOrgId);
      await supabaseAdmin.from('organizations').delete().eq('id', createdOrgId);
      return jsonResponse(
        { error: branchError?.message ?? 'فشل إنشاء الفرع الافتراضي' },
        400,
      );
    }

    // 3) المستودع الافتراضي
    const { data: warehouse, error: warehouseError } = await supabaseAdmin
      .from('warehouses')
      .insert({
        name: warehouseName || 'المستودع الرئيسي',
        org_id: createdOrgId,
        branch_id: branch.id,
      })
      .select('id')
      .single();

    if (warehouseError || !warehouse) {
      await supabaseAdmin.from('branches').delete().eq('id', branch.id);
      await supabaseAdmin.from('subscriptions').delete().eq('org_id', createdOrgId);
      await supabaseAdmin.from('organizations').delete().eq('id', createdOrgId);
      return jsonResponse(
        { error: warehouseError?.message ?? 'فشل إنشاء المستودع الافتراضي' },
        400,
      );
    }

    // 4) حساب المصادقة (Auth) لصاحب المنظمة
    const { data: authData, error: authError } =
      await supabaseAdmin.auth.admin.createUser({
        email: adminEmail,
        password: adminPassword,
        email_confirm: true,
      });

    if (authError || !authData.user) {
      await supabaseAdmin.from('warehouses').delete().eq('id', warehouse.id);
      await supabaseAdmin.from('branches').delete().eq('id', branch.id);
      await supabaseAdmin.from('subscriptions').delete().eq('org_id', createdOrgId);
      await supabaseAdmin.from('organizations').delete().eq('id', createdOrgId);
      return jsonResponse(
        { error: authError?.message ?? 'فشل إنشاء حساب المصادقة (البريد مستخدم مسبقاً؟)' },
        400,
      );
    }
    createdUserId = authData.user.id;

    // 5) صف الموظف - مدير عام كامل الصلاحيات على منظمته
    const { error: employeeError } = await supabaseAdmin.from('employees').insert({
      id: createdUserId,
      auth_id: createdUserId,
      org_id: createdOrgId,
      name: adminName,
      email: adminEmail,
      role: 'admin',
      is_super_admin: true,
      warehouse_id: warehouse.id,
      ...(adminPhone ? { phone: adminPhone } : {}),
    });

    if (employeeError) {
      // تنظيف كامل - ما نترك حساب مصادقة أو منظمة يتيمة بدون موظف
      await supabaseAdmin.auth.admin.deleteUser(createdUserId);
      await supabaseAdmin.from('warehouses').delete().eq('id', warehouse.id);
      await supabaseAdmin.from('branches').delete().eq('id', branch.id);
      await supabaseAdmin.from('subscriptions').delete().eq('org_id', createdOrgId);
      await supabaseAdmin.from('organizations').delete().eq('id', createdOrgId);
      return jsonResponse({ error: employeeError.message }, 400);
    }

    return jsonResponse({ success: true, orgId: createdOrgId, userId: createdUserId }, 200);
  } catch (e) {
    // تنظيف احتياطي لو صار خطأ غير متوقع بعد إنشاء بعض الأجزاء
    if (createdUserId) {
      await supabaseAdmin.auth.admin.deleteUser(createdUserId).catch(() => {});
    }
    if (createdOrgId) {
      await supabaseAdmin.from('subscriptions').delete().eq('org_id', createdOrgId).catch(() => {});
      await supabaseAdmin.from('organizations').delete().eq('id', createdOrgId).catch(() => {});
    }
    return jsonResponse({ error: String(e) }, 500);
  }
});
