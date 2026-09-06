<?php

namespace App\Observers;

/**
 * حسابُ الدخول تابعٌ لسجلّ الطالب — والسلوك كلّه في GeneratesAccount.
 */
class StudentObserver
{
    use GeneratesAccount;
}
