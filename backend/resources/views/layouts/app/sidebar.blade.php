<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" dir="rtl">
    <head>
        @include('partials.head')
    </head>
    <body class="min-h-screen bg-surface text-ink antialiased">
        <a href="#main-content" class="sr-only z-50 rounded-sm bg-primary px-4 py-2 text-on-primary focus:not-sr-only focus:fixed focus:start-4 focus:top-4">
            تخطَّ إلى المحتوى
        </a>

        {{--
            عناصر القائمة مغلَّفة بـ @can لا لتزيين الواجهة: بدونها يرى المستخدمُ
            روابطَ تؤدّي به إلى 403، فتصير الأدوار عقوبةً مفاجئة بدل أن تكون شكلاً
            للوحة يفهمه من نظرة.
        --}}
        <flux:sidebar sticky collapsible class="w-64 border-s border-line bg-raised transition-[width] duration-200 data-flux-sidebar-collapsed-desktop:w-16 data-flux-sidebar-collapsed-desktop:px-2 motion-reduce:transition-none" aria-label="التنقّل الرئيسي">
            {{--
                طيّ القائمة وتوسيعها أفقياً: على الحاسوب تنكمش من 264px إلى شريطٍ بعرض 80px أيقوناتُه وحدها (مع تلميحٍ باسم كل
                بند)، وعلى الجوال تُغلق. الحالةُ يحفظها Flux في المتصفّح فتبقى كما تركها المستخدم.
            --}}
            <flux:sidebar.header class="shrink-0 in-data-flux-sidebar-collapsed-desktop:flex-col in-data-flux-sidebar-collapsed-desktop:gap-2">
                <x-app-logo :sidebar="true" href="{{ route('dashboard') }}" wire:navigate />
                <flux:sidebar.collapse
                    class="in-data-flux-sidebar-collapsed-desktop:static! in-data-flux-sidebar-collapsed-desktop:opacity-100!"
                    :tooltip="'طيّ القائمة أو توسيعها'"
                    aria-label="طيّ القائمة أو توسيعها"
                />
            </flux:sidebar.header>

            <div class="px-2 pb-2 in-data-flux-sidebar-collapsed-desktop:hidden">
                <livewire:institute-switcher />
            </div>

            <flux:sidebar.nav>
                <flux:sidebar.group heading="المتابعة" class="grid">
                    <flux:sidebar.item icon="home" :href="route('dashboard')" :current="request()->routeIs('dashboard')" wire:navigate>
                        الصفحة الرئيسية
                    </flux:sidebar.item>

                    @can('attendance.take')
                        <flux:sidebar.item icon="clipboard-document-check" :href="route('attendance.index')" :current="request()->routeIs('attendance.*')" wire:navigate>
                            التفقّد
                        </flux:sidebar.item>
                    @endcan

                    @can('excuses.review')
                        <flux:sidebar.item icon="envelope-open" :href="route('excuses.index')" :current="request()->routeIs('excuses.*')" wire:navigate>
                            أعذار الغياب
                        </flux:sidebar.item>
                    @endcan

                    @can('reports.view')
                        <flux:sidebar.item icon="document-chart-bar" :href="route('reports.index')" :current="request()->routeIs('reports.*')" wire:navigate>
                            التقارير
                        </flux:sidebar.item>
                        <flux:sidebar.item icon="chart-bar" :href="route('stats.index')" :current="request()->routeIs('stats.*')" wire:navigate>
                            الإحصائيات
                        </flux:sidebar.item>
                    @endcan
                </flux:sidebar.group>

                @canany(['courses.manage', 'circles.manage'])
                    <flux:sidebar.group heading="التنظيم" class="grid">
                        @can('courses.manage')
                            <flux:sidebar.item icon="calendar-days" :href="route('courses.index')" :current="request()->routeIs('courses.*')" wire:navigate>
                                الدورات
                            </flux:sidebar.item>
                            <flux:sidebar.item icon="clock" :href="route('shifts.index')" :current="request()->routeIs('shifts.*')" wire:navigate>
                                أوقات الدوام
                            </flux:sidebar.item>
                        @endcan

                        @can('circles.manage')
                            <flux:sidebar.item icon="squares-2x2" :href="route('circles.index')" :current="request()->routeIs('circles.*')" wire:navigate>
                                الحلقات
                            </flux:sidebar.item>
                        @endcan
                    </flux:sidebar.group>
                @endcanany

                @canany(['students.manage', 'teachers.manage', 'credentials.export'])
                    <flux:sidebar.group heading="الأشخاص" class="grid">
                        @can('students.manage')
                            <flux:sidebar.item icon="users" :href="route('students.index')" :current="request()->routeIs('students.*')" wire:navigate>
                                الطلاب
                            </flux:sidebar.item>
                        @endcan

                        @can('teachers.manage')
                            <flux:sidebar.item icon="academic-cap" :href="route('teachers.index')" :current="request()->routeIs('teachers.*')" wire:navigate>
                                الأساتذة
                            </flux:sidebar.item>
                        @endcan

                        @can('credentials.export')
                            <flux:sidebar.item icon="key" :href="route('credentials.index')" :current="request()->routeIs('credentials.*')" wire:navigate>
                                بيانات الدخول
                            </flux:sidebar.item>
                        @endcan
                    </flux:sidebar.group>
                @endcanany

                @canany(['curricula.manage', 'announcements.manage'])
                    <flux:sidebar.group heading="المحتوى" class="grid">
                        @can('curricula.manage')
                            <flux:sidebar.item icon="book-open-text" :href="route('curricula.index')" :current="request()->routeIs('curricula.*')" wire:navigate>
                                المناهج
                            </flux:sidebar.item>
                        @endcan

                        {{-- ✅ م.8.1 --}}
                        @can('announcements.manage')
                            <flux:sidebar.item icon="megaphone" :href="route('announcements.index')" :current="request()->routeIs('announcements.*')" wire:navigate>
                                الإعلانات
                            </flux:sidebar.item>
                        @endcan
                    </flux:sidebar.group>
                @endcanany

                @canany(['institutes.manage', 'users.manage'])
                    <flux:sidebar.group heading="الإدارة العليا" class="grid">
                        @can('institutes.manage')
                            <flux:sidebar.item icon="building-office-2" :href="route('institutes.index')" :current="request()->routeIs('institutes.index') || request()->routeIs('institutes.create') || request()->routeIs('institutes.edit')" wire:navigate>
                                المعاهد
                            </flux:sidebar.item>
                            <flux:sidebar.item icon="presentation-chart-line" :href="route('institutes.overview')" :current="request()->routeIs('institutes.overview')" wire:navigate>
                                لوحة المعاهد
                            </flux:sidebar.item>
                        @endcan

                        @can('users.manage')
                            <flux:sidebar.item icon="shield-check" :href="route('users.index')" :current="request()->routeIs('users.*')" wire:navigate>
                                المستخدمون
                            </flux:sidebar.item>
                        @endcan
                    </flux:sidebar.group>
                @endcanany

                @can('settings.manage')
                    <flux:sidebar.group heading="الإعدادات" class="grid">
                        <flux:sidebar.item icon="identification" :href="route('institute.edit')" :current="request()->routeIs('institute.*')" wire:navigate>
                            بيانات المعهد
                        </flux:sidebar.item>
                        <flux:sidebar.item icon="adjustments-horizontal" :href="route('custom-fields.index')" :current="request()->routeIs('custom-fields.*')" wire:navigate>
                            الواصفات المخصّصة
                        </flux:sidebar.item>
                        <flux:sidebar.item icon="sparkles" :href="route('traits.index')" :current="request()->routeIs('traits.*')" wire:navigate>
                            الصفات
                        </flux:sidebar.item>
                    </flux:sidebar.group>
                @endcan

                @canany(['conflicts.review', 'system.debug'])
                    <flux:sidebar.group heading="النظام" class="grid">
                        @can('conflicts.review')
                            <flux:sidebar.item icon="arrows-right-left" :href="route('system.conflicts')" :current="request()->routeIs('system.conflicts')" wire:navigate>
                                تعارضات المزامنة
                            </flux:sidebar.item>
                        @endcan

                        @can('system.debug')
                            <flux:sidebar.item icon="device-phone-mobile" :href="route('system.devices')" :current="request()->routeIs('system.devices')" wire:navigate>
                                الأجهزة
                            </flux:sidebar.item>
                            <flux:sidebar.item icon="list-bullet" :href="route('system.change-log')" :current="request()->routeIs('system.change-log')" wire:navigate>
                                سجل التغييرات
                            </flux:sidebar.item>
                            <flux:sidebar.item icon="arrow-down-tray" :href="route('system.app-releases')" :current="request()->routeIs('system.app-releases')" wire:navigate>
                                تحديثات التطبيقات
                            </flux:sidebar.item>
                        @endcan
                    </flux:sidebar.group>
                @endcanany
            </flux:sidebar.nav>

            <flux:spacer />

            <x-desktop-user-menu class="hidden lg:block" :name="auth()->user()->name" />
        </flux:sidebar>

        {{--
            AppBar للجوال واللوحي (أقل من 1024px): ارتفاع 64px ثابت في الأعلى، زر القائمة بمساحة لمس 48px،
            علامة نزلاً المصغّرة واسم المعهد، ثم قائمة المستخدم. على الحاسوب يحلّ محلّه الشريط الجانبي.
        --}}
        <flux:header class="sticky top-0 z-10 h-16 gap-2 border-b border-line bg-raised px-2 lg:hidden sm:px-4">
            <flux:sidebar.toggle class="size-12" icon="bars-2" aria-label="فتح القائمة" />

            <x-app-logo :sidebar="true" href="{{ route('dashboard') }}" wire:navigate class="min-w-0 flex-1" />

            <flux:dropdown position="bottom" align="end">
                <flux:profile
                    class="min-h-12"
                    :initials="auth()->user()->initials()"
                    icon-trailing="chevron-down"
                    aria-label="قائمة المستخدم"
                />

                <flux:menu>
                    <div class="flex items-center gap-2 px-1 py-1.5 text-start text-sm">
                        <flux:avatar
                            :name="auth()->user()->name"
                            :initials="auth()->user()->initials()"
                        />

                        <div class="grid flex-1 text-start text-sm leading-tight">
                            <flux:heading class="truncate">{{ auth()->user()->name }}</flux:heading>
                            <flux:text class="truncate">{{ auth()->user()->email }}</flux:text>
                        </div>
                    </div>

                    <flux:menu.separator />

                    <flux:menu.radio.group>
                        <flux:menu.item :href="route('profile.edit')" icon="cog" wire:navigate>
                            الإعدادات الشخصية
                        </flux:menu.item>
                        <flux:menu.item :href="route('about')" icon="information-circle">
                            حول نزلاً
                        </flux:menu.item>
                    </flux:menu.radio.group>

                    <flux:menu.separator />

                    <form method="POST" action="{{ route('logout') }}" class="w-full">
                        @csrf
                        <flux:menu.item
                            as="button"
                            type="submit"
                            icon="arrow-right-start-on-rectangle"
                            class="w-full cursor-pointer"
                            data-test="logout-button"
                        >
                            تسجيل الخروج
                        </flux:menu.item>
                    </form>
                </flux:menu>
            </flux:dropdown>
        </flux:header>

        {{ $slot }}

        @persist('toast')
            <flux:toast.group>
                <flux:toast />
            </flux:toast.group>
        @endpersist

        @fluxScripts
    </body>
</html>
