# خطة نظام إدارة معهد تحفيظ القرآن (مساجد/حلقات)

> **حالة الخطة:** محدّثة بعد تنفيذ المراحل 0 إلى 4.5.
> ما نُفِّذ موسوم بـ ✅، وما تغيّر عن الخطة الأصلية موسوم بـ 🔄 مع سبب التغيير.
> التوثيق التفصيلي للمخطط في [ERD.md](ERD.md)، ونقاط التفتيش في
> [CHECKPOINT-PHASE-1.MD](CHECKPOINT-PHASE-1.MD)، [CHECKPOINT-PHASE-2.MD](CHECKPOINT-PHASE-2.MD)،
> [CHECKPOINT-PHASE-3.MD](CHECKPOINT-PHASE-3.MD)، [CHECKPOINT-PHASE-4.MD](CHECKPOINT-PHASE-4.MD)،
> و[CHECKPOINT-PHASE-4.5.MD](CHECKPOINT-PHASE-4.5.MD).

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
│  ├─ teacher/                 Flutter — Android + iOS  (المرحلة 5)
│  ├─ admin_desktop/           Flutter — Windows        (المرحلة 6)
│  ├─ guardian/                Flutter                  (المرحلة 7)
│  └─ student/                 Flutter                  (المرحلة 8)
├─ packages/
│  ├─ mousqe_core/             نماذج + drift(SQLite) + محرك المزامنة + عميل API
│  └─ mousqe_ui/               نظام التصميم: ألوان، خط كوفي، ويدجتس، RTL
├─ design/
│  ├─ logo/                    ملف الشعار الأصلي (⚠️ ما زال مطلوباً من العميل)
│  └─ design-tokens.json       ✅ مصدر واحد للألوان يُستهلك من Tailwind ومن Flutter
├─ docs/                       ✅ PLAN · ERD · CHECKPOINT-PHASE-1…4.5
├─ melos.yaml                  ✅
└─ README.md                   ✅
```

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

الأدوار الستة: `super_admin` · `admin` · `supervisor` · `teacher` · `guardian` · `student`،
مع 38 صلاحية مصنّفة في `RolesAndPermissionsSeeder`. الأدوار عامة (`team_id = null`) والإسناد وحده
مرتبط بمعهد.

> ⚠️ **إلزامي قبل أي `assignRole` أو `hasRole`:**
> `App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);`

---

## 5. الباك إند — Laravel 13

**الحزم:** `spatie/laravel-permission` ✅ مثبّتة. المؤجَّلة للمرحلة 4: `laravel/sanctum` (توكنات API)،
`spatie/laravel-activitylog`، `spatie/laravel-pdf` (Chromium — الوحيد الذي يدعم تشكيل العربية RTL
بشكل صحيح؛ **لا** dompdf)، `maatwebsite/excel` (اختياري).
قاعدة البيانات: **MySQL/MariaDB** للإنتاج، SQLite للتطوير المحلي.

**البنية:** نلتزم بـ `backend/AGENTS.md` (PHP 8.4، `php artisan make:*`، Pint، PHPUnit، اختبار لكل تغيير).

- ✅ `app/Models/` — 38 نموذجاً مع العلاقات و`HasUuid`
- ✅ `app/Enums/` — 21 enum بتسميات عربية (`label()`) وخريطة خيارات (`options()`)
  🔄 م.4.5: +`RecitationGrade` · `PointReason` · `NotePolarity`، −`ReportScope`
- ✅ `app/Concerns/HasUuid.php`
**قاعدة فصل الطبقات (اعتُمدت في المرحلة 3، وأُعيد عليها كلُّ ما سبق):**
**كل كتابة تمرّ بـ `app/Actions/`، وكل قراءة تمرّ بـ `app/Queries/`.**
ملف الشاشة لا يحمل استعلاماً ولا قاعدة عمل — يحمل حالة الواجهة وربطها فقط.

- ✅ `app/Actions/` — 31 إجراء كتابة: التسجيل والنقل والاستنساخ والتفعيل والاستمارة (م.2)،
  والتفقّد ودورة حياة الجلسة والإحصاء والأذونات (م.3)، والمزامنة (م.4)
  🔄 م.4.5: `SaveRecitation` · `DeleteRecitation` · `AwardStudentPoints` · `CalculateStudentPoints` ·
  `BuildStudentCoverageMap` · `BuildCirclePointsReport` · `SaveStudentCurriculumProgress`
  (−`RenderReportTemplate`)
- ✅ `app/Queries/` — 14 صنف قراءة: `DashboardOverviewQuery`, `AttendanceBoardQuery`,
  `AttendanceSessionQuery`, `CircleRankingQuery`, `StudentProfileQuery`, `StudentListQuery`,
  `StudentFormQuery`, `CircleQuery`, `InstituteCatalogQuery`, `AbsenceExcuseQuery`,
  `TeacherCircleQuery`, `GuardianChildrenQuery`, و🔄 م.4.5 `StudentPointsQuery` · `StatsQuery`
  (−`ReportTemplateQuery`)
- ✅ `app/Casts/DateOnly.php` — أعمدة التاريخ بلا وقت تُكتب دائماً `Y-m-d`
- ✅ `app/Support/` — `Quran` (السور + 🔄 م.4.5 الأسطر وسور كل جزء)، `HijriDate` (أم القرى عبر intl)،
  `ApiScope` (م.4)، و🔄 م.4.5 `PointsSettings` · `AttendanceRate` · `DateRange`
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
- ✅ `resources/views/pages/` — 19 مكوّن Livewire 4 أحادي الملف (SFC) للوحة التحكم
  🔄 لا مجلد `app/Livewire/`: هذا المشروع على Livewire 4 حيث المكوّن ملف Blade واحد تحت `pages::`
  🔄 أُزيلت سابقة ⚡ من أسماء الملفات: اختيارية في Livewire 4 (`Finder` يجرّبها ثم يسقط إلى الاسم
  المجرّد)، وكانت تُعقّد أوامر الطرفية والبحث بلا مقابل
- ✅ `app/Concerns/InteractsWithInstitute.php` — المعهد العامل والدورة الجارية لكل شاشة

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
   `points.award` — كلها تستدعي أفعال اللوحة نفسها.
3. **السحب:** `since=last_pulled_seq` يعيد كل تغييرات `change_log` ضمن `scope_key` المسموح للمستخدم.
   ✅ `SyncPull` — 🔄 النطاق الآن معهدٌ كامل لكل الأدوار، لا حلقات الأستاذ وحدها؛ التضييق مؤجَّل لِما
   بعد قياس أداء حقيقي (م.5).
4. **حلّ التعارض:** آخر `recorded_at` يفوز على مستوى صفّ `attendances`، والقيمة المُستبدَلة تُحفظ في
   `sync_conflicts` لعرضها للمشرف. ✅ `ResolveAttendanceConflicts`
5. **قفل الجلسة:** عند `completed` تُقفَل. أي تعديل لاحق يتطلب صلاحية `attendance.amend`. ✅
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
  ⬜ المستخدمون والصلاحيات — **المرحلة 6**.
  🔄 **قوالب التقارير: حُذفت** ولن تعود إلا مع قناة إرسال حقيقية.

---

## 7. تطبيقات فلاتر — المراحل 5 إلى 8

**الستاك الموحّد:** Riverpod 2 · drift (SQLite) · dio + retrofit · freezed · go_router ·
`flutter_localizations` (ar افتراضياً، RTL) · firebase_messaging · `pdf`+`printing` للتصدير المحلي ·
`window_manager` للديسكتوب. تُدار بـ **melos** ✅.

**`packages/mousqe_core`** (يستخدمه الأربعة): نماذج freezed مطابقة لمخطط الخادم، مخطط drift المحلي،
`SyncEngine` (طابور عمليات + إعادة محاولة + كشف الاتصال)، `ApiClient`، تخزين آمن للتوكن.

| التطبيق | المحتوى |
|---|---|
| **الأستاذ** (م.5) | حلقاتي · شاشة تفقّد بضغطة واحدة تعمل **أوف-لاين** · سجل الجلسات · ملف الطالب · تسجيل الحفظ · مؤشّر حالة المزامنة |
| **الديسكتوب/ويندوز** (م.6) | كل ما سبق + إدارة الطلاب/الحلقات/الدورات · الداشبورد · التقارير والطباعة · إدارة التعارضات · نسخ احتياطي محلي |
| **الأهل** (م.7) | متابعة أبنائي · إشعار فوري عند تسجيل غياب · تقديم إذن مسبق · التقرير الأسبوعي/الشهري · تقدّم الحفظ |
| **الطالب** (م.8) | حضوري ونسبتي · ترتيبي في الحلقة · وِرد اليوم وتقدّم الحفظ · الإعلانات |

---

## 8. الهوية البصرية

- ✅ **مصدر واحد للتوكنات:** `design/design-tokens.json` يُولّد منه `@theme` في Tailwind 4 و`ThemeData`
  في `mousqe_ui` ⇒ تطابق مضمون بين الويب والتطبيقات. يتضمّن تدرّجات كاملة وألوان حالات التفقّد.
- **الخطوط:** *Reem Kufi* / *Noto Kufi Arabic* للعناوين والشعار + *IBM Plex Sans Arabic* أو *Tajawal* للنصوص.
- ✅ **لوحة مؤقّتة** إلى حين وصول الشعار: أخضر عميق `#0F5132` · ذهبي `#C9A227` · رملي `#F7F3EA` · فحمي `#1C1B19`.
- عناصر زخرفية إسلامية خفيفة (إطارات هندسية) في الترويسات وأغلفة الـ PDF دون إثقال الواجهة.
- وضع فاتح/داكن، وحجم خط قابل للتكبير.

> ⚠️ **ما زال مطلوباً من العميل:** ملف الشعار (SVG مفضّل). نعمل باللوحة المؤقّتة ونستبدلها من
> `design-tokens.json` في خطوة واحدة عند وصوله.

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
| 5 | **تطبيق الأستاذ** | Flutter أوف-لاين كامل + `mousqe_core` + `mousqe_ui` | ٨–١٠ أيام | ⬜ التالية |
| 6 | **تطبيق الديسكتوب** | Windows، إعادة استخدام ≈٧٠٪ من كود الأستاذ + شاشات الإدارة والطباعة | ٦–٨ أيام | ⬜ |
| 7 | **تطبيق الأهل** | مع إشعارات FCM وطلبات الإذن | ٥–٦ أيام | ⬜ |
| 8 | **تطبيق الطالب** | عرض للقراءة + تحفيز (ترتيب، شارات) | ٣–٤ أيام | ⬜ |
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
php artisan test --compact                # 201/201 حالياً
vendor/bin/pint --dirty --format agent    # التنسيق قبل أي إنهاء
composer run dev                          # serve + queue + vite
```

حساب المشرف بعد البذر: `admin@mousqe.test` / `password`

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

**اختبارات مطلوبة في مراحلها:**

- (لا شيء معلّق من هذه القائمة بعد المرحلة 4.5)

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
| **ملف الشعار** | ⚠️ غير مرفق — نعمل بلوحة مؤقّتة (§8) ونستبدلها لاحقاً بخطوة واحدة |
| **الاستضافة** | ⚠️ غير محدّدة (Laravel Cloud / VPS / Hostinger) — تُحسم قبل المرحلة ٩ |
| **حساب Firebase** | ⚠️ مطلوب قبل المرحلة ٧ (إشعارات الأهل) |
| **iOS** | يتطلب حساب Apple Developer (٩٩$/سنة) وجهاز macOS للبناء — نبدأ بأندرويد فقط ما لم تُطلب iOS |
| **PDF العربي** | `spatie/laravel-pdf` يتطلب Chromium على الخادم — يُثبَّت في المرحلة ٣ |
| **قاعدة بيانات الإنتاج** | التطوير على SQLite؛ الانتقال إلى MySQL/MariaDB يُحسم قبل المرحلة ٩ |
| **المنطقة الزمنية للبيانات القائمة** | 🔴 التطبيق كان يعمل على UTC حتى م.4.5 («اليوم» ينقلب ٣:٠٠ فجراً بتوقيت دمشق)؛ صار `APP_TIMEZONE=Asia/Damascus`. **بيانات كُتبت قبل ذلك تحتاج ترحيلاً زمنياً** — في التطوير `migrate:fresh --seed` يكفي |
| **دقّة جدول أسطر السور** | جدول `Quran::LINES` تقديريّ مشتقّ حسابياً لا منقول عن مصدر رسمي (انحراف 0.12%)؛ استبداله تعديلُ ثابتٍ واحد ولا يمسّ التاريخ لأن الأسطر والنقاط مجمّدة في السجل |
| **حجم البيانات** | ≤٢٠ حلقة × ≤٢٠ طالباً ⇒ SQLite محلي ومزامنة كاملة كافيان بلا قلق أداء |

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
