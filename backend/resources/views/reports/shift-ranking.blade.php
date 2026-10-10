<x-report-sheet
    :title="'ترتيب حلقات '.$shift->name.' — '.$date"
    :institute="$shift->course->institute"
    :heading="$mode === 'cumulative' ? 'الترتيب التراكمي للحلقات' : 'الترتيب اليومي للحلقات'"
    :subheading="$shift->name.' · '.$shift->course->name"
    :meta="[
        'التاريخ' => $date,
        'الهجري' => App\Support\HijriDate::long(Illuminate\Support\Carbon::parse($date)) ?? '—',
        'أيام الدوام' => implode(' · ', $shift->weekdayLabels()),
        'عدد الحلقات' => $rows->count(),
    ]"
>
    @if ($rows->isEmpty())
        <p class="rounded-lg border border-line bg-surface p-4 text-center text-sm text-muted">
            لا توجد حلقات في هذا الدوام.
        </p>
    @else
        <table class="w-full border-collapse text-sm">
            <thead>
                <tr class="bg-sunken">
                    <th class="border border-line p-2 text-start">الترتيب</th>
                    <th class="border border-line p-2 text-start">الحلقة</th>
                    <th class="border border-line p-2 text-start">الأستاذ</th>
                    <th class="border border-line p-2 text-start">حاضر</th>
                    <th class="border border-line p-2 text-start">غائب</th>
                    <th class="border border-line p-2 text-start">متأخّر</th>
                    <th class="border border-line p-2 text-start">غائب بعذر</th>
                    @if ($mode === 'cumulative')
                        <th class="border border-line p-2 text-start">الجلسات</th>
                    @endif
                    <th class="border border-line p-2 text-start">النسبة</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($rows as $row)
                    @php($rank = $mode === 'cumulative' ? $row->stat?->overall_rank_in_shift : $row->stat?->daily_rank_in_shift)
                    <tr>
                        <td class="latin-numerals border border-line p-2 font-semibold {{ $rank === 1 ? 'text-bronze-ink' : '' }}">
                            {{ $rank ?? '—' }}
                        </td>
                        <td class="border border-line p-2">{{ $row->circle->name }}</td>
                        <td class="border border-line p-2">{{ $row->teachers->pluck('display_name')->join('، ') ?: '—' }}</td>
                        <td class="latin-numerals border border-line p-2">{{ $row->stat?->present ?? '—' }}</td>
                        <td class="latin-numerals border border-line p-2">{{ $row->stat?->absent ?? '—' }}</td>
                        <td class="latin-numerals border border-line p-2">{{ $row->stat?->late ?? '—' }}</td>
                        <td class="latin-numerals border border-line p-2">{{ $row->stat?->excused ?? '—' }}</td>
                        @if ($mode === 'cumulative')
                            <td class="latin-numerals border border-line p-2">{{ $row->stat?->sessions_count ?? '—' }}</td>
                        @endif
                        <td class="latin-numerals border border-line p-2 font-medium">
                            {{ $row->stat ? rtrim(rtrim(number_format((float) $row->stat->attendance_rate, 1, '.', ''), '0'), '.').'%' : '—' }}
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>

        <p class="mt-4 text-xs text-muted">
            النسبة = (الحاضرون + المتأخّرون) ÷ (المجموع − الغائبون بعذر). الإذن المسبق لا يُحسب غياباً على الحلقة.
        </p>
    @endif
</x-report-sheet>
