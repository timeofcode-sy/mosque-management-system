# خطة نظام إدارة معهد تحفيظ القرآن (مساجد/حلقات)

> **حالة الخطة:** محدّثة بعد تنفيذ المراحل 0 إلى **8.1** — **المرحلتان 5 و6 مكتملتان**: تطبيقُ
> الأستاذ يعمل على جهاز، وتطبيقُ الديسكتوب **خمسةَ عشرَ باباً من خمسةَ عشر** وبناؤه الأصلي على
> ويندوز مُجرَّب. ✅ **والمرحلة السابعة (تطبيق ولي الأمر) مكتملة**: أساسُها الخادمي منفَّذ
> (7.1) ومستودعُها في `mousqe_core` (7.2) **وتطبيقُها قائمٌ عاملاً** (7.3)، **وسطحُ الإشعار الفوري مبنيٌّ خادمياً** (7.4) — ولم يبقَ إلا ربطُ مشروع Firebase من متصفّح صاحبه.
> ما نُفِّذ موسوم بـ ✅، وما تغيّر عن الخطة الأصلية موسوم بـ 🔄 مع سبب التغيير.
> التوثيق التفصيلي للمخطط في [ERD.md](ERD.md)، ونقاط التفتيش في
> [CHECKPOINT-PHASE-1.MD](CHECKPOINT-PHASE-1.MD)، [CHECKPOINT-PHASE-2.MD](CHECKPOINT-PHASE-2.MD)،
> [CHECKPOINT-PHASE-3.MD](CHECKPOINT-PHASE-3.MD)، [CHECKPOINT-PHASE-4.MD](CHECKPOINT-PHASE-4.MD)،
> [CHECKPOINT-PHASE-4.5.MD](CHECKPOINT-PHASE-4.5.MD)، [CHECKPOINT-PHASE-4.6.MD](CHECKPOINT-PHASE-4.6.MD)،
> [CHECKPOINT-PHASE-4.7.MD](CHECKPOINT-PHASE-4.7.MD)، [CHECKPOINT-PHASE-5.1.MD](CHECKPOINT-PHASE-5.1.MD)،
> [CHECKPOINT-PHASE-5.2.MD](CHECKPOINT-PHASE-5.2.MD)، [CHECKPOINT-PHASE-5.3.MD](CHECKPOINT-PHASE-5.3.MD)،
> و[CHECKPOINT-PHASE-5.4.MD](CHECKPOINT-PHASE-5.4.MD)،
> و[CHECKPOINT-PHASE-6.1.MD](CHECKPOINT-PHASE-6.1.MD)، و[CHECKPOINT-PHASE-6.2.MD](CHECKPOINT-PHASE-6.2.MD)،
> و[CHECKPOINT-PHASE-6.3.MD](CHECKPOINT-PHASE-6.3.MD)، و[CHECKPOINT-PHASE-6.4.MD](CHECKPOINT-PHASE-6.4.MD)،
> و[CHECKPOINT-PHASE-6.5.MD](CHECKPOINT-PHASE-6.5.MD)، و[CHECKPOINT-PHASE-6.6.MD](CHECKPOINT-PHASE-6.6.MD)،
> و[CHECKPOINT-PHASE-7.1.MD](CHECKPOINT-PHASE-7.1.MD)، و[CHECKPOINT-PHASE-7.2.MD](CHECKPOINT-PHASE-7.2.MD).
>
> **توثيق المعمارية والعلاقات بين التطبيقات** — أُنشئ 2026-09-06 قبل بدء المرحلة 5:
> [ARCHITECTURE.md](ARCHITECTURE.md) الصورة العامة · [API.md](API.md) عقد الـ API لعملاء الأوف-لاين ·
> [SYNC-PROTOCOL.md](SYNC-PROTOCOL.md) بروتوكول المزامنة · [CLIENTS.md](CLIENTS.md) من يكتب ماذا ومن
> ينتظر مَن بين التطبيقات الخمسة.
>
> **قدرات المستخدم في كل تطبيق** — [APPS-FEATURES.md](APPS-FEATURES.md)، أُنشئ 2026-09-07:
> الملفات أعلاه تصف **بنية** النظام، وهذا يصف **ما يستطيع مستخدمُ كلِّ تطبيق أن يفعله به** —
> بطبقتين لكل تطبيق: وصفٌ بلغة المستخدم وجدولٌ تقني. يُقرأ عند بدء أي مرحلة من 6 إلى 8.
>
> **خطة المرحلة 5 مقسَّمةً ثلاثاً** — أُنشئت 2026-09-06 مع بدء التنفيذ:
> [PHASE-5-STAGES.MD](PHASE-5-STAGES.MD). تُقرأ عند استئناف أي مرحلة فرعية منها.
> **ونظيرُها للمرحلة 6** — أُنشئ 2026-09-07: [PHASE-6-STAGES.MD](PHASE-6-STAGES.MD)، ست مراحل
> فرعية أُنجزت كلُّها.
> **ونظيرُها للمرحلة 8** — أُنشئ 2026-09-10: [PHASE-8-STAGES.MD](PHASE-8-STAGES.MD)، **مرحلتان لا أربع**
> لأن تطبيق الطالب أصغرُ الأربعة: شاشةُ عرضٍ بلا كتابةٍ واحدة.
> **ونظيرُهما للمرحلة 7** — أُنشئ 2026-09-10 مع بدء التنفيذ: [PHASE-7-STAGES.MD](PHASE-7-STAGES.MD)،
> وفيه **القراراتُ الثلاثة** التي كانت موسومةً «ينتظر قراراً» وحُسمت قبل أوّل سطر: خروجُ ولي الأمر
> من `sync/pull`، وتأجيلُ الإشعار الفوري مرحلةً فرعيةً أخيرة، ونزعُ `reports.view` من دوره.
>
> **سياسة التوسّع:** المعلومةُ الجديدة تُضاف **قسماً في ملف قائم** إذا كانت تعمّق سؤالاً يجيب عنه
> أصلاً (تفاصيل شاشات تطبيق الأستاذ ⇒ تحت صفّه في [CLIENTS.md](CLIENTS.md) §1). ولا يُنشأ ملف جديد
> إلا لِـ**محور توثيقي جديد كلياً** لا يخدمه أيٌّ من الستّة — أمثلة محتملة لاحقاً:
> `DESIGN-SYSTEM.md` حين يُستهلك `design-tokens.json` فعلياً في `mousqe_ui`، أو `DEPLOYMENT.md` حين
> تُحسم الاستضافة قبل المرحلة 9. لا تُنشأ ملفات «احتياطاً». وأي ملف جديد يتبع نفس النمط
> (`ALL-CAPS-WITH-DASHES.md` تحت `docs/`)، ويُضاف إلى هذا الرأس فور إنشائه، ويُسجَّل قرارُ إنشائه في §14.

## 1. السياق — لماذا هذا العمل؟

المطلوب نظام متكامل لإدارة معهد قرآني (حلقات، أساتذة، طلاب، تفقّد يومي، إحصاءات) يخدم خمسة عملاء:
لوحة تحكم ويب، برنامج ويندوز للمشرف، وثلاثة تطبيقات موبايل (أستاذ، أهل، طالب).

**الوضع عند بدء العمل:**
- `d:\Development\Laravel\mousqe` — فارغ تماماً.
- `d:\Development\Laravel\Mosque-Management` — مشروع Laravel 13 + Livewire 4 + Flux + Fortify + Spatie Permission،
  فيه migrations فقط (بدون Models ولا واجهات ولا اختبارات). المخطط الموجود **لم يغطِّ** المتطلبات الجوهرية:
  الدورات، الدوامات، نقل الطلاب مع حفظ السجل، الواصفات المخصّصة، طبقة المزامنة، أولياء الأمور.

✅ **الوضع الحالي:** `Mosque-Management` نُقل إلى `mousqe/backend/` (المسار القديم لم يعد موجوداً)،
وأُعيد تصميم قاعدة البيانات من الصفر، والباك إند يعمل بنموذج بيانات كامل مغطّى باختبارات.

النتيجة المرجوّة: مستودع موحّد يعمل فيه الباك إند وتطبيقات فلاتر على **نموذج بيانات واحد**، والتفقّد يُسجَّل
أوف-لاين من الأستاذ (موبايل) ومن المشرف (ديسكتوب) ويتزامن دون فقدان بيانات.

---

## 2. القرارات المعتمدة

| القرار | المعتمد |
|---|---|
| القاعدة البرمجية | البناء على `Mosque-Management` (نفس الستاك) — بدون التزام بمخططه القديم ✅ |
| لوحة التحكم | Livewire 4 + Flux + Tailwind 4 — **لا Filament** (تحكّم كامل بالهوية البصرية) |
| برنامج الكمبيوتر | **Flutter Desktop (Windows)** — أوف-لاين كامل بـ SQLite محلي + مزامنة |
| التفقّد | الأستاذ من الموبايل **و** المشرف من الديسكتوب — كلاهما أوف-لاين مع حلّ تعارضات |
| بنية المجلدات | **مستودع موحّد** تحت `mousqe/` ✅ |
| ترتيب التطبيقات | الأستاذ ← الديسكتوب ← الأهل ← الطالب |
| واتساب | **مؤجَّل** — خارج نطاق هذه الخطة (انظر §11) |

---

## 3. بنية المستودع الموحّد ✅

```
d:\Development\Laravel\mousqe\
├─ backend/                    ✅ Laravel 13 — لوحة التحكم + API
│  ├─ app/  config/  routes/  database/  resources/  tests/
├─ apps/
│  ├─ teacher/              ✅ Flutter — Android          (المرحلتان 5.3 و5.4)
│  ├─ admin_desktop/        🔄 Flutter — Windows          (المرحلة 6 — 6.1→6.5 ✅)
│  ├─ guardian/             ⬜ Flutter                    (المرحلة 7)
│  └─ student/              ⬜ Flutter                    (المرحلة 8)
├─ packages/
│  ├─ mousqe_core/          ✅ نماذج + drift(SQLite) + محرك المزامنة + عميل API
│  └─ mousqe_ui/            ✅ نظام التصميم: ألوان، خط كوفي، ويدجتس، RTL
├─ design/
│  ├─ logo/                 ✅ شعار معهد عمر الفاروق — الأصلُ ومشتقّاتُه وأيقوناتُ التطبيق
│  └─ design-tokens.json    ✅ مصدر واحد للألوان يُستهلك من Tailwind ومن Flutter
├─ docs/                    ✅ PLAN · ERD · ARCHITECTURE · API · SYNC-PROTOCOL · CLIENTS
│                              · APPS-FEATURES · PHASE-5-STAGES · PHASE-6-STAGES
│                              · CHECKPOINT-PHASE-1…6.5
├─ pubspec.yaml             ✅ جذرُ مساحة العمل (workspace) وإعدادُ melos
└─ README.md                ✅
```

> 🔄 **م.5.2: لا `melos.yaml`.** melos 8 يقرأ إعداده من `melos:` في `pubspec.yaml` الجذري، وهو
> نفسه الذي يحمل `workspace:` لحزم Dart. فملفٌ ثانٍ يكرّر قائمة الحزم ويفترق عنها بصمت.

✅ `git init` منفَّذ على `mousqe/` وكل مرحلة تُسجَّل في commit مستقل.

---

## 4. نموذج البيانات ✅ (منفَّذ بالكامل)

38 migration جديدة، 53 جدولاً، 37 نموذج دومين، 18 enum. حُذف مجلد migrations الدومين القديم
وأُبقيت `users`, `cache`, `jobs`, `passkeys`, `two_factor`, `permission_tables`.

🔄 **بعد المرحلة 4.5:** 50 migration · 38 نموذجاً · 21 enum — أُضيف `student_points`، وحُذف
`report_templates`.

كل جدول دومين يحمل `uuid` (يولّده `App\Concerns\HasUuid` بـ `Str::uuid7`)، و`timestamps(3)` بدقّة
ميلي-ثانية، و`softDeletes` — شرط أساسي للمزامنة.

### 4.1 التنظيم الهرمي ✅

```
institute (معهد)
  └─ course (دورة)  ← تصفير عدّادات الغياب يبدأ هنا
       └─ shift (دوام)  ← أيام ثابتة أسبوعياً + وقت
            └─ course_circle (تشغيل حلقة ضمن هذه الدورة/الدوام)
                 └─ enrollment (طالب مُسجَّل)
```

| الجدول | الحقول الأساسية |
|---|---|
| `institutes` | name, short_name, logo_path, phone, email, address, settings(json), is_active — 🔄 حُذف `timezone` في م.4.5، والمنطقة الزمنية صارت واحدة للتطبيق في `config/app.php` |
| `courses` | institute_id, name, starts_on, ends_on, status, is_current — **الدورة = نطاق تصفير الإحصاءات** |
| `shifts` | course_id, name, starts_at, ends_at, sort_order, is_active |
| `shift_days` | shift_id, weekday(0-6) — `unique(shift_id, weekday)` |
| `circles` | institute_id, name, level, color, sort_order, is_active — **هوية الحلقة ثابتة عبر الدورات** |
| `course_circles` | course_id, circle_id, shift_id, room, capacity, status — `unique(course_id, circle_id)` ⇒ **الحلقة في دوام واحد فقط** |
| `course_circle_teachers` | course_circle_id, teacher_id, role(main/assistant), joined_on, left_on |

### 4.2 الأشخاص وتغطية استمارة تسجيل الطالب ✅

🔄 **توسّع عن الخطة الأصلية:** أُضيفت كل حقول استمارة التسجيل التي زوّدتني بها.

**`students`** — البيانات الأساسية والشخصية:

| حقل الاستمارة | العمود |
|---|---|
| رقم المعرف (البطاقة) | `registration_no` — `unique(institute_id, registration_no)` |
| تاريخ التسجيل | `registration_date` (ميلادي) + `registration_date_hijri` |
| الصورة الشخصية | `photo_path` |
| اسم الطالب الثلاثي | `first_name` + `father_name` + `family_name` — تُقرأ مجمّعة عبر الخاصية `full_name` |
| تاريخ الولادة / مكان الولادة | `birth_date` / `birth_place` |
| الصف الدراسي | `grade_level` |
| عمل/مهنة الطالب | `student_job` |
| رقم جوال الطالب | `phone` |
| العنوان الأساسي / الحالي | `permanent_address` / `current_address` |
| عدد أفراد العائلة | `family_members_count` |
| الوضع الصحي للطالب / للعائلة | `student_health_status` / `family_health_status` |
| الملاحظات العامة | `notes` |

إضافة: `gender`, `national_id`, `status`, `institute_id`, `user_id` (لربطه بحساب تطبيق الطالب).

**`guardians` + `guardian_student`** — بيانات الأب والأم:

اسم الأب وعمله وهاتفه، واسم الأم وعملها وهاتفها، **ليست أعمدة في `students`** بل سجلّان في `guardians`
مربوطان بالطالب عبر `guardian_student` بحقل `relation` (father/mother/brother/uncle/grandfather/other)
وصلاحيات `is_primary`, `can_view_reports`, `can_submit_excuses`.

> 🔄 **سبب القرار:** ولي الأمر يملك حساباً في تطبيق الأهل وقد يتابع أكثر من ابن في المعهد. تكرار حقوله
> داخل كل صفّ طالب كان سيمنع ربطه بحساب واحد ويُلزم بتعديل رقم هاتفه في عدة أماكن.
> الوصول المختصر متاح عبر `$student->father()` و`$student->mother()`.

**`traits` + `student_trait`** — الصفات الشخصية والسلوكية:

اختيار متعدّد وليس حقولاً بولينية. الصفات التسع الواردة في الاستمارة مزروعة عامةً
(`institute_id = null`): هادئ · مبدع · متواضع · كثير الحركة · ذكي · انطوائي · حزين · سعيد · خجول.
لكل إسناد `note` و`noted_by`، ولكل صفة `polarity` تميّز الإيجابي عمّا يحتاج متابعة.

> 🔄 اسم النموذج `PersonalTrait` لأن `Trait` كلمة محجوزة في PHP، وجدول الربط `student_trait` (مفرد،
> وفق اصطلاح Laravel) وليس `student_traits`.

**بقية جداول الأشخاص:**

| الجدول | الحقول |
|---|---|
| `teachers` | institute_id, user_id, display_name, phone, national_id, birth_date, specialization, qualification, photo_path, address, hired_on, status |
| `custom_fields` | institute_id, entity(student/teacher/circle), key, label, type, options(json), group, is_required, sort_order |
| `custom_field_values` | custom_field_id, entity(morph), value(json) |
| `tags` + `taggables` | تصنيفات سريعة |

`custom_fields` يحقّق متطلب "يمكن إضافة واصفات إضافية" — يعرّفها المشرف من اللوحة دون كود.

### 4.3 المناهج والمحفوظات ✅

🔄 **جديد كلياً** — لم يكن في الخطة الأصلية، أُضيف بناءً على متطلبات الاستمارة.

ثلاثة جداول بدل عشرات الأعمدة، حتى يضيف المعهد مناهج جديدة دون تعديل قاعدة البيانات:

| الجدول | الحقول |
|---|---|
| `curricula` | institute_id, name, slug, type(quran/hadith/mutun/custom), description, sort_order, is_active |
| `curriculum_items` | curriculum_id, name, code, sort_order, meta(json), is_active — 🔄 `meta.hadiths` / `meta.abyat` عدّادان يملؤهما المشرف (م.4.5) |
| `student_curriculum_progress` | student_id, curriculum_item_id, course_circle_id, status, percent, score, **points**, started_on, completed_on, **achieved_on**, teacher_id, notes — `unique(student_id, curriculum_item_id)` |

🔄 **م.4.5:** `points` تُشتقّ من `النسبة × عدّاد البند × معامل النوع` وتُجمَّد؛ و`achieved_on` تاريخ آخر
تحديث — بدونه لا يمكن تصفية نقاط البند بمدى زمني، لأن صفّ التقدّم حالةٌ لا حدث.
**أجزاء القرآن الثلاثون ثابتة:** لا تُضاف ولا تُحذف، بحراسة على الخادم لا بإخفاء الزر فقط.

المناهج المزروعة (41 بنداً):

| المنهج | النوع | البنود |
|---|---|---|
| القرآن الكريم | `quran` | الجزء الأول … الجزء الثلاثون (30 بنداً، `meta.juz` يحمل رقم الجزء) |
| الحديث الشريف | `hadith` | الأربعون النبوية (1) · (2) · (3) · مجامع الأنوار |
| المتون العلمية | `mutun` | البيقونية · اللامية · تحفة الأطفال · عقيدة العوام · المقدمة الجزرية · جوهرة التوحيد · الأرجوزة الميئية |

حالات التقدّم: `not_started` / `in_progress` / `memorized` / `mastered`.
**المناهج العلمية المضافة** = صفوف جديدة في `curricula` بنوع `custom`.

### 4.4 التسجيل والنقل ✅

| الجدول | الحقول |
|---|---|
| `enrollments` | course_circle_id, student_id, status(active/left/transferred), enrolled_on, left_on — `unique(course_circle_id, student_id)` |
| `student_transfers` | student_id, course_id, from_course_circle_id, to_course_circle_id, transferred_on, reason, performed_by |

النقل = إغلاق `enrollment` بـ `transferred` + فتح واحد جديد + قيد في `student_transfers`.
سجل الحضور القديم مرتبط بـ `enrollment_id` القديم ⇒ **يبقى محفوظاً ولا يظهر في التفقّد**.

### 4.5 التفقّد ✅

| الجدول | الحقول |
|---|---|
| `attendance_sessions` | course_circle_id, session_date, status(draft/completed/locked), opened_by, taken_by, completed_at — `unique(course_circle_id, session_date)` |
| `attendances` | attendance_session_id, student_id, enrollment_id, status(present/absent/late/excused), late_minutes, note, **note_polarity**(positive/negative), recorded_by, recorded_at — `unique(session_id, student_id)` |
| `teacher_attendances` | attendance_session_id, teacher_id, status, late_minutes, note, recorded_by, recorded_at |
| `absence_excuses` | student_id, from_date, to_date, reason, attachment_path, submitted_by, status(pending/approved/rejected), reviewed_by, reviewed_at |

🔄 أُضيف `enrollment_id` إلى `attendances` ليبقى سجل الحضور مربوطاً بالتسجيل الذي وقع تحته — وهو
ما يجعل بيانات الطالب قبل النقل قابلة للاستعلام دون التباس.

`absence_excuses` يحقّق "إبلاغنا بالغياب مسبقاً" — ولي الأمر يقدّمه من تطبيق الأهل فيُقترح تلقائياً
حالة `excused` على شاشة تفقّد الأستاذ.

🔄 **م.4.5:** `note_polarity` يميّز الملاحظة الإيجابية من السلبية — عليه يقوم مقياس «الأدب» في شاشة
الإحصائيات، وبه تتلوّن أيقونة الملاحظة في صفّ الطالب.

### 4.6 المتابعة القرآنية والتقييم ✅ (الجداول جاهزة، الواجهات لاحقاً)

| الجدول | الحقول |
|---|---|
| `memorization_logs` | student_id, course_circle_id, attendance_session_id, curriculum_item_id, date, type(hifz/murajaa/tilawah), **grade**, from_surah, from_ayah, to_surah, to_ayah, pages, **lines**, **new_lines**, **points**, **juz**, memorization_score, tajweed_score, mistakes_count, teacher_id, notes |
| `student_points` | 🔄 **جديد (م.4.5)** — student_id, course_circle_id, attendance_session_id, points(**يقبل السالب**), reason, note, awarded_by, awarded_on |
| `evaluations` | student_id, course_circle_id, period(weekly/monthly/term), period_start, period_end, behavior, commitment, memorization, tajweed, total, teacher_id, notes |

🔄 **م.4.5 — الجدول صار يُكتب فيه فعلاً.** التسميع يُسجَّل من شاشة الجلسة، و`new_lines` هي الأسطر
الجديدة دون المكرّر (تُحسب بطرح تقاطع المدى مع ما سبق عبر `BuildStudentCoverageMap`)، و`points`
تُجمَّد وقت التسجيل: `new_lines ÷ 15 × quran_per_15_lines × معامل التقدير`.
تجميدها شرطٌ لأن تغيير إعدادات النقاط لاحقاً يجب ألّا يعيد كتابة تاريخ الطلاب.

**إعدادات النقاط** تُخزَّن في `institutes.settings['points']` — لا جدول جديد، والغلاف
`App\Support\PointsSettings` يقرؤها بقيم افتراضية. **نقاط الحضور لا تُخزَّن** بل تُشتقّ من
`attendances.status`، لأن صفوف الحضور تتغيّر بالتعديل فتخزين نقاطها يخلق مصدرَي حقيقة.

### 4.7 الإحصاء والتقارير ✅ (الجداول جاهزة، الحساب في المرحلة 3)

| الجدول | الحقول |
|---|---|
| `circle_daily_stats` | course_circle_id, date, present, absent, late, excused, total, attendance_rate, **daily_rank_in_shift** |
| `circle_cumulative_stats` | course_circle_id, as_of_date, sessions_count, present, absent, late, excused, total, attendance_rate, **overall_rank_in_shift** |
| ~~`report_templates`~~ | 🔄 **حُذف في م.4.5** — قوالب «نص جاهز للإرسال» بلا أي قناة إرسال في النظام (لا `Notification::` ولا `Mail::` ولا واتساب). يُعاد بناؤه عند بناء `MessageDriver` فعلياً |
| `report_exports` | institute_id, type, params(json), file_path, status, generated_by, generated_at |

**التصنيف اليومي** = ترتيب الحلقة بين حلقات نفس الدوام حسب نسبة حضور اليوم.
**التصنيف الكلي** = الترتيب حسب معدّل النسبة منذ بداية الدورة.
تُحدَّث عبر `RecalculateCircleStats` job يُطلق عند إغلاق أي جلسة تفقّد (المرحلة 3).

🔄 **م.4.5:** صيغة النسبة `(present + late) ÷ (total − excused)` كانت مكرّرة عمداً في موضعين كي لا
يختلف رقم اللوحة عن رقم التقرير؛ ومع `StatsQuery` صارت ثلاثة، فاستُخرجت إلى `App\Support\AttendanceRate`
ويستدعيها الثلاثة.

### 4.8 المزامنة والنظام ✅ (الجداول جاهزة، المنطق في المرحلة 4)

| الجدول | الحقول |
|---|---|
| `change_log` | id (= server_seq), table_name, row_uuid, operation(create/update/delete), payload(json), scope_key (`institute:{uuid}` / `circle:{uuid}`), actor_user_id, device_uuid, **op_uuid (unique)**, created_at |
| `sync_devices` | device_uuid, user_id, app, last_pulled_seq, last_pushed_at, last_pulled_at, app_version, platform |
| `sync_conflicts` | table_name, row_uuid, server_payload, client_payload, resolution, device_uuid, reviewed_by, resolved_at |
| `devices` | user_id, fcm_token, app, platform, last_seen_at |
| `announcements` | institute_id, scope, scope_ids(json), title, body, created_by, published_at |
| `settings` | institute_id, key, value(json) |
| `activity_log` | من `spatie/laravel-activitylog` — **مؤجَّل للمرحلة 4 مع تثبيت الحزمة** |

🔄 نُقل `op_uuid` إلى `change_log` نفسه (بقيد `unique`) بدل جدول منفصل — يكفي لضمان idempotency
ويوفّر جدولاً وعملية قراءة.

### 4.9 الأدوار والصلاحيات ✅

`spatie/laravel-permission` **بوضع الفرق (teams) مفعّل والمفتاح `institute_id`** — كان مضبوطاً مسبقاً
في `config/permission.php`، وهو ما يجعل تعدّد المعاهد جاهزاً بنيوياً.

الأدوار السبعة: 🔄 م.4.6 `developer` · `super_admin` · `admin` · `supervisor` · `teacher` · `guardian` ·
`student`، مع 40 صلاحية مصنّفة في `RolesAndPermissionsSeeder`. الأدوار عامة (`team_id = null`) والإسناد
وحده مرتبط بمعهد.

🔄 **م.4.6 — الأدوار العليا الثلاثة صارت متمايزة:** المبرمج وحده يملك `system.debug`، والمشرف الأعلى
مثله عدا ذلك، ومدير المعهد مثلهما داخل معهده بلا `institutes.manage`. وقبل ذلك كان `admin` و`super_admin`
`['*']` حرفياً — دورين بأسمين وصلاحيات متطابقة.

🔄 **م.4.6 — الأدوار العابرة للمعاهد:** `developer` و`super_admin` تُسنَد بمفتاح فريق مُصطلَح عليه
`User::GLOBAL_TEAM_ID = 0` (لا معهد بهذا المعرّف)، لا بـ `null`: العمود `model_has_roles.institute_id`
هو `not null` **وجزءٌ من المفتاح الأساسي** في مخطّط spatie نفسه، والفراغ مستحيل عليه أبداً على MySQL.
`Gate::before` في `AppServiceProvider` هو ما يمنح هذين الدورين كل شيء.

> ⚠️ **إلزامي قبل أي `assignRole` أو `hasRole`:**
> `App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);`
> ويقع هذا على اللوحة في `App\Http\Middleware\SetPanelInstituteScope` (م.4.6) قبل middleware الصلاحيات،
> وفي الـ API في `SetApiInstituteScope`.

---

## 5. الباك إند — Laravel 13

**الحزم:** `spatie/laravel-permission` ✅ مثبّتة. المؤجَّلة للمرحلة 4: `laravel/sanctum` (توكنات API)،
`spatie/laravel-activitylog`، `spatie/laravel-pdf` (Chromium — الوحيد الذي يدعم تشكيل العربية RTL
بشكل صحيح؛ **لا** dompdf)، `maatwebsite/excel` (اختياري).
قاعدة البيانات: **MySQL/MariaDB** للإنتاج، SQLite للتطوير المحلي.

**البنية:** نلتزم بـ `backend/AGENTS.md` (PHP 8.4، `php artisan make:*`، Pint، PHPUnit، اختبار لكل تغيير).

- ✅ `app/Models/` — 38 نموذجاً مع العلاقات و`HasUuid`
- ✅ `app/Enums/` — 22 enum بتسميات عربية (`label()`) وخريطة خيارات (`options()`)
  🔄 م.4.5: +`RecitationGrade` · `PointReason` · `NotePolarity`، −`ReportScope` · 🔄 م.4.6: +`PanelRole` (هرم الأدوار)
- ✅ `app/Concerns/HasUuid.php`
**قاعدة فصل الطبقات (اعتُمدت في المرحلة 3، وأُعيد عليها كلُّ ما سبق):**
**كل كتابة تمرّ بـ `app/Actions/`، وكل قراءة تمرّ بـ `app/Queries/`.**
ملف الشاشة لا يحمل استعلاماً ولا قاعدة عمل — يحمل حالة الواجهة وربطها فقط.

- ✅ `app/Actions/` — 35 إجراء كتابة: التسجيل والنقل والاستنساخ والتفعيل والاستمارة (م.2)،
  والتفقّد ودورة حياة الجلسة والإحصاء والأذونات (م.3)، والمزامنة (م.4)
  🔄 م.4.5: `SaveRecitation` · `DeleteRecitation` · `AwardStudentPoints` · `CalculateStudentPoints` ·
  `BuildStudentCoverageMap` · `BuildCirclePointsReport` · `SaveStudentCurriculumProgress`
  (−`RenderReportTemplate`)
  🔄 م.4.6: `CreateInstitute` · `InviteUser` · `AssignUserRole` · `RevokeUserRole`
- ✅ `app/Queries/` — 16 صنف قراءة: `DashboardOverviewQuery`, `AttendanceBoardQuery`,
  `AttendanceSessionQuery`, `CircleRankingQuery`, `StudentProfileQuery`, `StudentListQuery`,
  `StudentFormQuery`, `CircleQuery`, `InstituteCatalogQuery`, `AbsenceExcuseQuery`,
  `TeacherCircleQuery`, `GuardianChildrenQuery`, و🔄 م.4.5 `StudentPointsQuery` · `StatsQuery`
  (−`ReportTemplateQuery`) · 🔄 م.4.6 `InstituteAdminQuery` (⚠️ الوحيد الذي يتجاوز نطاق المعهد عمداً) · `UserAdminQuery`
- ✅ `app/Casts/DateOnly.php` — أعمدة التاريخ بلا وقت تُكتب دائماً `Y-m-d`
- ✅ `app/Support/` — `Quran` (السور + 🔄 م.4.5 الأسطر وسور كل جزء)، `HijriDate` (أم القرى عبر intl)،
  `ApiScope` (م.4)، و🔄 م.4.5 `PointsSettings` · `AttendanceRate` · `DateRange`،
  و🔄 م.4.6 `PanelScope` (نطاق اللوحة والتبديل بين المعاهد) · `InstituteForm`
- ✅ `app/Http/Controllers/ReportPrintController.php` — المتحكّم الوحيد: صفحات الطباعة/PDF
  استجاباتُ HTTP ساكنة بلا حالة، فلا معنى لجعلها مكوّنات Livewire
- ✅ `app/Actions/SyncPush.php` + `SyncPull.php` + `RecordChange.php` + `ResolveAttendanceConflicts.php` —
  تُعيد استخدام أفعال اللوحة نفسها بدل إعادة كتابة منطقها (م.4)
- ✅ `app/Http/Resources/V1/` — Eloquent API Resources (م.4)
- ✅ `app/Support/ApiScope.php` — نظير `InteractsWithInstitute` لمستخدم Sanctum بلا جلسة (م.4)
- ✅ `resources/views/livewire/` — 🔄 م.4.5: مكوّنات Livewire **متداخلة** (`session-student-recitations`).
  وُضعت هنا لا في `views/components/` لأن ذلك المجلد مليء بمكوّنات Blade المجهولة، فيصير المكوّن
  قابلاً للاستدعاء بـ`<x-…>` أيضاً — و`views/livewire/` مسجَّل أصلاً في `component_locations`
- ✅ `resources/views/components/charts/` — 🔄 م.4.5: `bar` · `donut` · `line` · `sparkline`،
  SVG + أنميشن CSS خالص بلا مكتبة JS (الأعمدة HTML/CSS لأن نصّ SVG لا يلتفّ ولا يرث RTL)
- ✅ `resources/views/pages/` — 26 مكوّن Livewire 4 أحادي الملف (SFC) للوحة التحكم
  🔄 لا مجلد `app/Livewire/`: هذا المشروع على Livewire 4 حيث المكوّن ملف Blade واحد تحت `pages::`
  🔄 أُزيلت سابقة ⚡ من أسماء الملفات: اختيارية في Livewire 4 (`Finder` يجرّبها ثم يسقط إلى الاسم
  المجرّد)، وكانت تُعقّد أوامر الطرفية والبحث بلا مقابل
- ✅ `app/Concerns/InteractsWithInstitute.php` — المعهد العامل والدورة الجارية لكل شاشة
  🔄 م.4.6: الحسم نفسه انتقل إلى `App\Support\PanelScope` ليتشاركه المكوّنُ والوسيطُ
- ✅ `app/Http/Middleware/SetPanelInstituteScope.php` — 🔄 م.4.6: يضبط مفتاح فريق spatie على كل طلبات
  اللوحة قبل `permission:` — بدونه يفشل كل فحص صلاحية على اللوحة

**نقاط الـ API (`routes/api.php`, prefix `/api/v1`) — ✅ المرحلة 4:**

```
POST   /auth/login              /auth/logout   GET /auth/me
POST   /devices/register
GET    /bootstrap               لقطة أولية لنطاق المستخدم
GET    /sync/pull?since={seq}   تغييرات ضمن نطاق المستخدم فقط
POST   /sync/push               دفعة عمليات مع op_uuid (idempotent)
GET    /teacher/circles         /teacher/sessions/{date}
GET    /guardian/children       /guardian/children/{id}/attendance
POST   /guardian/excuses
GET    /student/me/attendance   /student/me/progress
```

🔄 لا `POST /teacher/sessions` منفصلة ولا `/reports/*` في هذه المرحلة: فتح/إكمال الجلسة يمرّان عبر
`sync/push` (نوعا العملية `attendance.session.open`/`attendance.session.complete`)، وتقارير PDF تبقى
صفحات طباعة من اللوحة (`ReportPrintController`، المرحلة 3) — لا حاجة موبايلية لها بعد.

**بروتوكول المزامنة — ✅ المرحلة 4 (التفصيل في [CHECKPOINT-PHASE-4.MD](CHECKPOINT-PHASE-4.MD)):**

1. كل صف يحمل `uuid` يولّده العميل ⇒ الإنشاء أوف-لاين لا يحتاج الخادم. ✅ جاهز
2. **الدفع:** العميل يرسل عمليات مرتّبة، كل عملية بـ `op_uuid` فريد. الخادم يتجاهل ما نُفّذ سابقاً
   (idempotency) ويكتب في `change_log`. ✅ `SyncPush`
   الأنواع المدعومة: `attendance.session.open` · `attendance.take` · `attendance.teacher.take` ·
   `attendance.session.complete` · `excuse.submit` · 🔄 م.4.5: `recitation.save` · `recitation.delete` ·
   `points.award` · 🔄 م.5.4: `points.delete` · 🔄 م.6.2: `excuse.review` · `student.save` ·
   `enrollment.save` · `student.transfer` · 🔄 م.6.4: `attendance.session.lock` — كلها تستدعي أفعال
   اللوحة نفسها. والقائمةُ الحاكمة بحقولها وحرّاسها في [API.md §6](API.md).
3. **السحب:** `since=last_pulled_seq` يعيد كل تغييرات `change_log` ضمن `scope_key` المسموح للمستخدم.
   ✅ `SyncPull` — 🔄 النطاق الآن معهدٌ كامل لكل الأدوار، لا حلقات الأستاذ وحدها؛ التضييق مؤجَّل لِما
   بعد قياس أداء حقيقي (م.5).
4. **حلّ التعارض:** آخر `recorded_at` يفوز على مستوى صفّ `attendances`، والقيمة المُستبدَلة تُحفظ في
   `sync_conflicts` لعرضها للمشرف. ✅ `ResolveAttendanceConflicts`
5. **قفل الجلسة:** عند `completed` تُغلق، وأي تعديل لاحق يتطلب `attendance.amend`. 🔄 **م.6.4:**
   وفوقها `locked` — قفلٌ نهائي خلف `attendance.lock` لا تعديلَ بعده لأحد. ✅
   `AttendanceSession::isEditable()` جاهزة — تسجيل `activity_log` ما زال مؤجَّلاً.
6. النطاق: 🔄 كل الأدوار تزامن معهدها كاملاً الآن (انظر البند 3)؛ الأهل/الطالب للقراءة فقط فعلياً عبر
   صلاحية `sync.pull` بلا `sync.push`.

---

## 6. لوحة التحكم (Livewire 4 + Flux + Tailwind 4) — المرحلة 2 ✅

RTL كامل (`dir="rtl"`, `lang="ar"`)، خصائص Tailwind المنطقية (`ps-*`/`pe-*`)، تاريخ هجري + ميلادي.
✅ `APP_LOCALE=ar` و`APP_FAKER_LOCALE=ar_SA` مضبوطان.

**الشاشات:**

- ✅ **الداشبورد** — بطاقات KPI (الطلاب، المسجَّلون في الدورة الجارية، الحلقات، الأساتذة) وجدول حلقات
  الدورة بالدوام والأيام والأستاذ وعدد الطلاب.
  ⬜ نِسب الحضور والمخططات الزمنية وترتيب الحلقات — **المرحلة 3** (تحتاج حساب الإحصاءات).
- ✅ **الدورات** — إنشاء وتعديل، استنساخ بنية دورة سابقة (دوامات + حلقات + أساتذة بلا تسجيلات)، أرشفة،
  تفعيل الدورة الجارية.
- ✅ **الدوامات** — أيام الأسبوع + الأوقات + عدد الحلقات المداومة، ومنع حذف دوام تعمل فيه حلقات.
- ✅ **الحلقات** — CRUD لهوية الحلقة، تشغيلها في الدورة الجارية بدوام وقاعة وطاقة، إسناد الأساتذة
  وإنهاؤه، قائمة الطلاب، والنقل بين حلقات الدورة نفسها.
  🔄 النقل من قائمة إجراءات الطالب + نافذة تأكيد بدل سحب-وإفلات — يعمل على الجوال ومع قارئ الشاشة،
  ويمرّ بالإجراء `TransferStudent` نفسه.
- ✅ **الطلاب** — استمارة التسجيل الكاملة (التسجيل، الشخصية، الأب والأم، العائلة، الوضع الصحي، الصفات،
  المحفوظات، الواصفات المخصّصة، الحلقة)، بحث وتصفية بالحالة والحلقة مع ترقيم، وملف الطالب
  (مسار الحلقات عبر الدورات، سجل النقل، المحفوظات، آخر سجلات الحضور).
  ⬜ الرسم البياني للحضور وخريطة تقدّم الحفظ في المصحف — **المرحلة 3**.
- ✅ **الأساتذة** — CRUD وبحث، وعدد حلقات الدورة الجارية المسنَدة.
  ⬜ حضور الأستاذ — **المرحلة 3** (مع شاشة التفقّد).
- ✅ **التفقّد** — شاشة الجلسة: التفقّد السريع، وحضور الأساتذة، والملاحظة بقطبيتها في مودال،
  و🔄 م.4.5 **تسجيل التسميع** (جزء ← سورة ← مدى ← تقدير مع عرض حيّ للنقاط) و**النقاط التقديرية**،
  و**القفل/إعادة الفتح للمشرف وحده** بصلاحية `attendance.lock` محروسة على الخادم.
- ✅ **المناهج** — إدارة المناهج وبنودها؛ 🔄 م.4.5: القرآن ثابت (لا إضافة ولا حذف)، وعدّادات
  الأحاديث/الأبيات تُحرَّر وتظهر في الشريحة.
- ✅ **التقارير** — تقرير الحلقة اليومي، وترتيب حلقات الدوام (مع خط مصغّر لمسار أسبوعين)،
  و🔄 م.4.5 **تقرير نقاط الحلقة** بفلتر مدى (أسبوع/شهر/دورة/مخصّص) ومراكز مبرَزة — كلها بصفحات طباعة A4.
  🔄 م.4.5: حُذف قسم «نص جاهز للإرسال» بالكامل.
- ✅ **الإحصائيات** — 🔄 **شاشة جديدة (م.4.5)**: كيان (حلقات/طلاب) × مقياس (حضوراً/تسميعاً/نقاطاً/أدباً)
  × مدى، بلوحَي «الأكثر» و«الأقل» متجاورين، ومنحنى ودونات متحرّكة.
- ✅ **ملف الطالب** — 🔄 م.4.5: قسم **تقدّم المناهج** صار قابلاً للتحرير (حالة البند ونسبته)، ومنه
  تُشتقّ نقاط الحديث والمتون.
- ✅ **الإعدادات** — بيانات المعهد والشعار (🔄 م.4.5: +إعدادات النقاط، −المنطقة الزمنية)،
  الواصفات المخصّصة، الصفات.
  🔄 **قوالب التقارير: حُذفت** ولن تعود إلا مع قناة إرسال حقيقية.
- ✅ **المعاهد** — 🔄 **شاشتان جديدتان (م.4.6)**: قائمة المعاهد (إنشاء · تعديل · تعطيل · حذف ناعم ·
  «دخول كـ») ونموذجها المشترك مع «بيانات المعهد»؛ ومعها **مبدّل المعهد** في الشريط الجانبي وشريط
  تنبيه حين يكون المعهد العامل ليس معهد المستخدم.
- ✅ **لوحة المعاهد** — 🔄 **شاشة جديدة (م.4.6)**: بطاقات إجمالية وجدول مقارنة (طلاب · حلقات · أساتذة ·
  جلسات · حضور · نقاط) ومخطّط أعمدة، بفلتر مدى — بخمسة استعلامات مجمّعة مهما بلغ عدد المعاهد.
- ✅ **المستخدمون والصلاحيات** — 🔄 **شاشة جديدة (م.4.6)** (كانت مؤجّلة للمرحلة 6): الأدوار كشرائح
  بمعهد كلٍّ منها، وإنشاء حساب بدور مع رابط تعيين كلمة مرور يُنسخ يدوياً (لا قناة بريد)، وربطه
  بسجلّ الأستاذ أو ولي الأمر أو الطالب.
- ✅ **النظام (المبرمج وحده)** — 🔄 **ثلاث شاشات جديدة (م.4.6)** خلف `system.debug`: تعارضات المزامنة
  ومراجعتها · الأجهزة المزامِنة و`last_pulled_seq` · سجل التغييرات بحمولاته.

🔒 **م.4.6 — اللوحة كلها صارت خلف `permission:`** لكل مجموعة مسارات، والقائمة الجانبية مغلَّفة بـ `@can`
مطابقةً لها. قبل ذلك كانت خلف `['auth', 'verified']` فقط، فأيّ حساب موثَّق — ولو كان طالباً — يفتح
`/institute` و`/settings/*` وقوائم الطلاب.

---

## 7. تطبيقات فلاتر — المراحل 5 إلى 8

**الستاك الموحّد:** drift (SQLite) · dio + retrofit · freezed · `flutter_localizations`
(ar افتراضياً، RTL) · `flutter_secure_storage` · firebase_messaging (م.7) · `pdf`+`printing`
للتصدير المحلي · `window_manager` للديسكتوب (م.6). تُدار بـ **melos** ✅.

> 🔄 **م.5.3: بلا Riverpod وبلا go_router.** الخطة الأصلية سمّتهما، والتنفيذ لم يحتجهما: حالةُ
> تطبيق الأستاذ ثلاثةُ كائنات `ChangeNotifier` فوق تدفّقات drift، وتنقّلُه ثماني شاشات بلا روابط
> عميقة ولا مسارات مسمّاة. فبقي على `Navigator` و`InheritedWidget` واحد.
>
> ✅ **وأُعيدت المسألة عند الديسكتوب في م.6.3 وحُسمت كما هي:** بُني الهيكلُ أوّلاً ثم قيست الحاجةُ
> عليه. برنامجُ نافذةٍ واحدة بلا رابطٍ عميق ولا شريطِ عنوان لا يستفيد ممّا يبيعه الموجّه؛
> و`IndexedStack` فوق `Navigator` لكل باب يعطي مكدّساً مستقلاً لكل قسم — وهو **نفسُ ما يلفّه**
> `StatefulShellRoute`؛ والأبوابُ تُرشَّح بـ`user.permissions` في زمن التشغيل، فجدولُ المسارات
> الثابت كان سيضاعف الحارس ([CHECKPOINT-PHASE-6.3.MD §2](CHECKPOINT-PHASE-6.3.MD)).

**`packages/mousqe_core`** ✅ (يستخدمه الأربعة): نماذج freezed مطابقة لمخطط الخادم، مخطط drift
المحلي (`schemaVersion` 6 🔄 م.6.5)، **و`StatsRepository` الذي يحسب الإحصاءَ المشتقّ محلياً و`AttendanceRate` معادلتُه الواحدة** 🔄 م.6.6، `SyncEngine` (طابور عمليات مرتَّب + إعادة محاولة + تمييز
الانقطاع عن الخطأ + **عزلُ ما يرفضه الخادم** 🔄 م.6.2)، `ApiClient` (**وترويسةُ `X-Institute`**
🔄 م.6.3)، تخزين آمن للتوكن، **وطبقةُ الحالة المشتركة** 🔄 م.6.3: `SessionController` (الدخولُ
واللقطةُ ومبدّلُ المعاهد) و`SyncController` و`BootstrapSnapshot`. و**`packages/mousqe_ui`** ✅: ثيم
المعهد الثلاثي وRTL والمكوّنات المشتركة — ومنها 🔄 م.6.3 `LoginForm` و`SyncBar`. **ولا تعتمد
`mousqe_ui` على `mousqe_core` عمداً**: مكوّناتُها تستقبل حالةً جاهزة، فما يربطهما يبقى في
التطبيق.

| التطبيق | المحتوى |
|---|---|
| **الأستاذ** (م.5) ✅ | حلقاتي · شاشة تفقّد بضغطة واحدة تعمل **أوف-لاين** · سجل الجلسات · ملف الطالب · تسجيل التسميع · النقاط · مؤشّر حالة المزامنة |
| **الديسكتوب/ويندوز** (م.6) ✅ **منفَّذ م.6.1–6.6** | كل ما سبق + إدارة الطلاب/الحلقات/الدورات · الداشبورد · التقارير والطباعة · نسخ احتياطي محلي · **والحكمُ في التعارضات** لا عرضُها · **وما تحتويه اللوحة**: المستخدمون والأدوار · بياناتُ الدخول وبطاقاتُها · بياناتُ المعهد وألوانُه · إدارةُ المعاهد. جمهورُه `supervisor` و`admin` و`super_admin` و`developer` ([APPS-FEATURES.md §4](APPS-FEATURES.md)) |
| **الأهل** (م.7) | متابعة أبنائي · إشعار فوري عند تسجيل غياب · تقديم إذن مسبق · التقرير الأسبوعي/الشهري · تقدّم الحفظ |
| **الطالب** (م.8) | حضوري ونسبتي · ترتيبي في الحلقة · وِرد اليوم وتقدّم الحفظ · الإعلانات |

---

## 8. الهوية البصرية

- 🔄 **م.5.1: `design-tokens.json` صار الافتراضيَّ لا المفروض.** لكل معهد ثلاثةُ ألوان في
  `institutes.settings['theme']` تحكم اللوحة والتقارير المطبوعة والتطبيقات الأربعة معاً، والسلالمُ
  تُشتقّ منها **خوارزمياً بنفس النسب** في `App\Support\InstituteTheme` و`MousqeTheme` — فالتطابق
  بين الويب والتطبيقات مضمونٌ مهما اختار المعهد. ومعهدٌ لم يضبط ألوانه يعود إلى هذه اللوحة.
- 🎨 **م.5.3: الخلفيةُ بيضاءُ دائماً في التطبيقات.** اللونُ الثالث (`surface`) **ليس طلاءَ صفحة**:
  كان يُسنَد خاماً إلى خلفية الشاشة، فمعهدٌ اختار لوناً مشبعاً غرقت واجهتُه فيه وذابت بطاقاتُه
  وحواراتُه في خلفيتها. صار مصدرَ حرارةٍ يُشتقّ منه بياضٌ دافئ (خلطٌ 92% نحو الأبيض) وسلّمُ أسطحٍ
  متدرّج؛ والهويةُ تظهر في الترويسة الملوّنة والأزرار والحدود. `primary` و`secondary` يبقيان خامين.
- **الخطوط:** *Reem Kufi* / *Noto Kufi Arabic* للعناوين والشعار + *IBM Plex Sans Arabic* أو *Tajawal* للنصوص.
- ✅ **لوحة افتراضية** إلى حين وصول الشعار: أخضر عميق `#0F5132` · ذهبي `#C9A227` · رملي `#F7F3EA` · فحمي `#1C1B19`.
- عناصر زخرفية إسلامية خفيفة (إطارات هندسية) في الترويسات وأغلفة الـ PDF دون إثقال الواجهة.
- وضع فاتح/داكن، وحجم خط قابل للتكبير.

- ✅ **وصل الشعار 2026-09-10** — «معهد عمر الفاروق لتحفيظ القرآن الكريم»، في
  [`design/logo/`](../design/logo/) ومعه README يشرح مشتقّاتِه. وألوانُه **مقيسةٌ من الملف**:
  المارون `#7F080A` والمشمشي `#FFBF9B` — وهما نفسُ ما تضبطه بيانات المعهد أصلاً.

> 🔄 **وما وُعد به هنا لم يعد صحيحاً، والوعدُ نفسُه سبق م.5.1.** كان النصّ: «نعمل باللوحة المؤقّتة
> **ونستبدلها من `design-tokens.json`** عند وصول الشعار». ثمّ غيّرت م.5.1 المعمارية: صار لكل معهدٍ
> ثلاثةُ ألوانٍ في `institutes.settings['theme']`، و`design-tokens.json` (ومعه
> `InstituteTheme::DEFAULTS`) صار **الاحتياطيَّ لمعهدٍ لم يضبط ألوانه** لا اللوحةَ المفروضة.
>
> فلو صُبغ الافتراضيُّ بمارون عمر الفاروق لَصار **كلُّ معهدٍ جديد مارونيّاً** حتى يغيّره صاحبُه —
> وهو عكسُ ما بُنيت له الميزة. الأخضرُ والذهبيُّ يبقيان لوحةً محايدة، وألوانُ هذا المعهد **بيانات**
> يضبطها مديرُه من شاشة «بيانات المعهد».
>
> ⚠️ **وأيقونةُ التطبيق استثناءٌ لذلك**: تُخبز في البناء ولا تُقرأ من `/bootstrap`، فلا تتبع كلَّ
> معهد. صارت شعارَ عمر الفاروق لأنه صاحبُ النظام، **ويوم يُنشر لمعهدٍ ثانٍ يلزم بناءٌ بنكهةٍ
> أخرى** — بندٌ لمرحلة النشر (م.9).

---

## 9. مراحل التنفيذ

| # | المرحلة | المخرجات | التقدير | الحالة |
|---|---|---|---|---|
| 0 | التهيئة | نقل الباك إند، `git init`، melos، `design-tokens.json` | يوم | ✅ **منفَّذة** |
| 1 | نواة الباك إند | 38 migration، 37 نموذجاً، 18 enum، 25 factory، 4 بذور، الأدوار والصلاحيات، 25 اختباراً | ٤–٥ أيام | ✅ **منفَّذة** — 58/58 اختباراً |
| 2 | لوحة التحكم — الإدارة | 14 شاشة Livewire، 5 إجراءات دومين، هوية بصرية RTL، 35 اختباراً | ٦–٨ أيام | ✅ **منفَّذة** — 93/93 اختباراً |
| 3 | التفقّد والتقارير | شاشة التفقّد، الإحصاء والترتيب، الداشبورد، التقارير والطباعة، طبقة `app/Queries/` | ٥–٦ أيام | ✅ **منفَّذة** — 135/135 |
| 4 | طبقة API والمزامنة | Sanctum، Resources، `sync/pull` و`sync/push`، `change_log`، حلّ التعارضات | ٥–٦ أيام | ✅ **منفَّذة** — 156/156 |
| 4.5 | النقاط والتسميعات والإحصائيات | نظام نقاط كامل، تسجيل التسميع في الجلسة، شاشة إحصائيات ورسوم، القفل بصلاحية، تنظيف الحمولة الميتة | ٤–٥ أيام | ✅ **منفَّذة** — 201/201 |
| 4.6 | إدارة المعاهد وحماية اللوحة | دور `developer`، `Gate::before` للأدوار العابرة، `permission:` على كل اللوحة، CRUD المعاهد ومبدّلها، المستخدمون والأدوار، لوحة المعاهد، أدوات المبرمج | ٤–٥ أيام | ✅ **منفَّذة** — 255/255 |
| 4.7 | الحسابات المولَّدة وبيانات الدخول | الدخول باسم مستخدم، توليد الحساب مع سجلّه عبر المراقبين، إقفال الحساب، شاشة بيانات الدخول وبطاقاتها، حذف التسجيل الذاتي | ٢–٣ أيام | ✅ **منفَّذة** — 279/279 |
| — | **توثيق المعمارية** | `ARCHITECTURE.md` · `API.md` · `SYNC-PROTOCOL.md` · `CLIENTS.md` — عقد المرحلة 5 قبل كتابة كودها | يوم | ✅ **منفَّذ** 2026-09-06 |
| 5.1 | **الأساس الخادمي وتوحيد الهوية** | `change_log` بالاتجاهين على مستوى الصفّ، الأدوار في الدخول، ثيم المعهد الثلاثي، حساب دقائق التأخير، سدّ ثغرة العبور بين المعاهد | ٢–٣ أيام | ✅ **منفَّذة** — 311/311 اختباراً |
| 5.2 | **الحزمتان المشتركتان** | `mousqe_core` (freezed · drift · ApiClient · SyncEngine) و`mousqe_ui` (ثيم المعهد · RTL · مكوّنات) | ٣–٤ أيام | ✅ **منفَّذة** — [CHECKPOINT-PHASE-5.2.MD](CHECKPOINT-PHASE-5.2.MD) |
| 5.3 | **تطبيق الأستاذ** | ثماني شاشات أوف-لاين كاملة فوق الحزمتين · الجلسة تُفتح بلا شبكة · ردمُ `change_log` | ٣–٤ أيام | ✅ **منفَّذة** — 324 خادماً (يومَها) + 56 فلاتر · مُجرَّبة على محاكٍ — [CHECKPOINT-PHASE-5.3.MD](CHECKPOINT-PHASE-5.3.MD) |
| 5.4 | **التصحيح والحذف أوف-لاين** | تصحيحُ التسميع والمنحة في مكانهما بمعرّفٍ يولّده العميل، وحذفُهما · `points.delete` · مسودّتان محليّتان (`schemaVersion` 3) · مدى التسميع مقيَّداً بالجزء في التطبيق واللوحة | يوم | ✅ **منفَّذة** — 337 خادماً + 69 فلاتر — [CHECKPOINT-PHASE-5.4.MD](CHECKPOINT-PHASE-5.4.MD) |
| 6.1 | **الأساس الخادمي للديسكتوب** | طريقُ مديرِ المعهد والمشرف إلى الـ API + مبدّلُ المعاهد + نقاطُ التعارضات + عزلُ العملية المسمومة | يوم | ✅ **منفَّذة** — 364 اختباراً — [CHECKPOINT-PHASE-6.1.MD](CHECKPOINT-PHASE-6.1.MD) |
| 6.2 | **سطحُ الإدارة في الـ API + الحزمتان** | نقاطُ المعاهد والمستخدمين والأدوار وبيانات الدخول، وأنواعُ عملياتِ الإدارة اليومية؛ وفي `mousqe_core` عزلُ العملية المرفوضة | ٢–٣ أيام | ✅ **منفَّذة** — 382 خادمياً + 33 في الحزمة — [CHECKPOINT-PHASE-6.2.MD](CHECKPOINT-PHASE-6.2.MD) |
| 6.3 | **هيكل تطبيق الديسكتوب** | النافذةُ والدخولُ والقائمةُ الجانبية ومبدّلُ المعاهد وشريطُ المزامنة · وحسمُ `go_router` | يومان | ✅ **منفَّذة** — 88 في Dart — [CHECKPOINT-PHASE-6.3.MD](CHECKPOINT-PHASE-6.3.MD) |
| 6.4 | **التفقّد والتصحيح** | كشفُ الحلقات والتفقّدُ بسلطة التصحيح الرجعي والقفل وتفقّدِ الأساتذة · والخطوة 3 من السيناريو المرجعي | يومان | ✅ **منفَّذة** — 127 في Dart + 387 خادمياً — [CHECKPOINT-PHASE-6.4.MD](CHECKPOINT-PHASE-6.4.MD) |
| 6.5 | **الإدارة اليومية وسطحُ الإدارة** | الاستمارةُ والتسجيلُ والنقلُ والأعذارُ وبنيةُ الدورة والمناهجُ والمستخدمون والبطاقاتُ وبياناتُ المعهد والمعاهد | يومان | ✅ **منفَّذة** — 160 في Dart + 393 خادمياً — [CHECKPOINT-PHASE-6.5.MD](CHECKPOINT-PHASE-6.5.MD) |
| 6.6 | **الداشبورد والتقارير والتعارضات** | إحصاءاتٌ تُحسب محلياً · طباعةٌ من الجهاز بـ`pdf`+`printing` · شاشةُ التعارضات · نسخٌ احتياطي بـ`VACUUM INTO` | يومان | ✅ **منفَّذة** — 189 في Dart + 394 خادمياً — [CHECKPOINT-PHASE-6.6.MD](CHECKPOINT-PHASE-6.6.MD) |
| — | **✅ المرحلة 6 مكتملة** | `apps/admin_desktop/` **خمسةَ عشرَ باباً من خمسةَ عشر** — ولم يبقَ ما يضطرّ المشرفَ أو مديرَ المعهد إلى فتح المتصفّح إلا رفعُ الشعار | — | ✅ [PHASE-6-STAGES.MD](PHASE-6-STAGES.MD) |
| 7.1 | **الأساس الخادمي لولي الأمر** | `session_date` في سجلّ الحضور · نقطتان جديدتان (الأعذارُ وتقدُّمُ الحفظ) · `ProgressResource` و`AbsenceExcuseResource` · `null` لا صفر في المنحنى · نزعُ `reports.view` | يوم | ✅ **منفَّذة** — 407 اختباراً (كانت 394) — [CHECKPOINT-PHASE-7.1.MD](CHECKPOINT-PHASE-7.1.MD) |
| 7.2 | **`mousqe_core`: مستودعُ ولي الأمر** | خمسُ نقاطٍ في `ApiClient` · `GuardianRepository` يقرأ REST ويخزّن اللقطة مع تاريخها · بلا `SyncEngine` ولا `schemaVersion` جديد | يوم | ✅ **منفَّذة** — 147 اختباراً في الحزمة — [CHECKPOINT-PHASE-7.2.MD](CHECKPOINT-PHASE-7.2.MD) |
| 7.3 | **تطبيق الأهل** | `apps/guardian/` — خمسُ شاشات فوق الحزمتين · `SnapshotView` يحمل «البيانُ القديم يُعلن قِدَمه» · منحنىً يتخطّى ما لم يُقَس | ٢–٣ أيام | ✅ **منفَّذة** — 8 في التطبيق · 210 في مساحة العمل — [CHECKPOINT-PHASE-7.3.MD](CHECKPOINT-PHASE-7.3.MD) |
| 7.4 | **الإشعارُ الفوري** | `PushNotifier` بتنفيذَين · إشعارٌ عند إغلاق الجلسة وعند البتّ في الإذن · تمريرُ التوكن عبر `/devices/register` القائمة · وربطُ مشروع `mousqe` | يوم | ✅ **منفَّذة** — 419 خادمياً · 212 في Dart · **والإشعارُ وصل شريطَ المحاكي بنصّه العربي** — [CHECKPOINT-PHASE-7.4.MD](CHECKPOINT-PHASE-7.4.MD) |
| 8.1 | **الأساس الخادمي للطالب** | `standing` تُحسب في الخادم فيخرج من `sync/pull` · نقاطُه · **الإعلاناتُ بطرفيها** — جدولٌ قائمٌ منذ م.1 بلا شاشةٍ ولا نقطة · والبذرةُ تنتج تسميعاتٍ ونقاطاً | يومان | ✅ **منفَّذة** — 437 خادمياً · 222 في Dart — [CHECKPOINT-PHASE-8.1.MD](CHECKPOINT-PHASE-8.1.MD) |
| 8.2 | **تطبيق الطالب** | `apps/student/` — خمسُ شاشات فوق الحزمتين | يومان | ⬜ |
| 9 | النشر | استضافة، نسخ احتياطي مجدول، مثبّت ويندوز، بناء المتاجر، دليل استخدام عربي | ٣–٤ أيام | ⬜ |

---

## 10. اقتراحات للتوسّع (مرتّبة بالأولوية)

**قيمة عالية / كلفة منخفضة**

1. **الأذونات المسبقة من الأهل** — ✅ الجدول جاهز (`absence_excuses`)؛ تقلّل الغياب "غير المبرَّر" جوهرياً.
2. **إشعارات فورية للأهل** عند تسجيل غياب — ✅ الجدول جاهز (`devices`)؛ البديل الطبيعي عن الواتساب المؤجَّل.
3. **تنبيه تلقائي عند تجاوز حدّ الغياب** (مثلاً ٣ غيابات متتالية) للمشرف والأستاذ.
4. **QR لكل طالب** — بطاقة عضوية يمسحها الأستاذ لتفقّد أسرع (`students.registration_no` جاهز كمحتوى للرمز).
5. **استيراد/تصدير Excel** للطلاب والحلقات — إدخال أولي سريع لبيانات ٤٠٠ طالب.

**قيمة عالية / كلفة متوسطة**

6. ✅ **سجلّ الحفظ والمراجعة والمناهج** — `curricula` + `curriculum_items` + `student_curriculum_progress`
   + `memorization_logs` **منفَّذة في المرحلة 1**؛ يبقى بناء الواجهات وخريطة تقدّم الطالب في المصحف.
7. **الشهادات وكشوف الدرجات** — توليد PDF بالهوية البصرية عند نهاية كل دورة (`evaluations` جاهز).
8. ✅ **لوحة المسابقات** — منفَّذة في الباك إند (م.4.5): نظام نقاط كامل (قرآن + حديث + متون + حضور +
   تقديرية)، وترتيب الطلاب في تقرير نقاط الحلقة، وشاشة إحصائيات بلوحَي الأكثر والأقل.
   يبقى: الشارات وجدار الشرف في تطبيق الطالب (م.8).
9. **الرسوم والاشتراكات** — إن كان المعهد يتقاضى رسوماً: أقساط، إيصالات، تقارير مالية.
10. **حضور الأساتذة والرواتب/المكافآت** — ✅ `teacher_attendances` جاهز، يبقى بناء التقارير.

**استراتيجي / لاحقاً**

11. ✅ **تعدّد المعاهد (SaaS)** — جاهز بنيوياً: `institute_id` في كل جدول + وضع الفرق في Spatie مفعّل؛
    يحتاج فقط شاشة إدارة مركزية.
12. **واتساب** — عند رغبتك: `wa.me` أو Cloud API خلف واجهة Driver.
    ⚠️ 🔄 **تصحيح (م.4.5): `report_templates` لم يعد جاهزاً — حُذف الجدول وكل كوده.** كان قوالب بلا قناة
    إرسال، أي حمولة ميتة تُصان بلا مقابل. يُعاد بناء طبقة القوالب **مع** `MessageDriver` لا قبله،
    فتُصمَّم على حاجة القناة الفعلية. مصفوفة `variables` في `BuildCircleDailyReport` باقية وهي
    نصف العمل.
13. **تقارير ذكية** — ملخّص شهري تلقائي بالعربية يحلّل اتجاه الحضور ويقترح تدخّلات.
14. **مواقيت الصلاة والتقويم الهجري** داخل الداشبورد وربطها بجدولة الدوامات
    (`students.registration_date_hijri` بداية).

---

## 11. خارج نطاق هذه الخطة

- **إرسال رسائل الواتساب** — مؤجَّل بطلبك. المعمارية تحفظ مكانه: `report_exports` جاهز، ومصفوفة
  `variables` في `BuildCircleDailyReport` تعطي كل أرقام التقرير جاهزةً للقالب. سيُضاف لاحقاً
  `MessageDriver` (wa.me / Cloud API) **ومعه** جدول القوالب — 🔄 حُذف `report_templates` في م.4.5 لأنه
  كان حمولة ميتة تُصان بلا قناة إرسال.

---

## 12. التحقق والاختبار

**الباك إند** (`cd backend`)

```bash
php artisan migrate:fresh --seed          # معهد + دورة + دوامان + 6 حلقات + 78 طالباً + 30 جلسة تفقّد
php artisan test --compact                # 437 حالياً (435 تمرّ + 2 متجاوَزان)
vendor/bin/pint --dirty --format agent    # التنسيق قبل أي إنهاء
composer run dev                          # serve + queue + vite
php artisan serve --host=0.0.0.0          # لتجربة تطبيق فلاتر على محاكٍ (10.0.2.2:8000)
```

🔴 **`sync:backfill-change-log` خطوةٌ واجبة على أي قاعدةٍ فيها بياناتٌ سابقة لمراقب التغييرات**
(بيانات ما قبل م.5.1، أو استيرادٌ بالجملة). `sync/pull` يقرأ `change_log` وحده، فالصفُّ الذي لم
يمرّ بالمراقب لا يراه عميلٌ أبداً — ويخرج معهدٌ عامرٌ بتطبيقاتٍ فارغة. البذرُ يستدعيه تلقائياً،
والنشرُ لا. التفصيل في [SYNC-PROTOCOL.md §10](SYNC-PROTOCOL.md) البند 9.

**تطبيقات فلاتر** (من الجذر)

```bash
dart run melos bootstrap                  # أو flutter pub get في كل حزمة
cd packages/mousqe_core && flutter test   # 29
cd packages/mousqe_ui   && flutter test   # 8
cd apps/teacher         && flutter test   # 32
cd apps/teacher && flutter run -d emulator-5554
```

حسابُ التجربة على المحاكي: **`teacher9001` / `secret-pass`** — أستاذٌ في معهد النور له حلقةٌ في
الدورة الجارية، وألوانُ معهده مضبوطة فتُرى فور الدخول.

حسابات البذر: `admin@mousqe.test` (مدير معهد) · 🔄 م.4.6 `super@mousqe.test` (مشرف أعلى) ·
`dev@mousqe.test` (مبرمج) — وكلمة المرور `password`

**اختبارات منفَّذة ✅ (المرحلة 1):**

- `StudentTest` — توليد UUID، الاسم الثلاثي، حقول الاستمارة، الأب والأم، الصفات المتعدّدة، منع تكرار الصفة.
- `CourseCircleTest` — الحلقة في دوام واحد ضمن الدورة، تكرارها في دورة أخرى، الأساتذة المسنَدون.
- `AttendanceSessionTest` — منع جلستين في اليوم نفسه، سجل واحد لكل طالب، قابلية التعديل حسب الحالة.
- `EnrollmentTest` — تسجيل واحد لكل حلقة، نطاق `active`، حفظ سجل الحلقات السابقة.
- `CurriculumSeederTest` — المناهج الثلاثة، الأجزاء الثلاثون، بنود الحديث والمتون، عدم التكرار.
- `RolesAndPermissionsSeederTest` — الأدوار الستة، حدود كل دور، عزل الدور بالمعهد.

**اختبارات منفَّذة ✅ (المرحلة 2):**

- `StudentTransferTest` — إغلاق التسجيل القديم وفتح الجديد، قيد النقل، اختفاء الطالب من قائمة الحلقة
  القديمة مع بقاء سجل حضوره، ورفض النقل إلى الحلقة نفسها أو بلا تسجيل جارٍ.
- `CourseResetTest` — الاستنساخ ينسخ البنية دون تسجيلات ولا تفقّد، الدوام المستنسَخ يحتفظ بأيامه،
  عدّادات الدورة الجديدة صفر مع بقاء سجل السابقة، وتفعيل دورة يُلغي تفعيل ما قبلها، والاستنساخ مرّتين
  لا يكرّر الحلقات.
- `StudentRegistrationTest` — الاستمارة تحفظ كل أقسامها، منع تكرار رقم المعرف، إلزامية الاسم الثلاثي،
  تحميل بيانات التعديل، إعادة بند محفوظات إلى «لم يبدأ» دون فقد ملاحظاته، وتصفية القائمة.
- `AdminPanelTest` — عرض الشاشات الأربع عشرة، حجب الزائر، إنشاء أول معهد، دورة رمضان وتفعيلها، منع
  تاريخ نهاية سابق للبداية، الاستنساخ من الشاشة، أيام الدوام، منع حذف دوام عامل، تشغيل حلقة، التسجيل
  والنقل والانسحاب، رفض تجاوز الطاقة، إسناد أستاذ وإنهاؤه، توليد مفتاح الواصفة، الصفات الخاصة
  بالمعهد، إدارة المناهج، وعدّادات الداشبورد.

**اختبارات منفَّذة ✅ (المرحلة 4):**

- `Api/AuthTest` — دخول صحيح بتوكن، رفض كلمة مرور خاطئة، `/me` وإبطال التوكن بالخروج، رفض طلب بلا توكن.
- `Api/SyncPushPullTest` — فتح جلسة ثم تفقّد يُنشئ صفَّي `change_log`، إعادة إرسال نفس `op_uuid` تُتجاهل،
  `since` يعيد التغييرات الصحيحة فقط ويحدّث مؤشّر الجهاز، لا تسرّب بين المعاهد.
- `Api/SyncConflictTest` — كتابة أقدم تصل متأخرة تُرفض وتُسجَّل في `sync_conflicts`، كتابة أحدث تستبدل
  القديمة بلا تعارض.
- `Api/ScopeTest` — الأستاذ يرى حلقاته فقط ومعزول عن معهد آخر، ولي الأمر يرى أبناءه فقط.
- `Api/DeviceRegistrationTest`, `Api/BootstrapTest`, `Api/StudentSelfTest` — تفصيلها في
  [CHECKPOINT-PHASE-4.MD](CHECKPOINT-PHASE-4.MD) §9.

**اختبارات منفَّذة ✅ (المرحلة 4.5):**

- `Support/QuranLinesTest` — 114 مدخلاً في جدول الأسطر، المجموع ≈9060، المدى الجزئي والعابر لسورتين،
  الأجزاء الثلاثون تغطّي كل السور.
- `Actions/StudentPointsTest` — رفض الجلسة المقفلة والآية خارج السورة والمدى المقلوب، المكرّر لا يُحتسب،
  معامل التقدير، النقاط السالبة بجلسة وبدونها، جمع المصادر الخمسة ضمن مدى.
- `Livewire/SessionRecitationTest` — افتراضات نموذج التسميع (آخر جزء + أوّل فجوة غير مغطّاة)،
  تجميد الأسطر والنقاط، الملاحظة بقطبيتها، **الأستاذ لا يرى زر القفل ويُرفض على الخادم** والمشرف يقفل.
- `Queries/StatsQueryTest` — الأكثر/الأقل لكل مقياس، وحساب «الأدب».
- `Reports/CirclePointsReportTest` — الترتيب تنازلي، التعادل يتشارك الرتبة، المدى الزمني، صفحة الطباعة.
- `Livewire/CurriculumItemsTest` + `CurriculumProgressTest` — ثبات أجزاء القرآن، العدّادات، اشتقاق نقاط
  الحديث والمتون ووصولها إلى مجموع الطالب.
- `Livewire/StatsScreenTest` — 24 تركيبة فلتر تُصيَّر بلا خطأ.

التفصيل في [CHECKPOINT-PHASE-4.5.MD](CHECKPOINT-PHASE-4.5.MD) §14.

**اختبارات منفَّذة ✅ (المرحلة 4.6):**

- `Authorization/PanelAccessTest` — **الأهمّ**: مصفوفة 17 مساراً × 7 أدوار (المسموح 200 والممنوع 403)،
  الطالب لا يصل `/institute` ولا `/settings/*` ولا `/students` ولا `/attendance`، ولي الأمر لا يصل
  `/students` ولا `/teachers`، المبرمج يصل كل شيء عبر `Gate::before`، وصفحات الطباعة خلف `reports.view`.
- `Actions/InviteUserTest` — الدور يُسنَد في المعهد الصحيح ولا يظهر في غيره، إنشاء سجلّ الأستاذ وربط
  سجلّ قائم، رابط تعيين كلمة المرور، **ومدير المعهد لا يمنح `super_admin` ولا `developer`**.
- `Livewire/InstituteSwitcherTest` — التبديل يغيّر السياق ويُرفض لمعهد لا دور فيه، **ومن لا معهد له
  يعود بـ `null` لا بأوّل معهد فعّال**، ومعهد الجلسة المنتهي يُنسى.
- `Queries/InstituteAdminQueryTest` — اللوحة تعبر المعاهد، نسبة كل معهد ونقاطه، **وعدد الاستعلامات لا
  يتغيّر بزيادة المعاهد**.
- `Livewire/SuperAdminPanelTest` — الشاشات السبع تُصيَّر، إنشاء معهد يبذر دورة مسودّة، المعهد الحالي
  لا يُحذف، دعوة مستخدم بدور، حساب دخول لأستاذ قائم، وتعليم تعارض مزامنة كمراجَع.

التفصيل في [CHECKPOINT-PHASE-4.6.MD](CHECKPOINT-PHASE-4.6.MD) §9.

**اختبارات منفَّذة ✅ (المرحلة 4.7):** 24 اختباراً — توليد الحساب مع سجلّه، تفرّد اسم المستخدم،
الدخول بالاسم أو بالبريد، رفض الحساب المقفل على اللوحة والـ API، تصدير البطاقات و CSV.
التفصيل في [CHECKPOINT-PHASE-4.7.MD](CHECKPOINT-PHASE-4.7.MD).

**اختبارات مطلوبة في مراحلها:**

- ⚠️ **الفجوات المكتشفة في توثيق 2026-09-06 غير مغطّاة باختبار** — §13 البنود الثلاثة الأخيرة:
  كتابةُ اللوحة لا تُسجَّل في `change_log`، وثلاثةُ فروع دفعٍ بلا تحقّق من المعهد، و`user.roles`
  الفارغة. كلٌّ منها يستحقّ اختباراً مع إصلاحه.

**فلاتر** (`cd mousqe`)

```bash
melos bootstrap
melos run test                             # وحدة + widget
flutter run -d windows      (apps/admin_desktop)
flutter run -d android      (apps/teacher)
```

**سيناريو E2E يدوي (اختبار القبول):**

1. من اللوحة: أنشئ دورة ← دواماً ← حلقة ← ٥ طلاب باستمارة التسجيل الكاملة.
2. من تطبيق الأستاذ: **أطفئ الشبكة**، سجّل التفقّد (حاضر/غائب/متأخّر/إذن)، أغلق الجلسة.
3. من الديسكتوب: عدّل حالة أحد الطلاب في نفس الجلسة **وهو أوف-لاين أيضاً**.
4. أعد الاتصال في الجهازين ← تأكّد من: توافق البيانات، وظهور التعارض في شاشة المشرف.
5. من اللوحة: تحقّق من نسبة الحضور والتصنيف اليومي/الكلي، وصدّر PDF أسبوعياً واقرأه (تشكيل عربي سليم، RTL، الشعار).
6. أنشئ دورة جديدة ← تأكّد من تصفير العدّادات مع بقاء سجل الطالب في الدورة السابقة.

---

## 13. مخاطر ونقاط مفتوحة

| البند | الحالة |
|---|---|
| ~~**ملف الشعار**~~ | ✅ **وصل 2026-09-10** — في `design/logo/` بالأصل والمشتقّات، ومنه أيقوناتُ المشغّل لتطبيقَي الأستاذ وولي الأمر. و**لم تُصبَغ به اللوحةُ الافتراضية** عمداً: هي احتياطيٌّ لكل معهد منذ م.5.1، وألوانُ هذا المعهد بيانات (§8) |
| **الاستضافة** | ⚠️ غير محدّدة (Laravel Cloud / VPS / Hostinger) — تُحسم قبل المرحلة ٩ |
| ~~**حساب Firebase**~~ | ✅ **سُدَّ في م.7.4**: مشروع `mousqe` مربوطٌ، ومفتاحُ حساب الخدمة في `storage/app/` (مستثنىً بنمطٍ في `.gitignore` بعد أن وقع مرّتين في مجلدٍ متتبَّع). **والنظامُ يبقى عاملاً بلا الحساب** بقناةٍ صامتة — وهو ما جعل المرحلة تُبنى قبل وصوله |
| **iOS** | يتطلب حساب Apple Developer (٩٩$/سنة) وجهاز macOS للبناء — نبدأ بأندرويد فقط ما لم تُطلب iOS |
| **PDF العربي** | `spatie/laravel-pdf` يتطلب Chromium على الخادم — يُثبَّت في المرحلة ٣ |
| **قاعدة بيانات الإنتاج** | التطوير على SQLite؛ الانتقال إلى MySQL/MariaDB يُحسم قبل المرحلة ٩ |
| **المنطقة الزمنية للبيانات القائمة** | 🔴 التطبيق كان يعمل على UTC حتى م.4.5 («اليوم» ينقلب ٣:٠٠ فجراً بتوقيت دمشق)؛ صار `APP_TIMEZONE=Asia/Damascus`. **بيانات كُتبت قبل ذلك تحتاج ترحيلاً زمنياً** — في التطوير `migrate:fresh --seed` يكفي |
| **دقّة جدول أسطر السور** | جدول `Quran::LINES` تقديريّ مشتقّ حسابياً لا منقول عن مصدر رسمي (انحراف 0.12%)؛ استبداله تعديلُ ثابتٍ واحد ولا يمسّ التاريخ لأن الأسطر والنقاط مجمّدة في السجل |
| ~~**`reports.view` لدور ولي الأمر**~~ | ✅ **سُدَّ في م.7.1: نُزعت الصلاحيةُ من الدور.** والبديلُ المرفوض: `reports.panel` جديدةً للطاقم — أدقُّ دلالةً لكنها تلمس الكتالوجَ وستّةَ أدوار لتُغلق باباً واحداً. مُغطّىً في `PanelAccessTest` و`GuardianAppTest` |
| **حجم البيانات** | ≤٢٠ حلقة × ≤٢٠ طالباً ⇒ SQLite محلي ومزامنة كاملة كافيان بلا قلق أداء |
| ~~**🔴 كتابات اللوحة لا تدخل `change_log`**~~ | ✅ **سُدَّ في م.5.1**: التسجيل صار أثراً بنيوياً على كل نموذج ينفّذ `Syncable` — [SYNC-PROTOCOL.md §2](SYNC-PROTOCOL.md) |
| ~~**🔴 المشرف بلا طريق إلى الـ API**~~ | ✅ **سُدَّ في م.6.1**: صار إسنادُ الدور داخل معهد طريقاً ثانياً إلى النطاق بعد السجلّات الثلاثة، ومعه مبدّلُ معاهدَ بترويسة `X-Institute` — [API.md §4](API.md) |
| **🔴 سطحُ الإدارة بلا نقطة API** | 2026-09-07: المعاهدُ والمستخدمون والأدوارُ وبياناتُ الدخول والطلابُ والحلقاتُ تُكتب من اللوحة عبر `app/Actions/` مباشرةً، ولا نقطةَ واحدة لها في `/api/v1`. **حاجبٌ لشاشات إدارة الديسكتوب — نطاق م.6.2** — [CLIENTS.md §5](CLIENTS.md) البند 2ب |
| ~~**⚠️ `user.roles` فارغة في `/auth/login` و`/auth/me`**~~ | ✅ **سُدَّ في م.5.1**: `AuthController::identity()` يحسم النطاق قبل قراءة الأدوار، والدورُ صار أيضاً في `/bootstrap` — [API.md §3.4](API.md) |
| **⚠️ `POST /auth/login` بلا حدّ معدّل** | 2026-09-06: `throttleApi()` غير مستدعى؛ الحدّ 5/دقيقة لِلوحة وحدها عبر Fortify، وكلمات المرور مولَّدة (م.4.7) ⇒ يُسدّ قبل النشر (م.9) |
| ~~**`conflicts.review` صلاحية لا تحرس شيئاً**~~ | ✅ **سُدّت 2026-09-07**: الشاشة خلف `conflicts.review` محصورةً بمعهد المستخدم، ومعها قلبُ الحكم (`OverturnSyncConflict`) — [SYNC-PROTOCOL.md §5](SYNC-PROTOCOL.md) |
| **🔴 صفٌّ خارج `change_log` لا يراه عميلٌ أبداً** | 2026-09-06 (م.5.3): `sync/pull` يقرأ التيّار وحده ولا يمسّ جداول الدومين، فـ`since=0` «التيّارُ من أوّله» لا «لقطةُ الحالة». **سُدَّ** بـ`sync:backfill-change-log` (يجري تلقائياً بعد البذر)، ويبقى **خطوةً واجبة عند النشر** على أي قاعدةٍ قائمة — §12 |
| **🔄 عمليةٌ مسمومة توقف طابور المزامنة** | ✅ **شقُّها الخادمي سُدَّ في م.6.1**: كلُّ عملية في معاملتها، والمرفوضةُ تعود في `failed[]` بـ200 ويمضي الباقي. ⬜ **ويبقى شقُّ العميل**: `mousqe_core` لا يعرف الحقل بعد فيعيد إرسالها كل دورة بلا أن يعرضها — م.6.2 — [SYNC-PROTOCOL.md §3](SYNC-PROTOCOL.md) |
| **⚠️ `change_log` بلا سياسة تقليم** | ينمو بلا حدّ، وجهازٌ جديد يسحب من `since=0` كلَّ تاريخ المعهد — وصار أثقل بعد م.5.1 والردم. مقبولٌ بالحجم المتوقَّع (≤٢٠ حلقة)، ويستدعي «لقطة أولية بدل تيّار من الصفر» قبل م.9 |
| ~~**⚠️ ثلاثة فروع دفع بلا تحقّق من المعهد**~~ | ✅ **سُدَّ في م.5.1**: الثلاثة تمرّ بمساعدات مقيّدة بـ`institute_id` ⇒ 404. مُغطّى بـ`Api/Phase5ContractTest` |

---

## 14. سجل التغييرات على الخطة

| التاريخ | التغيير |
|---|---|
| 2026-09-01 | إضافة استمارة تسجيل الطالب كاملة: البيانات الشخصية، بيانات الأب والأم عبر `guardians`، الحالة الصحية، الصفات التسع كاختيار متعدّد، ومحفوظات القرآن والحديث والمتون عبر `curricula` |
| 2026-09-01 | تنفيذ المرحلتين 0 و1 — انظر [CHECKPOINT-PHASE-1.MD](CHECKPOINT-PHASE-1.MD) |
| 2026-09-01 | نقل `op_uuid` إلى `change_log` بقيد `unique` بدل جدول منفصل |
| 2026-09-01 | إضافة `enrollment_id` إلى `attendances` لربط الحضور بالتسجيل الذي وقع تحته |
| 2026-09-01 | تسمية `PersonalTrait` بدل `Trait` (كلمة محجوزة في PHP)، وجدول الربط `student_trait` |
| 2026-09-01 | إصلاح موروث: تدفّق التسجيل والملف الشخصي كان مكسوراً — وُوئم مع `first_name`/`last_name` في جدول `users` |
| 2026-09-01 | تنفيذ المرحلة 2 — انظر [CHECKPOINT-PHASE-2.MD](CHECKPOINT-PHASE-2.MD) |
| 2026-09-01 | لا مجلد `app/Livewire/`: مكوّنات Livewire 4 أحادية الملف تحت `resources/views/pages/` |
| 2026-09-01 | نقل الطالب بقائمة إجراءات ونافذة تأكيد بدل سحب-وإفلات — يعمل على الجوال ومع قارئ الشاشة |
| 2026-09-01 | إضافة `Weekday` enum (19) لأسماء أيام الأسبوع العربية بترقيم `Carbon::dayOfWeek` |
| 2026-09-01 | الكتابة في `guardian_student` و`student_trait` تمرّ بنموذج الربط لا بـ `attach/sync` — العمودان يحملان `uuid` إلزامياً للمزامنة |
| 2026-09-01 | تنفيذ المرحلة 4 — انظر [CHECKPOINT-PHASE-4.MD](CHECKPOINT-PHASE-4.MD) |
| 2026-09-01 | إصلاح خلل: `TakeAttendance` كان يستبدل `recorded_at` دائماً بوقت وصول الطلب للخادم، ما يُبطل معنى "الأحدث يفوز" في حلّ التعارض — صار يقبل `recorded_at` اختيارياً من الصفّ |
| 2026-09-01 | `App\Support\ApiScope` لا يسقط افتراضياً إلى "أول معهد نشط" كما تفعل `InteractsWithInstitute` في اللوحة — توكن API بلا معهد مرتبط يُرفض صراحةً بدل تخمين معهد خطأ |
| 2026-09-03 | تنفيذ المرحلة 4.5 — انظر [CHECKPOINT-PHASE-4.5.MD](CHECKPOINT-PHASE-4.5.MD) |
| 2026-09-03 | **حذف `report_templates`** وكل كوده: قوالب بلا قناة إرسال = حمولة ميتة. §10 البند 12 صُحِّح تبعاً لذلك |
| 2026-09-03 | **حذف `institutes.timezone`** وضبط `APP_TIMEZONE=Asia/Damascus` — الحقل كان يُكتب ولا يُقرأ، والتطبيق كان يعمل فعلياً على UTC فينقلب «اليوم» ٣:٠٠ فجراً |
| 2026-09-03 | نقاط القرآن تُحتسب **للأسطر الجديدة دون المكرّر**، و`lines`/`new_lines`/`points` تُجمَّد في `memorization_logs` وقت التسجيل حتى لا يعيد تغييرُ الإعدادات كتابةَ تاريخ الطلاب |
| 2026-09-03 | إصلاح خلل: `can()` كانت تعود `false` في كل استدعاء بعد `mount()` لأن مفتاح فريق Spatie لا يُضبط إلا مرّة — أُضيف `bootedInteractsWithInstitute()` فيُحسم المعهد في كل دورة طلب |
| 2026-09-03 | استخراج صيغة نسبة الحضور إلى `App\Support\AttendanceRate` — كان تكرارها متعمَّداً في موضعين، وصار ثلاثة مع `StatsQuery` |
| 2026-09-03 | استعلامات التجميع تنتهي بـ `->toBase()`: تركيب نماذج Eloquent يحوّل `status` إلى enum فيكسر `(string)`، والأخطر أن مقارنة `note_polarity` تفشل **بصمت** فيُحسب مقياس الأدب بالمقلوب |
| 2026-09-03 | مكوّنات Livewire المتداخلة في `resources/views/livewire/` لا في `views/components/` — الأخير مليء بمكوّنات Blade المجهولة فيتعارض الاستدعاء |
| 2026-09-03 | `student_curriculum_progress` أُضيف إليه `points` و`achieved_on` — صفّ التقدّم حالةٌ لا حدث، فبلا تاريخٍ صريح لا تُصفّى نقاطه بمدى زمني |
| 2026-09-03 | تنفيذ المرحلة 4.6 — انظر [CHECKPOINT-PHASE-4.6.MD](CHECKPOINT-PHASE-4.6.MD) |
| 2026-09-03 | 🔒 **اللوحة كلها صارت خلف `permission:`**: كانت خلف `['auth', 'verified']` فقط، فأيّ حساب موثَّق يفتح `/institute` و`/settings/*` وقوائم الطلاب. الـ API كان محميّاً واللوحة لم تكن |
| 2026-09-03 | إضافة دور `developer` وصلاحيتَي `users.invite` و`system.debug`؛ و`admin` و`super_admin` لم يعودا `['*']` متطابقين |
| 2026-09-03 | **الأدوار العابرة للمعاهد تُسنَد بمفتاح فريق `0` لا `null`** خلافاً لملف الخطة الفرعي: `model_has_roles.institute_id` هو `not null` وجزءٌ من المفتاح الأساسي في مخطّط spatie، والفراغ مستحيل على MySQL أبداً |
| 2026-09-03 | `SetPanelInstituteScope` ملحقٌ بمجموعة `web`: بدونه يفشل كل `permission:` على اللوحة، فمفتاح فريق spatie كان يُضبط داخل مكوّن Livewire — بعد الـ middleware بمراحل |
| 2026-09-03 | 🔒 سدّ تسريب عبر المعاهد: السقوط الافتراضي إلى «أوّل معهد فعّال» اقتصر على الأدوار العابرة، وغيرهم يعود بـ `null` — تُوحِّد اللوحةَ مع سلوك `ApiScope` الذي كان يرفض هذه الحالة عمداً |
| 2026-09-03 | شاشات التفقّد خلف `attendance.take` لا `attendance.view` (خلافاً لجدول الملف الفرعي): الأخيرة يملكها الطالب وولي الأمر، فحراستها بها تفتح لوح تفقّد المعهد كلّه لطالب |
| 2026-09-03 | «المستخدمون والصلاحيات» نُقلت من المرحلة 6 إلى 4.6 — تطبيقات فلاتر لا تعمل بلا حسابات مربوطة بسجلّات الأساتذة |
| 2026-09-06 | تنفيذ المرحلة 4.7 — انظر [CHECKPOINT-PHASE-4.7.MD](CHECKPOINT-PHASE-4.7.MD) |
| 2026-09-06 | **الدخول باسم المستخدم لا بالبريد**: `POST /api/v1/auth/login` صار حقلُه `username` يقبل الاسم المولَّد أو البريد، و`email` صار `nullable` — الطالب وولي الأمر لا بريد لهما وهما جمهور التطبيقات |
| 2026-09-06 | **حساب الأستاذ/ولي الأمر/الطالب يولَّد مع سجلّه** عبر المراقبين لا من شاشة المستخدمين — فالتبعية اليدوية التي أُدخلت لأجلها م.4.6 سقطت ([CLIENTS.md §3](CLIENTS.md)) |
| 2026-09-06 | إنشاء [ARCHITECTURE.md](ARCHITECTURE.md) و[API.md](API.md) و[SYNC-PROTOCOL.md](SYNC-PROTOCOL.md) و[CLIENTS.md](CLIENTS.md): `PLAN.md` و`ERD.md` يغطّيان نموذج البيانات وما نُفِّذ، ولا يجيبان عن «كيف تتصل التطبيقات الخمسة» ولا «ما العقد الذي تبني عليه المراحل 5–8». أربعة محاور لا يخدمها ملفٌّ قائم |
| 2026-09-06 | 🔴 **كشفٌ أثناء التوثيق**: `RecordChange` مستدعىً من `SyncPush` وحده — فكتابات اللوحة لا تدخل `change_log` ولا تصل أي عميل، خلافاً لما يصفه §5. حاجب للمرحلة 5 |
| 2026-09-06 | 🔴 **كشفٌ أثناء التوثيق**: حساب `supervisor` بلا سجلّ مرتبط، و`ApiScope` يرفضه بـ422 ⇒ تطبيق الديسكتوب (م.6) بلا طريق إلى الـ API. حاجب للمرحلة 6 |
| 2026-09-06 | ⚠️ **كشفٌ أثناء التوثيق** (تحقُّق تجريبي): `user.roles` تعود `[]` في `/auth/login` و`/auth/me` لأن مفتاح فريق spatie غير مضبوط خارج `institute.scope`؛ اختبار `Api/AuthTest` يمرّ بسبب سياق مسرَّب من عملية الاختبار |
| 2026-09-06 | ⚠️ **كشفٌ أثناء التوثيق**: لا حدّ معدّل على `/auth/login` · `conflicts.review` لا تحرس مساراً · `sync_devices.last_pushed_at` عمود ميت · `scope_key = circle:{uuid}` موثَّق في [ERD.md](ERD.md) وغير منفَّذ · ثلاثة فروع دفع بلا تحقّق من المعهد |
| 2026-09-06 | **المرحلة 5 قُسّمت ثلاثاً** — [PHASE-5-STAGES.MD](PHASE-5-STAGES.MD): 5.1 خادمية · 5.2 الحزمتان المشتركتان · 5.3 التطبيق. التقسيمُ تقسيمُ **مخاطرة** لا زمن: كل مرحلة تُنهي نوعاً من عدم اليقين قبل أن يُبنى فوقها شيء |
| 2026-09-06 | تنفيذ المرحلة 5.1 — انظر [CHECKPOINT-PHASE-5.1.MD](CHECKPOINT-PHASE-5.1.MD) |
| 2026-09-06 | 🔴 **سُدّت الفجوة الحاجبة**: تسجيلُ التغيير انتقل من «استدعاءٍ يدوي في `SyncPush`» إلى **أثرٍ بنيوي على النموذج** — `App\Contracts\Syncable` + `App\Concerns\RecordsSyncChanges` + `App\Support\SyncRecorder`. كتاباتُ اللوحة و`POST /guardian/excuses` تصل العملاء الآن |
| 2026-09-06 | 🔴 **اكتشافٌ أثناء التنفيذ**: الحمولة كانت صفَّ **الجلسة** لا صفوف الحضور — أي أن `sync/pull` لم يكن قابلاً للتطبيق على مخزن العميل أصلاً. صار التسجيل على مستوى **الصفّ** |
| 2026-09-06 | 🔄 **حلُّ التعارض نزل من الجلسة إلى الصفّ** تبعاً لذلك، وتمييزُ الصفّ المزروع عند فتح الجلسة صار بـ`SyncRecorder::withoutDevice()` بدل شرطٍ على مستوى الجلسة |
| 2026-09-06 | 🎨 **ثلاثة ألوان لكل معهد** في `institutes.settings['theme']` تحكم اللوحة والتقارير المطبوعة والتطبيقات الأربعة. `design-tokens.json` صار **الافتراضيَّ لا المفروض**؛ والسلالم تُشتقّ خوارزمياً فلا يُنتج الإدخالُ اليدوي تبايناً غير مقروء |
| 2026-09-06 | ⏱️ **دقائق التأخير تُحسب على الخادم** من `shifts.starts_at` ناقص `late_grace_minutes`، في `TakeAttendance` لا في الشاشة — فيستوي مصدرُ الكتابة. الحالةُ تبقى قرار الأستاذ (لا تحويل تلقائي)، والقيمةُ المُرسَلة صراحةً تغلب المحسوبة |
| 2026-09-06 | تنفيذ المرحلة 5.2 — انظر [CHECKPOINT-PHASE-5.2.MD](CHECKPOINT-PHASE-5.2.MD) |
| 2026-09-06 | تنفيذ المرحلة 5.3 — انظر [CHECKPOINT-PHASE-5.3.MD](CHECKPOINT-PHASE-5.3.MD). **المرحلة 5 مكتملة** |
| 2026-09-06 | 🔴 **`attendance.session.open` كان يمنع السيناريو المرجعي نفسه**: المعرّف يُولَّد على الخادم وحده، فالأستاذُ المنقطع لا يعرف `session_uuid` ليُتبع الفتحَ بـ`attendance.take` في نفس الطابور — أي أن معيار القبول الأول للمرحلة 5.3 كان **غير قابل للتنفيذ**. الحلُّ إضافةٌ متوافقة مع `v1` (§7 من [API.md](API.md)): العميل يولّد `uuid` يُستعمل عند الإنشاء وحده، والخادم يقبل المفتاح الطبيعي `course_circle_uuid + session_date` بديلاً |
| 2026-09-06 | 🔴 **أخطرُ ما كشفته المرحلة — التيّارُ تيّارُ تغييرات لا لقطةُ حالة**: `SyncPull` يقرأ `change_log` وحده ولا يمسّ جداول الدومين، فالصفُّ الذي لم يمرّ بمراقب التغييرات لا سبيل لأي عميل أن يعرفه — لا في `since=0` ولا بعدها. وكان مكتوباً في `SyncRecorder::without()` أن «جهازاً جديداً يسحب من `since=0` فيرى البذرة كاملةً على أي حال»، وهي **حجّةٌ باطلة** صُحّحت. ظهر العطبُ في أوّل تشغيلٍ على محاكٍ: التطبيق يدخل ويرى ثيم المعهد ثم يعرض «لم تُسنَد إليك حلقة» وقاعدةُ البيانات عامرة. أُضيف `sync:backfill-change-log` (مُتماثِل، الأب قبل ابنه) ويجري تلقائياً بعد كل بذرة |
| 2026-09-06 | 🔴 **`SyncPayloadApplier` كان يُسقط `id` الخادمي** (م.5.2): الحمولة تحمل مفاتيح أجنبية بمعرّفات رقمية خادمية، فترْكُ المفتاح الأساسي لعدّاد drift يجعل كلَّ مفتاحٍ أجنبيٍّ يشير إلى لا شيء — صفوفُ الحضور تصل ولا تلتقي جلستَها أبداً بلا خطأٍ ظاهر. كان يُبطل `sync/pull` عملياً |
| 2026-09-06 | 🔴 **`device_uuid` لم يكن يُرسَل في `sync/push`** (م.5.2): بدونه لا يميّز `ResolveAttendanceConflicts` «كتابتي» من «كتابة غيري»، ويبقى `sync_devices.last_pushed_at` فارغاً |
| 2026-09-06 | ⚠️ **ترتيبُ طابور العميل شرطُ صحّة لا تجميل**: الخادم يطبّق الدفعة `foreach`، وفتحُ الجلسة وأولُ تفقّد يقعان في نفس الميلي-ثانية فعلاً — فالترتيبُ بـ`created_at` وحده يتركه لِما تقرّره sqlite. أُضيف عمود `pending_operations.sequence` تصاعدياً يُقرأ ويُكتب ضمن معاملة |
| 2026-09-06 | 🔄 **بلا Riverpod وبلا go_router** خلافاً لِما سمّته §7: حالةُ تطبيق الأستاذ ثلاثةُ `ChangeNotifier` فوق تدفّقات drift، وتنقّلُه ثماني شاشات بلا روابط عميقة. تُعاد المسألة عند الديسكتوب إن احتاج تنقّلاً أعقد |
| 2026-09-06 | 🎨 **الخلفيةُ بيضاءُ دائماً**: كان `surface` (ثالثُ ألوان المعهد) يُسنَد **خاماً** إلى `scaffoldBackgroundColor`، فمعهدٌ اختار رملاً مشبعاً خرجت شاشتُه خردلاً كاملاً، وحوارُ الإقفال يبدو **شفافاً** فوق قائمة الطلاب. صار `surface` مصدرَ حرارةٍ لا طلاءَ صفحة: الصفحةُ لونُه ممزوجاً 92% نحو الأبيض، والبطاقاتُ والحواراتُ بيضاءُ ناصعة، والهويةُ في ترويسةٍ ملوّنة. `primary` و`secondary` يبقيان خامين — العقدُ مع اللوحة واحد. جُرّبت معالجةٌ ثانية (ترويسةٌ بيضاء) على جهازٍ فعلي وحُذفت |
| 2026-09-06 | ⚠️ **صلاحية `INTERNET` كانت في manifest الـdebug وحده**: `flutter create` يضعها هناك لأداة hot reload، والتطبيقُ عميلُ API قبل كل شيء — فبناءُ الإصدار كان يخرج بلا صلاحية شبكة أصلاً |
| 2026-09-06 | **السيناريو المرجعي جُرّب على محاكٍ فعلي** ([SYNC-PROTOCOL.md §9](SYNC-PROTOCOL.md)): وضعُ الطيران ← فتحُ جلسة وتفقّدُ 13 طالباً وإقفالُها أوف-لاين ← إعادةُ الشبكة ⇒ جلسةٌ واحدة على الخادم بمعرّف العميل بحالاتٍ مطابقة. تبقى الخطوة 3 (جهازٌ ثانٍ يعدّل بالتوازي) حتى م.6 |
| 2026-09-07 | ✏️ **تصحيحُ التسميعات والنقاط في مكانها** (امتدادُ م.4.5 في اللوحة): كانت تُسجَّل أو تُحذف ولا تُصحَّح، فتقديرٌ أو مدىً خاطئ يعني حذفاً وإعادةً — وهو ما كان يفسد حسابَ «الأسطر الجديدة». و`BuildStudentCoverageMap` كان يستثني السجلَّ قيدَ التعديل أصلاً، لكن لا شيء كان يوصل `editingId` من الواجهة. و`awarded_by` يبقى لصاحب المنح الأصلي لا لمن صحّحه لاحقاً. الحارسُ نفسه على التعديل والحذف: تُرفض الجلسةُ المقفلة وسجلٌّ لا يخصّ هذا الطالب (المعرّف يصل من العميل) |
| 2026-09-07 | ✅ **المرحلة 5.4 — التصحيح والحذف من عميلٍ أوف-لاين.** `recitation.save` و`points.award` كانتا تسجيلاً فقط: كلُّ دفعةٍ تُنشئ صفّاً جديداً، فالأستاذ الذي أخطأ في المدى أو التقدير لا يملك من جهازه إلا أن يترك الخطأ — لا مفتاحَ أساسياً عنده يشير به إلى صفٍّ قد لا يكون أُنشئ على الخادم بعد. الحلُّ نفسُ حلِّ الجلسة في م.5.3: **العميل يولّد المعرّف**، فيصير التصحيحُ إعادةَ إرسالٍ بنفس `uuid` وبـ`op_uuid` جديد. وأُضيف نوعُ عمليةٍ `points.delete` — [API.md §6](API.md) |
| 2026-09-07 | ⚠️ **الحذف لا يُرجع 404 حين لا يجد صفّه**: العميلُ قد يصفّ الحذف مرّتين أو يحذف ما حذفه غيرُه، وعمليةٌ واحدة مرفوضة تُعلّق الطابور كلَّه خلفها (§13). فحذفُ ما لا وجود له **نتيجةٌ محقَّقة** ⇒ العملية `applied` بلا صفٍّ يسجّلها. أمّا معرّفٌ من معهدٍ آخر فمحاولةُ عبور، وردُّها 404 كما كان |
| 2026-09-07 | مخزنُ العميل `schemaVersion` 2 ⇒ 3: مسودّتا التسميع والنقاط (`local_recitations` · `local_points`) — بهما يرى الأستاذ ما سجّله **قبل** أن يؤكّده الخادم، فيملك تصحيحَه وحذفَه أوف-لاين. نفسُ طبقة المسودّة التي حكمت التفقّد في م.5.3 |
| 2026-09-07 | إنشاء [APPS-FEATURES.md](APPS-FEATURES.md): الملفات الستّة تصف **بنية** النظام، ولا يجيب أيٌّ منها عن «ما الذي يستطيع مستخدمُ كلِّ تطبيق أن يفعله به؟» — محورٌ توثيقيٌّ جديد بحسب سياسة التوسّع في رأس هذا الملف |
| 2026-09-07 | 📄 إنشاء [APPS-FEATURES.md](APPS-FEATURES.md): الستّةُ القائمة تصف **بنية** النظام وعقودَه ولا يصف أيٌّ منها **قدرات مستخدمه**؛ وميزاتُ الأستاذ كانت متناثرةً في أربعة ملفات، وميزاتُ الثلاثة الباقية سطراً واحداً لكلٍّ منها في §7 — أقلَّ ممّا يكفي لبدء م.6. محورٌ توثيقي جديد لا قسمٌ في ملف قائم: حشوُه في [CLIENTS.md](CLIENTS.md) يطمس سؤالَه («من يكتب ماذا» لا «ماذا يفعل المستخدم») |
| 2026-09-07 | 🔄 **الديسكتوب (م.6) يخدم مديرَ المعهد كما يخدم المشرف** — قرارُ صاحب المشروع. أثرُه أن الحاجب في [CLIENTS.md §5 البند 2](CLIENTS.md) (`InviteUser` ينشئ الحساب بلا سجلّ مرتبط، و`ApiScope` يرفضه بـ422) لم يعد فجوةً تنتظر قراراً بل **البند الأول في م.6**؛ و«ثلاثة أدوار لا تطبيق لها» صارت `developer` وحده |
| 2026-09-07 | 🔄 **الديسكتوب يحتوي ما تحتويه اللوحة** — قرارُ صاحب المشروع: أبوابُ الإدارة الثلاثة التي كانت محصورةً باللوحة (المعاهد والمستخدمون والأدوار · بياناتُ الدخول وبطاقاتُها وإقفالُ الحسابات · بياناتُ المعهد وألوانُه) تدخل تطبيقَ ويندوز، ويستعمله **المبرمج** أيضاً كما المشرفُ ومديرُ المعهد — كلٌّ بقدر صلاحيات دوره. أثرُه أن **سطحَ الإدارة كلَّه يحتاج عقداً في `/api/v1` لم يُبنَ منه شيء**، وهو أكبرُ بنود م.6 حجماً ([APPS-FEATURES.md §4.4](APPS-FEATURES.md) البند 3) |
| 2026-09-07 | ⚖️ **التعارضات: من العرض إلى الحكم، ومن المبرمج إلى أصحابها.** شاشةُ `system/sync-conflicts` كانت خلف `system.debug` بلا نطاق معهد وفعلُها الوحيد «عُلّم مراجَعاً». القرار: تنتقل خلف `conflicts.review` (يملكها `supervisor` و`admin` أصلاً)، ويرى كلٌّ **تعارضاتِ معهده وحدها**، ويملك **قلبَ الحكم** لا تعليمَه. ✅ **نُفِّذت في اللوحة في نفس اليوم** ولم تنتظر م.6. وكشفٌ عند الفحص: **`sync_conflicts` كان بلا `institute_id`** — فالحصرُ هجرةٌ يكتبها `ResolveAttendanceConflicts` وردمٌ للقائم، لا شرطُ استعلام. والقلبُ فعلٌ جديد `OverturnSyncConflict` يمرّ بـ`TakeAttendance` بـ`amend` فيدخل `change_log` ويصل الأجهزة، ويُختم **بزمن القرار لا بزمن الجهاز** وإلا قلبته أوّلُ دفعةٍ لاحقة. 7 اختبارات جديدة ⇒ **344** ([SYNC-PROTOCOL.md §5](SYNC-PROTOCOL.md)) |
| 2026-09-07 | ✅ **المرحلة 6.1 — الأساس الخادمي للديسكتوب** ([CHECKPOINT-PHASE-6.1.MD](CHECKPOINT-PHASE-6.1.MD)). ثلاثةٌ من بنود [APPS-FEATURES.md §4.4](APPS-FEATURES.md) الأربعة سُدَّت، ولم يُكتب سطرُ Dart واحد — كما في م.5.1 تماماً: الخادمُ أوّلاً لأن اكتشاف عقدٍ ناقصٍ بعد بناء الشاشات أغلى. 20 اختباراً جديداً ⇒ **364** |
| 2026-09-07 | 🔑 **`ApiScope` صار يقرأ إسنادَ الدور داخل المعهد** بعد السجلّات الثلاثة (`teacher`/`guardian`/`student`) — فعبَره `supervisor` و`admin` وهما بلا سجلٍّ عمداً. وحاملُ الدور العابر (`developer`/`super_admin`) يسقط إلى أوّل معهدٍ فعّال ويبدّل بترويسة **`X-Institute`** التي قائمتُها في `GET /institutes` الجديدة. **وما لم يتغيّر: لا تخمين** — حسابٌ بلا سجلٍّ ولا دورٍ في معهد يبقى 422، ومعهدٌ مطلوبٌ في الترويسة لا يعمل فيه صاحبُ التوكن يُرفض بـ**403** لا يُتجاهل بصمت |
| 2026-09-07 | 🔁 **«في أي معهد يعمل هذا المستخدم» صارت في `User` لا في `PanelScope`**: كانت اللوحةُ تعرف ما لا يعرفه الـ API عن نفس السؤال، فنُقلت إلى `User::instituteIds()` و`homeInstituteId()` و`canAccessInstitute()` ويقرؤها السطحان. صفةٌ في المستخدم لا في السطح الذي دخل منه |
| 2026-09-07 | 🛡️ **العمليةُ المسمومة لم تعد توقف الطابور**: كانت الدفعة كتلةً واحدة، فاستثناءٌ في العملية الخامسة يُنهي الطلب بـ500 **بعد أن التُزمت الأربع قبلها** — فتبقى العشرُ اللاحقة معلّقةً إلى الأبد لأن الخامسة لن تنجح أبداً. صارت كلُّ عملية في معاملتها، والمرفوضةُ تُردّ في `failed[]` برسالتها بـ200. **وهذا تغييرُ عقدٍ متوافق** (§7 من [API.md](API.md)): حقلٌ يُضاف، وعميلٌ قديم لا يعرفه يبقى سليماً. ⬜ ويبقى على `mousqe_core` أن يعزلها ويعرضها بدل إعادة إرسالها — م.6.2 |
| 2026-09-07 | 🖥️ **`/bootstrap` صارت تخدم الديسكتوب**: `permissions` بجانب `roles` — فالفرق بين المشرف ومديرِ المعهد صلاحياتٌ لا نسخةُ برنامج، وبناءُ الواجهة على أسماء الأدوار كان يعني نسخَ الكتالوج إلى Dart. والقائمةُ محسوبةٌ بـ`can()` لا بقراءة الإسنادات، وإلا عادت **فارغةً للمبرمج** وهو يملك كل شيء (`Gate::before`). و`circles` صارت تعود كاملةً لمن يملك `circles.view` بدل `[]` — وإلا فتح الديسكتوبُ على معهدٍ بلا حلقة واحدة حتى تكتمل أولُ دورةِ سحب |
| 2026-09-07 | ⚖️ **التعارضات صار لها سطحان لا سطح**: `GET /sync/conflicts` و`POST /sync/conflicts/{uuid}/resolve` خلف `conflicts.review`. والجدولُ لا يُزامَن فقُرئ من نقطةٍ مباشرة — هو أثرُ الدفعة لا بيانُ المعهد؛ والحكمُ متّصلٌ بطبعه فلا طابورَ له. و«أبقِ قيمة الخادم» أُخرجت من مكوّن اللوحة إلى `App\Actions\ReviewSyncConflict` ليستعملها السطحان — نفسُ قاعدةِ `OverturnSyncConflict` |
| 2026-09-08 | ✅ **المرحلة 6.2 — سطحُ الإدارة في الـ API** ([CHECKPOINT-PHASE-6.2.MD](CHECKPOINT-PHASE-6.2.MD)). أكبرُ بنود م.6 حجماً وآخرُ حاجبٍ خادميّ أمام أوّل شاشة: كلُّ ما تكتبه اللوحة من معاهدَ ومستخدمين وأدوارٍ وبياناتِ دخولٍ وبنيةِ دورةٍ صار له عقدٌ يستهلكه عميل. 18 اختباراً خادمياً جديداً ⇒ **382**، و4 في `mousqe_core` ⇒ **33**. ولا سطرَ Dart في `apps/` بعد |
| 2026-09-08 | 🧭 **قناتان لا واحدة — والقاعدةُ مُعلَنة**: السؤالُ المفتوح كان «REST أم طابور؟»، والجوابُ قسمةٌ لا اختيار. ما يُكتب **أوف-لاين ويقبل التأخير** (تسجيلُ طالب · التسجيلُ في حلقة · النقل · مراجعةُ الأعذار) أنواعُ عملياتٍ في `sync/push`؛ وما هو **متّصلٌ بطبعه** (حسابٌ ودورٌ وكلمةُ مرور، وإنشاءُ معهد) REST تحت `/admin` — لا معنى لطابورٍ يحمل سرّاً إلى وقتٍ لاحق. وبلا القاعدة كانت كلُّ شاشةِ إدارةٍ ستجتهد بعقدها ([API.md §3.10.1](API.md)) |
| 2026-09-08 | 🏗️ **بنيةُ الدورة REST لا طابور** — القرار الذي تركته الخطة معلّقاً. ليست الحجّةُ ندرةَ الكتابة وحدها بل أنها **بنيةٌ يُبنى عليها لا حدثٌ يُسجَّل**: الجلسةُ والتسجيلُ والتفقّد تُعلَّق كلُّها على `course_circles`، ولو صُفَّت أوف-لاين لصفَّ الجهازُ فوقها عشراتِ العمليات ثم رُفض أصلُها فسقط ما فوقه. وثمنُه أُدِّي في محلِّه: أربعةُ أفعالٍ (`SaveCourse` · `SaveShift` · `SaveCircle` · `RunCircleInCourse`) أُخرجت من شاشات اللوحة التي كانت تكتب النماذجَ مباشرةً، **فصارت الشاشاتُ تستدعيها هي أيضاً** |
| 2026-09-08 | 🔴 **الطابور كان مفتوحاً لكل حاملِ `sync.push`** — كشفٌ عند إدخال أنواع الإدارة. الحارسُ على المسار واحد والأستاذُ يملكه ليتفقّد، فكان يملك بها — نظرياً — أن يصفّ تسجيلَ طالبٍ لو عرف اسم النوع. صار `SyncPush::assertPermitted` يفحص صلاحيةَ كل نوع، ودخل معها **`attendance.amend`**: كان تعليقُ `TakeAttendance` يقول إن الصلاحية «تحرسه الواجهة» — أي أن التصحيح الرجعي، وهو ما يميّز الديسكتوب من تطبيق الأستاذ، كان مفتوحاً من الطابور. والرفضُ يقع في `failed[]` لا 403 على الدفعة |
| 2026-09-08 | 🧾 **`users` بلا `uuid` — والعنونةُ بـ`id` نتيجةٌ لا اختصار**: الجدول لا يُزامَن عمداً (حمولتُه بيانات دخول لا تُبثّ في تيّار)، فلا صفَّ منه يعبر `change_log` ليحتاج معرّفاً عالمياً. وهو نفسُه سببُ كون `GET /admin/users` و`/admin/credentials` **نقطتَي القراءة الوحيدتين** في سطح الإدارة: ما عداهما يُزامَن فيُقرأ من drift |
| 2026-09-08 | 🛡️ **العمليةُ المرفوضة تُعزَل في الجهاز** — الشقُّ الثاني ممّا بدأته م.6.1. `pending_operations` صار يحمل `failed_reason` و`failed_at` (`schemaVersion` 3 ⇒ 4): لا تُحذف (حذفُها ضياعُ كتابةٍ لم يعرف بها صاحبُها)، ولا يُعاد إرسالُها (نوعٌ مجهول أو صفٌّ من معهدٍ آخر لا يصير مقبولاً بالتكرار)، وتخرج من عدّاد «بانتظار المزامنة» كي لا يبقى عالقاً بلا سبب ظاهر. والقرارُ فيها بشري: `retryFailed` أو `discardFailed` — وهو **الطريق الوحيد لحذفها** |
| 2026-09-08 | 📦 **لا نماذجَ freezed لِما يصل في `sync/pull`** — خلافاً لِما سمّته خطةُ 6.2 (`Enrollment` · `Curriculum`). نماذجُ `mousqe_core` **لحمولات JSON لا للجداول**، وما يصل بالمزامنة له صفُّ drift أصلاً (`EnrollmentRow` · `TeacherRow`) فنموذجٌ ثانٍ له شكلٌ بلا قارئ. فاقتُصر على حمولات `/admin/*` وحدها: `AdminUser` · `UserRoleAssignment` · `RoleOption` · `IssuedCredentials` · `CredentialCard` |
| 2026-09-08 | ⚠️ **رفعُ الشعار بقي خارج الـ API**: `logo_path` يُقرأ ولا يُكتب — الرفعُ عقدٌ آخر (`multipart/form-data`)، وفتحُه لأجل حقلٍ واحد قبل أن تُبنى شاشتُه سابقٌ لأوانه. يُفتح في م.6.5 أو يبقى استثناءً موثَّقاً ([API.md §8](API.md)) |
| 2026-09-08 | ✅ **المرحلة 6.3 — هيكل تطبيق الديسكتوب** ([CHECKPOINT-PHASE-6.3.MD](CHECKPOINT-PHASE-6.3.MD)). أوّلُ سطر Dart في م.6: نافذةٌ بحالةٍ محفوظة، ودخولٌ يسجّل الجهاز بـ`app=admin_desktop`، وقائمةٌ جانبية دائمة، ومبدّلُ معاهد، وشريطُ مزامنة. **88 اختباراً في Dart** (كانت 65): 43 في `mousqe_core` و27 في الأستاذ و18 في الديسكتوب — و382 خادمياً بلا تغيير |
| 2026-09-08 | 🧭 **بلا `go_router` في الديسكتوب أيضاً** — المسألةُ المؤجَّلة من م.5.3 أُعيدت وحُسمت بعد بناء الهيكل لا قبله. برنامجُ نافذةٍ واحدة بلا روابطَ عميقة ولا شريطِ عنوان لا يستفيد ممّا يبيعه الموجّه؛ و`IndexedStack` فوق `Navigator` لكل باب يعطي مكدّساً مستقلاً لكل قسم وهو **نفسُ ما يلفّه `StatefulShellRoute`**؛ والأبوابُ تُرشَّح بـ`user.permissions` في زمن التشغيل، فجدولُ مساراتٍ ثابت كان سيكتب الحارسَ مرّتين (ترشيحُ القائمة و`redirect`) |
| 2026-09-08 | 🔑 **تبديلُ المعهد يمسح مخزنَ الجهاز ويصفّر المؤشّر** — ليس احتياطاً بل ضرورةً في البروتوكول: `sync/pull` يرشّح بـ`scope_key` بينما `since` رقمٌ **عامّ** في `change_log`، فجهازٌ بلغ 9140 في معهدٍ ثم بدّل كان سيتخطّى صفوفَ المعهد الجديد الأقدمَ منه ويفتح على معهدٍ **ناقصٍ لا يشكو من شيء**. ويُرفض التبديلُ والطابورُ غيرُ فارغ (`PendingWorkBlocksSwitch`) لأن المسح يمحو ما لم يصل الخادمَ بعد، وتُوقَف المزامنةُ حول التبديل لا أثناءه |
| 2026-09-08 | 📦 **ما يحتاجه الاثنان رُفع إلى الحزم ولم يُنسخ** (القرار 4 في خطة م.6): `api_errors` و`BootstrapSnapshot` (+`permissions`) و`SessionController` و`SyncController` إلى `mousqe_core`، و`SyncBar` و`LoginForm` إلى `mousqe_ui`. **و`mousqe_ui` لا تعتمد `mousqe_core`** رغم أن ذلك كان أقصر: حزمةُ الهوية البصرية لا تعرف طابورَ المزامنة، وإلا لم تُستعمل في شاشةٍ بلا مزامنة ولا اختُبرت بلا قاعدة. وثمنُه ٤٥ سطرَ ربطٍ في كل تطبيق. **وكسبٌ جانبي:** الشريطُ المشترك صار يعرض العملياتِ المعزولة ويعطي إعادةَ المحاولة والتخلّي — عقدُ م.6.2 الذي لم يكن له عارض، وتطبيقُ الأستاذ كسبه معه |
| 2026-09-08 | 🔴 **قفلُ الجلسة بلا نوع عملية** — كشفٌ عند بناء أبواب الديسكتوب على الصلاحيات. [APPS-FEATURES.md §4.2](APPS-FEATURES.md) كان يسمّي `attendance.session.complete` قفلاً «ومعها `attendance.lock`»، والحقيقةُ أنه **إكمالٌ** يفعله الأستاذُ نفسُه كل يوم؛ فحراستُه بتلك الصلاحية كانت ستكسر تطبيق الأستاذ، و`LockAttendanceSession` بلا نوعٍ يبلغه عميل. يُفتح في م.6.4 ومعه حارسُ `attendance.teacher.take` |
| 2026-09-09 | ✅ **المرحلة 6.4 — التفقّد والتصحيح في الديسكتوب** ([CHECKPOINT-PHASE-6.4.MD](CHECKPOINT-PHASE-6.4.MD)). أوّلُ بابين تُملأ شاشاتُهما: كشفُ حلقات المعهد، والتفقّدُ بسلطة **التصحيح الرجعي والقفل النهائي وتفقّدِ الأساتذة**. **127 اختباراً في Dart** (كانت 88) و**387** خادمياً (كانت 382). و⚠️ **بناءُ ويندوز صار مُجرَّباً** بعد تثبيت حِمل C++ — كان معلّقاً منذ م.6.3 |
| 2026-09-09 | 🧭 **الفرقُ بين الأستاذ والديسكتوب معاملٌ في مستودعٍ واحد** — امتحانُ قرار «يُرفع ولا يُنسخ» على ـ٩٢٨ سطراً. `TeacherRepository` صار `CircleRepository` في `mousqe_core`: `teacherUuid` فارغاً يعني المعهدَ كلَّه، و`SessionView.editableBy(canAmend:)` **تقرأ الصلاحية من اللقطة بدل أن تُفترض في الشيفرة** — فتطبيقُ الأستاذ يمنع تحريرَ المكتملة لأنه لا يملك `attendance.amend` لا لأن شيفرتَه تمنع، ولو مُنحها غداً لَانفتحت شاشتُه بلا سطرٍ يُعدَّل. **والشاشاتُ لا تُرفع**: بطاقاتُ إبهامٍ على هاتف ليست جدولاً على مكتب، ومكوّنٌ بمعاملِ `isDesktop` يخدم الاثنين ويليق بواحد — المرفوعُ **منطقٌ** كما ينصّ [ARCHITECTURE.md §6](ARCHITECTURE.md) |
| 2026-09-09 | 🔓 **القفلُ نوعٌ ثانٍ لا حارسٌ على الإكمال** — سدُّ ما كُشف في م.6.3. `attendance.session.lock` ⇐ `LockAttendanceSession` خلف `attendance.lock`، و`attendance.session.complete` بقي **بلا حارس** لأنه إكمالٌ يفعله الأستاذُ كلَّ يوم. و**الترتيبُ مسؤوليةُ العميل**: القفلُ لا يقع إلا على مكتملة، فقفلُ مسوّدةٍ يصفّ الإكمالَ قبله في نفس الدفعة — وإلا عاد معزولاً بعد ساعات والمشرفُ يظنّ البابَ مغلقاً وهو مفتوح |
| 2026-09-09 | 🛡️ **`attendance.teacher.take` حُرس بـ`teachers.view`** — بلا صلاحيةٍ جديدة في الكتالوج. التمييزُ المطلوب موجودٌ في البذرة أصلاً: حاملو `sync.push` هم الأستاذُ والمشرفُ ومن فوقه، **والأستاذ وحده منهم لا يملك `teachers.view`**. وهي حكمُ الأمر لا شكلُه: حارسُ الكتابة هنا ليس «الكتابة» — الكلُّ يكتب تفقّداً — بل **السلطةُ على الأساتذة** |
| 2026-09-09 | 🗃️ **`teacher_attendances` كان يُبثّ ولا يُلتقَط** — جدولٌ `Syncable` منذ م.4 تسير صفوفُه في `change_log` إلى كلِّ جهاز، و`SyncPayloadApplier` **يُسقطها على الأرض** لأن لا صفَّ drift يستقبلها. صمتٌ لا عطب: العملاءُ الثلاثة السابقون لا يتفقّدون أستاذاً. أُضيف الصفّان (المتزامنُ ومسوّدتُه) ⇒ `schemaVersion` 4 ⇒ **5**. و**الأستاذُ غيرُ المسجَّل لا يُفترض حاضراً**: الخادمُ يزرع للطلاب ولا يزرع للأساتذة، وادّعاءُ حضورٍ لم يقله أحد يجعل غيابَ الأستاذ حضوراً بالسكوت |
| 2026-09-09 | ✅ **الخطوة 3 من السيناريو المرجعي شُغِّلت أخيراً** ([SYNC-PROTOCOL.md §9](SYNC-PROTOCOL.md)) — بقيت مؤجَّلةً منذ م.5.3 لسببٍ واحد: لا عميلَ ثانٍ. فصارت جهازين بمخزنين ومؤشّرَي مزامنة على خادمٍ مصغَّر يحسم التعارض بشروط `ResolveAttendanceConflicts` الأربعة: الأحدثُ يفوز والأقدمُ يُسجَّل تعارضاً ولا يضيع · وجهازان على طالبين مختلفين لا يتنازعان · وتصحيحُ المشرف يصل جهازَ الأستاذ فيراه ولا يعدّله · ونفسُ الكتابة بلا `amend` **تُعزل** ولا تحجب ما بعدها |
| 2026-09-09 | 🔴 **عطبُ تخطيطٍ في تطبيق الأستاذ كشفه أوّلُ اختبار واجهةٍ له**: `mousqe_ui` تعطي كلَّ زرٍّ في ثيم الهاتف `minimumSize: Size.fromHeight(52)` — عرضاً **لا نهائياً** مقصوداً به «بعرض الشاشة» — وشريطُ أفعال شاشة التفقّد كان يضع زرَّ «إقفال» عارياً في `Row`. و`Row` يقيس ابنَه غيرَ المرن بعرضٍ غير محدود ⇒ ينكسر التخطيط. بقي ساكناً منذ م.5.3 لأن الشاشة لم تُرسم في اختبارٍ قطّ. **والدرسُ الثاني:** اختبارُ الديسكتوب الأوّل سقط بنفس الخطأ لأنه بنى ثيمَ الهاتف بينما `app.dart` يبني `forDesktop` — فاختبارٌ بثيمٍ غير ثيم التطبيق يقيس شاشةً لا وجود لها |
| 2026-09-08 | 🪟 **حالةُ النافذة في ملفّ لا في `app_state`**: مخزن drift يُمسح كاملاً عند الخروج وعند قفل الحساب، فكانت النافذةُ تقفز إلى مقاسها الافتراضي كلّما خرج صاحبُها — وحجمُ النافذة صفةُ الجهاز لا صفةُ الحساب. ومقاسُ نافذةٍ مكبَّرة لا يُحفظ مقاساً مستعاداً، وإلا فتحت التاليةُ بملء الشاشة بلا تكبيرٍ فلا يجد المستخدم حافّةً يسحبها |
| 2026-09-09 | ✅ **المرحلة 6.5 — الإدارة اليومية وسطحُ الإدارة** ([CHECKPOINT-PHASE-6.5.MD](CHECKPOINT-PHASE-6.5.MD)). تسعةُ أبوابٍ تُملأ دفعةً واحدة فيصير المفتوحُ **أحدَ عشرَ من خمسةَ عشر**: الاستمارةُ الكاملة والتسجيلُ والنقلُ والأعذارُ وبنيةُ الدورة والمناهجُ والمستخدمون والبطاقاتُ وبياناتُ المعهد والمعاهد. **160 اختباراً في Dart** (كانت 127) و**393** خادمياً (كانت 387). وبها لم يبقَ بابٌ يضطرّ المشرفَ إلى فتح المتصفّح **إلا رفعَ الشعار** |
| 2026-09-09 | 🧭 **قناةُ الكتابة تحدّ المستودعَ لا الموضوع** — ثلاثةُ مستودعاتٍ جديدة حدُّها **أوف-لاين أم متّصل** لا «الطلاب» و«الحلقات»: `StudentRepository` (drift ⇒ الطابور) · `CatalogRepository` (drift ⇒ REST) · `AdminRepository` (الشبكة ⇒ REST). وهو تجسيدُ قاعدة [API.md §3.10.1](API.md) في الشيفرة، فمن يضيف كتابةً يسأل «أتقبل التأخير؟» لا «أيُّ شاشةٍ هذه؟». **وثمنُ الأوسط مدفوعٌ في `runConnected`**: ما يُكتب بـREST يعود في `sync/pull` لا في ردّ الطلب، فتُطلَب مزامنةٌ فورية بعد كل نجاح، ويُفصَل «لا شبكة» (عملٌ يُعاد) عن «الخادم رفض» (حكمٌ لا تُجدي إعادتُه) |
| 2026-09-09 | 🔴 **منهجٌ عامّ يُسرَق بلا خطأ** — كشفه إخراجُ `SaveCurriculum` من شاشة اللوحة إلى فعلٍ مشترك (وهو خامسُ فعلٍ يُخرَج بهذه القاعدة). كانت الشاشةُ تُسند `institute_id` بلا شرط، والمناهجُ المزروعة (`institute_id = null`) يراها كلُّ معهد — فتعديلُ اسم «القرآن الكريم» من معهدٍ واحد **ينقله إلى ملكِه** فيختفي، بأجزائه الثلاثين وسجلّاتِ التقدّم المعلّقة عليها، عن كلِّ معهدٍ آخر. وهو **صمتٌ لا عطبٌ ظاهر**: لا خطأ يُرمى، والمعهدُ الآخر يفتح شاشتَه فلا يجد منهجاً. والحكمُ وُضع في الفعل لا في المتحكّم فسرى على السطحين في نفس الالتزام |
| 2026-09-09 | 🗃️ **`schemaVersion` 5 ⇒ 6: عشرةُ جداول وخمسةَ عشرَ عموداً كانت تُهدَر** — ثالثُ مرّةٍ يفترق فيها ما يُبثّ عمّا يُخزَّن (بعد خمسةٍ في م.5.3 و`teacher_attendances` في م.6.4). والعشرةُ غيابٌ ظاهر، **وأخطرُ منها `students`**: كان له صفُّ drift بثمانية أعمدة من عشرين تصل في الحمولة — أعمدةُ عرضٍ بُنيت لتطبيق الأستاذ. فكانت النتيجةُ **فقدَ بيانات لا غيابَ عرض**: تُفتح الاستمارةُ نصفَ فارغة فيحفظها المشرفُ ظانّاً أنه صحّح حقلاً، **فتمحو ما لم تعرضه**. والدرس: صفُّ drift عقدُ قراءةٍ لشاشة، فإذا صارت الشاشةُ تكتب صار عقدَ كتابةٍ أيضاً. والهجرةُ **تصفّر مؤشّرَ السحب** لأن ما أُهمل لا يُسترجَع إلا من الخادم |
| 2026-09-09 | 🔴 **`IndexedStack` صار مكلفاً حين مُلئت الأبواب** — قرارُ م.6.3 «بلا `go_router`» يقوم على أنه يعطي مكدّساً مستقلاً لكل باب **مجاناً**، وكانت الكلمةُ صحيحةً لأن الأبواب placeholder. فلمّا مُلئت تسعةٌ صار الإقلاعُ يشغّل `initState` لخمسةَ عشرَ باباً، ومنها ثلاثةٌ تقرأ من الشبكة — فيرسل التطبيقُ ثلاثةَ طلباتٍ لم يطلبها أحد ويعرض أخطاءَها لمن لم يفتح بابَها. **والعلاجُ بلا نقضِ القرار**: البابُ يُبنى عند أوّل زيارة ويبقى مبنيّاً بعده، فالمكدّسُ محفوظ والثمنُ يُدفع لِما يُفتح وحده |
| 2026-09-09 | 🔁 **درسُ الثيم لم يُرجَع به إلى الاختبار القديم** — م.6.4 سجّلت أن «اختباراً بثيمٍ غير ثيم التطبيق يقيس شاشةً لا وجود لها»، وطبّقته على اختبارها الجديد وحده؛ فبقي `desktop_shell_test` على ثيم الهاتف منذ م.6.3 وصمت **مرحلةً كاملة** لأن أبوابه بلا زرٍّ واحد، حتى مُلئت هنا فانكسر شريطُ الأدوات. والدرسُ فوق الدرس: **درسٌ يُكتب في نقطة تفتيشٍ لا يُطبَّق على ما مضى ما لم يُبحَث عنه عمداً** — والمواضعُ التي كانت تحته حين كُتب هي أوّلُ ما يُراجَع لا آخرُه |
| 2026-09-09 | ⚠️ **رفعُ الشعار بقي خارج الـ API بعد م.6.5** — لكنه **صار استثناءً معروضاً لصاحبه** لا فجوةً صامتة: شاشةُ «بيانات المعهد» بُنيت بلا بابِ شعار، وفيها بطاقةٌ تقول إنه يُرفع من لوحة التحكّم. وفتحُ عقد `multipart` لأجل حقلٍ واحد يبقى سابقاً لأوانه حتى يُطلب رفعُ ملفٍّ ثانٍ (صورةُ طالب مثلاً) |
| 2026-09-09 | ✅ **المرحلة 6.6 — الداشبورد والتقارير والتعارضات، وبها تنتهي المرحلة السادسة** ([CHECKPOINT-PHASE-6.6.MD](CHECKPOINT-PHASE-6.6.MD)). الأبوابُ الأربعة الأخيرة تُملأ فيصير المفتوحُ **خمسةَ عشرَ من خمسةَ عشر**، ولا تبقى في التطبيق `PlaceholderScreen` واحدة: الداشبوردُ محسوباً من drift · وتقريرا الحلقة مطبوعَين **من الجهاز** · والحكمُ في التعارضات · والنسخُ الاحتياطي. **189 اختباراً في Dart** (كانت 160) و**394** خادمياً (كانت 393). وبها تحقّق قرارُ 2026-09-07 كاملاً: لم يبقَ ما يضطرّ المشرفَ أو مديرَ المعهد إلى فتح المتصفّح **إلا رفعَ الشعار** |
| 2026-09-09 | 🔑 **«ما لم يُسجَّل لا يُفترض» صارت قاعدةَ الإحصاء كلِّه** — شاشةُ التفقّد تعرض للطالب بلا صفٍّ حالةً `suggested` («حاضر» مقترحةً تنتظر من يؤكّدها، نظيرَ زرعِ `OpenAttendanceSession`). ولو دخلت الإحصاءَ لَصار عددُ الحاضرين في حلقةٍ **لم يفتح أحدٌ جلستَها** كاملَ كشفِها، ولَقرأ المشرفُ **١٠٠٪ عن يومٍ لم يُتفقَّد فيه أحد** — وهو أسوأُ ما يقوله رقم: خبرٌ مطمئنٌّ عن غياب. وهي نفسُها قاعدةُ تفقّد الأساتذة في م.6.4، قيلت هناك عن جدولٍ واحد فسرت هنا على الإحصاء |
| 2026-09-09 | 🔑 **`null` ليست صفراً** — يومٌ بلا جلسة، وحلقةٌ بلا صفِّ حضورٍ واحد، وجلسةٌ لم تُفتح: كلُّها «لم تُقَس» لا «قِيست فكانت صفراً». ولو رُسمت أصفاراً لَهبط المنحنى كلَّ عطلة، **ولَبدت حلقةٌ لم تُفتح جلستُها أسوأَ من حلقةٍ غاب طلابُها كلُّهم**. والحلقةُ بلا نسبةٍ لا تُرتَّب أصلاً فلا تزاحم من قِيس فعلاً |
| 2026-09-09 | 🔴 **رقمٌ مطبوعٌ يخالف رقمَ اللوحة بلا خطأ يُرمى** — عمودُ الحضور في تقرير النقاط **مشتقٌّ يحسبه الجهاز**، وقيمُه في `institutes.settings['points']` وهو جدولٌ **لا يُزامَن**. فكان سيُحسب بافتراضيّات الحزمة في كل معهدٍ عدّل نقاطَه، ولا يعرف قارئُ الورقتين أيَّهما يصدّق. فأُضيف `institute.points` إلى `/bootstrap` — و**هي ثالثةُ مرّةٍ يتكرّر فيها النمط** بعد `theme` و`late_grace_minutes`، فصار قاعدةً مكتوبة في [SYNC-PROTOCOL.md §7](SYNC-PROTOCOL.md): ما يُحسب محلياً يحتاج ثابتاً خادمياً، وما لا يُزامَن يُحمَل في اللقطة |
| 2026-09-09 | 🔴 **درسٌ خادميٌّ لا يعبر إلى العميل من تلقاء نفسه** — استُخرجت `App\Support\AttendanceRate` في 2026-09-03 حين بلغت المعادلةُ ثلاثةَ مواضع «كي لا يختلف رقمُ اللوحة عن رقم التقرير»، وقد بدأ الشيءُ نفسُه في Dart بلا انتباه: نسخةٌ في `StudentProfile.attendanceRate` منذ م.5.3، وكانت م.6.6 ستضيف ثلاثاً. فخرجت `AttendanceRate` إلى `mousqe_core` نقلاً حرفياً. وهو نظيرُ درسِ الثيم في م.6.5: **ما يُكتب في نقطة تفتيشٍ لا يُطبَّق على السطح الآخر ما لم يُبحَث عنه عمداً** |
| 2026-09-09 | 🖨️ **الطباعةُ من الجهاز، وخطوطُ `pdf` المدمجة بلا حرفٍ عربيٍّ واحد** — مستندٌ يُبنى بـHelvetica يخرج **بمربّعاتٍ فارغة مكان كل كلمة** بلا خطأ يُرمى، لأن الخطَّ موجودٌ والحرفُ مفقود. فيُحمَّل `IBM Plex Sans Arabic` من أصول `mousqe_ui` — الحزمةُ تحمله أصلاً هويّةً بصرية، فالتقريرُ بخطّ الشاشة نفسِه ولا ملفَّ خطٍّ ثانٍ يفترق عنه. و`pw.TextDirection.rtl` يُعلَن **على الصفحة**، وبدونه يخرج النصُّ مقلوباً حرفاً حرفاً |
| 2026-09-09 | 💾 **النسخُ الاحتياطي بـ`VACUUM INTO` لا بنسخِ الملفّ، وبلا زرِّ استعادة** — نسخُ قاعدةٍ مفتوحة يلتقط صفحاتِ WAL غيرَ مدموجة، فتخرج نسخةٌ تُفتح ثم تشكو من تلفٍ لا يظهر إلا حين يُحتاج إليها: **نسخةٌ يظنّها صاحبُها موجودة**. ولا استعادة: مخزنُ drift مرآةُ تيّارٍ من الخادم، وإصلاحُ ما يفسد منه هو مسحُه وإعادةُ السحب. فما تحفظه النسخةُ وحدها هو **`pending_operations`** — كتاباتٌ ليست في أيّ مكانٍ آخر — ولذلك تقول الشاشةُ كم في الطابور قبل أن تنسخ |
| 2026-09-10 | 🔑 **قناةُ القراءة تحدّد المستودع — ووليُّ الأمر خرج من `sync/pull` كلِّه** (م.7.1). الفجوةُ السابعة («السحبُ معهدٌ كامل لكل الأدوار») كانت موصوفةً حِملَ أداءٍ يُقاس لاحقاً، وهي على جهاز الأب **شيءٌ آخر**: هاتفُ كلِّ وليّ أمرٍ يخزّن أسماءَ كلِّ طلاب المعهد وحضورَهم يوماً بيوم، وهو ليس طاقماً ولا يملك `students.view` على غير أبنائه — **تسريبٌ لا حِمل**. ولا يحتاجه أصلاً: من يستدعي التيّارَ من **يكتب** في الطابور ليعرف ما حُسم من كتابته، ووليُّ الأمر لا يملك `sync.push`. فصارت نقاطُ `/guardian/*` كلَّ مصادره و drift **مخزنَ لقطاتها**، والأوف-لاين باقٍ كما وُعد — الذي تغيّر مصدرُ الصفّ لا وجودُه. **وهي صياغةٌ ثانية لقاعدة م.6.5**: هناك حدّدت قناةُ الكتابةِ المستودعَ، وهنا تحدّده قناةُ القراءة |
| 2026-09-10 | 🔴 **سجلُّ حضورٍ لا يعرف يومَه** — `AttendanceResource` كان يعيد `recorded_at` وحده، وهو **لحظةُ كتابة الأستاذ لا يومُ الحضور**. كفى شاشةَ الأستاذ لأنها تفتح يوماً بعينه فتعرفه مسبقاً، فبقي النقصُ مستوراً مرحلتين؛ ولا يكفي وليَّ الأمر ولا الطالبَ وهما يقرآن يوماً بيوم: أستاذٌ يصحّح جلسةَ أمس اليومَ يضع سجلَّها في اليوم الخطأ عند قارئه. و`GuardianChildrenQuery` كان **يحمّل** `attendanceSession` فعلاً ولا يعرضها أحد. **والدرس: حقلٌ يكفي أوّلَ قارئٍ قد لا يكفي ثانيَه، والعقدُ يُراجَع عند كل جمهورٍ جديد لا عند كل جدولٍ جديد** |
| 2026-09-10 | 🔑 **قاعدةُ «`null` ليست صفراً» عبرت من Dart إلى الخادم** (م.7.1) — كُتبت في م.6.6 عن `StatsRepository`، وكان `StudentProfileQuery::attendanceTrend` يعيد `rate: 0.0` ليومٍ **بلا جلسة أصلاً** منذ م.3. لم يظهر أثرُها في اللوحة لأن مكوّنَ المنحنى يرشّح **دوائرَه** بـ`sessions > 0` — لكنّ **الخطَّ الواصلَ** كان يهبط إلى القاع كلَّ جمعةٍ وعطلة، فيبدو منحنى طالبٍ مواظبٍ مسنَّناً بين المئة والصفر؛ ولا مرشِّحَ في نقطة الـAPI إطلاقاً. **وهي ثالثةُ مرّةٍ يثبت فيها أن درساً يُكتب في نقطة تفتيشٍ لا يُطبَّق على السطح الآخر ما لم يُبحَث عنه عمداً** (بعد الثيم في م.6.5 و`AttendanceRate` في م.6.6) — والفرقُ أن الاتجاه هذه المرّة **من العميل إلى الخادم** |
| 2026-09-10 | ✅ **المرحلة 7.1 — الأساس الخادمي لولي الأمر** ([CHECKPOINT-PHASE-7.1.MD](CHECKPOINT-PHASE-7.1.MD)). نقطتان جديدتان (`GET /guardian/excuses` و`.../children/{uuid}/progress`) حلّتا محلَّ ما كان يصله في التيّار، ومورِدان جديدان (`AbsenceExcuseResource` و`ProgressResource`) — والثاني **قُدِّم من موعده** («قبل م.8») لأن نقطةَ تقدُّمٍ ثانيةً فُتحت، فأُغلقت به آخرُ نقطةٍ في النظام تعيد نموذجاً خاماً. ونُزعت `reports.view` من دور `guardian`، و**بقي `/bootstrap` بلا توسيع قراراً لا إهمالاً** |
| 2026-09-10 | 🗃️ **قناةُ القراءة تحدّد المستودع — تحقّقت عملياً في 7.2 و`schemaVersion` بقي 6.** جداولُ `students` و`attendances` و`absence_excuses` موجودةٌ في drift منذ م.5.2 و م.6.5، وكان الظاهرُ أن تُكتب فيها استجاباتُ `/guardian/*`. ولو فُعل لَوقع **عطبُ م.6.5 بعينه**: النقطةُ تعيد خمسةَ حقول وجدولُ الطالب عشرون عموداً، فيسكنه صفٌّ نصفُ ممتلئٍ يبدو كاملاً. وتطبيقُ ولي الأمر **لا يستعلم أصلاً** — الملخّصُ والمنحنى يصلان محسوبين من الخادم — فمخزنُه `app_state` نفسُه الذي تسكنه لقطةُ `/bootstrap`، ويُمسح معها في `clearAll()` فلا تبقى بياناتُ أبناءٍ على جهازٍ خرج صاحبُه منه |
| 2026-09-10 | 🔑 **`Snapshot<T>`: القراءةُ تحمل متى قُرئت وهل هي طازجة** — لا القيمةَ عارية. لأن بياناً قديماً يُعرض بلا إعلانِ قِدَمه يقرؤه صاحبُه حاضراً: أبٌ يفتح التطبيقَ في نفقٍ فيرى حضورَ الأسبوع الماضي بلا علامة فيطمئنّ إلى رقمٍ عمرُه ستّةُ أيام. والنوعُ يجعل الإعلانَ **إلزامياً على الشاشة** بدل أن يكون تذكُّراً. **واللقطةُ تُقدَّم عند انقطاع الشبكة وحده** (`isOffline`) لا عند أيّ خطأ: 403 «الحساب مقفل» يجب أن تصل `SessionController` فتمسح المخزن، ولو ابتُلعت لَبقي صاحبُ الجهاز يقرأ لقطةَ أبنائه بحسابٍ أُبطل توكنُه |
| 2026-09-10 | ✅ **المرحلة 7.2 — مستودعُ ولي الأمر في `mousqe_core`** ([CHECKPOINT-PHASE-7.2.MD](CHECKPOINT-PHASE-7.2.MD)). خمسُ نقاطٍ في `ApiClient` وأربعةُ نماذج و`GuardianRepository`، **وبلا `SyncEngine` ولا `SyncController` ولا نوعِ عمليةٍ في الطابور** — واختبارٌ يحرس ذلك صراحةً (`verifyNever` على `syncPull` و`syncPush`). **147** اختباراً في الحزمة (كانت 134). وتقديمُ الإذن **يُبطل لقطةَ الأعذار ولا يحقنها**: استجابةُ `POST` حقلان لا صفٌّ كامل، وحقنُها كان يضع في القائمة صفّاً بلا اسمِ ابنٍ ولا تاريخ |
| 2026-09-10 | 🔑 **`SnapshotView`: القاعدةُ في ودجت واحد لا في خمس شاشات** (م.7.3). «بيانٌ قديم يُعلن قِدَمه» التزامٌ على كلِّ قراءةٍ في التطبيق، ولو تُرك لكلِّ شاشةٍ لَنسيته إحداها — **وهي الحالةُ التي لا تظهر في التطوير أصلاً** لأن الشبكة عاملةٌ دائماً على مكتب المطوّر، فلا يكتشفها أحدٌ حتى يفتح أبٌ التطبيقَ في نفقٍ فيقرأ حضورَ الأسبوع الماضي حاضراً. **ولا `SyncBar` في هذا التطبيق**: شريطُ المزامنة يقول «بقيت ثلاثُ عمليات لم تصل» ولا طابورَ ههنا، والسؤالُ الذي يهمّ وليَّ الأمر مختلف — متى قرأ جهازي آخرَ مرّة؟ **والوقتُ يُكتب تاريخاً لا مدّة** («أمس 19:40» لا «قبل ٦ أيام»): المدّةُ تُقرأ ولا تُتحقَّق |
| 2026-09-10 | 🔴 **`INTERNET` ليس في بيان الإصدار — و`flutter create` يضعه في debug وprofile وحدهما.** تطبيقُ ولي الأمر يقرأ من الشبكة **حصراً** (لا `sync/pull` يملأ مخزنَه في الخلفية)، فبناءُ الإصدار كان سيخرج بلا وصولٍ إلى الخادم إطلاقاً — **ويعمل في التطوير تماماً**. وهو نمطُ العطب نفسُه الذي تتكرّر مواجهتُه في هذا المشروع: فرقٌ بين بيئةٍ يُبنى فيها وبيئةٍ يُسلَّم إليها، لا يُرمى فيه خطأ |
| 2026-09-10 | 🔁 **`badgeOf` تكرّرت ثالثةَ مرّة — ولا تُرفع، والتكرارُ ثمنُ حدٍّ مقصود.** ترجمةُ `AttendanceStatus` (في `mousqe_core`) إلى `BadgeStatus` (في `mousqe_ui`) أربعةُ أسطرٍ صارت في ثلاثة أسطح، والقاعدةُ المعتادة ترفعها إلى حزمة. لكنّ `mousqe_ui` **لا تعتمد `mousqe_core` عمداً** (§7): مكوّناتُها تستقبل حالةً جاهزة؛ ورفعُها إلى `mousqe_core` يقلب الاعتماد إلى ما هو أسوأ — طبقةُ بياناتٍ تعرف ودجت. فكُتبت الحجّةُ عند موضعها في الأسطح الثلاثة حتى لا تُرفع لاحقاً بحسن نيّة. **والدرس: «لا تكرّر» ليست فوق «لا تقلب اتجاه الاعتماد»** |
| 2026-09-10 | ✅ **المرحلة 7.3 — تطبيق ولي الأمر** ([CHECKPOINT-PHASE-7.3.MD](CHECKPOINT-PHASE-7.3.MD)). `apps/guardian/` بخمس شاشات فوق الحزمتين: الدخولُ وأبنائي وملفُّ الابن بلسانَي الحضور والحفظ والأعذارُ تقديماً ومتابعة. **والمنحنى بُني صحيحاً من أوّل سطر** — يتخطّى ما لم يُقَس ولا يهبط به إلى القاع — لأن القاعدة كانت مكتوبةً قبل الشاشة، وهو الفرقُ الذي تشتريه مرحلةٌ فرعيةٌ خادميّةٌ أوّلاً. **210** اختباراً في مساحة العمل (كانت 189)، منها 8 في التطبيق |
| 2026-09-10 | 🔴 **`attach()` على علاقةٍ وسيطُها نموذج يكتب صفّاً خاماً بلا `uuid`** — كشفه أوّلُ تشغيلٍ لاختبارات م.7.1، فسقطت ثمانيةٌ من ثلاثة عشر على `NOT NULL constraint failed: guardian_student.uuid`. و`guardian_student` **ليس جدولَ ربطٍ عارياً**: نموذجٌ يحمل `HasUuid` و`Syncable` لأنه يُبثّ في `sync/pull`، فالربطُ يمرّ بـ`GuardianStudent::create` كما تفعل `ScopeTest` منذ م.4. **والدرس أنّ هذا صنفُ عطبٍ لا يكشفه تحليلٌ ثابت ولا مراجعة**: `attach` دالّةٌ صحيحةُ التوقيع على علاقةٍ صحيحة، وتعمل في كل مشروعٍ جدولُه الوسيط عاديّ — ولا يظهر إلا بتشغيلٍ فعليّ |
| 2026-09-10 | ✅ **اختبارات المرحلة السابعة شُغِّلت كاملةً بعد تجهيز البيئة** — **407** خادمياً (405 تمرّ + 2 متجاوَزان، كانت 394) و`pint` نظيف، و**210** في Dart عبر الحزم الخمس (كانت 189)، و`app-debug.apk` يخرج من `apps/guardian` (160 MB). فلم يبقَ في المرحلة السابعة إلا ⏸ الإشعارُ الفوري (7.4) وتجربةُ السيناريو الكامل على جهازٍ بخادمٍ يعمل |
| 2026-09-10 | 🔑 **الإشعارُ عند إغلاق الجلسة لا عند كتابة الغياب** (م.7.4). الظاهرُ أن موضعَه `TakeAttendance` فهو الذي يكتب «غائب» — وهو خطأ: الفعلُ يُستدعى في كل ضغطة، وأستاذٌ يعلّم غائباً ثم يصل الطالبُ متأخّراً بعد دقيقة فيصحّحها. فيصل الأبَ **«غاب ابنُك» ثم لا يصله شيءٌ يصحّحه** — إنذارٌ كاذبٌ لا سبيل إلى سحبه، ويتكرّر كل يوم. والإغلاقُ هو اللحظة التي يقول فيها الأستاذ إن الكشف انتهى. **وهي قاعدةُ م.6.6 في سياقٍ ثالث**: ما لم يستقرّ لا يُعلَن، كما أن ما لم يُسجَّل لا يُفترض. و`$wasCompleted` يجعل الإشعارَ أثرَ **انتقالٍ** لا حالة، فلا يتكرّر مع التصحيح الرجعي ولا مع إعادة دفع عمليةٍ من الطابور |
| 2026-09-10 | 🔑 **قناةُ الإشعار تُختار بوجود بيانات الاعتماد لا بعلَمٍ يدوي** — معهدٌ بلا حساب Firebase يعمل كاملاً بـ`NullPushNotifier`، ولا يحتاج أحدٌ أن يتذكّر إطفاء مفتاحٍ ثانٍ. وعلَمٌ منفصل عن الواقع يعني حالتين تفترقان: `FIREBASE_ENABLED=true` وبلا ملفّ اعتماد ⇒ استثناءٌ عند أوّل غيابٍ يُسجَّل. **ويُفحَص وجودُ الملفّ لا اسمُه**: مسارٌ في `.env` إلى ملفٍّ لم يُنسَخ إلى الخادم هو بالضبط ما يقع عند النشر. **والإشعارُ لا يرمي أبداً** — أثرٌ جانبيٌّ لفعلٍ نجح، وإسقاطُ إغلاقِ جلسةٍ لأن FCM لم يستجب يقلب الأولوية |
| 2026-09-10 | 🔁 **ما هو مبنيٌّ لا يُبنى ثانية** — اقتُرح في خطة م.7.4 نقطةٌ جديدة (`PUT /guardian/fcm-token`) وعمودُ `fcm_token` على نموذج `Guardian`. والاثنان مبنيّان منذ م.4 بصيغةٍ **أصحّ**: `POST /devices/register` يقبل الحقلَ ويُستدعى عند كل دخول، وجدولُ `devices` صفٌّ **لكل جهاز** لا لكل شخص — فللأب هاتفٌ ولزوجه آخر، وعمودٌ واحد يمحو الثاني صامتاً. فكان الناقصُ **تمريرَ الحقل** لا بناءَ سطحٍ ثانٍ. والقارئُ `PushTokenReader` دالّةٌ يمرّرها التطبيق لا اعتمادٌ على `firebase_messaging` في `mousqe_core`: الحزمةُ تخدم أربعةً ولا يحتاج ثلاثةٌ منها Firebase |
| 2026-09-10 | 🔄 **المرحلة 7.4 — شقُّها الخادميُّ منفَّذٌ ومُختبَر** ([CHECKPOINT-PHASE-7.4.MD](CHECKPOINT-PHASE-7.4.MD)): `PushNotifier` بتنفيذَين، وإشعارُ الغياب عند الإغلاق، وإشعارُ البتِّ في الإذن (ولا يُشعَر عن `pending`)، وحذفُ التوكن الميت الذي يردّه FCM حتى لا ينمو `devices` صامتاً. **417** اختباراً خادمياً (كانت 407) و**149** في `mousqe_core` (كانت 147). ⏸ **ويبقى مشروعُ Firebase نفسُه**: إنشاؤه و`flutterfire configure` وتوليدُ مفتاح الخدمة — ثلاثتُها من متصفّح صاحب المشروع. و`firebase_core`/`firebase_messaging` **لا تُضافان قبل ذلك** لأن `flutterfire configure` يضيفهما بنفسه، وإضافتُهما بلا `google-services.json` تعني تطبيقاً يبني ثم يسقط عند أوّل إقلاع |
| 2026-09-10 | 🔴 **مفتاحُ حساب الخدمة وقع مرّتين في مجلدٍ متتبَّع** (م.7.4) — في `backend/app/` وفي جذر `backend/`، وكلاهما داخل git ولا يستثنيه نمطٌ قائم. السببُ بنيويّ لا سهو: الملفُّ يُحمَّل من لوحة Firebase باسمٍ مولَّد (`<project>-firebase-adminsdk-<hash>.json`) **ويُنسَخ يدوياً**، والمسارُ الصحيح (`storage/app/`) اسمٌ يُشبه `app/` فيقع الخلط. لم يدخل أيَّ التزام (`git log --all` عليه فارغ)، وحُذفت النسختان بعد تطابق SHA-256. **والحارسُ أُضيف بالنمط لا بالمسار**: `*firebase-adminsdk*.json` — لأن المسارَ الصحيح محميٌّ أصلاً، والخطرُ في المسارات الخطأ وهي غيرُ محدودة. ومُجرَّبٌ بـ`git check-ignore` |
| 2026-09-10 | 🔑 **تهيئةُ Firebase لا تُسقط التطبيق إن فشلت** — الشائعُ `await Firebase.initializeApp()` عاريةً في `main`، فيصير **الإشعارُ شرطاً لإقلاع التطبيق**. وليس كذلك: وليُّ الأمر يفتحه ليقرأ حضورَ ابنه وذاك يعمل بلا Firebase (م.7.1–7.3)، ولو رُميت هناك لَما فتح التطبيقُ في جهازٍ بلا Google Play Services ولا في بناءٍ بلا `google-services.json`. **وطلبُ الإذن عند الدخول لا عند الإقلاع**: نافذةٌ تقفز على غريبٍ لم يعرف التطبيقَ بعدُ أسرعُ طريقٍ إلى «رفض»، وحين تقع بعد أن يدخل بحسابه يكون قد عرف أنه تطبيقُ متابعةِ ابنه. و`POST_NOTIFICATIONS` تأتي من بيان `firebase_messaging` نفسِه فلا تُضاف يدوياً |
| 2026-09-10 | ✅ **المرحلة 7.4 مكتملة — وبها تمّت المرحلة السابعة** ([CHECKPOINT-PHASE-7.4.MD](CHECKPOINT-PHASE-7.4.MD)). مشروع `mousqe` مربوطٌ بـ`flutterfire configure` غيرِ تفاعلي، وتطبيقُ أندرويد مسجَّل، والقناةُ المربوطة صارت `FcmPushNotifier` لا الصامتة (مُتحقَّقٌ منها بـ`artisan tinker`). **417** اختباراً خادمياً و**212** في Dart، و`app-debug.apk` يخرج بـFirebase مدمجةً — مُتحقَّقٌ من أن إضافة Gradle عالجت `google-services.json` بقراءة `google_app_id` من الموارد المولَّدة، لا بمجرّد نجاح البناء |
| 2026-09-10 | 🔴 **ثلاثةُ أعطابٍ لم يكشفها إلا التجريبُ على المحاكي** (م.7.4) — بعد أن مرّت 417 اختباراً خادمياً و212 في Dart، وبعد بناءِ APK ناجح، وبعد `flutter analyze` نظيف. **(1) الخريطةُ الفارغة تخرج من PHP مصفوفةً `[]` لا كائناً `{}`**، فيبدّل الحقلُ **نوعَه بحسب محتواه** ويرمي العميلُ — والنقطةُ ردّت 200 والشاشةُ عرضت «حدث خطأ غير متوقّع». ولم يكشفه الاختبار لأنه **ينشئ صفَّ تقدُّمٍ قبل القراءة**، والحالةُ الفارغة حالُ كلِّ طالبٍ جديد. **(2) لسانٌ أخضرُ على ترويسةٍ خضراء**: `TabBar` يرث افتراضيّاتِ Material 3 (`colorScheme.primary`) لا ألوانَ الترويسة التي يجلس فيها، فيختفي — ولا خطأ يُرمى ولا اختبارَ يسقط، فالودجت في الشجرة ويجدها `find.text` وإنما لونُها لونُ ما تحتها. **(3) PHP بلا `cacert.pem`** فكلُّ HTTPS صادر يفشل بـcURL 60. **والدرس: الاختبارُ يقيس ما خطر ببال كاتبه، والبناءُ يقيس أن الكود يُترجَم — ولا يقوم أحدُهما مقامَ النظر إلى الشاشة** |
| 2026-09-10 | ✅ **السيناريو المرجعي للمرحلة السابعة جرى كاملاً على محاكي Pixel 8 Pro**: دخولٌ بحساب `guardian1000` ⇒ **نافذةُ إذن الإشعارات ظهرت عند الدخول لا عند الإقلاع** كما صُمِّمت ⇒ توكنٌ حقيقي (142 حرفاً) وصل `devices` مربوطاً بالتطبيق `guardian` ⇒ «أبنائي» ⇒ ملفُّ الابن بمنحنىً **يتخطّى الأيام غير المقيسة ولا يهبط بها إلى القاع** ⇒ إغلاقُ جلسةٍ فيها غياب من الخادم ⇒ **«تسجيل غياب» في شريط الإشعارات**، ثم رفضُ إذنٍ ⇒ **«رُفض إذن الغياب»**. وبه تكتمل المرحلة السابعة: أربعُ مراحلَ فرعية، **419** اختباراً خادمياً و**212** في Dart |
| 2026-09-10 | ✅ **وصل شعارُ العميل — «معهد عمر الفاروق لتحفيظ القرآن الكريم»** بعد أن ظلّ موسوماً «⚠️ ما زال مطلوباً» من المرحلة الأولى إلى السابعة. في `design/logo/` بالأصل ومشتقّاته، وألوانُه **مقيسةٌ من الملف** لا مقدَّرة: المارون `#7F080A` (21.1٪ من البكسلات) والمشمشي `#FFBF9B` — وهما نفسُ ما تضبطه بيانات المعهد أصلاً |
| 2026-09-10 | 🔄 **ولم تُصبَغ اللوحةُ الافتراضية بألوان الشعار — والوعدُ القديم بذلك سبق م.5.1.** كان النصّ في §8: «نستبدل اللوحةَ المؤقّتة من `design-tokens.json` عند وصول الشعار»، ثم غيّرت م.5.1 المعمارية فصار لكل معهدٍ ثلاثةُ ألوانٍ في بياناته و`design-tokens.json` **احتياطياً لمن لم يضبط**. فلو صُبغ الافتراضيُّ بمارون عمر الفاروق لَصار **كلُّ معهدٍ جديد مارونيّاً** — عكسُ ما بُنيت له الميزة. **والدرس: وعدٌ في وثيقةٍ يبقى مكتوباً بعد أن تنسخه المعمارية، فيُنفَّذ بحسن نيّة فيهدم ما بُني** |
| 2026-09-10 | 🎨 **وأيقونةُ المشغّل الرمزُ وحده لا الشعارُ كاملاً** — الشعارُ يحمل سطرَي نصٍّ لا يُقرآن عند 48px، وإدراجُهما يقلّص الرمزَ حتى يكاد يختفي في القناع الدائري. فيُكشَف الرمزُ آلياً بفجوةِ الصفوف الفارغة التي تفصله عن النصّ (367×523 من 640×640) ويُملأ به المربّعُ بهامش 8٪. **والأيقونةُ بأرضيةٍ بيضاء لا شفّافة**: مشغّلاتٌ كثيرة تضع خلفيةً داكنة، فيصير المارونُ أسودَ على أسود. ⚠️ **وهي استثناءٌ لقاعدة «لكل معهدٍ ألوانُه»**: تُخبز في البناء ولا تُقرأ من `/bootstrap`، فنشرُ النظام لمعهدٍ ثانٍ يلزمه بناءٌ بنكهةٍ أخرى — بندٌ لـم.9 |
| 2026-09-10 | 🔑 **الرتبةُ تُحسب في الخادم — فخرج الطالبُ من `sync/pull`** (م.8.1). الفجوةُ السابعة بقيت مفتوحةً له بعد خروج وليّ الأمر في م.7.1، **وحجّتُه أقوى**: وليُّ الأمر يقرأ عن أبنائه وهم أكثرُ من واحد، والطالبُ يقرأ عن نفسه وحدها. وما كان يمنع ميزةٌ واحدة — ترتيبُه بين زملائه — و[APPS-FEATURES.md §6.2] يقول «يُحسب محلياً»، أي أن هاتفَه يستقبل **صفوفَ حضورِ كلِّ زملائه** ليستخرج رقماً واحداً. فقُلب الاتجاه: الخادمُ يحسب ويعيد «أنت الخامس من عشرين» **ولا صفَّ عن زميل**. واختبارُ العقد يحرسه بالنصّ: يُنشأ زميلٌ باسمٍ مميّز ويُتحقَّق أن اسمَه ومعرّفَه ليسا في الحمولة. **ولا جدارَ شرفٍ بأسماء**: الكشفُ المسمّى يعيد التسريبَ من البابِ الذي أُغلق |
| 2026-09-10 | 🔴 **جدولٌ قائمٌ منذ م.1 والوثيقةُ تقول إنه غيرُ موجود** — `announcements` مهاجَرٌ بـ`scope` و`scope_ids` ونموذجُه `Syncable` والصلاحيتان في الكتالوج، بينما [APPS-FEATURES.md §6.2] يقول «⚠️ لا مصدرَ لها اليوم — **تحتاج جدولاً** ونقطةً». **والناقصُ لم يكن الجدول بل طرفاه**: لا شاشةَ تكتب ولا نقطةَ تقرأ — حمولةٌ ميتة نظيرُ `report_templates` المحذوف في م.4.5. فبُني الطرفان معاً في م.8.1، وإلا لَصارت شاشةُ الطالب **وعداً لا يُنجَز**. **والدرس: وثيقةٌ تصف نقصاً قد تكون هي الناقصة — والفحصُ قبل البناء يوفّر جدولاً يُبنى مرّتين** |
| 2026-09-10 | 🔴 **البذرةُ كانت تنتج حضوراً وحده** — حاجبٌ موثَّقٌ منذ م.4.5 وظهر أثرُه فعلاً في م.7.4 حين فُتحت شاشةُ المحفوظات فارغةً على المحاكي. **وهو صنفُ نقصٍ لا يكشفه اختبار**: الاختبارُ ينشئ ما يحتاجه قبل أن يقرأه، ولا يشكو منه إلا من يفتح التطبيقَ على قاعدةٍ مبذورة. فصارت البذرةُ تسجّل درساً لا حضوراً: 175 تسميعة و64 منحةَ نقاط وإعلانان. **والغائبُ لا يُسمَّع** — بذرةٌ تعطي تسميعاً لطالبٍ غائب تصنع بياناً لا يقع في الواقع، فتُخفي عطباً يقع |
| 2026-09-10 | ⚠️ **تصادمُ أسماءٍ كاد يمحو ٤٩٩ سطراً** — `StudentRepository` مأخوذٌ منذ م.6.5 لمستودع إدارةِ الطلاب في الديسكتوب (يكتب في الطابور ويقرأ من drift)، وكتابةُ مستودعِ قراءةٍ للطالب باسمه محته. اكتُشف قبل الالتزام واستُعيد من `git`، وصار الاسمُ `StudentSelfRepository` نظيرَ `StudentSelfController` الخادمي. **والدرس: اسمٌ عامٌّ في حزمةٍ تخدم أربعةَ تطبيقات يُشغَل مبكّراً بمعنى غير الذي يخطر ببال من يكتب لاحقاً — والفحصُ قبل الكتابة أرخصُ من الاستعادة بعدها** |
| 2026-09-10 | ✅ **المرحلة 8.1 — كلُّ ما يقرؤه الطالب** ([CHECKPOINT-PHASE-8.1.MD](CHECKPOINT-PHASE-8.1.MD)): ثلاثُ نقاطٍ خادمية و`StudentSelfRepository` في `mousqe_core`، وشاشةُ إعلاناتٍ في اللوحة، وبذرةٌ تنتج درساً. و🔁 **`SnapshotStore` رُفعت من `GuardianRepository`** حين احتاجها المستودعُ الثاني — واختباراتُ ولي الأمر الثلاثةَ عشرَ مرّت بلا تعديلِ سطر، فالرفعُ نقلٌ لا إعادةُ كتابة. **437** خادمياً (كانت 419) و**222** في Dart (كانت 213) |
