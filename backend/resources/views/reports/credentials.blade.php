<x-report-sheet
    title="بطاقات الدخول"
    :institute="$institute"
    heading="بطاقات الدخول"
    subheading="تُقصّ البطاقات وتُسلَّم لأصحابها"
    :meta="[
        'المعهد' => $institute?->name,
        'التاريخ' => now()->format('Y-m-d'),
        'عدد البطاقات' => (string) $rows->count(),
    ]"
>
    @if ($rows->isEmpty())
        <p class="mt-6 rounded-lg border border-sand-300 bg-sand-50 p-4 text-center text-sm text-ink-500">
            لا توجد بيانات دخول مطابقة.
        </p>
    @else
        <section class="mt-6 grid grid-cols-2 gap-3">
            @foreach ($rows as $row)
                <article class="avoid-break rounded-lg border border-dashed border-sand-400 p-3">
                    <header class="flex items-baseline justify-between gap-2">
                        <h2 class="font-display text-sm font-semibold">{{ $row['name'] }}</h2>
                        <span class="text-xs text-ink-500">{{ $row['role'] }}</span>
                    </header>

                    <dl class="mt-2 space-y-1 text-sm">
                        <div class="flex justify-between gap-2">
                            <dt class="text-ink-500">اسم المستخدم</dt>
                            <dd class="latin-numerals font-semibold">{{ $row['username'] }}</dd>
                        </div>
                        <div class="flex justify-between gap-2">
                            <dt class="text-ink-500">كلمة المرور</dt>
                            <dd class="latin-numerals font-semibold">{{ $row['password'] ?? 'مُغيَّرة' }}</dd>
                        </div>
                        @if ($row['detail'])
                            <div class="flex justify-between gap-2">
                                <dt class="text-ink-500">رقم التسجيل</dt>
                                <dd class="latin-numerals">{{ $row['detail'] }}</dd>
                            </div>
                        @endif
                    </dl>
                </article>
            @endforeach
        </section>
    @endif
</x-report-sheet>
