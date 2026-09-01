@php
    $v = $variables;
@endphp

<x-report-sheet
    :title="'تقرير '.$v['circle_name'].' — '.$v['date']"
    :institute="$courseCircle->course->institute"
    heading="تقرير التفقّد اليومي"
    :subheading="$v['circle_name'].' · '.$v['shift_name']"
    :meta="[
        'اليوم' => $v['weekday'],
        'التاريخ' => $v['date'],
        'الهجري' => $v['date_hijri'],
        'الدورة' => $v['course_name'],
        'الأستاذ' => $v['teacher_names'],
        'القاعة' => $v['room'],
        'الترتيب اليومي' => $v['daily_rank'],
        'الترتيب الكلي' => $v['overall_rank'],
    ]"
>
    <section class="avoid-break grid grid-cols-5 gap-3 text-center">
        @foreach ([
            ['حاضر', $v['present'], 'text-present'],
            ['غائب', $v['absent'], 'text-absent'],
            ['متأخّر', $v['late'], 'text-late'],
            ['مأذون', $v['excused'], 'text-excused'],
            ['النسبة', $v['rate'], 'text-brand-600'],
        ] as [$label, $value, $tone])
            <div class="rounded-lg border border-sand-300 p-3">
                <p class="text-xs text-ink-500">{{ $label }}</p>
                <p class="latin-numerals mt-1 font-display text-2xl font-semibold {{ $tone }}">{{ $value }}</p>
            </div>
        @endforeach
    </section>

    @if ($session === null)
        <p class="mt-6 rounded-lg border border-sand-300 bg-sand-50 p-4 text-center text-sm text-ink-500">
            لم تُفتح جلسة تفقّد لهذه الحلقة في هذا التاريخ.
        </p>
    @else
        <section class="mt-6">
            <h2 class="font-display text-lg font-semibold">كشف الحضور</h2>

            <table class="mt-2 w-full border-collapse text-sm">
                <thead>
                    <tr class="bg-sand-100 text-start">
                        <th class="border border-sand-300 p-2 text-start">#</th>
                        <th class="border border-sand-300 p-2 text-start">الطالب</th>
                        <th class="border border-sand-300 p-2 text-start">رقم المعرف</th>
                        <th class="border border-sand-300 p-2 text-start">الحالة</th>
                        <th class="border border-sand-300 p-2 text-start">التأخّر</th>
                        <th class="border border-sand-300 p-2 text-start">ملاحظة</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($session->attendances->sortBy(fn ($a) => $a->student->full_name)->values() as $i => $attendance)
                        <tr>
                            <td class="latin-numerals border border-sand-300 p-2">{{ $i + 1 }}</td>
                            <td class="border border-sand-300 p-2">{{ $attendance->student->full_name }}</td>
                            <td class="latin-numerals border border-sand-300 p-2">{{ $attendance->student->registration_no ?: '—' }}</td>
                            <td class="border border-sand-300 p-2">
                                <span class="{{ match ($attendance->status) {
                                    App\Enums\AttendanceStatus::Present => 'text-present',
                                    App\Enums\AttendanceStatus::Absent => 'text-absent',
                                    App\Enums\AttendanceStatus::Late => 'text-late',
                                    App\Enums\AttendanceStatus::Excused => 'text-excused',
                                } }} font-medium">{{ $attendance->status->label() }}</span>
                            </td>
                            <td class="latin-numerals border border-sand-300 p-2">{{ $attendance->late_minutes ? $attendance->late_minutes.' د' : '—' }}</td>
                            <td class="border border-sand-300 p-2">{{ $attendance->note ?: '—' }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </section>

        <section class="avoid-break mt-6 grid grid-cols-2 gap-4 text-sm">
            @foreach ([
                'الغائبون' => $lists['absent'],
                'المتأخّرون' => $lists['late'],
                'المأذونون' => $lists['excused'],
            ] as $label => $names)
                @if ($names !== [])
                    <div class="rounded-lg border border-sand-300 p-3">
                        <h3 class="font-medium">{{ $label }} ({{ count($names) }})</h3>
                        <p class="mt-1 text-ink-500">{{ implode('، ', $names) }}</p>
                    </div>
                @endif
            @endforeach
        </section>

        <section class="avoid-break mt-10 grid grid-cols-2 gap-12 text-sm">
            <div>
                <p class="text-ink-500">توقيع الأستاذ</p>
                <div class="mt-8 border-t border-ink-900/40"></div>
            </div>
            <div>
                <p class="text-ink-500">توقيع المشرف</p>
                <div class="mt-8 border-t border-ink-900/40"></div>
            </div>
        </section>
    @endif
</x-report-sheet>
