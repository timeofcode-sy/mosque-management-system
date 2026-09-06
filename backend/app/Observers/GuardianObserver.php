<?php

namespace App\Observers;

/**
 * حسابُ الدخول تابعٌ لسجلّ ولي الأمر — والسلوك كلّه في GeneratesAccount.
 */
class GuardianObserver
{
    use GeneratesAccount;
}
