@props(['logoUrl' => null])

{{--
    حقول نموذج المعهد — تشترك فيها شاشتان بنطاقين مختلفين: «بيانات المعهد» التي
    يحرّر بها مديرُ المعهد معهدَه، و«المعاهد» التي ينشئ بها المشرف الأعلى معهداً
    ويحرّر أيّها شاء. النموذج واحد، فلا يصحّ أن يتفرّع الحقلُ في إحداهما دون الأخرى.

    تعتمد على خصائص المكوّن المستدعي بأسمائها: name · short_name · phone · email ·
    address · is_active · logo · points · theme · attendance.
--}}
<div class="space-y-6">
    <flux:input wire:model="name" label="اسم المعهد" required autofocus />
    <flux:input wire:model="short_name" label="الاسم المختصر" description="يُستخدم في ترويسة التقارير الضيقة" />

    <div class="grid gap-6 sm:grid-cols-2">
        <flux:input wire:model="phone" label="الهاتف" />
        <flux:input wire:model="email" type="email" label="البريد الإلكتروني" />
    </div>

    <flux:input wire:model="address" label="العنوان" />

    <x-image-upload
        model="logo"
        label="الشعار"
        :existing-url="$logoUrl"
        hint="PNG أو JPG، حتى 2 ميغابايت"
    />

    <flux:switch wire:model="is_active" label="المعهد فعّال" />

    <flux:separator text="الهوية البصرية" />

    {{--
        ثلاثة ألوان تكفي: منها تُشتقّ سلالمُ التدرّج كلّها (App\Support\InstituteTheme)،
        وتُعتمد في اللوحة وصفحات الطباعة وتطبيقات الموبايل والديسكتوب معاً — فيكفي أن
        تُدخَل مرّةً هنا لتتوحّد واجهات المعهد كلُّها.
    --}}
    <flux:text size="sm" class="text-ink-500 dark:text-zinc-400">
        تُؤخذ عادةً من شعار المعهد: لونه الغالب أساسياً، ولونه المساعد ثانوياً، وأفتحُ ألوانه أرضيةً.
        وتُطبَّق فوراً على اللوحة والتقارير وتطبيقات الأستاذ والأهل والطالب.
    </flux:text>

    <div class="grid gap-6 sm:grid-cols-3">
        @foreach ([
            'primary' => ['اللون الأساسي', 'الترويسات والأزرار والروابط'],
            'secondary' => ['اللون الثانوي', 'الإبرازات والشارات'],
            'surface' => ['لون الأرضية', 'خلفية الصفحات والبطاقات'],
        ] as $key => [$label, $hint])
            <div wire:key="theme-{{ $key }}" class="space-y-2">
                <flux:input
                    wire:model.live="theme.{{ $key }}"
                    :label="$label"
                    :description="$hint"
                    class="latin-numerals"
                    dir="ltr"
                    maxlength="7"
                    :data-test="'theme-'.$key"
                />
                <label class="flex items-center gap-2">
                    {{-- منتقي اللون الأصلي: الإدخال اليدوي للهكس يبقى، وهذا يخدم من لا يحفظه --}}
                    <input type="color" wire:model.live="theme.{{ $key }}" class="h-8 w-14 cursor-pointer rounded border border-sand-300 bg-transparent dark:border-zinc-600">
                    <span class="text-xs text-ink-500 dark:text-zinc-400">اختيار من اللوحة</span>
                </label>
            </div>
        @endforeach
    </div>

    <flux:separator text="التفقّد" />

    <flux:input
        wire:model="attendance.late_grace_minutes"
        type="number" min="0" max="240"
        label="فترة السماح · دقائق"
        description="دقائق التأخير تُحسب تلقائياً من بداية الدوام مطروحاً منها هذه الفترة. صفرٌ يعني احتساب التأخير من بداية الدوام تماماً."
        class="latin-numerals max-w-56"
        data-test="late-grace"
    />

    <flux:separator text="النقاط" />

    <flux:text size="sm" class="text-ink-500 dark:text-zinc-400">
        نقاط القرآن تُحتسب للأسطر الجديدة دون المكرّر، ثم يضربها معامل التقدير.
    </flux:text>

    <div class="grid gap-6 sm:grid-cols-3">
        <flux:input
            wire:model="points.quran_per_15_lines"
            type="number" step="0.5" min="0"
            label="القرآن · لكل ١٥ سطراً"
            class="latin-numerals"
            data-test="points-quran"
        />
        <flux:input
            wire:model="points.hadith_per_item"
            type="number" step="0.5" min="0"
            label="الحديث · لكل حديث"
            class="latin-numerals"
            data-test="points-hadith"
        />
        <flux:input
            wire:model="points.mutun_per_bayt"
            type="number" step="0.5" min="0"
            label="المتون · لكل بيت"
            class="latin-numerals"
            data-test="points-mutun"
        />
    </div>

    <div>
        <flux:heading size="sm">نقاط الحضور</flux:heading>
        <div class="mt-3 grid gap-6 sm:grid-cols-4">
            @foreach (\App\Enums\AttendanceStatus::cases() as $status)
                <flux:input
                    wire:key="points-attendance-{{ $status->value }}"
                    wire:model="points.attendance.{{ $status->value }}"
                    type="number" step="0.5"
                    :label="$status->label()"
                    class="latin-numerals"
                    :data-test="'points-attendance-'.$status->value"
                />
            @endforeach
        </div>
    </div>

    <div>
        <flux:heading size="sm">معامل التقدير</flux:heading>
        <flux:text size="sm" class="mt-1 text-ink-500 dark:text-zinc-400">نسبة مئوية تُضرب في نقاط التسميع.</flux:text>
        <div class="mt-3 grid gap-6 sm:grid-cols-3">
            @foreach (\App\Enums\RecitationGrade::cases() as $grade)
                <flux:input
                    wire:key="points-grade-{{ $grade->value }}"
                    wire:model="points.grade_multiplier.{{ $grade->value }}"
                    type="number" step="5" min="0" max="200"
                    :label="$grade->label().' %'"
                    class="latin-numerals"
                    :data-test="'points-grade-'.$grade->value"
                />
            @endforeach
        </div>
    </div>
</div>
