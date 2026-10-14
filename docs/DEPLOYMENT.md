# تشغيل نزلاً: محلياً للتجربة وعلى الخادم الرئيسي

يغطي هذا الملف طريقتين لتشغيل الموقع (اللوحة + الـ API)، وكيف يتصل به تطبيقا نزلاً (الهاتف والإدارة) في كل منهما.

| | متى | الخادم | الاتصال |
|---|---|---|---|
| **أ. محلي** | تجربة، أو مسجد بلا إنترنت | حاسوب في الشبكة نفسها (أو نقطة اتصال منه) | `http://<IP>:8000` |
| **ب. الرئيسي** | الإنتاج | Hostinger Cloud على `nuzuln.com` | `https://nuzuln.com` |

التطبيقات تُبنى بعنوان افتراضي (`https://nuzuln.com/api/v1`)، ويُبدَّل من **شاشة البدء بثلاث نقرات على الشعار**: الخادم الرئيسي أو «خادم محلّي» (انظر §أ.4). فنسخة واحدة من التطبيق تصلح للطريقتين.

---

## أ. تشغيل محلي على شبكة مشتركة

### أ.1 المتطلبات على الحاسوب الذي يعمل خادماً (ويندوز)

PHP 8.3 أو أحدث (يُفضَّل 8.4) مع إضافات `pdo_sqlite` و`mbstring` و`openssl` و`curl` و`fileinfo` و`intl`، وComposer، وNode 20 أو أحدث.

### أ.2 تجهيز الباك إند (مرة واحدة)

```powershell
cd backend
composer install
npm ci
npm run build                     # يبني CSS والخطوط في public/build
copy .env.example .env
php artisan key:generate
php artisan migrate --seed        # قاعدة SQLite ومعهد تجريبي كامل
php artisan storage:link
```

- إن كانت القاعدة مبذورة من قبل فالبذر يتخطى المعهد التجريبي ويكتب تنبيهاً، ولا يسقط. ولقاعدة **نظيفة** (تمسح كل بياناتها) شغّل `php artisan migrate:fresh --seed`.
- إن ظهر «The [public/storage] link already exists» فهو سليم: الرابط موجود.
- إن ظهر تحذير «The lock file is not up to date» فقد صُحّح في المستودع (`composer update --lock`)؛ اسحب آخر نسخة.

في `.env` ضع عنوان الحاسوب بدل `localhost` (يظهر في الروابط والتنبيهات): `APP_URL=http://192.168.1.10:8000`.

### أ.3 التشغيل

```powershell
php artisan serve --host=0.0.0.0 --port=8000
php artisan queue:listen          # نافذة ثانية: الطابور (database)
```

`--host=0.0.0.0` هو ما يجعل الخادم مرئياً من الشبكة؛ بدونه يُقبل `localhost` وحده.

1. اعرف عنوان الحاسوب: `ipconfig` ثم عنوان IPv4 للمحوّل الفعّال (مثل `192.168.1.10`).
2. افتح المنفذ في جدار ويندوز (PowerShell كمدير):

   ```powershell
   New-NetFirewallRule -DisplayName "Nuzuln dev 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow -Profile Private
   ```

   وتأكد أن الشبكة معرَّفة «خاصة» (Private)، فقاعدة الجدار أعلاه لا تسري على الشبكات العامة.
3. جرّب من هاتف على الشبكة نفسها: افتح `http://192.168.1.10:8000` في المتصفح. تظهر الصفحة الرئيسية للموقع.
4. **لا إنترنت؟** فعّل نقطة اتصال (Mobile Hotspot) من إعدادات ويندوز وصِل الهواتف بها. عنوان الحاسوب عليها غالباً `192.168.137.1`، فاستعمله بدل عنوان الشبكة.

حسابات التجربة (من `DemoInstituteSeeder`، وكلمة المرور `password` للجميع):

| الدور | اسم المستخدم |
|---|---|
| مشرف المعهد | `admin1000` (أو `admin@mousqe.test`) |
| مشرف أعلى | `sadmin1000` |
| مبرمج | `dev1000` |

حسابات الأستاذ والطالب وولي الأمر مولَّدة في قاعدة البيانات؛ اعرضها من اللوحة (**بيانات الدخول**) أو من شاشة «بيانات الدخول» في برنامج المكتب.

### أ.4 ربط التطبيقات بالخادم المحلي

في أي تطبيق (الأستاذ، ولي الأمر، الطالب، المكتب):

1. افتح التطبيق، وعلى شاشة البدء **انقر الشعار ثلاث نقرات متتابعة**.
2. اختر **خادم محلّي**، واكتب العنوان بلا بروتوكول: `192.168.1.10:8000` (إن حذفتَ المنفذ فالمفترض `8000`).
3. اضغط **حفظ**. يتحقق التطبيق أن العنوان خادم نزلاً فعلاً (يسأل `GET /auth/me`) ويعرض سبب الرفض إن فشل.
4. تبديل الخادم **يُخرجك من حسابك ويمسح بيانات الجهاز المحلية**، لأن الرموز والمعرّفات من خادم لا يعرفه الآخر. فلا تبدّل والعمل غير مزامَن.

يسمح أندرويد بالاتصال غير المشفّر (`usesCleartextTraffic`) في تطبيقات الهاتف الأربعة؛ ويفعل برنامج المكتب في ويندوز ذلك دون إعداد.

### أ.5 مشاكل شائعة

- **الهاتف لا يصل:** غالباً الجدار أو شبكة «عامة» أو الهاتف على شبكة غير الحاسوب. اختبر بالمتصفح أولاً.
- **تغيّر عنوان الحاسوب:** يمنحه الراوتر عنواناً جديداً أحياناً. ثبّته من الراوتر (حجز DHCP) أو أعد إدخاله في التطبيق.
- **صفحات بلا تنسيق:** لم يُنفَّذ `npm run build`.

---

## ب. الخادم الرئيسي على Hostinger Cloud

> أسماء القوائم في hPanel تتغيّر بين الخطط والإصدارات؛ الخطوات أدناه على نمط Hostinger عموماً ولم أجرّبها على حسابك. تحقّق منها في لوحتك.

### ب.1 ما يلزم في الخطة

PHP 8.3 أو 8.4 (من hPanel: Websites ← Advanced ← PHP Configuration)، ووصول SSH، وقاعدة MySQL، وCron Jobs، وشهادة SSL للنطاق `nuzuln.com`، وإضافات PHP الافتراضية (`pdo_mysql` و`mbstring` و`openssl` و`curl` و`fileinfo` و`intl`).

### ب.2 التجهيز على جهازك

```powershell
cd backend
composer install --no-dev --optimize-autoloader
npm ci
npm run build                      # public/build غير مُتتبَّع في git: يُرفع يدوياً
```

### ب.3 قاعدة البيانات

أنشئ قاعدة MySQL ومستخدماً لها من hPanel (Databases ← MySQL) وسجّل: الاسم والمستخدم وكلمة المرور والمضيف (غالباً `localhost`).

### ب.4 الرفع وبنية المجلدات

1. ارفع محتوى `backend/` (من غير `node_modules` ولا `.env` ولا `database/*.sqlite`) إلى مجلد **خارج** المجلد العام، مثل `~/nuzuln/`، عبر Git على السيرفر (SSH) أو SFTP أو ضغط وفكّ.
2. ارفع `public/build` أيضاً (مبنياً من الخطوة ب.2).
3. اجعل **الجذر العام (document root) للنطاق = `~/nuzuln/public`**. إن لم تتح خطتك تغيير الجذر، فاترك المشروع خارج `public_html` وأنشئ رابطاً رمزياً: احذف محتوى `public_html` وأنشئ `ln -s ~/nuzuln/public ~/public_html` (أو انسخ محتوى `public` إليه وعدّل مسارات `index.php` إلى `../nuzuln/...`).
4. الصلاحيات: `storage` و`bootstrap/cache` قابلان للكتابة (`chmod -R 775`).

### ب.5 ملف البيئة `.env` على السيرفر

```ini
APP_NAME=نزلاً
APP_ENV=production
APP_DEBUG=false
APP_URL=https://nuzuln.com
APP_TIMEZONE=Asia/Damascus
APP_LOCALE=ar
APP_FALLBACK_LOCALE=ar

DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=<اسم القاعدة>
DB_USERNAME=<المستخدم>
DB_PASSWORD=<كلمة المرور>

SESSION_DRIVER=database
CACHE_STORE=database
QUEUE_CONNECTION=database

LOG_LEVEL=warning

# بريد حقيقي بدل log (استعادة كلمة المرور): بيانات SMTP من hPanel
MAIL_MAILER=smtp
MAIL_HOST=smtp.hostinger.com
MAIL_PORT=465
MAIL_USERNAME=<البريد>
MAIL_PASSWORD=<كلمة المرور>
MAIL_FROM_ADDRESS=<البريد>

# تنبيهات ولي الأمر (Firebase): مسار ملف حساب الخدمة، خارج المجلد العام
FIREBASE_CREDENTIALS=/home/<مستخدم>/nuzuln-secrets/firebase-credentials.json

# النسخ الاحتياطي الليلي: خارج المجلد العام
BACKUP_PATH=/home/<مستخدم>/nuzuln-backups
BACKUP_KEEP_DAYS=14

# بيانات التواصل في الصفحة الرئيسية (اختيارية؛ ما لم يُضبط لا يُعرض)
NUZULN_PHONE=
NUZULN_EMAIL=
```

### ب.6 أول تشغيل (عبر SSH داخل `~/nuzuln`)

```bash
php artisan key:generate --force
php artisan migrate --force
php artisan db:seed --class=RolesAndPermissionsSeeder --force   # الأدوار والصلاحيات
php artisan db:seed --class=CurriculumSeeder --force            # المناهج العامة: الأجزاء والحديث والمتون
php artisan db:seed --class=PersonalTraitSeeder --force         # الصفات الشخصية العامة
php artisan storage:link
php artisan config:cache && php artisan route:cache && php artisan view:cache
```

**لا تُشغّل `db:seed` كاملاً في الإنتاج**: يضيف المعهد التجريبي وحسابات كلمة مرورها `password`.

أنشئ أول مشرف أعلى بكلمة مرور قوية (من `php artisan tinker`):

```php
$u = App\Models\User::create([
    'username' => 'sadmin', 'first_name' => 'المشرف', 'last_name' => 'الأعلى',
    'email' => 'you@nuzuln.com', 'password' => Hash::make('<كلمة مرور قوية>'),
]);
$u->email_verified_at = now(); $u->save();
$u->assignGlobalRole('super_admin');
```

ثم من اللوحة أنشئ المعهد (**المعاهد ← إضافة**) والدورة والحلقات والحسابات — أو **استورده كاملاً** ببياناته القديمة
(`php artisan institute:import`) كما في [IMPORT.md](IMPORT.md).

### ب.7 المهام المجدولة والطابور (إلزامية)

لارافيل لا يوقظ نفسه. من hPanel ← Advanced ← **Cron Jobs** أضف مهمتين:

| التكرار | الأمر |
|---|---|
| كل دقيقة | `cd ~/nuzuln && php artisan schedule:run >> /dev/null 2>&1` |
| كل دقيقة | `cd ~/nuzuln && php artisan queue:work --stop-when-empty --max-time=55 >> /dev/null 2>&1` |

الأولى تشغّل **النسخ الاحتياطي الليلي** (الثانية صباحاً): بدونها لا يُكتب نسخ ولا يُرفع خطأ. والثانية تعالج الطابور بدل عامل دائم (غير متاح عادةً في هذه الخطط).

### ب.8 التحديث لاحقاً

```bash
# جهازك: npm run build ثم ارفع public/build
# السيرفر:
git pull   # أو ارفع الملفات
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:cache && php artisan route:cache && php artisan view:cache
```

### ب.9 التطبيقات

لا إعداد إضافي: العنوان الافتراضي المبني فيها هو `https://nuzuln.com/api/v1`. ولتجربة النسخة الجديدة على خادم آخر من دون إعادة بناء، استعمل ثلاث نقرات على الشعار (§أ.4).

---

## تصدير التطبيقات

```powershell
.\scripts\export-apps.ps1 -DryRun                       # ما الإصدار التالي؟
.\scripts\export-apps.ps1                               # بيتا جديدة لكل التطبيقات في dist/beta/<الإصدار>/
.\scripts\export-apps.ps1 -Channel release              # إصدار نهائي (من commit نظيف)
.\scripts\export-apps.ps1 -BaseUrl http://192.168.1.10:8000/api/v1   # يخبز عنواناً محلياً افتراضياً
.\scripts\export-apps.ps1 -SkipPubGet                   # حين يتعذر الوصول إلى pub.dev
```

> إن منع ويندوز تشغيل السكربت («running scripts is disabled») فشغّله بسياقٍ مؤقت لهذه النافذة فقط: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` ثم الأمر. ولتمرير ملاحظات عربية استعمل المتغيّر: `$notes = 'ملاحظة 1','ملاحظة 2'; .\scripts\export-apps.ps1 -Notes $notes`.
> يمرّ التصدير باختبارات كل تطبيق قبل بنائه، ولا يكتب في `VERSION.md` إن فشل أيّ بناء. أنشئ ملفات السجلّ خارج المستودع (أو التزم قبل التصدير) وإلا عُدَّ المستودع «غير نظيف».

الناتج في `dist/<القناة>/<الإصدار>/` (مثل `dist/beta/1.0.0-beta.5/`) فلا تتراكم الملفاتُ في `dist/`: حزمةُ APK لتطبيق «نزلاً» للهاتف (`mobile` ← `apps/nuzuln`، للأستاذ وولي الأمر والطالب) وأخرى للإدارة (`admin_android`)، ومجلد ويندوز مضغوط لبرنامج المكتب. وحتى تُحذف التطبيقات القديمة الثلاثة تخرج حزمُها أيضاً، فحدِّد `-Only mobile,admin_desktop,admin_android` لتجنّبها. وبرنامجُ الإدارة مشروعٌ واحد (`apps/admin_desktop`) يخرج منه ويندوز وأندرويد، فتُشغَّل اختباراتُه مرّةً واحدة. ويُسجَّل كل تصدير ناجح في [`VERSION.md`](VERSION.md). يلزم لبناء APK حزمة Android SDK (`flutter doctor`)، ولبناء ويندوز Visual Studio بحمل «Desktop development with C++».

**تثبيت APK على الهاتف:** انسخ الملف وافتحه (فعّل «تثبيت من مصادر غير معروفة» لتطبيق الملفات). التوقيع حالياً بمفتاح التصحيح (debug)؛ نشر المتجر يحتاج مفتاح توقيع خاصاً.
