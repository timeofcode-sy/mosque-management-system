<?php

namespace App\Observers;

/**
 * حسابُ الدخول تابعٌ لسجلّ الأستاذ — والسلوك كلّه في GeneratesAccount.
 */
class TeacherObserver
{
    use GeneratesAccount;
}
