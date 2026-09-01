# نقطة تفتيش — المرحلة 4: طبقة API والمزامنة

**التاريخ:** 2026-09-01
**الحالة:** ✅ مكتملة — 156/156 اختباراً ناجحاً، Pint نظيف، `npm run build` ناجح
**البناء على:** [CHECKPOINT-PHASE-3.MD](CHECKPOINT-PHASE-3.MD) · المرجع التفصيلي: [ERD.md](ERD.md)

---

## 1. ما الذي أُنجز

| المخرَج | العدد | التفصيل |
|---|---|---|
| حزمة جديدة | **1** | `laravel/sanctum` — توكنات شخصية، لا جلسة ولا كوكي |
| نقاط API | **13** | `/api/v1/*` — دخول، أجهزة، لقطة أولية، مزامنة، ومسارات الأدوار الثلاثة |
| إجراءات دومين جديدة | **6** | `SyncPush`, `SyncPull`, `RecordChange`, `RegisterDevice`, `ResolveAttendanceConflicts` |
| أصناف قراءة جديدة | **2** | `TeacherCircleQuery`, `GuardianChildrenQuery` |
| متحكّمات API | **6** | `Auth`, `Sync`, `Device`, `Bootstrap`, `Teacher`, `Guardian`, `StudentSelf` |
| Resources | **5** | `app/Http/Resources/V1/` |
| Middleware جديد | **1** | `SetApiInstituteScope` — نظير `InteractsWithInstitute` بلا جلسة |
| اختبارات جديدة | **21** | `tests/Feature/Api/` — المجموع **156 / 156** ناجحة |

---

## 2. اكتشاف: سقالة المزامنة كانت جاهزة جزئياً

عند بدء هذه المرحلة تبيّن أن migrations وnماذج `change_log`, `sync_devices`, `sync_conflicts`, `devices`
وenum `SyncOperation` وصلاحيات `sync.pull`/`sync.push`/`conflicts.review` كانت **موجودة مسبقاً** من
المرحلة 1 (تصميم استباقي في نموذج البيانات). لم يكن هناك ما يقرأ منها أو يكتب إليها — هذا هو عمل هذه
المرحلة: تفعيل السقالة، لا إعادة بنائها.

---

## 3. المصادقة — Sanctum لا جلسة

```bash
composer require laravel/sanctum
php artisan install:api --without-migration-prompt
```

- `User` أضيف إليه `Laravel\Sanctum\HasApiTokens` إلى جانب `HasRoles` الموجود.
- `bootstrap/app.php`: `api: routes/api.php` أُضيف إلى `withRouting()` (Laravel 13 لا يسجّله تلقائياً)،
  ومسار الصلاحيات (`role`, `permission`, `role_or_permission`) من Spatie **لم يكن مسجَّلاً كـ middleware alias
  في أي مكان بالمشروع** — أُضيف صراحةً في `withMiddleware()` لأن `bootstrap/app.php` (نمط Laravel 11+) لا
  يُحمِّل middleware تلقائياً كما كان الحال في الإصدارات الأقدم.
- تسجيل الدخول: `POST /api/v1/auth/login` بـ `email`/`password`/`device_name` يعيد `plainTextToken`.
  لا انتهاء صلاحية (`config/sanctum.php: expiration = null`) — العميل يعمل أوف-لاين لفترات طويلة.

---

## 4. حسم النطاق بلا جلسة — `App\Support\ApiScope`

`InteractsWithInstitute` (المرحلة 2) مبني على `Session` و`#[Computed]` — لا يصلح لطلب API بلا حالة.
`ApiScope` نظيره: يحسم معهد المستخدم من `teacher/guardian/student` **فقط**، **بلا** السقوط الافتراضي إلى
"أول معهد نشط" الذي تستعمله اللوحة — توكن بلا معهد مرتبط يُرفض بـ 422 صراحةً بدل تخمين معهد خطأ.

```php
$scope = ApiScope::for($request->user());
$institute = $scope->institute();   // يضبط أيضاً setPermissionsTeamId
$scopeKey = $scope->scopeKey();     // "institute:{uuid}"
```

Middleware جديد `SetApiInstituteScope` (اسمه المستعار `institute.scope`) يشغّل هذا الحسم **قبل** أي فحص
`role:`/`permission:` لاحق في نفس مجموعة المسارات — بدونه يفشل كل فحص صلاحية على مستخدم أُسندت أدواره
ضمن معهد بعينه (وضع الفرق في Spatie).

---

## 5. المزامنة

### 5.1 الدفع — `POST /api/v1/sync/push`

`SyncPush` يطبّق دفعة عمليات مُنشأة أوف-لاين **بإعادة استخدام أفعال اللوحة نفسها**
(`OpenAttendanceSession`, `TakeAttendance`, `TakeTeacherAttendance`, `CompleteAttendanceSession`,
`SubmitAbsenceExcuse`) بدل إعادة كتابة منطقها — وهو المكسب العملي من فصل Actions/Queries في المرحلة 3.

كل عملية تحمل `op_uuid` يولّده العميل. عمليةٌ سبق تطبيقها (موجودة في `change_log.op_uuid`) تُتجاهل بصمت:

```json
{"applied": ["<op_uuid>"], "skipped": ["<op_uuid آخر سبق دفعه>"]}
```

أنواع العمليات المدعومة الآن: `attendance.session.open`, `attendance.take`, `attendance.teacher.take`,
`attendance.session.complete`, `excuse.submit` — نطاق الأستاذ/الأهل التشغيلي فقط (المرحلة 5). توسيعه إلى
كتابات أخرى (تسجيل طالب، نقل) مؤجَّل لِما بعد تطبيق الديسكتوب.

### 5.2 السحب — `GET /api/v1/sync/pull?since=&app=`

`SyncPull` يعيد صفوف `change_log` حيث `scope_key` = نطاق المستخدم و`id > since`، ويحدّث
`sync_devices.last_pulled_seq`. النطاق الآن **معهدٌ كامل** لكل الأدوار (لا حلقات الأستاذ وحدها) —
تضييقه مؤجَّل لِما بعد قياس كلفته الفعلية على جهاز حقيقي (المرحلة 5).

### 5.3 تسجيل الكتابات — `App\Actions\RecordChange`

كل عملية دفع ناجحة تُسجَّل في `change_log` عبر `RecordChange::handle()`. كتابات اللوحة (الأدمن) **لا**
تُسجَّل تلقائياً بعد — هذا يعني أن تطبيق الأستاذ لن يرى حلقة أُنشئت من اللوحة إلا عبر `bootstrap` الأولي،
لا عبر `sync/pull`. ربط `RecordChange` بكل Actions اللوحة ذات الصلة (فتح/إغلاق الجلسة، التسجيل) نقطة
مفتوحة — انظر §8.

### 5.4 حلّ التعارضات — `App\Actions\ResolveAttendanceConflicts`

جهازان يأخذان نفس الجلسة أوف-لاين: **الأحدث `recorded_at` يفوز**، والقديم يُسجَّل في `sync_conflicts`.

> ⚠️ **خلل حقيقي اكتُشف وأُصلح أثناء بناء هذا:** `TakeAttendance::handle()` كان يستبدل دائماً
> `recorded_at` بـ `now()` (وقت وصول الطلب للخادم) متجاهلاً وقت الحدث الحقيقي على الجهاز. هذا يجعل
> "الأحدث يفوز" عديم المعنى: كل كتابة توصف بأنها الأحدث لمجرّد وصولها متأخرة. أُصلح بقبول `recorded_at`
> اختيارياً في كل صفّ (`app/Actions/TakeAttendance.php`) يستعمله الدفع أوف-لاين، بينما تبقى اللوحة
> تعتمد `now()` الافتراضي.
>
> صفّ التفقّد المزروع تلقائياً عند فتح الجلسة (`OpenAttendanceSession`) **ليس تعارضاً محتملاً** — لا جهاز
> حقيقي أنتجه. `ResolveAttendanceConflicts` يتحقّق أولاً من وجود عملية `attendance.take` سابقة من جهاز
> آخر في `change_log` قبل اعتبار الصفّ منافساً؛ بدون هذا الفحص كانت أول كتابة حقيقية تتعارض زوراً مع
> الزرع الافتراضي (وقته دائماً "الآن" ⇒ أحدث من أي وقت تاريخي يرسله العميل).

---

## 6. الأجهزة والّلقطة الأولية

- `POST /api/v1/devices/register` — `RegisterDevice` يفتح مؤشّر مزامنة في `sync_devices`، وإن أُرفق
  `fcm_token` يسجَّل أيضاً في `devices` (إشعارات فورية — تُستهلك في المرحلة 7).
- `GET /api/v1/bootstrap` — لقطة أولية: المعهد، الدورة الجارية، وحلقات الأستاذ إن كان الحساب حساب أستاذ.
  يستهلكها العميل عند أول تشغيل قبل أن تبدأ `sync/pull` التزايدية.

---

## 7. نقاط الـ API الكاملة

```
POST   /api/v1/auth/login                لا يحتاج توكناً
POST   /api/v1/auth/logout                يحذف التوكن الحالي
GET    /api/v1/auth/me
POST   /api/v1/devices/register

GET    /api/v1/bootstrap                  (يتطلّب institute.scope)
GET    /api/v1/sync/pull?since=&app=      (permission: sync.pull)
POST   /api/v1/sync/push                  (permission: sync.push)

GET    /api/v1/teacher/circles            (role: teacher)
GET    /api/v1/teacher/sessions/{date}
GET    /api/v1/guardian/children          (role: guardian)
GET    /api/v1/guardian/children/{student}/attendance
POST   /api/v1/guardian/excuses
GET    /api/v1/student/me/attendance      (role: student)
GET    /api/v1/student/me/progress
```

`/auth/logout` و`/auth/me` و`/devices/register` **عمداً بلا** `institute.scope` — حساب بلا معهد مرتبط
بعد (أو أدمن بلا سجلّ teacher/guardian/student) يجب أن يقدر على تسجيل الخروج والاستعلام عن هويته.

---

## 8. ما لم يُنفَّذ (مقصود)

| البند | السبب / مرحلته |
|---|---|
| تسجيل كتابات اللوحة تلقائياً في `change_log` | مربوط الآن فقط بمسار الدفع (`SyncPush`)؛ ربط `RecordChange`
  بأفعال اللوحة (فتح/إغلاق الجلسة من الأدمن، التسجيل، النقل) يحتاج تدقيقاً في كل Action على حدة —
  **قبل المرحلة 5** حتى يرى تطبيق الأستاذ تغييرات اللوحة عبر `sync/pull` لا `bootstrap` فقط |
| تضييق نطاق `sync/pull` لحلقات الأستاذ | النطاق الآن معهدٌ كامل؛ تضييقه يحتاج قياس كلفته الفعلية —
  **بعد قياس أداء حقيقي في المرحلة 5** |
| توسيع أنواع عمليات `SyncPush` (تسجيل طالب، نقل، مناهج) | خارج التفقّد — **المرحلة 6 (الديسكتوب)** حين
  يحتاج المشرف كتابة كاملة أوف-لاين |
| `Http\Resources` لبقية الكيانات (المعلّم، الحلقة الكاملة، الطالب الكامل) | أُنشئ الحد الأدنى الذي
  تستهلكه نقاط الـ API الحالية؛ التوسّع حسب حاجة كل شاشة في تطبيقات فلاتر |
| `docs/sync-protocol.md` منفصل | التوثيق أُدرج هنا وفي تعليقات الكود بدل ملف مستقل؛ يُستخرج لاحقاً إن
  احتاجه فريق موبايل خارجي |

---

## 9. الاختبارات

```bash
cd backend
php artisan test --compact                          # 156/156
php artisan test --compact tests/Feature/Api         # 21
vendor/bin/pint --test
```

| الملف | العدد | ما يغطّيه |
|---|---|---|
| `Api/AuthTest.php` | 4 | دخول صحيح بتوكن · رفض كلمة مرور خاطئة · `/me` وإبطال التوكن بالخروج · رفض طلب بلا توكن |
| `Api/SyncPushPullTest.php` | 4 | فتح جلسة ثم تفقّد يُنشئ صفَّي change_log · إعادة إرسال نفس op_uuid تُتجاهل idempotent · `since` يعيد التغييرات الصحيحة فقط ويحدّث مؤشّر الجهاز · لا تسرّب بين المعاهد |
| `Api/SyncConflictTest.php` | 2 | كتابة أقدم تصل متأخرة تُرفض وتُسجَّل في sync_conflicts · كتابة أحدث تستبدل القديمة بلا تعارض |
| `Api/ScopeTest.php` | 4 | الأستاذ يرى حلقاته فقط · معزول عن معهد آخر (sync/pull وteacher/circles) · ولي الأمر يرى أبناءه فقط · لا يقرأ حضور طفل ليس له |
| `Api/DeviceRegistrationTest.php` | 3 | تسجيل جهاز يفتح مؤشّر مزامنة · fcm_token يسجَّل أيضاً في devices · نفس device_uuid مرتين يحدّث لا يكرّر |
| `Api/BootstrapTest.php` | 2 | اللقطة الأولية تعيد المعهد والدورة وحلقات الأستاذ · حساب غير أستاذ يعيد قائمة حلقات فارغة |
| `Api/StudentSelfTest.php` | 2 | الطالب يقرأ ملخّص حضوره وتقدّمه · حساب غير طالب يُرفض بـ403 |

**تحقّق إضافي خارج الاختبارات:** `migrate:fresh --seed` نظيف، دخول فعلي عبر `php artisan serve` ضد
بيانات مبذورة حقيقية أعاد توكناً صالحاً، `npm run build` ناجح.

---

## 10. مزالق تقنية وُوجهت

| المزلق | الحل |
|---|---|
| `$request->validate([...])` في نقطة الدفع يُسقط حقول كل عملية غير المصرَّح بها صراحةً (`course_circle_uuid`, `session_date`, ...) لأن كل نوع عملية له حقول مختلفة | التحقّق من الشكل العام فقط، ثم تمرير `$request->input('operations')` الخام لـ `SyncPush` |
| Sanctum لا يُبطل توكناً فعلياً ضمن نفس عملية PHPUnit عبر طلب HTTP تالٍ (تخزين مؤقت لحارس المصادقة داخل نفس دورة الاختبار) | التحقّق من إبطال الخروج عبر حالة القاعدة (`PersonalAccessToken::count()`) لا عبر طلب `/me` لاحق في نفس الاختبار |
| `belongsToMany()->attach()` على `course_circle_teachers`/`guardian_student` يفشل بقيد NOT NULL على `uuid` (الأعمدة تتطلّب uuid للمزامنة، والعلاقة المحورية القياسية في Eloquent لا تستدعي `HasUuid`) | الكتابة عبر النموذج مباشرة: `CourseCircleTeacher::create([...])` / `GuardianStudent::create([...])` — matches القاعدة المسجَّلة في PLAN.md §14 |
| Spatie `role`/`permission` middleware لم يكن مسجَّلاً كـ alias في أي مكان | تسجيله صراحة في `bootstrap/app.php: withMiddleware()` |
| مقارنة "آخر recorded_at يفوز" كانت تقارن دائماً وقت وصول الطلب لا وقت الحدث | `TakeAttendance` يقبل الآن `recorded_at` اختيارياً من الصفّ — §5.4 |

---

## 11. نقاط مفتوحة تحتاج قراراً منك

| البند | الأثر | متى |
|---|---|---|
| ربط `RecordChange` بأفعال اللوحة | بدونه لا يرى تطبيق الأستاذ تغييرات الأدمن إلا عند إعادة `bootstrap` | قبل المرحلة 5 |
| تضييق نطاق `sync/pull` لحلقات الأستاذ فقط | الآن يسحب المعهد كاملاً؛ قد يكون غير عملي لمعهد كبير | بعد قياس أداء في المرحلة 5 |
| ملف الشعار · الاستضافة · Firebase · iOS · قاعدة بيانات الإنتاج | كما في [CHECKPOINT-PHASE-3.MD](CHECKPOINT-PHASE-3.MD) §11 | مراحلها |

---

## 12. الخطوة التالية

**المرحلة 5 — تطبيق الأستاذ (Flutter):** `packages/mousqe_core` (نماذج freezed، مخطط drift، `SyncEngine`،
`ApiClient`)، ثم شاشات حلقاتي/تفقّد بضغطة واحدة/سجل الجلسات تستهلك بالضبط `POST /api/v1/auth/login`،
`GET /bootstrap`، `GET /sync/pull`، `POST /sync/push` المبنية في هذه المرحلة.

**للاستئناف السريع:**

```bash
cd d:\Development\Laravel\mousqe\backend
composer run dev              # serve + queue + vite
```

اختبار API يدوياً:

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@mousqe.test","password":"password","device_name":"test"}'
```

لإعادة البذر: `php artisan migrate:fresh --seed`.
