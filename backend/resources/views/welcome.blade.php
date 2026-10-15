<!DOCTYPE html>
<html lang="ar" dir="rtl">
    <head>
        @include('partials.head')
        <meta name="description" content="نظام لإدارة الحلقات في المساجد والمعاهد: الحضور والتسميع والتقارير، على الجوال والحاسوب، حتى دون اتصال.">
    </head>
    <body class="bg-surface text-ink antialiased">
        <a href="#main-content" class="sr-only z-50 rounded-sm bg-primary px-4 py-2 text-on-primary focus:not-sr-only focus:fixed focus:start-4 focus:top-4">
            تخطَّ إلى المحتوى
        </a>

        {{-- الرأس: الشعار الأفقي يمينًا، ثم الأقسام، ثم «تسجيل الدخول». على الجوال تختفي الروابط ويبقى الزر. --}}
        <header class="sticky top-0 z-20 border-b border-line bg-raised">
            <div class="nz-container flex min-h-16 items-center gap-6">
                <a href="{{ route('home') }}" class="shrink-0 rounded-sm" aria-label="نزلاً · الصفحة الرئيسية">
                    <img class="nz-only-light h-11 w-auto" src="/brand/logos/nuzuln-lockup-horizontal-night.svg" alt="نزلاً · نظام إدارة الحلقات في المساجد والمعاهد">
                    <img class="nz-only-dark h-11 w-auto" src="/brand/logos/nuzuln-lockup-horizontal-bronze.svg" alt="نزلاً · نظام إدارة الحلقات في المساجد والمعاهد">
                </a>

                <nav aria-label="أقسام الموقع" class="ms-auto hidden items-center gap-6 text-sm font-medium sm:flex">
                    <a href="#features" class="rounded-sm py-2 hover:text-bronze-ink">المزايا</a>
                    <a href="#teachers" class="rounded-sm py-2 hover:text-bronze-ink">للمعلّمين</a>
                    <a href="#parents" class="rounded-sm py-2 hover:text-bronze-ink">لأولياء الأمور</a>
                    <a href="{{ route('about') }}" class="rounded-sm py-2 hover:text-bronze-ink">حول نزلاً</a>
                </nav>

                <a href="{{ auth()->check() ? route('dashboard') : route('login') }}" class="nz-btn nz-btn--primary nz-btn--sm ms-auto sm:ms-0">
                    {{ auth()->check() ? 'حسابي' : 'تسجيل الدخول' }}
                </a>
            </div>
        </header>

        <main id="main-content" tabindex="-1">
            {{-- الواجهة: أرضية night بالنقش. على الجوال تصعد العلامة فوق النص. --}}
            <section class="nz-pattern-night py-12 text-star sm:py-16 lg:py-20" aria-labelledby="hero-title">
                <div class="nz-container grid items-center gap-8 lg:grid-cols-[1.2fr_.8fr] lg:gap-12">
                    <div class="order-2 lg:order-1">
                        <span class="nz-tag" style="background: var(--night-line); color: var(--bronze)">لحلقات المساجد والمعاهد في سوريا</span>
                        <h1 id="hero-title" class="my-4 text-balance text-[38px] leading-[1.25] font-bold sm:text-5xl lg:text-[56px]">
                            كلّ ما تحتاجه حلقتك، من الحضور إلى الإجازة
                        </h1>
                        <p class="mb-8 max-w-[34em] text-[17px] leading-[1.9] text-[#D9E2DD] sm:text-[19px]">
                            يسجّل المعلّم الحضور والتسميع بنقرة لكل طالب، ويتابع المشرف الحلقات كلها من لوحة واحدة، ويطمئن وليّ الأمر على حفظ ابنه، على الجوال والحاسوب، حتى دون اتصال.
                        </p>
                        <div class="flex flex-wrap gap-3">
                            <a href="#contact" class="nz-btn" style="background: var(--bronze); color: var(--night)">سجّل مسجدك</a>
                            <a href="#features" class="nz-btn" style="border-color: #3D6658; color: var(--star)">تعرّف على النظام</a>
                        </div>
                    </div>

                    <div class="order-1 grid place-items-center lg:order-2">
                        <img src="/brand/logos/nuzuln-mark.svg" alt="" class="w-[min(180px,45%)] lg:w-[min(320px,70%)]" width="320" height="455">
                    </div>
                </div>
            </section>

            <section id="features" class="py-12 sm:py-16 lg:py-20" aria-labelledby="features-title">
                <div class="nz-container">
                    <div class="text-[13px] font-semibold text-bronze-ink">المزايا</div>
                    <h2 id="features-title" class="font-display mt-2 mb-8 text-balance text-[28px] leading-[1.35] font-bold sm:text-[34px]">صُمّم لما يجري فعلًا في الحلقة</h2>

                    <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                        <article class="rounded-xl border border-line bg-raised p-6">
                            <flux:icon icon="clipboard-document-check" class="size-7 text-primary" />
                            <h3 class="mt-3 mb-2 text-[19px] font-semibold leading-[1.6]">الحضور بنقرة</h3>
                            <p class="text-muted">حاضر، متأخر، غائب بعذر، غائب: نقرة واحدة لكل طالب، ويُحفظ على الجهاز إن انقطع الاتصال ثم يُزامَن.</p>
                        </article>
                        <article class="rounded-xl border border-line bg-raised p-6">
                            <flux:icon icon="book-open-text" class="size-7 text-primary" />
                            <h3 class="mt-3 mb-2 text-[19px] font-semibold leading-[1.6]">التسميع والمراجعة</h3>
                            <p class="text-muted">المقطع وعدد الأخطاء والتقدير، وما يُعاد يعود تلقائيًا في الجلسة التالية.</p>
                        </article>
                        <article class="rounded-xl border border-line bg-raised p-6 sm:col-span-2 lg:col-span-1">
                            <flux:icon icon="chart-bar" class="size-7 text-primary" />
                            <h3 class="mt-3 mb-2 text-[19px] font-semibold leading-[1.6]">تقارير للمشرف</h3>
                            <p class="text-muted">نسب الحضور والأجزاء المحفوظة لكل حلقة، وتنبيه بالغياب المتكرر، وتصدير للطباعة.</p>
                        </article>
                    </div>
                </div>
            </section>

            <section id="teachers" class="nz-pattern-soft py-12 sm:py-16 lg:py-20" aria-labelledby="teachers-title">
                <div class="nz-container grid items-start gap-8 lg:grid-cols-2 lg:gap-12">
                    <div>
                        <div class="text-[13px] font-semibold text-bronze-ink">للمعلّمين</div>
                        <h2 id="teachers-title" class="font-display mt-2 mb-6 text-balance text-[28px] leading-[1.35] font-bold sm:text-[34px]">تقدّم كل طالب في الأجزاء الثلاثين، بنظرة واحدة</h2>
                        <p class="text-[17px] leading-[1.9] text-muted">ثلاثون خطًا بزاوية الشعار: ما حُفظ، وما يُحفظ الآن، وما بقي.</p>
                    </div>

                    {{-- بطاقة طالب مثالية: بيانات توضيحية لا طالب حقيقي. --}}
                    <article class="nz nz-card" aria-label="مثال على بطاقة طالب">
                        <div class="nz-card__head">
                            <div class="nz-avatar" aria-hidden="true"><x-app-logo-icon :small="true" class="size-5 opacity-60" alt="" /></div>
                            <div class="nz-card__who">
                                <div class="nz-card__name">عبدالرحمن</div>
                                <div class="nz-card__meta">حلقة أبي بن كعب · حضر اليوم</div>
                            </div>
                            <span class="nz-badge nz-badge--present"><flux:icon icon="check" variant="micro" />حاضر</span>
                        </div>
                        <div class="nz-juz nz-juz--sm">
                            <div class="nz-juz__label"><b>محفوظ 12 من 30 جزءًا</b><span>يحفظ الآن: الجزء 18</span></div>
                            <div class="nz-juz__bar" role="img" aria-label="محفوظ 12 جزءًا من 30، والجزء الحالي 18">
                                @for ($juz = 1; $juz <= 30; $juz++)
                                    <span class="nz-juz__seg {{ $juz >= 19 ? 'nz-juz__seg--done' : ($juz === 18 ? 'nz-juz__seg--current' : '') }}"></span>
                                @endfor
                            </div>
                        </div>
                        <div class="nz-card__task"><span>التسميع القادم</span>سورة الملك 1–15</div>
                    </article>
                </div>
            </section>

            <section id="parents" class="py-12 sm:py-16 lg:py-20" aria-labelledby="parents-title">
                <div class="nz-container">
                    <div class="text-[13px] font-semibold text-bronze-ink">لأولياء الأمور</div>
                    <h2 id="parents-title" class="font-display mt-2 mb-8 text-balance text-[28px] leading-[1.35] font-bold sm:text-[34px]">اطمئنّوا على أبنائكم في كل جلسة</h2>
                    <ul class="grid gap-6 sm:grid-cols-3">
                        <li class="rounded-xl border border-line bg-raised p-6">
                            <h3 class="mb-2 text-[19px] font-semibold">حضر ابنكم اليوم</h3>
                            <p class="text-muted">يصلكم تنبيه بحضور ابنكم أو غيابه فور حفظ الحضور.</p>
                        </li>
                        <li class="rounded-xl border border-line bg-raised p-6">
                            <h3 class="mb-2 text-[19px] font-semibold">تقدّم الحفظ</h3>
                            <p class="text-muted">الأجزاء المحفوظة والتسميع القادم، دون سؤال المعلّم.</p>
                        </li>
                        <li class="rounded-xl border border-line bg-raised p-6">
                            <h3 class="mb-2 text-[19px] font-semibold">عذر الغياب</h3>
                            <p class="text-muted">قدّموا عذر الغياب من التطبيق ويراجعه المشرف.</p>
                        </li>
                    </ul>
                </div>
            </section>

            <section class="pb-12 sm:pb-16 lg:pb-20" aria-label="حديث">
                <div class="nz-container">
                    <figure class="nz nz-quote w-full">
                        <blockquote class="nz-quote__text">مَن غدا إلى المسجدِ أو راحَ، أعدَّ اللهُ له نُزُلَهُ من الجنّةِ كلّما غدا أو راحَ</blockquote>
                        <figcaption class="nz-quote__src">متفق عليه</figcaption>
                    </figure>
                </div>
            </section>
        </main>

        <x-site-footer />

        @fluxScripts
    </body>
</html>
