# نزلاً (Nuzuln) — نظام إدارة معهد تحفيظ القرآن

<img src="design/logo/nuzuln-icon.svg" alt="نزلاً" width="96" />

مستودع موحّد يضم الباك إند (Laravel 13 + Livewire 4) وأربعة تطبيقات Flutter تعمل على **نموذج بيانات واحد**،
مع تفقّد يُسجَّل أوف-لاين ويتزامن دون فقدان بيانات.

## البنية

| المسار | المحتوى |
|---|---|
| `backend/` | Laravel 13 · Livewire 4 · Flux · Fortify · Spatie Permission — لوحة التحكم + API |
| `apps/teacher/` | تطبيق الأستاذ (Android/iOS) — التفقّد أوف-لاين |
| `apps/admin_desktop/` | برنامج المشرف (Windows) — إدارة كاملة أوف-لاين |
| `apps/guardian/` | تطبيق أولياء الأمور |
| `apps/student/` | تطبيق الطالب |
| `packages/mousqe_core/` | نماذج + drift(SQLite) + محرك المزامنة + عميل API |
| `packages/mousqe_ui/` | نظام التصميم: ألوان، خط كوفي، ويدجتس، RTL |
| `design/design-tokens.json` | **مصدر واحد للهوية البصرية** — يُستهلك من Tailwind ومن Flutter |
| `design/logo/` | الشعار: الأصل، والعلامة الشفافة (PNG/SVG)، وأيقونة البلاطة — ومنها تُولَّد أيقونات التطبيقات والموقع |
| `docs/` | `PLAN.md` (الخطة وسجل تغييراتها) · `ERD.md` (نموذج البيانات) · `CHECKPOINT-PHASE-*.MD` (نقطة تفتيش لكل مرحلة منفَّذة) |

## البدء

```bash
# الباك إند
cd backend
composer install && npm install
php artisan migrate:fresh --seed
composer run dev            # serve + queue + vite

# تطبيقات فلاتر
melos bootstrap
melos run test
```

## التحقق قبل أي إنهاء

```bash
cd backend
php artisan test --compact
vendor/bin/pint --dirty --format agent
```

انظر `docs/PLAN.md` للخطة وحالتها، و`docs/ERD.md` لنموذج البيانات، وآخر نقطة تفتيش لتفاصيل ما نُفِّذ.
