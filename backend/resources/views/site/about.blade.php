{{-- حول نزلاً: نبذةٌ موجزة عن النظام وتطبيقيه، وطرقُ التواصل مع الدعم الفني والتقني. --}}
<x-layouts::site title="حول نزلاً" description="نزلاً نظامٌ لإدارة حلقات تحفيظ القرآن الكريم في المساجد والمعاهد، من تطوير Time of Code. نبذةٌ عنه وطرقُ التواصل مع الدعم الفني.">
    <section class="nz-pattern-night py-12 text-star sm:py-16" aria-labelledby="about-title">
        <div class="nz-container grid items-center gap-8 lg:grid-cols-[1.2fr_.8fr]">
            <div>
                <span class="nz-tag" style="background: var(--night-line); color: var(--bronze)">حول التطبيق</span>
                <h1 id="about-title" class="my-4 text-balance text-[34px] leading-[1.3] font-bold sm:text-[44px]">نزلاً</h1>
                <p class="max-w-[38em] text-[17px] leading-[1.9] text-[#D9E2DD]">
                    نظامٌ لإدارة حلقات تحفيظ القرآن الكريم في المساجد والمعاهد: التفقّدُ والتسميعُ والنقاطُ والتقارير،
                    على الهاتف والحاسوب، حتى دون اتصال.
                </p>
            </div>
            <div class="hidden place-items-center lg:grid">
                <img src="/brand/logos/nuzuln-mark.svg" alt="" class="w-[min(220px,60%)]" width="220" height="313">
            </div>
        </div>
    </section>

    <section class="py-12 sm:py-16" aria-labelledby="apps-title">
        <div class="nz-container">
            <h2 id="apps-title" class="font-display mb-6 text-[26px] leading-[1.35] font-bold sm:text-[30px]">ثلاثُ واجهاتٍ لنظامٍ واحد</h2>
            <ul class="grid gap-6 sm:grid-cols-3">
                <li class="rounded-xl border border-line bg-raised p-6">
                    <flux:icon icon="device-phone-mobile" class="size-7 text-primary" />
                    <h3 class="mt-3 mb-2 text-[19px] font-semibold">تطبيق نزلاً للهاتف</h3>
                    <p class="text-muted">للأستاذ ووليّ الأمر والطالب: دخولٌ واحد، ولكلٍّ شاشاتُه بحسب حسابه.</p>
                </li>
                <li class="rounded-xl border border-line bg-raised p-6">
                    <flux:icon icon="computer-desktop" class="size-7 text-primary" />
                    <h3 class="mt-3 mb-2 text-[19px] font-semibold">برنامج الإدارة</h3>
                    <p class="text-muted">للمشرف ومدير المعهد على ويندوز وأندرويد، يعمل دون اتصال ويتزامن حين يعود.</p>
                </li>
                <li class="rounded-xl border border-line bg-raised p-6">
                    <flux:icon icon="globe-alt" class="size-7 text-primary" />
                    <h3 class="mt-3 mb-2 text-[19px] font-semibold">لوحة التحكم</h3>
                    <p class="text-muted">في المتصفّح على <span dir="ltr">{{ config('nuzuln.domain') }}</span>: الإدارةُ الكاملة والتقاريرُ المطبوعة.</p>
                </li>
            </ul>
        </div>
    </section>

    <section class="nz-pattern-soft py-12 sm:py-16" aria-labelledby="support-title">
        <div class="nz-container">
            <div class="text-[13px] font-semibold text-bronze-ink">تواصل معنا</div>
            <h2 id="support-title" class="font-display mt-2 mb-6 text-[26px] leading-[1.35] font-bold sm:text-[30px]">الدعم الفني والتقني</h2>

            <ul class="grid gap-4 sm:grid-cols-2" data-test="support-contacts">
                @foreach (config('developer.support') as $person)
                    @php($digits = preg_replace('/\D/', '', $person['phone']))
                    <li class="flex flex-wrap items-center gap-4 rounded-xl border border-line bg-raised p-5">
                        <div class="min-w-0 flex-1">
                            <div class="text-[17px] font-semibold">{{ $person['name'] }}</div>
                            <div class="text-muted" dir="ltr" style="text-align: right">{{ $person['phone'] }}</div>
                        </div>
                        <div class="flex gap-2">
                            <a href="tel:+{{ $digits }}" class="nz-btn nz-btn--sm" aria-label="اتصال بـ{{ $person['name'] }}">
                                <flux:icon icon="phone" variant="micro" />اتصال
                            </a>
                            <a href="https://wa.me/{{ $digits }}" target="_blank" rel="noopener" class="nz-btn nz-btn--primary nz-btn--sm" aria-label="مراسلة {{ $person['name'] }} عبر واتساب">
                                <flux:icon icon="chat-bubble-left-right" variant="micro" />واتساب
                            </a>
                        </div>
                    </li>
                @endforeach
            </ul>
        </div>
    </section>

    <section class="py-12 sm:py-16" aria-labelledby="owner-title">
        <div class="nz-container flex flex-wrap items-center justify-between gap-6 rounded-xl border border-line bg-raised p-6">
            <div class="flex items-center gap-4">
                <img src="{{ config('developer.logo') }}" alt="{{ config('developer.name') }}" class="h-16 w-auto" width="104" height="80">
                <div>
                    <h2 id="owner-title" class="text-[19px] font-semibold">من تطوير <span dir="ltr">{{ config('developer.name') }}</span> وملكيّتها</h2>
                    <p class="text-muted">{{ config('developer.tagline') }} · {{ config('developer.address') }}</p>
                </div>
            </div>
            <a href="{{ route('developer') }}" class="nz-btn">حول المطوِّر</a>
        </div>
    </section>
</x-layouts::site>
