# عقد الـ API — mousqe

الحالة: **2026-09-06 · محدَّث حتى المرحلة 5.1** — ✅ 14 نقطة منفَّذة ومغطّاة باختبارات
(`tests/Feature/Api/`). هذا الملف هو **العقد الذي تبني عليه تطبيقات المراحل 5–8** — كل حقل فيه منسوخ
من `routes/api.php` ومن المتحكّمات و`app/Http/Resources/V1/` لا مستنتَج.

> الصورة العامة في [ARCHITECTURE.md](ARCHITECTURE.md) · المزامنة بتفصيلها في
> [SYNC-PROTOCOL.md](SYNC-PROTOCOL.md) · من يستهلك ماذا في [CLIENTS.md](CLIENTS.md) ·
> نموذج البيانات في [ERD.md](ERD.md).

---

## 1. الأساسيات

| البند | القيمة |
|---|---|
| العنوان الأساسي | `{APP_URL}/api/v1` — تطويراً `http://127.0.0.1:8000/api/v1` عبر `composer run dev` |
| الصيغة | JSON دائماً؛ `shouldRenderJsonWhen(request->is('api/*'))` في `bootstrap/app.php` يجعل حتى الأخطاء JSON |
| المصادقة | توكن Sanctum شخصي: `Authorization: Bearer {token}` — **لا جلسة ولا كوكي**، فالتطبيق يعمل أوف-لاين |
| صلاحية التوكن | بلا انتهاء مضبوط؛ يُبطَل بـ`POST /auth/logout`، أو تلقائياً حين يُقفل الحساب (§5) |
| التوقيت | `APP_TIMEZONE=Asia/Damascus` — كل التواريخ المعادة بهذا التوقيت 🔄 م.4.5 |
| ترميز التاريخ | حقول التاريخ وحده `Y-m-d` (عبر `App\Casts\DateOnly`)، والطوابع الزمنية ISO-8601 بدقّة ميلي-ثانية |

**سلسلة الوسائط (middleware) بالترتيب الفعلي:**

```
كل نقاط api  →  EnsureUserIsActive        (ملحق بمجموعة api في bootstrap/app.php)
/auth/login  →  (بلا مصادقة)
باقي النقاط  →  auth:sanctum
             →  institute.scope = SetApiInstituteScope   ← عدا /auth/* و/devices/register
             →  permission:… أو role:…                    ← حسب النقطة
```

### لماذا `POST /devices/register` خطوة منفصلة عن الدخول؟

الدخول يُثبت **هوية المستخدم**؛ والتسجيل يفتح **مؤشّر مزامنة للجهاز**:

1. `sync_devices.last_pulled_seq` مفتاحه `device_uuid` لا `user_id` — للمستخدم الواحد أن يعمل على
   هاتفه وحاسوب الحلقة، ولكلٍّ منهما موضعه في `change_log` مستقلاً عن الآخر.
2. `fcm_token` يُسجَّل هنا (في `devices`) وهو خاصّ بتثبيت التطبيق لا بالحساب، ويتغيّر بإعادة التثبيت
   بلا تغيّر كلمة المرور.
3. هي و`/auth/*` **خارج `institute.scope`** — فحساب بلا معهد مرتبط يستطيع الدخول وتسجيل جهازه ثم
   يُرفض عند أول نقطة بيانات (§4). مقصود: تمييز «كلمة مرور خاطئة» من «حسابك غير مربوط بمعهد».

---

## 2. فهرس نقاط النهاية

| الطريقة | المسار | الغرض | الحارس |
|---|---|---|---|
| `POST` | `/auth/login` | توكن Sanctum مقابل `username` + كلمة المرور | — (مفتوحة) |
| `POST` | `/auth/logout` | إبطال التوكن الحالي وحده | `auth:sanctum` |
| `GET` | `/auth/me` | هوية صاحب التوكن | `auth:sanctum` |
| `POST` | `/devices/register` | فتح مؤشّر مزامنة للجهاز + تسجيل `fcm_token` | `auth:sanctum` |
| `GET` | `/bootstrap` | لقطة أولى لنطاق المستخدم — أول استدعاء بعد الدخول | `institute.scope` |
| `GET` | `/sync/pull` | تغييرات `change_log` منذ `since` ضمن نطاق المستخدم | `permission:sync.pull` |
| `POST` | `/sync/push` | دفعة عمليات أوف-لاين بـ`op_uuid` (idempotent) | `permission:sync.push` |
| `GET` | `/teacher/circles` | حلقات الأستاذ في الدورة الجارية | `role:teacher` |
| `GET` | `/teacher/sessions/{date}` | جلسة حلقة في تاريخ (بـ`course_circle_uuid`) | `role:teacher` |
| `GET` | `/guardian/children` | أبناء ولي الأمر | `role:guardian` |
| `GET` | `/guardian/children/{student_uuid}/attendance` | آخر 30 سجل حضور لابن بعينه | `role:guardian` |
| `POST` | `/guardian/excuses` | تقديم إذن غياب مسبق | `role:guardian` |
| `GET` | `/student/me/attendance` | ملخّص الطالب ومنحناه وآخر 20 سجلاً | `role:student` |
| `GET` | `/student/me/progress` | محفوظات الطالب مجمّعة بالمنهج | `role:student` |

**الحارس `role:` لا `permission:`** في نقاط `teacher/guardian/student` — أي أن المشرف الذي يملك
`students.view` لا يصل `/guardian/children`؛ الوصول محسوم بالدور لا بالصلاحية. من يملك الأدوار
وأيّ صلاحية موزّعة عليها: [ERD.md §7](ERD.md) و`RolesAndPermissionsSeeder`.

---

## 3. تفصيل النقاط

### 3.1 `POST /auth/login`

```jsonc
// الطلب — كل الحقول مطلوبة
{
  "username": "teacher2395",        // اسم المستخدم المولَّد أو البريد لمن له بريد 🔄 م.4.7
  "password": "…",
  "device_name": "iPhone الأستاذ"   // اسم التوكن في personal_access_tokens (≤64)
}
```

```jsonc
// 200
{
  "token": "12|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "user": {
    "id": 41,
    "name": "أحمد بن سعيد",
    "username": "teacher2395",
    "email": null,                  // الطالب وولي الأمر بلا بريد 🔄 م.4.7
    "roles": ["teacher"]            // ✅ م.5.1 — كانت فارغة دائماً
  }
}
```

🔄 **م.5.1: `roles` صارت تعمل.** كانت تعود `[]` دائماً لأن المسار خارج `institute.scope` فمفتاح فريق
spatie غير مضبوط. صار `AuthController::identity()` يحسم النطاق **إن أمكن** قبل قراءة الأدوار.
وحسابٌ بلا معهد مرتبط يبقى يدخل بنجاح و`roles` فارغة — التمييز مقصود بين «كلمة مرور خاطئة»
و«حسابك غير مربوط بمعهد»، والثاني يُكتشف عند أول نقطة بيانات (§4).

🔄 **م.4.7:** الحقل كان `email` فصار `username` يقبل الاثنين — الطالب وولي الأمر لا بريد لهما وهما
جمهور هذه التطبيقات. التفصيل في [CHECKPOINT-PHASE-4.7.MD](CHECKPOINT-PHASE-4.7.MD) §3–4.

### 3.2 `POST /auth/logout` · `GET /auth/me`

`logout` يحذف **التوكن الحالي وحده** (`currentAccessToken()->delete()`) فلا يُخرج بقيةَ أجهزة
المستخدم ⇒ `{"message":"تم تسجيل الخروج."}`.
`me` يعيد نفس كائن `user` أعلاه بلا تغليف (`id`, `name`, `username`, `email`, `roles`).

### 3.3 `POST /devices/register`

```jsonc
// الطلب
{
  "device_uuid": "0199…",     // مطلوب · uuid يولّده العميل ويثبت مدى عمر التثبيت
  "app": "teacher",           // مطلوب · ≤24 — نفس القيمة تُرسل لاحقاً في sync/pull
  "platform": "android",      // اختياري ≤32
  "app_version": "1.0.0",     // اختياري ≤32
  "fcm_token": "…"            // اختياري ≤512 — يُكتب في devices ⬜ لا مُرسِل بعد (م.7)
}
```

```jsonc
// 201
{ "device_uuid": "0199…", "last_pulled_seq": 0 }
```

استدعاؤه ثانيةً بنفس `device_uuid` **تحديثٌ لا إنشاء** (`updateOrCreate`) ولا يُصفّر
`last_pulled_seq` — فإعادة التسجيل عند كل إقلاع آمنة.

### 3.4 `GET /bootstrap` — أول استدعاء بعد الدخول

هذه هي النقطة التي تُبنى بها الشاشة الأولى في كل تطبيق: لقطةٌ صغيرة تكفي لعرض واجهة عاملة **قبل**
أن تبدأ المزامنة التزايدية. لا تأخذ أي معامل، ونطاقها محسوم من التوكن وحده.

```jsonc
// 200
{
  "user": {                                     // ✅ م.5.1
    "name": "أحمد بن سعيد",
    "roles": ["teacher"]                        // الدور هنا يبني عليه التطبيق توجيهه
  },
  "institute": {
    "uuid": "0199…",
    "name": "معهد النور",
    "logo_path": null,
    "theme": {                                  // ✅ م.5.1 — هوية المعهد الموحّدة
      "primary":   "#7d0a0a",                   // الترويسات والأزرار والروابط
      "secondary": "#ffbf9b",                   // الإبرازات والشارات
      "surface":   "#ead196"                    // خلفية الصفحات والبطاقات
    },
    "attendance": {                             // ✅ م.5.1
      "late_grace_minutes": 0                   // تُطرح من دقائق التأخير المحسوبة (§6)
    }
  },
  "course":    { "uuid": "0199…", "name": "دورة 1447" },   // أو null إن لا دورة جارية
  "circles": [                                              // CourseCircleResource
    {
      "uuid": "0199…",
      "circle_name": "حلقة الفرقان",
      "shift_name": "الدوام الصباحي",
      "room": "قاعة 2",
      "capacity": 15,
      "status": "active",
      "students_count": 13
    }
  ]
}
```

**`theme` عقدٌ من ثلاثة ألوان لا لوحةٌ كاملة.** الخادم يشتقّ منها سلالمَ التدرّج للوحة وصفحات
الطباعة (`App\Support\InstituteTheme`)، و`mousqe_ui` يشتقّها للتطبيقات **بنفس النسب** — خلطٌ خطّي في
sRGB نحو الأبيض للفواتح ونحو الأسود للدواكن، واللونُ المُدخَل يقع عند الدرجة الأساسية
(`brand-600` · `gold-500` · `sand-100`). النسبُ الدقيقة في ثوابت ذلك الصنف، وهي **جزءٌ من العقد**:
تغييرُها يغيّر شكل التطبيقات كلّها. معهدٌ لم يضبط ألوانه يعود بلوحة `design/design-tokens.json`
الافتراضية، فالحقل موجود دائماً ولا يحتاج العميل إلى حالة «بلا ثيم».

وتغييرُ الألوان من اللوحة يصل الأجهزةَ **مرّتين**: في `/bootstrap` عند الإقلاع، وفي `sync/pull`
لأن `institutes` صفٌّ يُزامَن ([SYNC-PROTOCOL.md §2](SYNC-PROTOCOL.md)).

⚠️ **`circles` تُملأ للأستاذ وحده.** الشرط في الكود
`$user->teacher === null || $course === null ⇒ []` — فولي الأمر والطالب يحصلان على المعهد والدورة
ومصفوفة فارغة. تطبيقا المرحلتين 7 و8 يحتاجان توسيع هذه النقطة (أبناء ولي الأمر / حلقة الطالب) أو
الاكتفاء بنقاطهما المخصّصة بعدها مباشرةً — قرارٌ يُتّخذ في مرحلته (§7).

### 3.5 `GET /teacher/circles` · `GET /teacher/sessions/{date}`

`circles` ⇒ `{"data": [ …CourseCircleResource كما في §3.4… ]}` — حلقات **الدورة الجارية** المسنَدة
لهذا الأستاذ فقط، مع `students_count` من `withCount('activeEnrollments')`.

`sessions/{date}` — التاريخ في المسار (`Carbon::parse`)، والحلقة في `?course_circle_uuid=…`،
وحلقةٌ ليست للأستاذ ⇒ 404:

```jsonc
// 200 — و "data": null إن لا جلسة في ذلك اليوم
{
  "data": {
    "uuid": "0199…",
    "course_circle_uuid": "0199…",
    "session_date": "2026-09-06",
    "status": "draft",              // draft | completed | locked
    "editable": true,               // AttendanceSession::isEditable() — انظر SYNC-PROTOCOL §6
    "completed_at": null,
    "attendances": [
      {
        "uuid": "0199…",
        "student_uuid": "0199…",
        "student_name": "محمد بن خالد",
        "status": "present",        // present | absent | late | excused
        "late_minutes": null,
        "note": null,
        "recorded_at": "2026-09-06T08:12:44.310000Z"
      }
    ]
  }
}
```

`attendances` محمّلة دائماً هنا (`sessionOn` تعمل `with('attendances.student')`)، وغائبة حيث لم
تُحمَّل (`whenLoaded`).

### 3.6 نقاط ولي الأمر

`GET /guardian/children` ⇒ `{"data": [ StudentResource ]}`:

```jsonc
{ "uuid": "0199…", "registration_no": "1042", "full_name": "محمد بن خالد المصري",
  "photo_path": null, "status": "active" }
```

`GET /guardian/children/{student_uuid}/attendance` ⇒ `{"data":[ …AttendanceResource… ]}` — **آخر 30
سجلاً** مرتّبة بـ`recorded_at` تنازلياً؛ ابنٌ ليس له ⇒ 404.

`POST /guardian/excuses`:

```jsonc
// الطلب
{ "student_uuid": "0199…", "from_date": "2026-09-08", "to_date": "2026-09-10",
  "reason": "سفر عائلي" }          // reason ≤500 · to_date ≥ from_date
// 201
{ "uuid": "0199…", "status": "pending" }   // pending | approved | rejected
```

هي **الكتابة الوحيدة في النظام عبر REST مباشر لا عبر `sync/push`** — لأن ولي الأمر لا يملك
`sync.push` أصلاً، ولأن تقديم إذن حدثٌ متّصلٌ بطبعه لا يحتاج طابوراً أوف-لاين.

### 3.7 نقاط الطالب

`GET /student/me/attendance`:

```jsonc
{
  "summary": { "present": 84, "absent": 6, "late": 3, "excused": 2,
               "total": 95, "rate": 93.5 },        // rate = (present+late)/(total-excused) · null إن لا سجل
  "trend":  [ { "date": "2026-08-08", "rate": 100.0, "sessions": 1 }, … ],  // 30 يوماً بالضبط، الفارغ منها rate 0
  "recent": [ …AttendanceResource… ]                // آخر 20
}
```

`GET /student/me/progress` ⇒ `{"data": { "<اسم المنهج>": [ … ] }}` — مجمَّعة باسم المنهج العربي،
ومقصورة على `in_progress` و`memorized` و`mastered`.
⚠️ هذه النقطة الوحيدة التي **تعيد نماذج `StudentCurriculumProgress` خاماً بلا Resource** — أي كل
أعمدة الجدول كما هي، وشكلُها غير مثبَّت بعقد. مرشَّحة لـ`ProgressResource` في المرحلة 8 (§8).

---

## 4. قواعد النطاق — `App\Support\ApiScope`

النطاق يُحسم **من الحساب لا من الطلب**؛ لا معامل `institute_id` في أي نقطة:

```php
institute() = user->teacher?->institute_id
           ?? user->guardian?->institute_id
           ?? user->student?->institute_id
           ?? RuntimeException  ⇒ 422
```

ثم يضبط مفتاح فريق spatie (`setPermissionsTeamId`) — **وبدون هذه الخطوة يفشل كل فحص `permission:`
لاحق**، ولذلك `SetApiInstituteScope` يسبق كل شيء في المجموعة.

| الدور | ما يراه فعلياً | آلية الحصر |
|---|---|---|
| `teacher` | حلقاته المسنَدة في الدورة الجارية وحدها | `whereHas('teachers', …teacher->id)` في `TeacherCircleQuery` |
| `guardian` | أبناؤه وحدهم | `guardian->students()->where('students.uuid', …)` — لا استعلام مفتوح على `students` |
| `student` | نفسه وحده | `user->student` مباشرةً؛ لا معرّف في أي مسار |
| **الجميع** | **معهدهم كاملاً في `sync/pull`** | `scope_key = "institute:{uuid}"` — أوسع من النطاق أعلاه عمداً، انظر [SYNC-PROTOCOL.md §4](SYNC-PROTOCOL.md) |

**لماذا يُرفض توكن بلا معهد صراحةً بدل السقوط لأوّل معهد؟** نظير `ApiScope` على اللوحة هو
`PanelScope`، وهو يسقط إلى «أوّل معهد فعّال» للأدوار العابرة فقط — لأن المستخدم أمام الشاشة يرى
المعهد في الشريط ويصحّحه بالمبدّل. على الـ API لا شاشة ولا مبدّل: التخمين يعني كتابة تفقّد كامل في
معهد خطأ بلا أن يلاحظ أحد. سُجّل هذا قراراً في [PLAN.md §14](PLAN.md) (2026-09-01).

---

## 5. رموز الأخطاء

| الرمز | الحالة | الجسم | المصدر |
|---|---|---|---|
| `401` | بلا توكن أو توكن مُبطَل | `{"message":"Unauthenticated."}` | `auth:sanctum` |
| `403` | **الحساب مقفل** (`is_active = false`) — ويُحذف التوكن الحالي فوراً | `{"message":"هذا الحساب مقفل."}` | `EnsureUserIsActive` 🔄 م.4.7 |
| `403` | الدور أو الصلاحية غير متوفّرة (`role:teacher`، `permission:sync.push`…) | رسالة spatie | `RoleMiddleware`/`PermissionMiddleware` |
| `404` | الحساب من نوع آخر (`/teacher/*` بحساب ولي أمر)، أو صفٌّ خارج ملكية المستخدم | `{"message":"هذا الحساب ليس حساب أستاذ."}` أو رسالة `firstOrFail` | المتحكّمات |
| `422` | **توكن بلا معهد مرتبط** | `{"message":"لا يملك هذا المستخدم معهداً مرتبطاً."}` | `SetApiInstituteScope` |
| `422` | فشل تحقّق، **وكذلك كلمة مرور خاطئة وحسابٌ مقفل عند الدخول** | `{"message":…,"errors":{"username":["بيانات الدخول غير صحيحة."]}}` | `validate()` / `ValidationException` |
| `500` | نوع عملية غير معروف في `sync/push` | استثناء `RuntimeException` | `SyncPush::apply()` — ⚠️ §8 |

**لا يوجد `409` في هذا النظام.** تعارض المزامنة **لا يُعاد للعميل خطأً**: الخادم يحسمه بنفسه، ويردّ
`200` مع العملية ضمن `applied`، ويحفظ المرفوض في `sync_conflicts` — [SYNC-PROTOCOL.md §5](SYNC-PROTOCOL.md).

---

## 6. أنواع عمليات `sync/push`

الغلاف واحد لكل الأنواع (`op_uuid` + `type` مطلوبان، والباقي حسب النوع)، ودورة الدفع وقواعد
التكرار في [SYNC-PROTOCOL.md §3](SYNC-PROTOCOL.md)، والفعل الذي يستدعيه كل نوع في
[ARCHITECTURE.md §3](ARCHITECTURE.md). ما يخصّ **الشكل على السلك**:

| `type` | الحقول | ملاحظات |
|---|---|---|
| `attendance.session.open` | `course_circle_uuid` · `session_date?` | الحلقة تُتحقَّق ضمن معهد المستخدم |
| `attendance.take` | `session_uuid` · `attendances[]{student_uuid, status, late_minutes?, note?, recorded_at?}` · `amend?` | `recorded_at` **هو مفتاح حسم التعارض** — أرسله دائماً بزمن الجهاز وقت التسجيل، لا وقت الدفع. و`late_minutes` **اتركه فارغاً** ليحسبه الخادم (انظر أسفل الجدول) |
| `attendance.teacher.take` | `session_uuid` · `teacher_attendances[]{teacher_uuid, status, late_minutes?, note?}` | بلا `recorded_at` ⇒ بلا حسم تعارض |
| `attendance.session.complete` | `session_uuid` | يقفل الجلسة (§6 في SYNC-PROTOCOL) |
| `excuse.submit` | `student_uuid` · `from_date` · `to_date` · `reason` · `attachment_path?` | نظير `POST /guardian/excuses` لعميل يملك `sync.push` |
| `recitation.save` | `session_uuid` · `student_uuid` · `recitation{from_surah, from_ayah, to_surah, to_ayah, grade?, juz?, type?, curriculum_item_id?, notes?}` · `recorded_at?` | `grade`: `excellent`/`very_good`/`good` · `type`: `hifz`/`murajaa`/`tilawah`. الأسطر والنقاط تُحسب على الخادم وتُجمَّد |
| `recitation.delete` | `recitation_uuid` | |
| `points.award` | `student_uuid` · `points` · `reason` · `note?` · `awarded_on?` · `session_uuid?` | `reason`: `behavior`/`participation`/`competition`/`reward`/`excellence`/`volunteering`/`other` |

```jsonc
// POST /sync/push  ⇒  200
{ "applied": ["op-uuid-1", "op-uuid-2"], "skipped": ["op-uuid-0"] }
```

`skipped` = عمليات سبق تطبيقها بنفس `op_uuid` (إعادة إرسال بعد انقطاع). أي نوع خارج الجدول ⇒ 500.

### `late_minutes` يحسبه الخادم ✅ م.5.1

الحقل **اختياري ومقصودٌ تركُه فارغاً**. حين لا يصل، يحسبه `TakeAttendance` من
`shifts.starts_at` وزمنِ `recorded_at`، مطروحاً منه `late_grace_minutes` من `/bootstrap`:

```
late_minutes = max(0, minutes(recorded_at − shift.starts_at) − late_grace_minutes)
```

بثلاث حالات تعود صفراً/فارغاً قصداً: حالةٌ غير `late` ⇒ `null` · وصولٌ قبل بداية الدوام ⇒ `0` ·
و`recorded_at` من **يومٍ غير يوم الجلسة** (تفقّد رجعي) ⇒ `0`، فالفرق أيامٌ لا دقائق.

**متى يرسله العميل إذاً؟** حين يصحّحه الأستاذ بيده — القيمةُ المُرسَلة صراحةً تغلب المحسوبة دائماً.
الحالةُ قرارُ الأستاذ والرقمُ تلقائي، ولا تحويل تلقائي إلى «متأخر». والعميل يعرض الرقم فوراً
أوف-لاين بنظير الصيغة نفسها في `mousqe_core` — عرضاً مبكّراً لا مصدرَ حقيقة ثانياً.

---

## 7. سياسة الإصدارات

`/api/v2` **ليس الردّ الافتراضي** على حاجة حقلٍ جديد. القاعدة:

| الحالة | الإجراء |
|---|---|
| حقل **يُضاف** إلى استجابة قائمة | يُضاف في نفس `v1`. عميل قديم يتجاهله؛ لا كسر |
| نقطة أو نوع عملية **جديد** | يُضاف في نفس `v1` |
| حقل يُحذف أو يتغيّر **معناه/نوعه** (مثل `status` من نصّ إلى كائن) | ممنوع في `v1`. الحلّان: حقل جديد بجانب القديم مع إهمال القديم موسوماً، أو `v2` **للمورد الواحد المتغيّر فقط** (`/api/v2/teacher/sessions/{date}`) لا للـ API كلّه |
| تغيير يمسّ عقد المصادقة أو المزامنة | يستدعي `v2` كاملة — العملاء الأربعة يتشاركون `mousqe_core` فينكسرون معاً |

وأياً كان القرار: يُسجَّل في [PLAN.md §14](PLAN.md) ويُحدَّث هذا الملف في نفس الالتزام (commit).
ما دام العملاء الأربعة يُبنون من مستودع واحد ويُوزَّعون معاً، يبقى تعديل `v1` أرخص من إصدار ثانٍ.

---

## 8. ⚠️ فجوات مؤكَّدة من الكود — تُحسم في مراحلها

كلها **تحقَّقت من الكود لا من الخطة**، وليست موثَّقة في [PLAN.md](PLAN.md) قبل اليوم:

| الفجوة | الأثر على المراحل 5–8 |
|---|---|
| ~~**`user.roles` تعود `[]` دائماً**~~ | ✅ **سُدّت في م.5.1** — `AuthController::identity()` يحسم النطاق قبل قراءة الأدوار، والدورُ صار أيضاً في `/bootstrap` (§3.4) |
| **`POST /auth/login` بلا أي حدّ معدّل (throttle)** | `throttleApi()` غير مستدعى في `bootstrap/app.php`؛ الحدّ 5/دقيقة موجود لِلوحة وحدها عبر Fortify. وكلمات المرور مولَّدة قصيرة 🔄 م.4.7 ⇒ التخمين مفتوح. يُسدّ قبل النشر (م.9) |
| **`/bootstrap` لا يخدم إلا الأستاذ** (§3.4) | م.7 وم.8 يحتاجان توسيعها أو نقاطاً بديلة. ⚠️ لاحظ أن `user` و`institute.theme` تصل **كل** الأدوار، فالنقص محصورٌ في `circles` |
| **`/student/me/progress` بلا Resource** (§3.7) | شكلها غير مستقرّ؛ تثبيتها قبل م.8 |
| **`sync/pull` بلا مؤشّر «بقيّة»** | الصفحة 500 صفّاً و`server_seq` = آخر صفّ في الصفحة؛ العميل يكرّر السحب حتى تعود `changes` فارغة — [SYNC-PROTOCOL.md §4](SYNC-PROTOCOL.md) |
| ⚠️ **صفحةُ السحب الأولى صارت أثقل** 🔄 م.5.1 | كتاباتُ اللوحة صارت تدخل `change_log` (وهو المقصود)، فالمعهدُ العامل منذ شهور يعطي جهازاً جديداً آلافَ الصفوف من `since=0`. مقبولٌ بالحجم المتوقَّع، ويستدعي «لقطة أولية بدل تيّار من الصفر» قبل م.9 — [SYNC-PROTOCOL.md §10](SYNC-PROTOCOL.md) البند 7 |

---

## 9. مرجعية عكسية — لمن يخطّط للمراحل 5 إلى 8

عند التخطيط لأي تطبيق من الأربعة، **اقتبس من هذا الملف ولا تعد اكتشاف العقد من كود PHP**:

| التطبيق | الأقسام الملزمة |
|---|---|
| **الأستاذ** (م.5) | §1 · §3.1 · §3.3 · §3.4 · §3.5 · §6 كاملاً · §8 البند الأول |
| **الديسكتوب** (م.6) | نفسها + `attendance.teacher.take` و`amend` في §6 · §5 (يحتاج `attendance.amend`) |
| **الأهل** (م.7) | §3.6 · §3.4 مع تحفّظه · `sync/pull` بلا `push` (§4) |
| **الطالب** (م.8) | §3.7 بتحفّظه · `sync/pull` بلا `push` |

وأي تغيير على الكود يمسّ ما ورد هنا يُحدَّث في هذا الملف **في نفس الالتزام** — وإلا فقد العقد
معناه.
