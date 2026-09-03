<?php

namespace App\Http\Middleware;

use App\Support\PanelScope;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * يحسم معهد المستخدم في اللوحة ويضبط مفتاح الفريق في Spatie قبل أي فحص صلاحية.
 *
 * نظير SetApiInstituteScope للوحة. بلا هذا يفشل كل middleware من نوع permission:
 * على اللوحة: الأدوار مسنَدة داخل معهد، وحسمُ المعهد كان يقع داخل مكوّن Livewire —
 * أي بعد الـ middleware بمراحل، فيجد الفحصُ مفتاحَ الفريق غير مضبوط ويرفض الجميع.
 *
 * المستخدم بلا معهد لا يُرفض هنا (خلافاً للـ API): لوحة المعلومات وصفحات الحساب
 * الشخصي تعمل بلا معهد، والرفض موضعه فحصُ الصلاحية على الطريق نفسه.
 */
class SetPanelInstituteScope
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->user() !== null) {
            PanelScope::resolve($request->user());
        }

        return $next($request);
    }
}
