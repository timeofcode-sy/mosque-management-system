# نموذج البيانات — mousqe

الحالة: **المرحلة 1 منفَّذة** — كل الجداول والنماذج والبذور والاختبارات موجودة في `backend/`.

## قواعد عامة

كل جدول دومين يحمل:

| الحقل | الغرض |
|---|---|
| `uuid` | معرّف عالمي يولّده العميل أوف-لاين — **مفتاح المزامنة**. يُولَّد تلقائياً عبر `App\Concerns\HasUuid` |
| `created_at` / `updated_at` بدقّة ميلي-ثانية | حسم التعارضات في المزامنة |
| `deleted_at` (حيث ينطبق) | حذف ناعم — لا يُفقد سجل تاريخي |

الجداول الخالية من `uuid` هي جداول مشتقّة أو محلية فقط: `circle_daily_stats`، `circle_cumulative_stats`،
`taggables`، `devices`، `sync_devices`، `settings`.

---

## 1. التنظيم الهرمي

```
institutes (معهد)
  └─ courses (دورة)              ← نطاق تصفير عدّادات الغياب
       └─ shifts (دوام)          ← + shift_days: أيام ثابتة أسبوعياً
            └─ course_circles    ← تشغيل حلقة ضمن هذه الدورة/الدوام
                 ├─ course_circle_teachers
                 ├─ enrollments (طالب مُسجَّل)
                 └─ attendance_sessions → attendances
```

`circles` منفصل عن `course_circles`: **هوية الحلقة ثابتة عبر الدورات**، بينما تشغيلها ضمن دورة بعينها
هو صفّ في `course_circles`. مع كل دورة جديدة تُستنسخ الحلقات وتُعدَّل قوائم الطلاب، ويبقى سجل الطالب
التاريخي محفوظاً ومرتبطاً بالتسجيل القديم.

قيد `unique(course_id, circle_id)` على `course_circles` يضمن أن **الحلقة تعمل في دوام واحد فقط ضمن الدورة**.

---

## 2. الطالب — تغطية استمارة التسجيل

### 2.1 البيانات الأساسية والشخصية → `students`

| حقل الاستمارة | العمود |
|---|---|
| رقم المعرف (بطاقة الطالب) | `registration_no` — `unique(institute_id, registration_no)` |
| تاريخ التسجيل | `registration_date` (ميلادي) + `registration_date_hijri` (نص هجري) |
| الصورة الشخصية | `photo_path` |
| اسم الطالب الثلاثي | `first_name` + `father_name` + `family_name` — يُقرأ مجمّعاً عبر الخاصية `full_name` |
| تاريخ الولادة | `birth_date` |
| مكان الولادة | `birth_place` |
| الصف الدراسي | `grade_level` |
| عمل/مهنة الطالب | `student_job` |
| رقم جوال الطالب | `phone` |
| العنوان الأساسي | `permanent_address` |
| العنوان الحالي | `current_address` |

إضافة: `gender`، `national_id`، `status`، `notes`، `institute_id`، `user_id` (لربطه بحساب تطبيق الطالب).

### 2.2 بيانات ولي الأمر والعائلة → `guardians` + `guardian_student`

بيانات الأب والأم **ليست أعمدة في `students`**، بل سجلّان في `guardians` مربوطان بالطالب عبر
`guardian_student` بحقل `relation`:

| حقل الاستمارة | الموقع |
|---|---|
| اسم الأب | `guardians.full_name` حيث `guardian_student.relation = father` |
| عمل الأب | `guardians.occupation` |
| رقم هاتف الأب | `guardians.phone` (+ `alternate_phone`) |
| اسم الأم / عملها / هاتفها | نفس الأعمدة حيث `relation = mother` |
| عدد أفراد العائلة | `students.family_members_count` |

**لماذا هذا الفصل؟** ولي الأمر يملك حساباً في تطبيق الأهل، وقد يتابع أكثر من ابن في المعهد، ويحتاج
صلاحيات (`can_view_reports`, `can_submit_excuses`). لو كانت الحقول مكرّرة داخل `students` لتكرّرت بياناته
مع كل ابن ولاستحال ربطه بحساب واحد. الوصول المختصر متاح عبر `$student->father()` و`$student->mother()`.

### 2.3 الحالة الصحية والاجتماعية → `students`

`student_health_status` و`family_health_status` — حقلا نص مفتوح.

### 2.4 الصفات الشخصية والسلوكية → `traits` + `student_trait`

اختيار متعدّد وليس حقولاً بولينية: كل صفة صفٌّ في `traits`، وإسنادها للطالب صفٌّ في `student_trait`
(مع `note` و`noted_by`). الصفات التسع الواردة في الاستمارة مزروعة عامةً (`institute_id = null`):

> هادئ · مبدع · متواضع · كثير الحركة · ذكي · انطوائي · حزين · سعيد · خجول

النموذج اسمه `PersonalTrait` لأن `Trait` كلمة محجوزة في PHP. الحقل `polarity` يميّز الصفة الإيجابية عن
تلك التي تحتاج متابعة، ليستفيد منه الداشبورد لاحقاً. المشرف يضيف صفات خاصة بمعهده بحرّية.

### 2.5 سجل المحفوظات والمناهج → `curricula` + `curriculum_items` + `student_curriculum_progress`

ثلاثة جداول بدل عشرات الأعمدة، حتى يضيف المعهد مناهج جديدة دون تعديل قاعدة البيانات:

| المنهج (`curricula`) | النوع | البنود (`curriculum_items`) |
|---|---|---|
| القرآن الكريم | `quran` | الجزء الأول … الجزء الثلاثون (30 بنداً، `meta.juz` يحمل رقم الجزء) |
| الحديث الشريف | `hadith` | الأربعون النبوية (1) · (2) · (3) · مجامع الأنوار |
| المتون العلمية | `mutun` | البيقونية · اللامية · تحفة الأطفال · عقيدة العوام · المقدمة الجزرية · جوهرة التوحيد · الأرجوزة الميئية |

`student_curriculum_progress` يحمل حالة كل بند لكل طالب: `status` (لم يبدأ / قيد الحفظ / محفوظ / متقَن)،
`percent`، `score`، `started_on`، `completed_on`، `teacher_id`، `notes` — مع `unique(student_id, curriculum_item_id)`.

المناهج الثلاثة مزروعة عامةً (`institute_id = null`)، و**المناهج العلمية المضافة** هي ببساطة صفوف جديدة
في `curricula` بنوع `custom`.

### 2.6 الملاحظات العامة

`students.notes` حقل نصي مفتوح. يضاف إليه `memorization_logs` (سجل يومي للحفظ والمراجعة والتلاوة)
و`evaluations` (تقييم دوري: سلوك، التزام، حفظ، تجويد).

### 2.7 واصفات إضافية

`custom_fields` + `custom_field_values` تتيح للمشرف تعريف أي حقل جديد على الطالب أو الأستاذ أو الحلقة
من اللوحة دون كتابة كود (`text`, `textarea`, `number`, `date`, `select`, `multi_select`, `bool`).

---

## 3. التسجيل والنقل

`enrollments` — `unique(course_circle_id, student_id)` بحالة `active` / `left` / `transferred`.

النقل = إغلاق التسجيل القديم بـ `transferred` + فتح تسجيل جديد + قيد في `student_transfers`.
سجل الحضور القديم مرتبط بـ `enrollment_id` القديم ⇒ يبقى محفوظاً ولا يظهر في تفقّد الحلقة الجديدة.

---

## 4. التفقّد

| الجدول | القيد المهم |
|---|---|
| `attendance_sessions` | `unique(course_circle_id, session_date)` — لا جلستان في يوم واحد لنفس الحلقة |
| `attendances` | `unique(attendance_session_id, student_id)` — يجعل تعارضات المزامنة نادرة جداً |
| `teacher_attendances` | حضور الأستاذ ضمن نفس الجلسة |
| `absence_excuses` | إذن مسبق من ولي الأمر يُقترح تلقائياً كحالة `excused` |

الحالات: `present` / `absent` / `late` (+ `late_minutes`) / `excused`.
الجلسة `draft` قابلة للتعديل؛ `completed` و`locked` تتطلبان صلاحية `attendance.amend`.

---

## 5. الإحصاء والتقارير

`circle_daily_stats` (نسبة اليوم + `daily_rank_in_shift`) و`circle_cumulative_stats`
(النسبة منذ بداية الدورة + `overall_rank_in_shift`). تُحدَّث عند إغلاق أي جلسة تفقّد.
`report_templates` قالب نصّي بمتغيّرات، و`report_exports` سجل الملفات المولَّدة.

---

## 6. المزامنة

`change_log` — معرّفه التسلسلي هو `server_seq` الذي يقرأ منه العملاء عبر `sync/pull?since=`،
مع `scope_key` (`institute:{uuid}` أو `circle:{uuid}`) لحصر ما يراه كل مستخدم، و`op_uuid` فريد
يضمن ألّا تتكرّر عملية دُفعت مرّتين. `sync_devices` يتتبّع `last_pulled_seq` لكل جهاز،
و`sync_conflicts` يحفظ القيمة المُستبدَلة لعرضها على المشرف.

---

## 7. الأدوار والصلاحيات

`spatie/laravel-permission` مع **وضع الفرق مفعّل** والمفتاح `institute_id` — أي أن إسناد الدور مرتبط
بمعهد بعينه، والمشروع جاهز لتعدّد المعاهد. الأدوار نفسها عامة (`team_id = null`).

| الدور | الخلاصة |
|---|---|
| `super_admin` / `admin` | كل الصلاحيات |
| `supervisor` | إدارة الطلاب والتسجيل والنقل + تفقّد وتعديل وقفل + تقارير + مراجعة التعارضات |
| `teacher` | تفقّد حلقاته، متابعة الحفظ والتقييم، مراجعة الأعذار، قراءة التقارير |
| `guardian` | متابعة أبنائه + تقديم إذن مسبق (قراءة فقط عدا ذلك) |
| `student` | قراءة حضوره وتقدّمه والإعلانات |

---

## 8. بيانات البذر

`php artisan migrate:fresh --seed` ينتج:

| الكيان | العدد |
|---|---|
| معهد | 1 (معهد النور) |
| دورة جارية | 1 |
| دوامات | 2 (صباحي: الأحد/الثلاثاء/الخميس — مسائي: الاثنين/الأربعاء) |
| حلقات | 6 |
| أساتذة | 6 |
| طلاب | 78 (13 لكل حلقة) بأولياء أمورهم (أب وأم لكل طالب) |
| صفات مُسنَدة | 3 لكل طالب |
| جلسات تفقّد | 30 جلسة مكتملة عن آخر أسبوعين |
| مناهج | 3 مناهج و41 بنداً |

حساب المشرف: `admin@mousqe.test` / كلمة المرور `password`.
