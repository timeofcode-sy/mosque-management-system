<?php

namespace App\Http\Controllers;

use App\Queries\CredentialQuery;
use App\Support\PanelScope;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * تسليم بيانات الدخول خارج الشاشة: ملفّ CSV يُفتح في إكسل، وصفحةُ بطاقات تُطبع
 * وتُقصّ وتُوزّع باليد.
 *
 * الطريقان يقرآن المرشّحات نفسها من الرابط لتُصدَّر القائمة المعروضة بعينها، ويمرّان
 * بـ CredentialQuery نفسه فتنطبق عليهما قيود الرتبة والمعهد بلا تكرار.
 */
class CredentialExportController extends Controller
{
    /**
     * البايتات الثلاث الأولى (BOM) ليست زينة: بدونها يقرأ إكسل العربيةَ طلاسمَ.
     */
    public function csv(Request $request, CredentialQuery $credentials): StreamedResponse
    {
        $rows = $this->rows($request, $credentials);
        $name = 'credentials-'.now()->format('Y-m-d').'.csv';

        return response()->streamDownload(function () use ($rows): void {
            $handle = fopen('php://output', 'wb');

            fwrite($handle, "\xEF\xBB\xBF");
            fputcsv($handle, ['الاسم', 'الدور', 'اسم المستخدم', 'كلمة المرور', 'الحالة', 'رقم التسجيل']);

            foreach ($rows as $row) {
                fputcsv($handle, [
                    $row['name'],
                    $row['role'],
                    $row['username'],
                    $row['password'] ?? 'مُغيَّرة',
                    $row['is_active'] ? 'نشط' : 'مقفل',
                    $row['detail'],
                ]);
            }

            fclose($handle);
        }, $name, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    public function print(Request $request, CredentialQuery $credentials): View
    {
        return view('reports.credentials', [
            'institute' => PanelScope::resolve(),
            'rows' => $this->rows($request, $credentials),
        ]);
    }

    /**
     * @return Collection<int, array<string, mixed>>
     */
    private function rows(Request $request, CredentialQuery $credentials): Collection
    {
        $institute = PanelScope::resolve();

        abort_if($institute === null, 404);

        return $credentials->rows(
            $institute,
            $request->user(),
            $request->string('role')->toString(),
            $request->string('q')->toString(),
            $request->integer('circle') ?: null,
        );
    }
}
