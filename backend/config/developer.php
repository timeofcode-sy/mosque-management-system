<?php

/**
 * المطوِّر والمالك والدعم الفني — تعرضها صفحتا «حول نزلاً» و«المطوِّر» في الموقع.
 *
 * ونظيرُها في تطبيقات فلاتر `packages/mousqe_ui/lib/src/about/developer.dart`:
 * من يعدّل هنا يعدّل هناك.
 */
return [
    'name' => 'Time of Code',
    'arabic_name' => 'تايم أوف كود',
    'tagline' => 'شركةُ حلولٍ برمجيةٍ ورقمية',
    'about' => 'شركةٌ سوريةٌ مقرُّها دمشق، تصمّم المواقعَ وتطوّر تطبيقاتِ الهاتف وتبني الهويّاتِ البصرية. تؤمن بأن البرمجيةَ الجيّدة تُرى في التفاصيل الصغيرة: أن يعمل التطبيقُ حين تنقطع الشبكة، وأن يُقرأ بالعربية كما تُقرأ، وأن يحفظ وقتَ من يستعمله.',
    'address' => 'سوريا - دمشق',
    'logo' => '/brand/timeofcode/timeofcode-logo.png',

    'services' => [
        'تصميم المواقع الإلكترونية',
        'تطوير تطبيقات الهاتف المحمول',
        'بناء الهوية البصرية',
        'تصاميم وسائل التواصل الاجتماعي',
        'إدارة صفحات التواصل الاجتماعي',
        'مونتاج الفيديو والموشن غرافيك',
    ],

    /** ما يُعرض، وما يُفتح، وأيقونتُه في Flux (heroicons). */
    'contacts' => [
        ['label' => 'الموقع', 'value' => 'timeofcode.com', 'url' => 'https://timeofcode.com', 'icon' => 'globe-alt'],
        ['label' => 'البريد', 'value' => 'Contact@timeofcode.com', 'url' => 'mailto:Contact@timeofcode.com', 'icon' => 'envelope'],
        ['label' => 'الهاتف', 'value' => '+963 986 209 313', 'url' => 'tel:+963986209313', 'icon' => 'phone'],
        ['label' => 'واتساب', 'value' => '+963 986 209 313', 'url' => 'https://wa.me/963986209313', 'icon' => 'chat-bubble-left-right'],
        ['label' => 'تيليغرام', 'value' => '@Time_of_Code', 'url' => 'https://t.me/Time_of_Code', 'icon' => 'paper-airplane'],
        ['label' => 'فيسبوك', 'value' => 'TimeofCode.sy', 'url' => 'https://www.facebook.com/TimeofCode.sy', 'icon' => 'link'],
        ['label' => 'إنستغرام', 'value' => '@timeofcode.sy', 'url' => 'https://www.instagram.com/timeofcode.sy', 'icon' => 'camera'],
    ],

    /** الدعم الفني والتقني: من يُتّصل به حين يتعطّل شيءٌ في النظام. */
    'support' => [
        ['name' => 'محمد علاء عبد الرحمن الشحرور', 'phone' => '+963 964 630 090'],
        ['name' => 'غالب صلاح النن', 'phone' => '+963 980 149 515'],
    ],
];
