# خطة نظام إدارة معهد تحفيظ القرآن (مساجد/حلقات)

> **حالة الخطة:** محدّثة بعد تنفيذ المرحلتين 0 و1.
> ما نُفِّذ موسوم بـ ✅، وما تغيّر عن الخطة الأصلية موسوم بـ 🔄 مع سبب التغيير.
> التوثيق التفصيلي للمخطط في [ERD.md](ERD.md)، ونقطة تفتيش المرحلة 1 في [CHECKPOINT-PHASE-1.MD](CHECKPOINT-PHASE-1.MD).

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
├─ docs/                       ✅ PLAN · ERD · CHECKPOINT-PHASE-1
├─ melos.yaml                  ✅
└─ README.md                   ✅
```

✅ `git init` منفَّذ على `mousqe/` وكل مرحلة تُسجَّل في commit مستقل.

---

## 4. نموذج البيانات ✅ (منفَّذ بالكامل)

38 migration جديدة، 53 جدولاً، 37 نموذج دومين، 18 enum. حُذف مجلد migrations الدومين القديم
وأُبقيت `users`, `cache`, `jobs`, `passkeys`, `two_factor`, `permission_tables`.

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
| `institutes` | name, short_name, logo_path, phone, email, address, timezone, settings(json), is_active |
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
| `curriculum_items` | curriculum_id, name, code, sort_order, meta(json), is_active |
| `student_curriculum_progress` | student_id, curriculum_item_id, course_circle_id, status, percent, score, started_on, completed_on, teacher_id, notes — `unique(student_id, curriculum_item_id)` |

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
| `attendances` | attendance_session_id, student_id, enrollment_id, status(present/absent/late/excused), late_minutes, note, recorded_by, recorded_at — `unique(session_id, student_id)` |
| `teacher_attendances` | attendance_session_id, teacher_id, status, late_minutes, note, recorded_by, recorded_at |
| `absence_excuses` | student_id, from_date, to_date, reason, attachment_path, submitted_by, status(pending/approved/rejected), reviewed_by, reviewed_at |

🔄 أُضيف `enrollment_id` إلى `attendances` ليبقى سجل الحضور مربوطاً بالتسجيل الذي وقع تحته — وهو
ما يجعل بيانات الطالب قبل النقل قابلة للاستعلام دون التباس.

`absence_excuses` يحقّق "إبلاغنا بالغياب مسبقاً" — ولي الأمر يقدّمه من تطبيق الأهل فيُقترح تلقائياً
حالة `excused` على شاشة تفقّد الأستاذ.

### 4.6 المتابعة القرآنية والتقييم ✅ (الجداول جاهزة، الواجهات لاحقاً)

| الجدول | الحقول |
|---|---|
| `memorization_logs` | student_id, course_circle_id, attendance_session_id, curriculum_item_id, date, type(hifz/murajaa/tilawah), from_surah, from_ayah, to_surah, to_ayah, pages, memorization_score, tajweed_score, mistakes_count, teacher_id, notes |
| `evaluations` | student_id, course_circle_id, period(weekly/monthly/term), period_start, period_end, behavior, commitment, memorization, tajweed, total, teacher_id, notes |

### 4.7 الإحصاء والتقارير ✅ (الجداول جاهزة، الحساب في المرحلة 3)

| الجدول | الحقول |
|---|---|
| `circle_daily_stats` | course_circle_id, date, present, absent, late, excused, total, attendance_rate, **daily_rank_in_shift** |
| `circle_cumulative_stats` | course_circle_id, as_of_date, sessions_count, present, absent, late, excused, total, attendance_rate, **overall_rank_in_shift** |
| `report_templates` | institute_id, key, name, scope(circle/shift/course/institute), body (نص بمتغيرات `{{circle_name}}`, `{{date}}`, `{{present_list}}`, `{{absent_list}}`, `{{rate}}`, `{{daily_rank}}`, `{{overall_rank}}`) |
| `report_exports` | institute_id, type, params(json), file_path, status, generated_by, generated_at |

**التصنيف اليومي** = ترتيب الحلقة بين حلقات نفس الدوام حسب نسبة حضور اليوم.
**التصنيف الكلي** = الترتيب حسب معدّل النسبة منذ بداية الدورة.
تُحدَّث عبر `RecalculateCircleStats` job يُطلق عند إغلاق أي جلسة تفقّد (المرحلة 3).

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

- ✅ `app/Models/` — 37 نموذجاً مع العلاقات و`HasUuid`
- ✅ `app/Enums/` — 18 enum بتسميات عربية (`label()`) وخريطة خيارات (`options()`)
- ✅ `app/Concerns/HasUuid.php`
- ⬜ `app/Actions/` — `TakeAttendance`, `CompleteAttendanceSession`, `TransferStudent`, `CloneCourseCircles`, `RecalculateCircleStats` (المرحلتان 2 و3)
- ⬜ `app/Services/Sync/` — `SyncPuller`, `SyncPusher`, `ConflictResolver` (المرحلة 4)
- ⬜ `app/Http/Resources/V1/` — Eloquent API Resources (المرحلة 4)
- ⬜ `app/Livewire/` — مكوّنات لوحة التحكم (المرحلة 2)

**نقاط الـ API (`routes/api.php`, prefix `/api/v1`) — المرحلة 4:**

```
POST   /auth/login              /auth/logout   GET /auth/me
POST   /devices/register
GET    /bootstrap               لقطة أولية لنطاق المستخدم
GET    /sync/pull?since={seq}   تغييرات ضمن نطاق المستخدم فقط
POST   /sync/push               دفعة عمليات مع op_uuid (idempotent)
GET    /teacher/circles         /teacher/sessions/{date}
POST   /teacher/sessions        POST /teacher/sessions/{id}/complete
GET    /guardian/children       /guardian/children/{id}/attendance
POST   /guardian/excuses
GET    /student/me/attendance   /student/me/progress
GET    /reports/circle/{id}/weekly|monthly (PDF)
```

**بروتوكول المزامنة (`docs/sync-protocol.md` — يُكتب في المرحلة 4):**

1. كل صف يحمل `uuid` يولّده العميل ⇒ الإنشاء أوف-لاين لا يحتاج الخادم. ✅ جاهز
2. **الدفع:** العميل يرسل عمليات مرتّبة، كل عملية بـ `op_uuid` فريد. الخادم يتجاهل ما نُفّذ سابقاً
   (idempotency) ويكتب في `change_log`.
3. **السحب:** `since=last_pulled_seq` يعيد كل تغييرات `change_log` ضمن `scope_key` المسموح للمستخدم.
4. **حلّ التعارض:** آخر `recorded_at` يفوز على مستوى صفّ `attendances` (المفتاح `session+student`
   يجعل التعارضات نادرة جداً)، والقيمة المُستبدَلة تُحفظ في `sync_conflicts` لعرضها للمشرف.
5. **قفل الجلسة:** عند `completed` تُقفَل. أي تعديل لاحق يتطلب صلاحية `attendance.amend` ويُسجَّل في
   `activity_log`. ✅ `AttendanceSession::isEditable()` جاهزة
6. النطاق: الأستاذ يزامن حلقاته فقط؛ الديسكتوب يزامن المعهد كاملاً؛ الأهل/الطالب للقراءة فقط.

---

## 6. لوحة التحكم (Livewire 4 + Flux + Tailwind 4) — المرحلة 2

RTL كامل (`dir="rtl"`, `lang="ar"`)، خصائص Tailwind المنطقية (`ps-*`/`pe-*`)، تاريخ هجري + ميلادي.
✅ `APP_LOCALE=ar` و`APP_FAKER_LOCALE=ar_SA` مضبوطان.

**الشاشات:**

- **الداشبورد** — نِسب الحضور/الغياب على مستوى المعهد، لكل دوام، ولكل حلقة. مخططات خطية للاتجاه
  الزمني، جدول ترتيب الحلقات، بطاقات KPI، مؤشرات الطلاب الأكثر غياباً.
- **الدورات** — إنشاء دورة، استنساخ حلقات الدورة السابقة، أرشفة، تفعيل الدورة الحالية.
- **الدوامات** — أيام الأسبوع + الأوقات + الحلقات المداومة فيه.
- **الحلقات** — CRUD، إسناد الأستاذ، قائمة الطلاب، سحب-وإفلات لنقل طالب بين حلقات نفس الدورة.
- **الطلاب** — CRUD باستمارة التسجيل الكاملة (البيانات الشخصية، الأب والأم، الحالة الصحية، الصفات،
  المحفوظات)، بحث/تصفية، الواصفات المخصّصة، ملف الطالب (تاريخ الحضور عبر كل الدورات، الرسم البياني،
  النقلات، خريطة تقدّم الحفظ).
- **الأساتذة** — CRUD، الحلقات المسنَدة، حضور الأستاذ.
- **التفقّد** — شبكة Checkbox سريعة (حاضر/غائب/متأخّر/إذن) مع لوحة مفاتيح، تفقّد رجعي، وقفل الجلسة.
- **المناهج** — إدارة المناهج وبنودها، وإسناد التقدّم للطلاب.
- **التقارير** — أسبوعي/شهري لكل حلقة/دوام/دورة، تصدير PDF عربي بالهوية البصرية.
- **الإعدادات** — بيانات المعهد، الشعار، الواصفات المخصّصة، الصفات، قوالب التقارير، المستخدمون والصلاحيات.

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
| 2 | لوحة التحكم — الإدارة | المعاهد/الدورات/الدوامات/الحلقات/الطلاب/الأساتذة/التسجيل/النقل/الواصفات/المناهج + هوية بصرية RTL | ٦–٨ أيام | ⬜ التالية |
| 3 | التفقّد والتقارير | شاشة التفقّد، حساب الإحصاءات والترتيب، الداشبورد، تصدير PDF | ٥–٦ أيام | ⬜ |
| 4 | طبقة API والمزامنة | Sanctum، Resources، `sync/pull` و`sync/push`، `change_log`، حلّ التعارضات | ٥–٦ أيام | ⬜ |
| 5 | **تطبيق الأستاذ** | Flutter أوف-لاين كامل + `mousqe_core` + `mousqe_ui` | ٨–١٠ أيام | ⬜ |
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
8. **لوحة المسابقات** — ترتيب الطلاب والحلقات، شارات إنجاز، جدار شرف شهري.
9. **الرسوم والاشتراكات** — إن كان المعهد يتقاضى رسوماً: أقساط، إيصالات، تقارير مالية.
10. **حضور الأساتذة والرواتب/المكافآت** — ✅ `teacher_attendances` جاهز، يبقى بناء التقارير.

**استراتيجي / لاحقاً**

11. ✅ **تعدّد المعاهد (SaaS)** — جاهز بنيوياً: `institute_id` في كل جدول + وضع الفرق في Spatie مفعّل؛
    يحتاج فقط شاشة إدارة مركزية.
12. **واتساب** — عند رغبتك: قالب رسالة (`report_templates` جاهز) + `wa.me` أو Cloud API خلف واجهة Driver.
13. **تقارير ذكية** — ملخّص شهري تلقائي بالعربية يحلّل اتجاه الحضور ويقترح تدخّلات.
14. **مواقيت الصلاة والتقويم الهجري** داخل الداشبورد وربطها بجدولة الدوامات
    (`students.registration_date_hijri` بداية).

---

## 11. خارج نطاق هذه الخطة

- **إرسال رسائل الواتساب** — مؤجَّل بطلبك. المعمارية تحفظ مكانه: `report_templates` (متغيّرات القالب)
  و`report_exports` جاهزان، وسيُضاف لاحقاً `MessageDriver` (wa.me / Cloud API) دون إعادة كتابة.

---

## 12. التحقق والاختبار

**الباك إند** (`cd backend`)

```bash
php artisan migrate:fresh --seed          # معهد + دورة + دوامان + 6 حلقات + 78 طالباً + 30 جلسة تفقّد
php artisan test --compact                # 58/58 حالياً
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

**اختبارات مطلوبة في مراحلها:**

- `StudentTransferTest` (م.2) — بعد النقل: لا يظهر في تفقّد الحلقة القديمة، وسجله التاريخي سليم.
- `CourseResetTest` (م.2) — دورة جديدة ⇒ عدّادات الغياب صفر، والسجل القديم قابل للاستعلام.
- `CircleStatsTest` (م.3) — صحة نسبة الحضور والتصنيف اليومي والكلي.
- `SyncPushPullTest` (م.4) — إعادة إرسال نفس `op_uuid` لا تكرّر البيانات؛ `since` يعيد التغييرات الصحيحة فقط.
- `SyncConflictTest` (م.4) — جهازان يعدّلان نفس صفّ الحضور ⇒ الأحدث يفوز والقديم يُسجَّل في `sync_conflicts`.
- `ScopeTest` (م.4) — الأستاذ لا يسحب بيانات حلقة ليست له؛ ولي الأمر يرى أبناءه فقط.

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
