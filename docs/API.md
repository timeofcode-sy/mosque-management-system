# عقد الـ API — mousqe

الحالة: **2026-09-08 · محدَّث حتى المرحلة 6.2** — ✅ 36 نقطة منفَّذة ومغطّاة باختبارات
(`tests/Feature/Api/`)، و**مستهلَكةٌ فعلياً** من تطبيق الأستاذ لا من الاختبارات وحدها. هذا الملف هو
**العقد الذي تبني عليه تطبيقات المراحل 5–8** — كل حقل فيه منسوخ من `routes/api.php` ومن المتحكّمات
و`app/Http/Resources/V1/` لا مستنتَج.

🔄 **م.6.1 فتحت الـ API لجمهورٍ ثانٍ:** لم يعد جمهورَ التطبيقات الثلاثة وحدها (أستاذ · ولي أمر ·
طالب)، بل صار يعبره **مديرُ المعهد والمشرف والمشرف الأعلى والمبرمج** — وهم جمهور الديسكتوب (م.6).
وأثرُ ذلك في §3.4 و§3.8 و§3.9 و§4 و§6.

🔄 **م.6.2 أعطت ذلك الجمهورَ ما يعمل به:** كان يعبر الـ API ولا يجد فيه بابَ إدارةٍ واحداً — المعاهدُ
والمستخدمون والأدوارُ وبياناتُ الدخول وبنيةُ الدورة تُكتب من اللوحة مباشرةً بلا نقطةٍ في `/api/v1`
([CLIENTS.md §2](CLIENTS.md)). صار لها **تسع عشرة نقطة REST** (§3.10) و**أربعةُ أنواع عمليات** في
`sync/push` (§6)، والقسمةُ بينهما قاعدةٌ مُعلَنة لا اجتهادُ كلِّ شاشة (§3.10.1).

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
| `GET` | `/institutes` ✅ م.6.1 | معاهد صاحب التوكن — مصدر مبدّل المعاهد | `institute.scope` |
| `GET` | `/sync/pull` | تغييرات `change_log` منذ `since` ضمن نطاق المستخدم | `permission:sync.pull` |
| `POST` | `/sync/push` | دفعة عمليات أوف-لاين بـ`op_uuid` (idempotent) | `permission:sync.push` |
| `GET` | `/sync/conflicts` ✅ م.6.1 | تعارضات المعهد — معلّقةً أو مراجَعة | `permission:conflicts.review` |
| `POST` | `/sync/conflicts/{uuid}/resolve` ✅ م.6.1 | الحكم: قيمة الجهاز أم قيمة الخادم | `permission:conflicts.review` |
| `GET` | `/teacher/circles` | حلقات الأستاذ في الدورة الجارية | `role:teacher` |
| `GET` | `/teacher/sessions/{date}` | جلسة حلقة في تاريخ (بـ`course_circle_uuid`) | `role:teacher` |
| `GET` | `/guardian/children` | أبناء ولي الأمر | `role:guardian` |
| `GET` | `/guardian/children/{student_uuid}/attendance` | آخر 30 سجل حضور لابن بعينه | `role:guardian` |
| `POST` | `/guardian/excuses` | تقديم إذن غياب مسبق | `role:guardian` |
| `GET` | `/student/me/attendance` | ملخّص الطالب ومنحناه وآخر 20 سجلاً | `role:student` |
| `GET` | `/student/me/progress` | محفوظات الطالب مجمّعة بالمنهج | `role:student` |
| **سطحُ الإدارة ✅ م.6.2** — كلُّها تحت `/admin` (§3.10) | | | |
| `PUT` | `/admin/institute` | بياناتُ المعهد العامل وألوانُه وإعداداتُه | `permission:settings.manage` |
| `POST` | `/admin/institutes` | إنشاءُ معهد ومعه دورةٌ أولى مسودّة | `permission:institutes.manage` |
| `PUT` | `/admin/institutes/{uuid}` | تحريرُ معهدٍ بعينه | `permission:institutes.manage` |
| `GET` | `/admin/roles` | كتالوجُ الأدوار: ما يُسنده هذا الحساب وما يُنشئه | `permission:users.manage` |
| `GET` | `/admin/users` | مستخدمو المعهد وأدوارُهم عبر المعاهد | `permission:users.manage` |
| `POST` | `/admin/users` | إنشاءُ حسابٍ إداري ⇐ كلمةُ المرور مرّةً واحدة | `permission:users.invite` |
| `POST` | `/admin/users/{id}/roles` | إسنادُ دور | `permission:users.manage` |
| `DELETE` | `/admin/users/{id}/roles` | سحبُ دور | `permission:users.manage` |
| `POST` | `/admin/users/{id}/activation` | إقفالُ حسابٍ أو فتحُه | `permission:users.manage` |
| `POST` | `/admin/users/{id}/password` | تبديلُ كلمة مرور ⇐ الجديدةُ مرّةً واحدة | `permission:credentials.manage` |
| `GET` | `/admin/credentials` | بطاقاتُ الدخول جاهزةً للطباعة | `permission:credentials.export` |
| `POST` · `PUT` | `/admin/courses` · `/admin/courses/{uuid}` | دورةٌ جديدة أو تحريرُها | `permission:courses.manage` |
| `POST` | `/admin/courses/{uuid}/activate` | «اجعلها الدورة الجارية» | `permission:courses.manage` |
| `POST` · `PUT` | `/admin/shifts` · `/admin/shifts/{uuid}` | دوامٌ وأيامُه الأسبوعية | `permission:shifts.manage` |
| `POST` · `PUT` | `/admin/circles` · `/admin/circles/{uuid}` | حلقةٌ — هويّتُها الثابتة عبر الدورات | `permission:circles.manage` |
| `POST` | `/admin/circles/{uuid}/run` | تشغيلُ الحلقة في دورةٍ ودوام | `permission:circles.manage` |

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
    "roles": ["teacher"],                       // الدور هنا يبني عليه التطبيق توجيهه
    "permissions": ["attendance.take", "…"],    // ✅ م.6.1 — صلاحياته في هذا المعهد
    "teacher_uuid": "0199…"                     // ✅ م.5.3 — null لمن ليس أستاذاً
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

**`teacher_uuid` هو مفتاح ترشيح العرض في العميل.** ✅ م.5.3 — `sync/pull` يبثّ **معهداً كاملاً**
([SYNC-PROTOCOL.md §4](SYNC-PROTOCOL.md))، فتصل جهازَ الأستاذ صفوفُ `course_circle_teachers` عن
حلقات كل أساتذة المعهد بمعرّفاتِ أساتذةٍ لا يعرف أيُّها هو. بدون هذا الحقل لا يستطيع أن يرشّح
«حلقاتي» من مخزنه المحلّي، فيبقى معتمداً على `/teacher/circles` — أي على الشبكة. وهو `null` لمن
ليس أستاذاً، وثابتٌ لا يتغيّر، فيُحفَظ مع لقطة `/bootstrap` ويُقرأ منها أوف-لاين.

**`theme` عقدٌ من ثلاثة ألوان لا لوحةٌ كاملة.** الخادم يشتقّ منها سلالمَ التدرّج للوحة وصفحات
الطباعة (`App\Support\InstituteTheme`)، و`mousqe_ui` يشتقّها للتطبيقات **بنفس النسب** — خلطٌ خطّي في
sRGB نحو الأبيض للفواتح ونحو الأسود للدواكن، واللونُ المُدخَل يقع عند الدرجة الأساسية
(`brand-600` · `gold-500` · `sand-100`). النسبُ الدقيقة في ثوابت ذلك الصنف، وهي **جزءٌ من العقد**:
تغييرُها يغيّر شكل التطبيقات كلّها. معهدٌ لم يضبط ألوانه يعود بلوحة `design/design-tokens.json`
الافتراضية، فالحقل موجود دائماً ولا يحتاج العميل إلى حالة «بلا ثيم».

وتغييرُ الألوان من اللوحة يصل الأجهزةَ **مرّتين**: في `/bootstrap` عند الإقلاع، وفي `sync/pull`
لأن `institutes` صفٌّ يُزامَن ([SYNC-PROTOCOL.md §2](SYNC-PROTOCOL.md)).

**`permissions` هي ما يبني عليه الديسكتوب واجهته** ✅ م.6.1 — لا اسمُ الدور. فالفرق بين المشرف
ومديرِ المعهد صلاحياتٌ لا نسخةُ برنامج ([APPS-FEATURES.md §4.1](APPS-FEATURES.md))، وبناءُ الواجهة
على أسماء الأدوار كان يعني نسخَ كتالوج الصلاحيات إلى Dart فيفترق السطحان عند أول تعديل عليه.
والقائمة محسوبةٌ بـ`can()` لكل صلاحية لا بقراءة إسنادات المستخدم، فيدخلها ما يمنحه `Gate::before`
لحاملي الأدوار العابرة (مبرمج/مشرف أعلى) — وإلا لعادت لهم **فارغة** وهم يملكون كل شيء.

**`circles` تُملأ للأستاذ ولمن يملك `circles.view`** 🔄 م.6.1:

```
user->teacher موجود؟        ⇒ حلقاتُه المسنَدة في الدورة الجارية   (كما كان)
وإلا can('circles.view')؟   ⇒ حلقاتُ الدورة الجارية كلُّها          (المشرف ومدير المعهد)
وإلا:                        ⇒ []                                   (ولي الأمر والطالب)
```

كانت تعود `[]` لكل من ليس أستاذاً، فيفتح الديسكتوبُ على معهدٍ بلا حلقة واحدة حتى تكتمل أولُ دورةِ
`sync/pull` — وهي آلافُ الصفوف على معهدٍ قائمٍ منذ شهور، وشاشةُ أوّلِ تشغيلٍ هي بالضبط ما بُنيت له
هذه النقطة. ⚠️ ويبقى ولي الأمر والطالب على المصفوفة الفارغة: تطبيقا المرحلتين 7 و8 يحتاجان
توسيعاً ثانياً (أبناء ولي الأمر / حلقة الطالب) أو الاكتفاء بنقاطهما المخصّصة — قرارٌ يُتّخذ في
مرحلته (§7).

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

### 3.8 `GET /institutes` ✅ م.6.1 — مبدّل المعاهد

```jsonc
// 200
{
  "current": "0199…",                       // المعهد الذي يعمل فيه هذا الطلب
  "data": [ { "uuid": "0199…", "name": "معهد النور",
              "logo_path": null, "is_active": true } ]
}
```

من يرى ماذا: حاملُ الدور العابر (مبرمج · مشرف أعلى) يرى **كل** المعاهد، وغيرُه يرى ما له فيه سجلٌّ
أو دورٌ مسنَد — أي صفّاً واحداً في الحال الغالبة.

**والتبديلُ بلا حالةٍ على الخادم:** الجهاز يختار معهداً من هذه القائمة ثم يُرفق `uuid`ه في ترويسة
`X-Institute` مع كل طلب لاحق (§4). فلا جلسةَ تُخزَّن، وجهازان لنفس الحساب يعملان في معهدين في آنٍ
واحد بلا أن يزيح أحدُهما الآخر — وهو الفرق عن مبدّل اللوحة الذي يثبّت الاختيار في الجلسة.

### 3.9 نقاط التعارضات ✅ م.6.1 — `permission:conflicts.review`

`GET /sync/conflicts?status=pending|reviewed|all` (الافتراضي `pending`، وحدُّها 200 صفّاً):

```jsonc
{ "data": [ {
  "uuid": "0199…",
  "table_name": "attendances",
  "row_uuid": "0199…",
  "server_payload": { "status": "present", "recorded_at": "…" },   // القيمة الباقية
  "client_payload": { "status": "absent",  "recorded_at": "…" },   // القيمة المرفوضة
  "resolution": "server_wins",          // أو client_wins بعد قلب الحكم
  "device_uuid": "0199…",
  "reviewed_by": "أحمد بن سعيد",        // أو null
  "resolved_at": null, "created_at": "…"
} ] }
```

`POST /sync/conflicts/{uuid}/resolve` بجسم `{"decision": "client_wins"}` أو `{"decision": "server_wins"}`:

| القرار | الأثر |
|---|---|
| `client_wins` | `App\Actions\OverturnSyncConflict` — تُعاد كتابة قيمة الجهاز عبر `TakeAttendance`، فتدخل `change_log` وتصل الأجهزةَ في سحبها التالي. جلسةٌ مقفلة ⇒ 422 برسالة الفعل |
| `server_wins` | `App\Actions\ReviewSyncConflict` — خَتمٌ بلا كتابة: الصفّ يحمل قيمة الخادم منذ لحظة الدفع، والقرارُ هنا «لا تفعل» موثَّقاً باسم من قرّره ووقتِه |

**ولماذا نقطةُ قراءةٍ مباشرة لا `sync/pull`؟** لأن `sync_conflicts` جدولٌ **لا يُزامَن**
([SYNC-PROTOCOL.md §7](SYNC-PROTOCOL.md)) — هو أثرُ الدفعة لا بيانُ المعهد. والحكمُ فيه متّصلٌ
بطبعه: من يقلب حكماً ينتظر نتيجته، ولا معنى لأن يُصفّ قرارٌ أوف-لاين على تعارضٍ قد يكون حُسم من
جهازٍ آخر. والحصرُ بمعهد المستخدم — عدا `system.debug` فهي أداةُ تشخيصٍ عند المبرمج، وصفوفُ ما قبل
هجرة `institute_id` بلا معهد فلا يراها غيرُه.

### 3.10 سطحُ الإدارة ✅ م.6.2 — `/admin/*`

هذه هي النقاط التي **لم تكن موجودة إطلاقاً** قبل م.6.2: كلُّ ما تكتبه اللوحةُ من معاهدَ ومستخدمين
وأدوارٍ وبياناتِ دخولٍ وبنيةِ دورةٍ كان يمرّ من `app/Actions/` مباشرةً بلا نقطةِ API واحدة. وكلُّها
**فوق تلك الأفعال نفسِها** بلا إعادة كتابة منطق ([ARCHITECTURE.md §3](ARCHITECTURE.md)) — والحراسةُ
فيها لا هنا: `AssignUserRole::assertAssignable` و`outranks` تُطبَّقان على السطحين معاً.

#### 3.10.1 القاعدة الحاكمة: أيّ كتابةٍ REST وأيّها في الطابور؟

| الصنف | القناة | لماذا |
|---|---|---|
| ما يُكتب **أوف-لاين** ويقبل التأخير: تسجيلُ طالب، التسجيلُ في حلقة، النقل، مراجعةُ الأعذار | **نوعُ عمليةٍ في `sync/push`** (§6) | يكتبه المشرف في المسجد بلا شبكة، ولا ينتظر جواباً فورياً |
| ما هو **متّصلٌ بطبعه**: الحسابات والأدوار وكلماتُ المرور وإقفالُها، وإنشاءُ معهد، وبنيةُ الدورة | **REST مباشر** (هنا) | من يُنشئ حساباً ينتظر كلمةَ مرورٍ ليطبعها؛ ولا معنى لطابورٍ يحمل سرّاً إلى وقتٍ لاحق. نظيرُ `POST /guardian/excuses` (§3.6) |

**ولماذا الدوراتُ والدواماتُ والحلقات في الصفّ الثاني؟** لأنها **بنيةٌ يُبنى عليها لا حدثٌ يُسجَّل**:
الجلسةُ والتسجيلُ والتفقّد تُعلَّق كلُّها على `course_circles`. ولو صُفَّت أوف-لاين لَصفَّ الجهازُ
فوقها عشراتِ العمليات ثم رُفض أصلُها فسقط ما فوقه. وهي تُهيَّأ **مرّةً في الفصل** من مكتبٍ لا من
مسجدٍ بلا شبكة.

**ولماذا لا `GET` لهذه الثلاثة؟** لأن `courses` و`shifts` و`circles` و`course_circles` جداولُ
**تُزامَن**، فالديسكتوب يقرؤها من drift لا من الشبكة — وما يُكتب هنا يعود إليه في `sync/pull` بلا
نقطةِ قراءةٍ ثانية. والاستثناءان الوحيدان `users` و«البطاقات»، وسببُهما في §3.10.3.

#### 3.10.2 المعهدُ وألوانُه

```jsonc
// PUT /admin/institute   (المعهد العامل — settings.manage)
// PUT /admin/institutes/{uuid} · POST /admin/institutes   (institutes.manage)
{
  "name": "معهد النور",
  "short_name": "النور", "phone": "…", "email": "…", "address": "…", "is_active": true,
  "theme":      { "primary": "#7d0a0a", "secondary": "#ffbf9b", "surface": "#ead196" },
  "attendance": { "late_grace_minutes": 5 },
  "points":     { "…": "كما تعود في data" }
}
```

```jsonc
// 200 (أو 201 للإنشاء)
{ "data": { "uuid": "0199…", "name": "معهد النور", "short_name": "النور",
            "phone": null, "email": null, "address": null, "is_active": true,
            "logo_path": null,
            "theme": { … }, "attendance": { … }, "points": { … } } }
```

**المجموعاتُ الثلاث اختيارية**: ما لا يصل منها يُملأ من الحالة المخزَّنة، فتبعث الشاشةُ بابَ الألوان
وحده بلا أن تمسح إعداداتِ النقاط. والقواعدُ مقروءةٌ من `App\Support\InstituteForm` نفسِه الذي
تستعمله شاشتا اللوحة — نموذجٌ واحد للمعهد لا نموذجان يفترقان عند أوّل تعديل.

**والإنشاء يمرّ بـ`CreateInstitute`** فيخرج المعهدُ ومعه **دورةٌ أولى مسودّة**؛ وإلا استقبل صاحبَه
بستّ شاشات تقول «لا توجد دورة جارية».

⚠️ **`institutes.manage` منزوعةٌ من `admin` عمداً** ([APPS-FEATURES.md §4.3](APPS-FEATURES.md)):
مديرُ المعهد يحرّر معهدَه من `/admin/institute` ولا ينشئ ثانياً.

#### 3.10.3 المستخدمون والأدوارُ وبياناتُ الدخول

```jsonc
// POST /admin/users            ⇒ 201
// { "first_name":"خالد", "last_name":"المصري", "email":null, "phone":null,
//   "role":"supervisor", "institute_uuid": null }   // المعهدُ العامل حين يُترك فارغاً
{
  "data": { "id": 41, "name": "خالد المصري", "username": "supervisor4821",
            "email": null, "phone": null, "is_active": true,
            "roles": [ { "role": "supervisor", "label": "مشرف",
                         "institute": "معهد النور", "is_global": false } ] },
  "credentials": { "username": "supervisor4821", "password": "48213097" }   // مرّةً واحدة
}
```

| النقطة | الجسم | الأثر |
|---|---|---|
| `GET /admin/roles` | — | `{"assignable":[…], "creatable":[…]}` — كلُّ صفٍّ `{name, label, is_global, rank}`. **`rank` الأصغرُ أعلى** |
| `GET /admin/users?q=&role=&scope=` | — | `{"data":[…], "meta":{current_page,last_page,total}}`. و`scope=all` لحاملِ الدور العابر وحده، وإلا فالمعهدُ العامل |
| `POST /admin/users/{id}/roles` | `{"role":"supervisor","institute_uuid":null}` | إسنادٌ ⇐ `AssignUserRole` |
| `DELETE /admin/users/{id}/roles` | نفسه | سحبٌ ⇐ `RevokeUserRole` |
| `POST /admin/users/{id}/activation` | `{"is_active":false}` | إقفالٌ ⇐ `ToggleUserActivation`؛ والمقفلُ تسقط رموزُه عند أوّل طلب (§5) |
| `POST /admin/users/{id}/password` | `{"password":null}` | توليدُ ثمانية أرقام، أو كلمةٌ يكتبها المشرف ⇐ `ChangeUserPassword`. الردُّ `{"credentials":{…}}` |
| `GET /admin/credentials?role=&q=` | — | `{"data":[{id,name,role,username,password,is_active,detail}]}` — بطاقاتٌ جاهزةٌ للطباعة، و`password` يعود `null` لمن بدّل كلمته بنفسه |

**`id` لا `uuid` — عمداً.** `users` جدولٌ **لا يُزامَن** ([SYNC-PROTOCOL.md §2](SYNC-PROTOCOL.md)):
حمولتُه بيانات دخول لا تُبثّ في تيّارٍ يقرؤه كل جهاز في المعهد. فلا عمود `uuid` فيه أصلاً لأن لا صفَّ
منه يعبر `change_log` ليحتاج معرّفاً عالمياً. **وهو نفسُه سببُ وجود نقطتَي قراءةٍ هنا وحدهما**: ما لا
يصل في `sync/pull` لا بدّ أن يُقرأ من الشبكة.

**ولماذا كتالوجُ أدوارٍ من الخادم؟** لأن البديل كان نسخَ `PanelRole` وهرمَه وتسمياتِه العربية إلى
Dart، فيفترق السطحان عند أوّل تعديل — وهو القرار 3 في
[PHASE-6-STAGES.MD §0](PHASE-6-STAGES.MD): الفرق بين الأدوار صلاحياتٌ لا نسخةُ برنامج.

**والحراسةُ رتبةٌ لا صلاحيةٌ وحدها:** لا يُسند أحدٌ دوراً أعلى من دوره (`assertAssignable`)، ولا
يبدّل مشرفٌ كلمةَ مشرفٍ نظيره ولا يُقفل حسابَه (`outranks`). ورفضُ الفعل **422 برسالته العربية** لا
403 — فهو حكمُ الفعل لا حكمُ الوسيط (§5).

#### 3.10.4 بنيةُ الدورة

| النقطة | الجسم | الفعل |
|---|---|---|
| `POST · PUT /admin/courses[/{uuid}]` | `{name, starts_on, ends_on?, status, notes?}` | `SaveCourse` |
| `POST /admin/courses/{uuid}/activate` | — | `ActivateCourse` — تُنزل الجاريةَ السابقة |
| `POST · PUT /admin/shifts[/{uuid}]` | `{course_uuid?, name, starts_at:"08:00", ends_at:"11:00", sort_order?, is_active?, weekdays:[0..6]}` | `SaveShift` — الأيامُ تُحذف وتُعاد كتابتُها بالنموذج فيراها مراقبُ المزامنة |
| `POST · PUT /admin/circles[/{uuid}]` | `{name, level?, color?, sort_order?, is_active?, notes?}` | `SaveCircle` |
| `POST /admin/circles/{uuid}/run` | `{course_uuid?, shift_uuid, room?, capacity?}` | `RunCircleInCourse` ⇒ `CourseCircleResource` (§3.4) |

`course_uuid` المتروكُ فارغاً يعني **الدورة الجارية**، ومعهدٌ بلا دورةٍ جارية ⇒ 422 برسالته لا 500.
والحلقةُ تعمل **مرّةً واحدة في الدورة** (قيد `unique(course_id, circle_id)` في الهجرة) — يُفحص قبل
الكتابة فتعود رسالةٌ مقروءة بدل انتهاكِ قيد.

**والأفعالُ الأربعة الجديدة** (`SaveCourse` · `SaveShift` · `SaveCircle` · `RunCircleInCourse`)
أُخرجت من شاشات اللوحة التي كانت تكتب النماذجَ مباشرةً، **فصارت الشاشاتُ تستدعيها هي أيضاً** — وإلا
كان للدورة الواحدة كاتبان يفترقان عند أوّل تعديل.

---

## 4. قواعد النطاق — `App\Support\ApiScope`

النطاق يُحسم **من الحساب لا من الطلب**؛ لا معامل `institute_id` في أي مسار ولا في أي جسم:

```php
// 🔄 م.6.1 — الترتيب الكامل
institute() = ترويسة X-Institute إن وصلت  ⇒ يُتحقَّق أنها من معاهد الحساب، وإلا AuthorizationException ⇒ 403
           ?? user->teacher?->institute_id
           ?? user->guardian?->institute_id
           ?? user->student?->institute_id
           ?? أوّلُ معهدٍ أُسند فيه للمستخدم دور      // ← الجديد: مدير المعهد والمشرف
           ?? أوّلُ معهدٍ فعّال — لحاملِ الدور العابر وحده (مبرمج/مشرف أعلى)
           ?? RuntimeException  ⇒ 422
```

**ما تغيّر في م.6.1 ولماذا:** كان الحسم من السجلّات الثلاثة وحدها، وحسابُ مدير المعهد والمشرف
يُنشئه `InviteUser` **بلا أيٍّ منها عمداً** ⇒ 422 على كل نقطة. عملياً: لم يكن يدخل الـ API مشرفٌ
إلا إن كان **أيضاً** أستاذاً مسجَّلاً — وهو الحاجب الأول أمام الديسكتوب
([CLIENTS.md §5 البند 2](CLIENTS.md)). فصار **إسنادُ الدور داخل معهد** طريقاً ثانياً إلى النطاق،
وهو نفسُ ما تقرؤه اللوحةُ منذ م.4.6 (`User::instituteIds()` يقرؤه السطحان معاً الآن).

**وما لم يتغيّر: لا تخمين.** حسابٌ بلا سجلٍّ ولا دورٍ في أي معهد يبقى 422 كما كان. والسقوطُ إلى
«أوّل معهد فعّال» مقصورٌ على حامل الدور العابر — وهو يرى المعاهد كلَّها أصلاً ويملك مبدّلاً.

**ترويسة `X-Institute`** ✅ م.6.1 (`App\Support\ApiScope::HEADER`) تحمل `uuid` المعهد الذي يعمل
فيه الجهاز الآن. وهي **تضيّق ما يملكه صاحبُ الحساب ولا توسّعه**: معهدٌ لا يعمل فيه ⇒ **403** صريحة
لا تجاهلٌ صامت — ولو سقط الطلب إلى معهده الأصلي بلا خبر لكتب مديرُ المعهد بياناتٍ وهو يظنّها في
معهدٍ آخر. وهي نظير الجلسة على اللوحة: ما تثبّته `PanelScope` في الجلسة تحمله هنا كلُّ طلب.

🔄 **وفي جانب العميل (م.6.3):** `ApiClient` يقرأ المعهدَ العامل من **دالّة** عند كل طلب لا من نصٍّ
يُثبَّت عند البناء، فيغيّر المبدّلُ وجهةَ الطلبات التالية بلا إعادةِ بناءٍ للعميل ومعترضاته.
والترويسةُ **تُحذف إن غاب المعهد ولا تُرسَل فارغة** — الفارغةُ تعني «معهدٌ لم يُعثر عليه» ⇒ 403،
بينما غيابُها يعني «معهدي الأصلي» وهو المقصود. وتبديلُ المعهد على الجهاز يمسح مخزنَه ويصفّر مؤشّرَ
سحبه ([SYNC-PROTOCOL.md §8](SYNC-PROTOCOL.md) البند 11).

ثم يضبط مفتاح فريق spatie (`setPermissionsTeamId`) — **وبدون هذه الخطوة يفشل كل فحص `permission:`
لاحق**، ولذلك `SetApiInstituteScope` يسبق كل شيء في المجموعة.

| الدور | ما يراه فعلياً | آلية الحصر |
|---|---|---|
| `teacher` | حلقاته المسنَدة في الدورة الجارية وحدها | `whereHas('teachers', …teacher->id)` في `TeacherCircleQuery` |
| `guardian` | أبناؤه وحدهم | `guardian->students()->where('students.uuid', …)` — لا استعلام مفتوح على `students` |
| `student` | نفسه وحده | `user->student` مباشرةً؛ لا معرّف في أي مسار |
| `supervisor` · `admin` ✅ م.6.1 | معهدَه كاملاً | إسنادُ الدور في `model_has_roles.institute_id` |
| `super_admin` · `developer` ✅ م.6.1 | المعاهد كلَّها، واحداً في كل طلب | الترويسة، وإلا أوّلُ معهدٍ فعّال |
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
| `403` | **معهدٌ مطلوب في `X-Institute` لا يعمل فيه الحساب** ✅ م.6.1 | `{"message":"لا يعمل هذا الحساب في المعهد المطلوب."}` | `ApiScope` |
| `422` | **توكن بلا معهد مرتبط** | `{"message":"لا يملك هذا المستخدم معهداً مرتبطاً."}` | `SetApiInstituteScope` |
| `422` | فشل تحقّق، **وكذلك كلمة مرور خاطئة وحسابٌ مقفل عند الدخول** | `{"message":…,"errors":{"username":["بيانات الدخول غير صحيحة."]}}` | `validate()` / `ValidationException` |
| `422` | **رفضُ فعلٍ إداري بالرتبة أو بالهرم** ✅ م.6.2 — «لا تملك إسناد دور…» · «لا تملك تبديل كلمة مرور هذا الحساب» | `{"message":"…"}` | `AssignUserRole` · `ChangeUserPassword` · `ToggleUserActivation` عبر `/admin/*` |
| ~~`500`~~ | ~~نوع عملية غير معروف في `sync/push`~~ | 🔄 **م.6.1: لم يعد 500.** العملية المرفوضة تعود في `failed[]` بـ200 ولا تُسقط الدفعة معها (§6) | `SyncPush` |

**لا يوجد `409` في هذا النظام.** تعارض المزامنة **لا يُعاد للعميل خطأً**: الخادم يحسمه بنفسه، ويردّ
`200` مع العملية ضمن `applied`، ويحفظ المرفوض في `sync_conflicts` — [SYNC-PROTOCOL.md §5](SYNC-PROTOCOL.md).

---

## 6. أنواع عمليات `sync/push`

الغلاف واحد لكل الأنواع (`op_uuid` + `type` مطلوبان، والباقي حسب النوع)، ودورة الدفع وقواعد
التكرار في [SYNC-PROTOCOL.md §3](SYNC-PROTOCOL.md)، والفعل الذي يستدعيه كل نوع في
[ARCHITECTURE.md §3](ARCHITECTURE.md). ما يخصّ **الشكل على السلك**:

| `type` | الحقول | ملاحظات |
|---|---|---|
| `attendance.session.open` | `course_circle_uuid` · `session_date?` · `uuid?` ✅ م.5.3 | الحلقة تُتحقَّق ضمن معهد المستخدم. `uuid` معرّفٌ يولّده العميل ويُستعمل **عند الإنشاء وحده** (انظر أسفل الجدول) |
| `attendance.take` | `session_uuid?` · `course_circle_uuid?` + `session_date?` ✅ م.5.3 · `attendances[]{student_uuid, status, late_minutes?, note?, recorded_at?}` · `amend?` | `recorded_at` **هو مفتاح حسم التعارض** — أرسله دائماً بزمن الجهاز وقت التسجيل، لا وقت الدفع. و`late_minutes` **اتركه فارغاً** ليحسبه الخادم (انظر أسفل الجدول) |
| `attendance.teacher.take` | `session_uuid?` · `course_circle_uuid?` + `session_date?` ✅ م.5.3 · `teacher_attendances[]{teacher_uuid, status, late_minutes?, note?}` | بلا `recorded_at` ⇒ بلا حسم تعارض |
| `attendance.session.complete` | `session_uuid?` · `course_circle_uuid?` + `session_date?` ✅ م.5.3 | يقفل الجلسة (§6 في SYNC-PROTOCOL) |
| `excuse.submit` | `student_uuid` · `from_date` · `to_date` · `reason` · `attachment_path?` | نظير `POST /guardian/excuses` لعميل يملك `sync.push` |
| `recitation.save` | `session_uuid?` · `course_circle_uuid?` + `session_date?` ✅ م.5.3 · `student_uuid` · `recitation{uuid?, from_surah, from_ayah, to_surah, to_ayah, grade?, juz?, type?, curriculum_item_id?, notes?}` · `recorded_at?` | `grade`: `excellent`/`very_good`/`good` · `type`: `hifz`/`murajaa`/`tilawah`. الأسطر والنقاط تُحسب على الخادم وتُجمَّد. `uuid` معرّفٌ يولّده العميل: معرّفٌ جديد ⇒ تسجيل، ومعرّفٌ قائم ⇒ **تصحيحٌ في مكانه** ✅ م.5.4 (انظر أسفل الجدول) |
| `recitation.delete` | `recitation_uuid` | تسميعٌ لا وجود له ⇒ نجاحٌ صامت لا 404 ✅ م.5.4 |
| `points.award` | `uuid?` ✅ م.5.4 · `student_uuid` · `points` · `reason` · `note?` · `awarded_on?` · `session_uuid?` · `course_circle_uuid?` + `session_date?` ✅ م.5.3 | `reason`: `behavior`/`participation`/`competition`/`reward`/`excellence`/`volunteering`/`other`. و`uuid` كنظيره في `recitation.save` |
| `points.delete` ✅ م.5.4 | `point_uuid` | منحةٌ لا وجود لها ⇒ نجاحٌ صامت لا 404 |
| `excuse.review` ✅ م.6.2 | `excuse_uuid` · `decision` · `note?` | `decision`: `approved`/`rejected` — وقبولُ الإذن يحوّل غيابَ الجلسات **غيرِ المقفلة** إلى «مأذون» (`ReviewAbsenceExcuse`). يتطلّب `excuses.review` |
| `student.save` ✅ م.6.2 | `uuid?` · `student{…}` · `guardians{father,mother}` · `trait_uuids[]?` · `memorized_item_uuids[]?` · `custom_fields{}?` · `course_circle_uuid?` | استمارةُ التسجيل كاملةً ⇐ `SaveStudentRegistration`. و`uuid` كنظيره في `recitation.save`: معرّفٌ قائم ⇒ تحريرٌ في مكانه. **والمراجعُ كلُّها بالـ`uuid`** (انظر أسفل الجدول). يتطلّب `students.manage` |
| `enrollment.save` ✅ م.6.2 | `student_uuid` · `course_circle_uuid` · `enrolled_on?` | ⇐ `EnrollStudent` — تسجيلٌ واحد لكل دورة، والطاقةُ الاستيعابية تُحترم. يتطلّب `enrollments.manage` |
| `student.transfer` ✅ م.6.2 | `student_uuid` · `to_course_circle_uuid` · `reason?` · `transferred_on?` | ⇐ `TransferStudent` — التسجيلُ القديم يُغلق «منقولاً» ولا يُحذف. يتطلّب `transfers.manage` |

```jsonc
// POST /sync/push  ⇒  200
{ "applied": ["op-uuid-1", "op-uuid-2"],
  "skipped": ["op-uuid-0"],
  "failed":  [ { "op_uuid": "op-uuid-3",                     // ✅ م.6.1
                 "message": "صفٌّ تقصده العملية غير موجود في هذا المعهد." } ] }
```

`skipped` = عمليات سبق تطبيقها بنفس `op_uuid` (إعادة إرسال بعد انقطاع).

🔄 **`failed` أُضيفت في م.6.1، والعمليةُ المرفوضة لم تعد تُسقط الدفعة معها.** كانت الدفعة كتلةً
واحدة: عمليةٌ ترفع استثناءً — نوعٌ مجهول، أو صفٌّ من معهدٍ آخر، أو جلسةٌ لا وجود لها — تُنهي الطلب
كلَّه، فيبقى كلُّ ما خلفها معلّقاً في الجهاز **إلى الأبد** لأن الأولى لن تنجح أبداً. صارت كلُّ
عملية في معاملتها، والمرفوضةُ تُردّ هنا برسالتها ويمضي الباقي.

**وما على العميل فعلُه بها:** يحذف ما في `applied` و`skipped` وحدهما — كما كان — و**يعزل** ما في
`failed` بلا حذفٍ ولا إعادةِ إرسالٍ آلية، ويعرضه لصاحب الجهاز
([SYNC-PROTOCOL.md §3](SYNC-PROTOCOL.md)). فعميلٌ قديم لا يعرف الحقل يبقى سليماً: يُعيد إرسالها في
دورته التالية كما كان يفعل، دون أن تحجب ما بعدها.

### لكل نوعٍ صلاحيتُه ✅ م.6.2

كان الطابور **مفتوحاً لكل حاملِ `sync.push`**: الحارسُ على المسار واحد، والأستاذُ يملك الصلاحية
ليتفقّد — فكان يملك بها، نظرياً، أن يصفّ تسجيلَ طالبٍ لو عرف اسم النوع. وحراسةُ اللوحة على الشاشات
لا تُغني: الطلب يصل الخادمَ كيفما بُنيت الواجهة (نفسُ حجّة `AssignUserRole`). فصار لكل نوعٍ
صلاحيتُه في `SyncPush::assertPermitted`:

| النوع | الصلاحية |
|---|---|
| `attendance.take` **بـ`amend: true`** | `attendance.amend` — التصحيحُ الرجعي فعلٌ مقصود، وهو ما يميّز الديسكتوب من تطبيق الأستاذ ([APPS-FEATURES.md §4.2](APPS-FEATURES.md)) |
| `student.save` · `enrollment.save` · `student.transfer` · `excuse.review` | `students.manage` · `enrollments.manage` · `transfers.manage` · `excuses.review` |
| ما عداها | كما كان: `sync.push` على المسار وحدها |

**والرفضُ يقع في `failed[]` لا 403 على الدفعة كلِّها**: عمليةٌ واحدة لا يحقّها صاحبُ الجهاز لا
تُسقط تفقُّدَ يومٍ معها.

### `student.save` يشير بالـ`uuid` لا بالمفتاح الأساسي ✅ م.6.2

الصفاتُ وبنودُ المناهج والواصفاتُ المخصّصة تصل الجهازَ في `sync/pull` بمعرّفاتها **العالمية** وحدها
— ولا يعرف أرقامَها الداخلية أصلاً. ولذلك `trait_uuids` و`memorized_item_uuids` و`custom_fields`
(مفتاحُها `uuid` الواصفة) تُحسم على الخادم، **محصورةً بالمعهد**: الصفاتُ العامة (بلا معهد) متاحةٌ
للجميع كما في شاشة الاستمارة، وما لا يُطابق يُترك بلا أن يُسقط العملية.

و`student{}` **قائمةٌ بيضاء** من أعمدة الاستمارة (`SyncPush::STUDENT_ATTRIBUTES`): الحمولةُ تصل من
جهازٍ لا من نموذجٍ مُتحقَّق منه، فما ليس فيها لا يُسنَد. و`uuid` يشير إلى طالبٍ **في معهدٍ آخر** ⇒
مرفوضٌ في `failed[]` كما في `recitation.delete` — الحالتان تبدوان «لم يُعثر عليه» وهما نقيضان.

### كيف تُحسَم الجلسة في عمليات الجلسة ✅ م.5.3

كان `session_uuid` **مطلوباً** في الأنواع الخمسة، وهو ما جعل «فتحُ جلسةٍ أوف-لاين» مستحيلاً:
الأستاذُ المنقطع لا يعرف المعرّف الذي سيولّده الخادم، فلا يستطيع أن يُتبع `attendance.session.open`
بـ`attendance.take` في **نفس الطابور**. الحلُّ شقّان:

**1) العميل يولّد `uuid` الجلسة** ويرسله في `attendance.session.open`، فيُستعمل عند الإنشاء وحده
(`OpenAttendanceSession::handle(..., ?string $uuid)`). **جلسةٌ قائمة تحتفظ بمعرّفها** — لو استبدلناه
لَتغيّر معرّفٌ سبق أن بُثَّ لأجهزة أخرى في `sync/pull`.

**2) المفتاح الطبيعي احتياطاً.** لأن الجلسة قد تكون فُتحت قبله — مشرفٌ من اللوحة، أو أستاذٌ ثانٍ
أوف-لاين بمعرّفٍ آخر — فالصفُّ القائم يحمل معرّفاً لا يعرفه هذا الجهاز. لذلك يحسم `SyncPush`
الجلسةَ بهذا الترتيب:

```
session_uuid موجود وطابق صفّاً في المعهد؟      ⇒ هي
وإلا: course_circle_uuid + session_date طابقا؟  ⇒ هي   (قيد unique في الهجرة)
وإلا:                                            ⇒ 404
```

فليرسل العميلُ **الثلاثة معاً** في كل عملية جلسة أنشأها أوف-لاين. وبلا مفتاحٍ طبيعي يبقى السلوك
القديم كما هو: `session_uuid` وحده، و404 إن لم يُطابق — فالعملاءُ القدامى لا ينكسرون (§7).

⚠️ `points.award` استثناءٌ في قراءة الفراغ: الجلسة فيه **اختيارية أصلاً**، فلا تُطلَب إلا حين يصل
`session_uuid` أو `course_circle_uuid`؛ وبلا أيّهما تُسجَّل النقاط بلا جلسة كما كانت.

### التصحيح والحذف من عميلٍ أوف-لاين ✅ م.5.4

`recitation.save` و`points.award` كانتا **تسجيلاً فقط**: كل دفعةٍ تُنشئ صفّاً جديداً. فالأستاذ
الذي أخطأ في المدى أو في التقدير لا يملك من جهازه إلا أن يترك الخطأ — لا مفتاحَ أساسياً عنده
يشير به إلى صفٍّ قد لا يكون أُنشئ على الخادم بعد.

الحلّ نفسُ حلّ الجلسة في م.5.3: **العميل يولّد المعرّف**. يرسله في `recitation.save`
(داخل `recitation{}`) وفي `points.award` (في جذر العملية)، فيُحسم الصفّ به:

```
uuid فارغ؟                    ⇒ تسجيلٌ جديد بمعرّفٍ يولّده الخادم   (سلوك العملاء القدامى)
uuid لا يطابق صفّاً؟           ⇒ تسجيلٌ جديد يحمل معرّف العميل
uuid يطابق صفّاً (ولو محذوفاً)؟ ⇒ تصحيحٌ في مكانه، والمحذوف يُحيا
```

فيصير التصحيح **إعادةَ إرسالٍ بنفس `uuid` وبـ`op_uuid` جديد**، والحذف عمليةً مستقلّة
(`recitation.delete` · `points.delete`). والأسطر والنقاط تُعاد حسابُها في كل تصحيح، والسجلُّ
المصحَّح يُستثنى من خريطة تغطيته كي لا يُحسب مكرّراً لنفسه.

⚠️ الحذف **لا يُرجع 404** حين لا يجد صفّه: العميلُ قد يصفّ الحذف مرّتين أو يحذف ما حذفه غيرُه،
وعمليةٌ واحدة مرفوضة تُعلّق الطابور كلَّه خلفها. فالنتيجة محقَّقة ⇒ العملية `applied`.

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
| ~~**`/bootstrap` لا يخدم إلا الأستاذ**~~ (§3.4) | 🔄 **سُدّت نصفاً في م.6.1**: صارت تخدم من يملك `circles.view` أيضاً — أي الديسكتوب. ويبقى ولي الأمر والطالب على `circles: []` حتى م.7 وم.8 |
| **`/student/me/progress` بلا Resource** (§3.7) | شكلها غير مستقرّ؛ تثبيتها قبل م.8 |
| ⚠️ **رفعُ الشعار خارج الـ API** 🔄 م.6.2 (§3.10.2) | `logo_path` يُقرأ ولا يُكتب: الرفعُ عقدٌ آخر (`multipart/form-data`) لم يُفتح بعد، فيبقى شعارُ المعهد يُرفع من اللوحة وحدها. يُفتح مع أوّل شاشةِ رفعٍ في م.6.5، أو يبقى استثناءً موثَّقاً |
| **`sync/pull` بلا مؤشّر «بقيّة»** | الصفحة 500 صفّاً و`server_seq` = آخر صفّ في الصفحة؛ العميل يكرّر السحب حتى تعود `changes` فارغة — [SYNC-PROTOCOL.md §4](SYNC-PROTOCOL.md) |
| ⚠️ **صفحةُ السحب الأولى صارت أثقل** 🔄 م.5.1 | كتاباتُ اللوحة صارت تدخل `change_log` (وهو المقصود)، فالمعهدُ العامل منذ شهور يعطي جهازاً جديداً آلافَ الصفوف من `since=0`. مقبولٌ بالحجم المتوقَّع، ويستدعي «لقطة أولية بدل تيّار من الصفر» قبل م.9 — [SYNC-PROTOCOL.md §10](SYNC-PROTOCOL.md) البند 7 |

---

## 9. مرجعية عكسية — لمن يخطّط للمراحل 5 إلى 8

عند التخطيط لأي تطبيق من الأربعة، **اقتبس من هذا الملف ولا تعد اكتشاف العقد من كود PHP**:

| التطبيق | الأقسام الملزمة |
|---|---|
| **الأستاذ** (م.5) | §1 · §3.1 · §3.3 · §3.4 · §3.5 · §6 كاملاً · §8 البند الأول |
| **الديسكتوب** (م.6) | نفسها + §3.8 و§3.9 و**§3.10 كاملاً** · `attendance.teacher.take` و`amend` في §6 · §4 كاملاً (الترويسة والنطاق) · `failed[]` وأنواعُ الإدارة الأربعة في §6 |
| **الأهل** (م.7) | §3.6 · §3.4 مع تحفّظه · `sync/pull` بلا `push` (§4) |
| **الطالب** (م.8) | §3.7 بتحفّظه · `sync/pull` بلا `push` |

وأي تغيير على الكود يمسّ ما ورد هنا يُحدَّث في هذا الملف **في نفس الالتزام** — وإلا فقد العقد
معناه.
