{{-- حول المطوِّر: الشركةُ المالكة وخدماتُها وطرقُ التواصل معها — من config/developer.php. --}}
<x-layouts::site title="المطوِّر" description="Time of Code — شركةٌ سوريةٌ في دمشق تطوّر المواقع وتطبيقات الهاتف وتبني الهويّات البصرية، ومطوِّرةُ نظام نزلاً ومالكتُه.">
    <section class="py-12 sm:py-16" aria-labelledby="developer-title">
        <div class="nz-container grid items-center gap-8 lg:grid-cols-[.8fr_1.2fr] lg:gap-12">
            <div class="grid place-items-center">
                <img src="{{ config('developer.logo') }}" alt="{{ config('developer.name') }}" class="w-[min(320px,80%)]" width="435" height="338">
            </div>
            <div>
                <div class="text-[13px] font-semibold text-bronze-ink">حول المطوِّر</div>
                <h1 id="developer-title" class="font-display mt-2 text-[34px] leading-[1.3] font-bold sm:text-[40px]">{{ config('developer.arabic_name') }}</h1>
                <p class="mb-4 text-muted" dir="ltr" style="text-align: right">{{ config('developer.name') }}</p>
                <p class="text-[17px] leading-[1.9]">{{ config('developer.about') }}</p>
                <p class="mt-4 font-semibold">نزلاً من تطوير <span dir="ltr">{{ config('developer.name') }}</span> وملكيّتها.</p>
            </div>
        </div>
    </section>

    <section class="nz-pattern-soft py-12 sm:py-16" aria-labelledby="services-title">
        <div class="nz-container">
            <h2 id="services-title" class="font-display mb-6 text-[26px] leading-[1.35] font-bold sm:text-[30px]">خدماتنا</h2>
            <ul class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                @foreach (config('developer.services') as $service)
                    <li class="flex items-center gap-3 rounded-xl border border-line bg-raised p-5">
                        <flux:icon icon="sparkles" class="size-6 shrink-0 text-primary" />
                        <span class="font-medium">{{ $service }}</span>
                    </li>
                @endforeach
            </ul>
        </div>
    </section>

    <section class="py-12 sm:py-16" aria-labelledby="contact-title">
        <div class="nz-container">
            <h2 id="contact-title" class="font-display mb-6 text-[26px] leading-[1.35] font-bold sm:text-[30px]">تواصل معنا</h2>
            <ul class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3" data-test="developer-contacts">
                @foreach (config('developer.contacts') as $contact)
                    <li>
                        <a href="{{ $contact['url'] }}" @if (str_starts_with($contact['url'], 'https://')) target="_blank" rel="noopener" @endif
                           class="flex items-center gap-3 rounded-xl border border-line bg-raised p-5 hover:border-bronze-ink">
                            <flux:icon :icon="$contact['icon']" class="size-6 shrink-0 text-primary" />
                            <span class="min-w-0">
                                <span class="block font-semibold">{{ $contact['label'] }}</span>
                                <span class="block truncate text-muted" dir="ltr" style="text-align: right">{{ $contact['value'] }}</span>
                            </span>
                        </a>
                    </li>
                @endforeach
                <li class="flex items-center gap-3 rounded-xl border border-line bg-raised p-5">
                    <flux:icon icon="map-pin" class="size-6 shrink-0 text-primary" />
                    <span>
                        <span class="block font-semibold">العنوان</span>
                        <span class="block text-muted">{{ config('developer.address') }}</span>
                    </span>
                </li>
            </ul>
        </div>
    </section>
</x-layouts::site>
