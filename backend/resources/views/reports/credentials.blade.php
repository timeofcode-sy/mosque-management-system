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
        <p class="mt-6 rounded-lg border border-line bg-surface p-4 text-center text-sm text-muted">
            لا توجد بيانات دخول مطابقة.
        </p>
    @else
        <section class="mt-6 grid grid-cols-2 gap-3">
            @foreach ($rows as $row)
                {{-- بطاقة الدخول على نمط بطاقة الطالب في الهوية: شريطُ ليلٍ بالعلامة، ثم البيانات. --}}
                <article class="avoid-break overflow-hidden rounded-xl border border-dashed border-line">
                    <div class="flex items-center gap-2 bg-night px-3 py-2 text-star">
                        <img src="/brand/logos/nuzuln-mark-small-bronze.svg" alt="" class="size-8 shrink-0">
                        <span class="truncate text-xs">{{ $institute?->name ?? config('app.name') }}</span>
                    </div>

                    <header class="flex items-baseline justify-between gap-2 px-3 pt-3">
                        <h2 class="text-sm font-semibold">{{ $row['name'] }}</h2>
                        <span class="text-xs text-muted">{{ $row['role'] }}</span>
                    </header>

                    <dl class="space-y-1 p-3 text-sm">
                        <div class="flex justify-between gap-2">
                            <dt class="text-muted">اسم المستخدم</dt>
                            <dd class="latin-numerals font-semibold">{{ $row['username'] }}</dd>
                        </div>
                        <div class="flex justify-between gap-2">
                            <dt class="text-muted">كلمة المرور</dt>
                            <dd class="latin-numerals font-semibold">{{ $row['password'] ?? 'مُغيَّرة' }}</dd>
                        </div>
                        @if ($row['detail'])
                            <div class="flex justify-between gap-2">
                                <dt class="text-muted">رقم التسجيل</dt>
                                <dd class="latin-numerals">{{ $row['detail'] }}</dd>
                            </div>
                        @endif
                    </dl>
                </article>
            @endforeach
        </section>
    @endif
</x-report-sheet>
