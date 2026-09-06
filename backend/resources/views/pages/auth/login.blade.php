<x-layouts::auth :title="__('Log in')">
    <div class="flex flex-col gap-6">
        <x-auth-header title="الدخول إلى حسابك" description="أدخل اسم المستخدم وكلمة المرور" />

        <!-- Session Status -->
        <x-auth-session-status class="text-center" :status="session('status')" />

        <x-passkey-verify />

        <form method="POST" action="{{ route('login.store') }}" class="flex flex-col gap-6">
            @csrf

            <!-- اسم المستخدم — أو البريد لمن له بريد -->
            <flux:input
                name="username"
                label="اسم المستخدم"
                :value="old('username')"
                type="text"
                required
                autofocus
                autocomplete="username"
                class="latin-numerals"
                placeholder="student1234"
            />

            <!-- Password -->
            <div class="relative">
                <flux:input
                    name="password"
                    :label="__('Password')"
                    type="password"
                    required
                    autocomplete="current-password"
                    :placeholder="__('Password')"
                    viewable
                />

                @if (Route::has('password.request'))
                    <flux:link class="absolute top-0 text-sm end-0" :href="route('password.request')" wire:navigate>
                        {{ __('Forgot your password?') }}
                    </flux:link>
                @endif
            </div>

            <!-- Remember Me -->
            <flux:checkbox name="remember" :label="__('Remember me')" :checked="old('remember')" />

            <div class="flex items-center justify-end">
                <flux:button variant="primary" type="submit" class="w-full" data-test="login-button">
                    {{ __('Log in') }}
                </flux:button>
            </div>
        </form>

        <flux:text size="sm" class="text-center">
            الحسابات تُنشئها إدارة المعهد — راجع مشرفك إن لم تصلك بيانات دخولك.
        </flux:text>
    </div>
</x-layouts::auth>
