<x-report-sheet
    :title="'تقرير الطالب — '.$student->full_name"
    :institute="$student->institute"
    heading="تقرير الطالب"
    :subheading="$student->full_name"
    :meta="[
        'رقم المعرف' => $student->registration_no,
        'تاريخ التسجيل' => $student->registration_date?->toDateString(),
        'الحالة' => $student->status->label(),
        'الجوال' => $student->phone,
    ]"
>
    <section class="avoid-break grid grid-cols-5 gap-3 text-center">
        @foreach ([
            ['حاضر', $summary['present'], 'text-present'],
            ['غائب', $summary['absent'], 'text-absent'],
            ['متأخّر', $summary['late'], 'text-late'],
            ['مأذون', $summary['excused'], 'text-excused'],
            ['نسبة الحضور', $summary['rate'] !== null ? $summary['rate'].'%' : '—', 'text-brand-600'],
        ] as [$label, $value, $tone])
            <div class="rounded-lg border border-sand-300 p-3">
                <p class="text-xs text-ink-500">{{ $label }}</p>
                <p class="latin-numerals mt-1 font-display text-2xl font-semibold {{ $tone }}">{{ $value }}</p>
            </div>
        @endforeach
    </section>

    <section class="avoid-break mt-6">
        <h2 class="font-display text-lg font-semibold">تقدّم الحفظ في المصحف</h2>

        <div class="mt-2 flex flex-wrap items-center gap-4 text-sm">
            <span class="latin-numerals">
                <strong>{{ $map['memorized_ayahs'] }}</strong> آية من {{ App\Support\Quran::TOTAL_AYAHS }}
            </span>
            <span class="latin-numerals"><strong>{{ $map['completed_surahs'] }}</strong> سورة مكتملة</span>
            <span class="latin-numerals"><strong>{{ round($map['overall_ratio'] * 100, 1) }}%</strong> من المصحف</span>
        </div>

        <x-surah-map :surahs="$map['surahs']" class="mt-3" />
    </section>

    <section class="mt-6">
        <h2 class="font-display text-lg font-semibold">مسار الحلقات</h2>

        @if ($enrollments->isEmpty())
            <p class="mt-2 text-sm text-ink-500">لم يُسجَّل الطالب في أي حلقة بعد.</p>
        @else
            <table class="mt-2 w-full border-collapse text-sm">
                <thead>
                    <tr class="bg-sand-100">
                        <th class="border border-sand-300 p-2 text-start">الدورة</th>
                        <th class="border border-sand-300 p-2 text-start">الحلقة</th>
                        <th class="border border-sand-300 p-2 text-start">الدوام</th>
                        <th class="border border-sand-300 p-2 text-start">من</th>
                        <th class="border border-sand-300 p-2 text-start">إلى</th>
                        <th class="border border-sand-300 p-2 text-start">الحالة</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($enrollments as $enrollment)
                        <tr>
                            <td class="border border-sand-300 p-2">{{ $enrollment->courseCircle->course->name }}</td>
                            <td class="border border-sand-300 p-2">{{ $enrollment->courseCircle->circle->name }}</td>
                            <td class="border border-sand-300 p-2">{{ $enrollment->courseCircle->shift->name }}</td>
                            <td class="latin-numerals border border-sand-300 p-2">{{ $enrollment->enrolled_on?->toDateString() ?? '—' }}</td>
                            <td class="latin-numerals border border-sand-300 p-2">{{ $enrollment->left_on?->toDateString() ?? '—' }}</td>
                            <td class="border border-sand-300 p-2">{{ $enrollment->status->label() }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        @endif
    </section>

    @if ($progressByCurriculum->isNotEmpty())
        <section class="avoid-break mt-6">
            <h2 class="font-display text-lg font-semibold">المحفوظات</h2>

            <div class="mt-2 space-y-3 text-sm">
                @foreach ($progressByCurriculum as $curriculumName => $entries)
                    <div>
                        <h3 class="font-medium">{{ $curriculumName }}</h3>
                        <p class="mt-1 text-ink-500">{{ $entries->map(fn ($p) => $p->curriculumItem->name)->join('، ') }}</p>
                    </div>
                @endforeach
            </div>
        </section>
    @endif

    <section class="avoid-break mt-10 grid grid-cols-2 gap-12 text-sm">
        <div>
            <p class="text-ink-500">توقيع المشرف</p>
            <div class="mt-8 border-t border-ink-900/40"></div>
        </div>
        <div>
            <p class="text-ink-500">توقيع ولي الأمر</p>
            <div class="mt-8 border-t border-ink-900/40"></div>
        </div>
    </section>
</x-report-sheet>
