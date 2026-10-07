<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" dir="rtl">
    <head>
        @include('partials.head')
    </head>
    <body class="min-h-screen bg-sand-50 dark:bg-zinc-800">
        {{--
            عناصر القائمة مغلَّفة بـ @can لا لتزيين الواجهة: بدونها يرى المستخدمُ
            روابطَ تؤدّي به إلى 403، فتصير الأدوار عقوبةً مفاجئة بدل أن تكون شكلاً
            للوحة يفهمه من نظرة.
        --}}
        <flux:sidebar sticky collapsible="mobile" class="border-e border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
            <flux:sidebar.header>
                <x-app-logo :sidebar="true" href="{{ route('dashboard') }}" wire:navigate />
                <flux:sidebar.collapse class="lg:hidden" />
            </flux:sidebar.header>

            <div class="px-2 pb-2">
                <livewire:institute-switcher />
            </div>

            <flux:sidebar.nav>
                <flux:sidebar.group heading="المتابعة" class="grid">
                    <flux:sidebar.item icon="home" :href="route('dashboard')" :current="request()->routeIs('dashboard')" wire:navigate>
                        لوحة المعلومات
                    </flux:sidebar.item>

                    @can('attendance.take')
                        <flux:sidebar.item icon="clipboard-document-check" :href="route('attendance.index')" :current="request()->routeIs('attendance.*')" wire:navigate>
                            التفقّد
                        </flux:sidebar.item>
                    @endcan

                    @can('excuses.review')
                        <flux:sidebar.item icon="envelope-open" :href="route('excuses.index')" :current="request()->routeIs('excuses.*')" wire:navigate>
                            أذونات الغياب
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
                                الدوامات
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
                            <flux:sidebar.item icon="user-group" :href="route('users.index')" :current="request()->routeIs('users.*')" wire:navigate>
                                المستخدمون
                            </flux:sidebar.item>
                        @endcan
                    </flux:sidebar.group>
                @endcanany

                @can('settings.manage')
                    <flux:sidebar.group heading="الإعدادات" class="grid">
                        <flux:sidebar.item icon="building-library" :href="route('institute.edit')" :current="request()->routeIs('institute.*')" wire:navigate>
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
                        @endcan
                    </flux:sidebar.group>
                @endcanany
            </flux:sidebar.nav>

            <flux:spacer />

            <x-desktop-user-menu class="hidden lg:block" :name="auth()->user()->name" />
        </flux:sidebar>

        <!-- قائمة المستخدم على الجوال -->
        <flux:header class="lg:hidden">
            <flux:sidebar.toggle class="lg:hidden" icon="bars-2" inset="left" />

            <flux:spacer />

            <flux:dropdown position="top" align="end">
                <flux:profile
                    :initials="auth()->user()->initials()"
                    icon-trailing="chevron-down"
                />

                <flux:menu>
                    <flux:menu.radio.group>
                        <div class="p-0 text-sm font-normal">
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
                        </div>
                    </flux:menu.radio.group>

                    <flux:menu.separator />

                    <flux:menu.radio.group>
                        <flux:menu.item :href="route('profile.edit')" icon="cog" wire:navigate>
                            الإعدادات الشخصية
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

        <x-institute-banner />

        {{ $slot }}

        @persist('toast')
            <flux:toast.group>
                <flux:toast />
            </flux:toast.group>
        @endpersist

        @fluxScripts
    </body>
</html>
