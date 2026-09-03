<x-report-sheet
    :title="'نقاط '.$courseCircle->circle->name.' — '.$range->from.' إلى '.$range->to"
    :institute="$courseCircle->circle->institute"
    heading="تقرير نقاط الحلقة"
    :subheading="$courseCircle->circle->name.' · '.$courseCircle->shift->name.' · '.$courseCircle->course->name"
    :meta="[
        'المدى' => $range->label(),
        'من' => $range->from,
        'إلى' => $range->to,
        'عدد الطلاب' => $rows->count(),
    ]"
>
    @if ($rows->isEmpty())
        <p class="rounded-lg border border-sand-300 bg-sand-50 p-4 text-center text-sm text-ink-500">
            لا يوجد طلاب مسجَّلون في هذه الحلقة.
        </p>
    @else
        <table class="w-full border-collapse text-sm">
            <thead>
                <tr class="bg-sand-100">
                    <th class="border border-sand-300 p-2 text-start">#</th>
                    <th class="border border-sand-300 p-2 text-start">الطالب</th>
                    <th class="border border-sand-300 p-2 text-start">القرآن</th>
                    <th class="border border-sand-300 p-2 text-start">الحديث</th>
                    <th class="border border-sand-300 p-2 text-start">المتون</th>
                    <th class="border border-sand-300 p-2 text-start">الحضور</th>
                    <th class="border border-sand-300 p-2 text-start">تقديرية</th>
                    <th class="border border-sand-300 p-2 text-start">المجموع</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($rows as $row)
                    <tr>
                        <td @class([
                            'latin-numerals border border-sand-300 p-2 font-semibold',
                            'text-gold-600' => $row['rank'] <= 3,
                        ])>{{ $row['rank'] }}</td>
                        <td class="border border-sand-300 p-2">{{ $row['student']->full_name }}</td>
                        @foreach (['quran', 'hadith', 'mutun', 'attendance', 'manual'] as $source)
                            <td class="latin-numerals border border-sand-300 p-2">{{ $row[$source] }}</td>
                        @endforeach
                        <td class="latin-numerals border border-sand-300 p-2 font-semibold">{{ $row['total'] }}</td>
                    </tr>
                @endforeach
            </tbody>
            <tfoot>
                <tr class="bg-sand-100">
                    <td class="border border-sand-300 p-2" colspan="2">المجموع</td>
                    @foreach (['quran', 'hadith', 'mutun', 'attendance', 'manual', 'total'] as $source)
                        <td class="latin-numerals border border-sand-300 p-2 font-semibold">{{ $totals[$source] }}</td>
                    @endforeach
                </tr>
            </tfoot>
        </table>

        <p class="mt-4 text-xs text-ink-500">
            نقاط القرآن تُحتسب للأسطر الجديدة دون المكرّر، مضروبةً بمعامل التقدير. ونقاط الحضور
            مشتقّة من حالات التفقّد بإعدادات المعهد، والتقديرية ما منحه الأستاذ أو المشرف بيده.
        </p>
    @endif
</x-report-sheet>
