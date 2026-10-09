<?php

/**
 * بيانات التواصل العامة التي يعرضها الموقع التعريفي (nuzuln.com). تُضبط من البيئة؛
 * وما لم يُضبط منها لا يُعرض أصلاً — فلا تظهر أرقامٌ تجريبية في موقعٍ منشور.
 */
return [
    'domain' => env('NUZULN_DOMAIN', 'nuzuln.com'),
    'phone' => env('NUZULN_PHONE'),
    'email' => env('NUZULN_EMAIL'),
    'place' => env('NUZULN_PLACE', 'دمشق، الجمهورية العربية السورية'),
];
