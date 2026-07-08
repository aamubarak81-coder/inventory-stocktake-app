// Supabase Edge Function: create-employee
//
// الهدف: إنشاء حساب مصادقة (Supabase Auth) وصف موظف جديد بأمان، بدون
// ما يحتاج مفتاح service_role يوصل لتطبيق العميل إطلاقاً. هذا الكود
// وحده يشتغل على سيرفر Supabase (Deno)، ومفتاح service_role محفوظ
// كـ secret على السيرفر بس - المتصفح ما بيشوفه أبداً.
//
// التحقق من الصلاحيات: قبل ما ننشئ أي حساب، نتأكد إنه المستخدم اللي
// طالب العملية (عبر التوكن المرفق بالطلب) هو فعلاً admin أو
// super_admin بنفس منظمته - وإلا نرفض الطلب.

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

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'مطلوب تسجيل دخول' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // عميل بصلاحيات المستخدم الحالي فقط (لتحديد هويته والتحقق من صلاحياته)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
    } = await supabaseClient.auth.getUser();

    if (!user) {
      return new Response(
        JSON.stringify({ error: 'جلسة غير صالحة' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // نتأكد إن الطالب فعلاً admin أو super_admin بمنظمته
    const { data: callerEmployee, error: callerError } = await supabaseClient
      .from('employees')
      .select('org_id, role, is_super_admin')
      .eq('id', user.id)
      .single();

    if (callerError || !callerEmployee) {
      return new Response(
        JSON.stringify({ error: 'لا يمكن التحقق من صلاحياتك' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (callerEmployee.role !== 'admin' && !callerEmployee.is_super_admin) {
      return new Response(
        JSON.stringify({ error: 'ليس لديك صلاحية إضافة موظفين' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const body = await req.json();
    const { email, password, name, role, phone, warehouseId } = body;

    if (!email || !password || !name || !role) {
      return new Response(
        JSON.stringify({ error: 'بيانات ناقصة (البريد/كلمة السر/الاسم/الدور مطلوبين)' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // عميل بصلاحيات service_role - يشتغل هون بس (السيرفر)، ما بيوصل
    // للمتصفح إطلاقاً
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: authData, error: authError } =
      await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      });

    if (authError || !authData.user) {
      return new Response(
        JSON.stringify({ error: authError?.message ?? 'فشل إنشاء حساب المصادقة' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const { error: insertError } = await supabaseAdmin.from('employees').insert({
      id: authData.user.id,
      org_id: callerEmployee.org_id,
      name,
      email,
      role,
      is_super_admin: role === 'super_admin',
      ...(phone ? { phone } : {}),
      ...(warehouseId ? { warehouse_id: warehouseId } : {}),
    });

    if (insertError) {
      // نظّف حساب Auth اليتيم لو فشل إدراج صف الموظف، حتى ما يضل
      // حساب معلّق بدون صف موظف مرتبط فيه
      await supabaseAdmin.auth.admin.deleteUser(authData.user.id);
      return new Response(
        JSON.stringify({ error: insertError.message }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    return new Response(
      JSON.stringify({ success: true, userId: authData.user.id }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
