# نقطة تفتيش — المرحلة 1: نواة الباك إند

**التاريخ:** 2026-09-01
**الحالة:** ✅ مكتملة — 58/58 اختباراً ناجحاً، Pint نظيف
**آخر commit:** `3200963` — feat(backend): نموذج بيانات المعهد كاملاً مع استمارة تسجيل الطالب

---

## 1. ما الذي أُنجز

### المرحلة 0 — التهيئة (مكتملة)

| البند | الحالة |
|---|---|
| نقل `Mosque-Management` إلى `mousqe/backend/` | ✅ نُقل كاملاً بما فيه `vendor/` و`node_modules/` |
| هيكل المستودع الموحّد | ✅ `apps/{teacher,admin_desktop,guardian,student}` · `packages/{mousqe_core,mousqe_ui}` · `design/` · `docs/` |
| `git init` | ✅ commitان على المستودع الجذر |
| `design/design-tokens.json` | ✅ لوحة مؤقّتة + خطوط + أنصاف أقطار + ظلال |
| `melos.yaml` | ✅ مع سكربتات `analyze` / `test` / `format` / `gen` |
| `.gitignore` موحّد | ✅ يغطي Laravel وFlutter وأدوات التطوير |

> ⚠️ المسار القديم `d:\Development\Laravel\Mosque-Management` **لم يعد موجوداً** — نُقل بالكامل.

### المرحلة 1 — نواة الباك إند (مكتملة)

| المخرَج | العدد | التفصيل |
|---|---|---|
| Migrations | **38 جديدة** (44 إجمالاً) | حُذف مخطط الدومين القديم بالكامل؛ أُبقيت `users`, `cache`, `jobs`, `passkeys`, `two_factor`, `permission_tables` |
| جداول قاعدة البيانات | **53** | تشمل جداول النظام وSpatie |
| Models | **37 دومين** + `User` | كلها تحمّل بنجاح وتُحلّ إلى جداولها الصحيحة |
| Enums | **18** | جميعها `string`-backed مع `label()` عربية و`options()` |
| Factories | **25 جديدة** | ببيانات عربية واقعية (أسماء، مدن، مهن، صفوف دراسية) |
| Seeders | **4** + `DatabaseSeeder` | الأدوار، الصفات، المناهج، المعهد التجريبي |
| اختبارات جديدة | **25** | في `tests/Feature/Models` و`tests/Feature/Seeders` |
| إجمالي الاختبارات | **58 / 58 ناجحة** | 130 تأكيداً، ~3.5 ثانية |

---

## 2. نموذج البيانات

### 2.1 التنظيم الهرمي

```
institutes
  └─ courses                    ← نطاق تصفير عدّادات الغياب
       └─ shifts + shift_days   ← أيام ثابتة أسبوعياً
            └─ course_circles   ← unique(course_id, circle_id)
                 ├─ course_circle_teachers
                 ├─ enrollments
                 └─ attendance_sessions → attendances / teacher_attendances
```

`circles` منفصل عن `course_circles`: هوية الحلقة ثابتة عبر الدورات، وتشغيلها ضمن دورة بعينها صفٌّ مستقل.
هذا ما يحقّق **تصفير العدّادات مع كل دورة جديدة** دون فقدان السجل التاريخي للطالب.

### 2.2 تغطية استمارة تسجيل الطالب

| مجموعة الاستمارة | الجدول | التغطية |
|---|---|---|
| البيانات الأساسية والشخصية (12 حقلاً) | `students` | ✅ كاملة |
| بيانات ولي الأمر (الأب والأم: اسم/عمل/هاتف) | `guardians` + `guardian_student` | ✅ كاملة |
| عدد أفراد العائلة | `students.family_members_count` | ✅ |
| الحالة الصحية للطالب والعائلة | `students.student_health_status` / `family_health_status` | ✅ |
| الصفات التسع (هادئ … خجول) | `traits` + `student_trait` | ✅ اختيار متعدّد + مزروعة |
| محفوظات القرآن (30 جزءاً) | `curricula` + `curriculum_items` | ✅ مزروعة |
| الحديث (الأربعون ١/٢/٣ + مجامع الأنوار) | نفسها | ✅ مزروعة |
| المتون السبعة | نفسها | ✅ مزروعة |
| متابعة تقدّم الطالب في كل بند | `student_curriculum_progress` | ✅ |
| المناهج العلمية المضافة | `curricula` بنوع `custom` | ✅ بلا تعديل مخطط |
| الملاحظات العامة | `students.notes` + `memorization_logs` + `evaluations` | ✅ |

**قرارا تصميم يستحقان التسجيل:**

1. **بيانات الأب والأم ليست أعمدة في `students`.** ولي الأمر يملك حساباً في تطبيق الأهل وقد يتابع أكثر
   من ابن؛ تكرار حقوله داخل كل صفّ طالب كان سيمنع ربطه بحساب واحد ويكرّر تعديل رقم هاتفه. الوصول
   المختصر متاح عبر `$student->father()` و`$student->mother()`.
2. **الصفات جدول مستقل لا حقول بولينية.** يتيح للمشرف إضافة صفات خاصة بمعهده، ويحمل `polarity`
   لتمييز ما يحتاج متابعة، و`note` و`noted_by` لكل إسناد.

### 2.3 القيود الحرجة المطبَّقة

| القيد | الجدول | ما يمنعه |
|---|---|---|
| `unique(course_id, circle_id)` | `course_circles` | الحلقة في أكثر من دوام ضمن الدورة الواحدة |
| `unique(course_circle_id, student_id)` | `enrollments` | تسجيل الطالب مرّتين في الحلقة |
| `unique(course_circle_id, session_date)` | `attendance_sessions` | جلستا تفقّد في اليوم نفسه |
| `unique(attendance_session_id, student_id)` | `attendances` | ازدواج سجل الحضور — ويجعل تعارضات المزامنة نادرة |
| `unique(student_id, curriculum_item_id)` | `student_curriculum_progress` | ازدواج سجل الحفظ للبند الواحد |
| `unique(student_id, trait_id)` | `student_trait` | إسناد الصفة مرّتين |
| `unique(institute_id, registration_no)` | `students` | تكرار رقم بطاقة الطالب |

كلها مغطّاة باختبارات تتوقّع `UniqueConstraintViolationException`.

### 2.4 جاهزية المزامنة

كل جدول دومين يحمل `uuid` (يولّده `App\Concerns\HasUuid` بـ `Str::uuid7`) و`timestamps(3)` و`softDeletes`.
جداول `change_log` و`sync_devices` و`sync_conflicts` منشأة وجاهزة للمرحلة 4 — لم تُكتب منطقيتها بعد.

الجداول المستثناة من `uuid` عمداً (مشتقّة أو محلية): `circle_daily_stats`، `circle_cumulative_stats`،
`taggables`، `devices`، `sync_devices`، `settings`.

---

## 3. الأدوار والصلاحيات

`spatie/laravel-permission` **بوضع الفرق مفعّل** والمفتاح `institute_id` (كان مضبوطاً مسبقاً في
`config/permission.php`). الأدوار عامة (`team_id = null`)، والإسناد وحده مرتبط بمعهد.

```php
// ⚠️ إلزامي قبل أي assignRole / hasRole
App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);
```

الأدوار الستة: `super_admin` · `admin` · `supervisor` · `teacher` · `guardian` · `student`
والصلاحيات 38 صلاحية مصنّفة في `RolesAndPermissionsSeeder::PERMISSIONS`.

---

## 4. بيانات البذر

```bash
cd backend && php artisan migrate:fresh --seed
```

| الكيان | العدد |
|---|---|
| معهد | 1 — معهد النور لتحفيظ القرآن الكريم |
| دورة جارية | 1 |
| دوامات | 2 — صباحي (الأحد/الثلاثاء/الخميس) · مسائي (الاثنين/الأربعاء) |
| حلقات | 6 |
| أساتذة | 6 |
| طلاب | 78 (13 لكل حلقة) |
| أولياء أمور | 156 (أب وأم لكل طالب) |
| صفات مُسنَدة | 234 (3 لكل طالب) |
| جلسات تفقّد مكتملة | 30 عن آخر أسبوعين |
| سجلات حضور | 390 |
| مناهج / بنود | 3 / 41 |

**حساب المشرف:** `admin@mousqe.test` — كلمة المرور `password`

---

## 5. الاختبارات

```bash
cd backend
php artisan test --compact                       # 58/58
php artisan test --compact tests/Feature/Models  # 16
vendor/bin/pint --dirty --format agent
```

| الملف | عدد الاختبارات | ما يغطّيه |
|---|---|---|
| `Models/StudentTest.php` | 6 | توليد UUID · الاسم الثلاثي · حقول الاستمارة · الأب والأم · الصفات المتعدّدة · منع تكرار الصفة |
| `Models/CourseCircleTest.php` | 3 | الحلقة في دوام واحد · تكرارها في دورة أخرى · الأساتذة المسنَدون |
| `Models/AttendanceSessionTest.php` | 4 | منع جلستين في يوم · سجل واحد لكل طالب · قابلية التعديل حسب الحالة · تحويل الحالة إلى enum |
| `Models/EnrollmentTest.php` | 3 | تسجيل واحد لكل حلقة · نطاق `active` · حفظ سجل الحلقات السابقة |
| `Seeders/CurriculumSeederTest.php` | 4 | المناهج الثلاثة · الأجزاء الثلاثون · بنود الحديث والمتون · عدم التكرار عند إعادة البذر |
| `Seeders/RolesAndPermissionsSeederTest.php` | 5 | الأدوار الستة · صلاحيات المشرف · حدود الأستاذ وولي الأمر · عزل الدور بالمعهد |

---

## 6. تغييرات على الكود الموروث

| التغيير | السبب |
|---|---|
| `User` — إضافة `HasRoles` وتصحيح `#[Fillable]` إلى `first_name/last_name/...` | المخطط الموروث لجدول `users` يستخدم هذه الأعمدة، بينما النموذج ظلّ على `name` |
| `UserFactory` — `first_name` + `last_name` بدل `name` | نفس السبب |
| `CreateNewUser` و`ProfileValidationRules` وواجهتا التسجيل والملف الشخصي | **كان تدفّق التسجيل مكسوراً قبل هذا العمل** (خطأ NOT NULL على `users.first_name`) |
| `RegistrationTest` و`ProfileUpdateTest` | مواءمة الاختبارين مع المخطط |
| `.env` و`.env.example` | `APP_NAME=مُصلّى` · `APP_LOCALE=ar` · `APP_FALLBACK_LOCALE=ar` · `APP_FAKER_LOCALE=ar_SA` |

أُضيف `name` كخاصية محسوبة على `User` تجمع الاسم الأول والأخير، فلم ينكسر أي استخدام سابق للعرض.

---

## 7. ما لم يُنفَّذ بعد (مقصود — خارج نطاق المرحلة 1)

| البند | مرحلته |
|---|---|
| `app/Actions/` — `TakeAttendance`, `TransferStudent`, `CloneCourseCircles`, `RecalculateCircleStats` | 2 و3 |
| لوحة التحكم Livewire + الهوية البصرية RTL | 2 |
| شاشة التفقّد وحساب الإحصاءات والترتيب وتصدير PDF | 3 |
| الحزم المؤجَّلة: `laravel/sanctum`, `spatie/laravel-activitylog`, `spatie/laravel-pdf`, `maatwebsite/excel` | 4 (وجدول `activity_log` معها) |
| `app/Services/Sync/` ونقاط `/api/v1` ومنطق `change_log` | 4 |
| تطبيقات فلاتر و`packages/mousqe_core` و`mousqe_ui` | 5 – 8 |
| اختبارات `StudentTransferTest`, `CourseResetTest`, `CircleStatsTest`, `SyncPushPullTest`, `SyncConflictTest`, `ScopeTest` | تتبع مراحلها |

---

## 8. نقاط مفتوحة تحتاج قراراً منك

| البند | الأثر | متى يلزم |
|---|---|---|
| **ملف الشعار (SVG مفضّل)** | نعمل الآن بلوحة مؤقّتة في `design-tokens.json`؛ الاستبدال خطوة واحدة | قبل نهاية المرحلة 2 |
| **الاستضافة** (Laravel Cloud / VPS / Hostinger) | يحدّد إعداد النشر والنسخ الاحتياطي | قبل المرحلة 9 |
| **حساب Firebase** | إشعارات تطبيق الأهل | قبل المرحلة 7 |
| **iOS** | يتطلب حساب Apple Developer وجهاز macOS — نبدأ بأندرويد فقط ما لم تُطلب | قبل المرحلة 5 |
| **قاعدة بيانات الإنتاج** | التطوير على SQLite؛ الخطة تعتمد MySQL/MariaDB للإنتاج | قبل المرحلة 9 |

---

## 9. الخطوة التالية

**المرحلة 2 — لوحة التحكم (الإدارة):** المعاهد والدورات والدوامات والحلقات والطلاب والأساتذة
والتسجيل والنقل والواصفات المخصّصة، مع الهوية البصرية وRTL كامل.
التقدير: ٦–٨ أيام. تبدأ بـ `app/Actions/` ثم مكوّنات Livewire.

**للاستئناف السريع:**

```bash
cd d:\Development\Laravel\mousqe\backend
php artisan migrate:fresh --seed
composer run dev              # serve + queue + vite
```

المرجع التفصيلي لنموذج البيانات: [ERD.md](ERD.md)
