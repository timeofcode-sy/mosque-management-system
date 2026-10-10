# نظام التصميم (هوية نزلاً v3)

مرجعٌ للعاملين على الواجهات: ما المصدر، وكيف تُستعمل الرموز في الويب وفي Flutter، وكيف تُضاف أيقونة، وما القرارات التي اتُّخذت فوق دليل المصمّم.

المصدر الكامل في `brand-v3/` (مجلد غير مُتتبَّع في git لحجمه: 24MB من الفيديو والصور المرجعية). **كل ما يستهلكه النظام مولَّد منه ومُلتزَم في المستودع**، فلا يحتاج التشغيل ولا البناء إلى المجلد؛ يلزم فقط لإعادة التوليد.

| الناتج | السكربت | يستهلكه |
|---|---|---|
| `design/design-tokens.json` | نسخة من `brand-v3/identity/design-system/tokens.json` | مرجع |
| `backend/resources/css/nuzul-tokens.css` و`nuzul-kit.css` | `node scripts/build-web-tokens.mjs` | الموقع واللوحة |
| `backend/resources/views/flux/icon/*.blade.php` | `node scripts/build-web-icons.mjs` | أيقونات Flux |
| `packages/nuzul_ui/lib/src/generated/icon_extra.dart` و`icon_names.dart` | `node scripts/build-flutter-icons.mjs` | أيقونات Flutter |
| أيقونات أندرويد وأيقونة ويندوز وشعار الشاشة الأولى | `python scripts/build-app-icons.py` | التطبيقات |

(الأيقونات كلها معرَّفة في `scripts/icons/set.mjs`؛ تتطلب Pillow لسكربت الأيقونات.)

## القرارات فوق دليل المصمّم

1. **الأرقام لاتينية (0–9)** في الويب والتطبيقات والتقارير والتصدير؛ لا مشرقية. `nzDigits` تعيد الرقم كما هو، وعلامة المئوية `%` لا `٪`.
2. **ألوان نزلاً ثابتة.** ألوان المعهد الثلاثة (`institutes.settings.theme`) تبقى بياناتٍ في الخادم والـ API ولا تصبغ الواجهة (تفاصيل التاريخ في [ARCHITECTURE.md](ARCHITECTURE.md)). السبب: ضمان التباين 4.5:1 للنص و3:1 للحدود والتركيز في السمتين، وهو ما لا يضمنه لونٌ يختاره المستخدم. شعار المعهد واسمه يظهران حيث كانا.
3. **التواريخ** ميلادية بأسماء الأشهر السورية (كانون الثاني، شباط …) عبر `formatLongDate` في `mousqe_ui`، لا `DateFormat(…, 'ar')`.
4. **تسمية «مأذون»** تبقى كما في النظام والعميل (الدليل يقترح «مستأذن»).
5. **ملفات أيقونة أندرويد التكيّفية** في الحزمة المسلَّمة مُزاحة 60px إلى اليمين، فتُبنى من الشعار الشفاف في `build-app-icons.py`.

## الويب (Tailwind 4 + Flux)

- **الألوان:** أسماء دلالية في `app.css` (`@theme inline`) تنقلب وحدها بين الفاتح (`:root`) والليلي (`.dark`): `bg-surface` `bg-raised` `bg-sunken` `border-line` `text-ink` `text-muted` `bg-primary` `text-on-primary` `text-bronze-ink` `bg-bronze-soft` وأزواج الحالة `success|warning|danger|info` (+ `-soft`). **لا تكتب ألواناً حرفية ولا أزواج `dark:`.**
- **حالات التفقّد:** `bg-present|absent|late|excused`.
- **الخطوط:** Reem Kufi للعناوين من 26px فما فوق فقط (`font-display`، وكل `h1`)، IBM Plex Sans Arabic للواجهة، Amiri للنص المأثور. تُبنى من `resources/fonts` وتُحمَّل بتجزئة في الاسم.
- **الزوايا:** 3px للتحكّمات و6px للبطاقات (`rounded-lg` و`rounded-xl` مرتبطان بذلك). لا كبسولات.
- **مكوّنات الهوية** (`.nz-btn` `.nz-tag` `.nz-badge` `.nz-card` `.nz-juz` `.nz-quote` …) في `nuzul-kit.css` للموقع العام؛ واللوحة تستعمل مكوّنات Flux مُعاد تلوينها.
- **الإطار:** `layouts/app/sidebar.blade.php` (قائمة جانبية **تلاصق أقصى يمين الشاشة** بعرض 256px تُطوى إلى شريط 64px، يحفظ Flux حالتها في المتصفح. الصفحةُ لا تتمرّر كلُّها بل منطقةُ المحتوى وحدها، فيقع شريطُ تمريرها عند **أقصى اليسار** بألوان الثيم، ولا يدفع القائمةَ إلى الداخل — شريطُ تمرير الصفحة في كروم وإيدج يقع دائماً يميناً، بخلاف شريط العنصر فيتبع اتجاهه)، وشريط تطبيق بارتفاع 64px على الجوال واللوحي، ورابط «تخطَّ إلى المحتوى»، و`x-panel-footer`.
- **الجداول والترقيم:** مسافات الخلايا في `app.css` (16px أفقياً و12px عمودياً، وأول عمود وآخره 20px عن حافة البطاقة). الترقيم الموحّد في `flux/pagination.blade.php` (يستعمله `<flux:table :paginate>` و`<flux:pagination :paginator>`): ملخص «عرض 1–20 من 78» وأزرار مربعة ونافذة صفحات بنقاط حذف، وعلى الجوال «صفحة 2 من 4». القوائم الطويلة (الطلاب، الأساتذة، المستخدمون، الأعذار، بيانات الدخول، سجلات النظام) كلها مرقَّمة.
- **الأيقونات:** `<flux:icon icon="…">` بأسماء Flux المعتادة؛ الاستبدال بأيقونات الهوية في `resources/views/flux/icon/` (مولَّد). لا تخلط مكتبة أخرى.
- **اللغة:** نصوص الواجهة في `lang/ar.json` ورسائل التحقق في `lang/ar/`.
- **الطباعة:** `components/report-sheet.blade.php` على الورق الرسمي (الشعار الأفقي، خط نحاسي، تذييل منقوش).

## Flutter

- الحزمة `packages/nuzul_ui` هي الهوية (رموز `NzColorTokens` و`NzType` و`NzSpace` و`NzRadius` و`NzSize`، `NuzulTheme.light/dark`، `NzIcon`، `NzMark`، `NzPattern`، `NzAdaptiveScaffold`، `NzAppBar` …). لا تعدّل `generated/tokens.dart` يدوياً.
- `mousqe_ui` تلفّها: `MousqeTheme.light()` و`MousqeTheme.dark()` (الكثافة تُختار من المنصة)، وتعيد تصدير `nuzul_ui` فتعتمد التطبيقات حزمة واحدة. ودجتس مشتركة: `StatCard` `StatusBadge` `NoticeBanner` `AttendanceStatusBadge` `EmptyState` `LoginForm` `SyncBar` `SnapshotView`.
- **في الشاشات:** خذ اللون من `context.nz` (مثل `c.ink` و`c.surfaceRaised`)، والنص من `NzType`، والمسافة من `NzSpace`. لا `Colors.x` ولا `Color(0x…)` ولا `BorderRadius.circular(999)`، ولا نص أصغر من 12px.
- **الأيقونات:** `NzIcon(NzIcons.x)`، لا `Icons.x` من Material.
- **الترقيم في Flutter:** `PagedList` (قائمة بنمط الجدول: بطاقة بحدّ، رأس على sunken، صفوف بهوامش 20/12، وترقيم تحتها) و`PagedView` (ترقيم لأي جسم قابل للتمرير) و`PaginationBar` في `mousqe_ui`. مستعملة في الطلاب والمستخدمين وبطاقات الدخول وسجل الجلسات والأعذار والتعارضات (المكتب) وسجل جلسات الأستاذ. تُعاد الصفحة إلى الأولى حين يتغيّر `resetKey` (بحث أو مرشّح).
- **القائمة الجانبية في المكتب:** `desktop_shell.dart`؛ 264px أو شريط 80px، ويُطوى بزر في أسفل القائمة ويُحفظ الخيار في `nuzuln_ui.json` بجانب بيانات التطبيق، وتُطوى قسراً دون 1024px.
- **تقارير PDF من الجهاز:** `reports/report_documents.dart` تستعمل الشعار المضمَّن (`report_brand.dart`) وReem Kufi للعنوان.

## إضافة أيقونة

1. أضفها في `scripts/icons/set.mjs` بقواعد الهوية: شبكة 24، خط 2px، زوايا حادّة، خطوط أفقية أو رأسية أو بميل 35° أو 45° فقط، ولا منحنيات (الهلال استثناء الشعار). الأوامر المسموحة `M L H V Z` مطلقةً ونسبية.
2. إن لزمت في Flux فأضف ربط الاسم في `flux` بالملف نفسه.
3. شغّل `node scripts/build-web-icons.mjs` و`node scripts/build-flutter-icons.mjs`.

## الفحص

- الويب: `cd backend && php artisan test --compact`.
- Flutter: `flutter test --no-pub` في كل حزمة وتطبيق (`--no-pub` حين يتعذّر الوصول إلى pub.dev).
- في `nuzul_ui` اختبار تباين 4.5:1 للرموز في السمتين، فأي تغيير في الرموز يمرّ عليه.
