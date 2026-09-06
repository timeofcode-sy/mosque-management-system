@props(['institute' => null])

{{--
    ألوان المعهد الثلاثة مطبَّقةً على سلالم Tailwind.

    موضعُه بعد @vite لا قبله: متغيّرات @theme تُعرَّف على :root في ورقة الأنماط، وهذه
    تُعرَّف على :root أيضاً — فالغلبةُ لترتيب المصدر لا للتخصيص، ووسمُ <style> اللاحق
    هو الذي يفوز. ولذلك لا يُنقل هذا السطر إلى أعلى الترويسة.

    ومعهدٌ لم يضبط ألوانه لا يُحقَن له شيء أصلاً، فتبقى الصفحة على لوحة design-tokens.json
    بلا وسمٍ زائد في كل طلب.
--}}
@php($theme = App\Support\InstituteTheme::for($institute))

@unless ($theme->isDefault())
    <style>{!! $theme->cssVariables() !!}</style>
@endunless
