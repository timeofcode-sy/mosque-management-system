"""
يبني مصنّف الاستيراد لمعهد عمر الفاروق من مصدرين قديمين:

  1. نسخة احتياطية من برنامج الإدارة (*.mousqe-backup.sqlite) — المعهد والدوامات والحلقات
     والأساتذة والطلاب وأولياء أمورهم وتسجيلاتهم ومحفوظاتهم كما كانت على الخادم القديم.
  2. جدول التسجيل الورقي (sheet.xlsx) — بياناتٌ أغنى (الأم، الأرقام، العنوان، السكن، الحفظ)
     لطلابٍ بعضُهم في النظام وأكثرهم ليس فيه.

الناتج مصنّفٌ واحد بالبنية التي يقرؤها `php artisan institute:import` (انظر docs/IMPORT.md)،
وفيه ورقة «قرارات» تسرد كلَّ قرارٍ آليّ اتُّخذ — دمجُ مكرَّر، تصحيحُ إملاء، رقمٌ مرفوض،
استنتاجُ حلقة — سجلّاً لما جرى. الورقة لا يقرؤها الاستيراد.

قواعد الدمج:
  - الحقل الواحد: ما في النظام يغلب ما في الجدول إن كان صالحاً، والجدول يملأ الفراغ. إلا:
    تاريخ الولادة يُحسم بأغلبية المصادر (والتاريخ الكامل يغلب السنة وحدها)، وجوال الطالب في
    النظام إن كان رقمَ وليّ أمرٍ في الجدول حلّ محلّه رقمُ الطالب من الجدول.
  - المحفوظات اتّحادُ المصادر: الحفظ لا ينقص، فما ذكره أيٌّ منها محفوظ. والعددُ المنفرد في
    «الحفظ» («16»، «جزء 12») لا يُخترع منه حفظ: يبقى نصُّه في الملاحظات.
  - اسم الأب الكامل لا يُكتب: هو اسم الأب والكنية. واسم الأم يُقسم: الكلمة الأولى اسم والباقي كنية.
  - «رقم ولي الأمر» يصير جوال الأم إن اختلف عن رقم الأب، وجوال الأب إن طابقه أو غاب رقم الأب.
  - الإخوة (لا إخوة لأبٍ أو لأمٍّ في المعهد إلا بتقاطعٍ في أكثر من أمر):
      · أبٌ واحد وأمٌّ واحدة ⇐ أشقّاء.
      · أبٌ واحد وأمٌّ غائبة عن أحدهما ⇐ أشقّاء، إلا أن يُكتب للأبوين رقمان مختلفان فهما رجلان.
      · أبٌ واحد وأمّان مختلفتان ⇐ إخوةٌ لأب إن اشتركا في رقمٍ أو عنوان، وإلا رجلان باسمٍ واحد.
      · أمٌّ واحدة (بكنيتها) وأبوان مختلفان ⇐ إخوةٌ لأم إن اشتركا في رقمٍ أو عنوان.
  - الحلقة: تسجيل النظام أولاً، ثم عمود «الحلقة» في الجدول، ثم حلقة «أستاذ الجدول» إن كانت له حلقة
    واحدة. وأستاذ حلقةٍ بلا أستاذ يُستنتج إن اتّفق عليه اثنان فأكثر من طلابها ولم يخالف أحد.

الاستعمال:
    python -I scripts/import/build_omar_alfarouq.py "temp data/x.mousqe-backup.sqlite" "temp data/sheet.xlsx" "temp data/omar-alfarouq-import.xlsx"
"""

from __future__ import annotations

import datetime as dt
import json
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field

import openpyxl
from openpyxl.styles import Alignment, Font, PatternFill

# ------------------------------------------------------------------ تطبيع النصوص


def clean(value) -> str:
    """نصٌّ بفراغٍ واحد بين كلماته، وحرفٌ منفردٌ بعد كلمةٍ يُلصق بها («الزغلو ل» ← «الزغلول») — إلا واو العطف."""
    if value is None:
        return ''
    text = re.sub(r'\s+', ' ', str(value).replace('ـ', '')).strip()
    text = re.sub(r'([ء-ي]{2,}) ((?!و)[ء-ي])(?= |$)', r'\1\2', text)
    return text


def key(value) -> str:
    """مفتاح مطابقة لا يُخزَّن: الهمزات والتاء المربوطة والألف المقصورة موحّدة."""
    text = clean(value)
    for a, b in (('أ', 'ا'), ('إ', 'ا'), ('آ', 'ا'), ('ة', 'ه'), ('ى', 'ي')):
        text = text.replace(a, b)
    return text


# تصحيحاتٌ إملائية ظاهرة — كلُّ تطبيقٍ لها يُسجَّل في «قرارات».
SPELLING = {
    'عائسة': 'عائشة',
    'حذيقة': 'حذيفة',
    'بكلوريا': 'بكالوريا',
}

GRADES = {'10': 'عاشر', 'جامع': 'جامعي', 'خ': 'خامس', 'بكلوريا': 'بكالوريا'}

HOUSING = {'ملك': 'ملك', 'اجار': 'أجار', 'أجار': 'أجار', 'عائلي': 'عائلي', 'عيلة': 'عائلي', 'بيت العيلة': 'عائلي'}

SURAH_NAMES = {1: 'الفاتحة', 2: 'البقرة', 18: 'الكهف', 32: 'السجدة', 36: 'يس', 44: 'الدخان', 55: 'الرحمن',
               56: 'الواقعة', 67: 'الملك'}

# الأجزاء التي تقع فيها كلُّ سورةٍ منها: السورة في أجزاءٍ محفوظة كلِّها لا تُكتب ثانيةً.
SURAH_JUZ = {1: {1}, 2: {1, 2, 3}, 18: {15, 16}, 32: {21}, 36: {22, 23}, 44: {25}, 55: {27}, 56: {27}, 67: {29}}

WEEKDAYS = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت']

# كلمةٌ تسبق آخر كلمة فتجعل الكنية كلمتين: الشيخ حسن، عبد العال، أبو الليل…
FAMILY_PREFIXES = {'الشيخ', 'السيد', 'عبد', 'ابو', 'الحاج', 'ال'}

# أرقام بنود المناهج في الخادم القديم بترتيب CurriculumSeeder: 1-30 الأجزاء، ثم الحديث، ثم المتون.
OLD_ITEMS = {i: ('juz', i) for i in range(1, 31)}
OLD_ITEMS.update({
    31: ('other', 'الأربعون النبوية (1)'), 32: ('other', 'الأربعون النبوية (2)'),
    33: ('other', 'الأربعون النبوية (3)'), 34: ('other', 'مجامع الأنوار'),
    35: ('other', 'المنظومة البيقونية'), 36: ('other', 'اللامية'), 37: ('other', 'تحفة الأطفال'),
    38: ('other', 'عقيدة العوام'), 39: ('other', 'المقدمة الجزرية'), 40: ('other', 'جوهرة التوحيد'),
    41: ('other', 'الأرجوزة الميئية'),
})


class Log:
    def __init__(self):
        self.rows: list[tuple[str, str, str, str]] = []

    def add(self, ref: str, topic: str, decision: str, detail: str = ''):
        if (ref, topic, decision, detail) not in self.rows:
            self.rows.append((ref, topic, decision, detail))


log = Log()


def spell(text: str, ref: str, topic: str) -> str:
    fixed = text
    for wrong, right in SPELLING.items():
        fixed = re.sub(rf'(?<!\S){wrong}(?!\S)', right, fixed)
    if fixed != text:
        log.add(ref, topic, 'تصحيح إملائي', f'{text} ← {fixed}')
    return fixed


def split_person(full: str) -> tuple[str, str]:
    """اسم طالبٍ في الجدول («محمد نور عبد العال») إلى اسمٍ وكنية."""
    words = full.split(' ')
    if len(words) < 2:
        return full, ''
    cut = len(words) - 1
    if len(words) >= 3 and key(words[-2]) in FAMILY_PREFIXES:
        cut -= 1
    return ' '.join(words[:cut]), ' '.join(words[cut:])


def split_first(full: str) -> tuple[str, str]:
    """اسم الأم: الكلمة الأولى اسم والباقي كنية — القسمة نفسها في Guardian::splitName."""
    words = full.split(' ', 1)
    return words[0], (words[1] if len(words) > 1 else '')


def phone(value, ref: str, topic: str) -> str:
    if value is None:
        return ''
    raw = clean(value)
    digits = re.sub(r'\D', '', raw)
    if not digits:
        if raw:
            log.add(ref, topic, 'رقم مرفوض', raw)
        return ''
    if len(digits) == 9 and digits.startswith('9'):
        digits = '0' + digits
    if len(digits) == 10 and digits.startswith('09'):
        return digits
    if digits not in ('0', '9', '09'):
        log.add(ref, topic, 'رقم مرفوض (ليس جوالاً سورياً من 10 أرقام)', raw)
    return ''


def local_date(timestamp) -> str:
    """drift يحفظ التاريخ ثوانيَ منتصف ليلٍ محلي (دمشق +3)."""
    if timestamp is None:
        return ''
    return (dt.datetime(1970, 1, 1) + dt.timedelta(seconds=int(timestamp) + 3 * 3600)).date().isoformat()


def sheet_date(value, ref: str) -> str:
    if value is None or clean(value) == '':
        return ''
    if isinstance(value, dt.datetime):
        return value.date().isoformat()
    if isinstance(value, (int, float)) and 1950 < value < 2030:
        return f'{int(value)}-01-01'
    text = clean(value)
    match = re.fullmatch(r'(\d{1,2})/(\d{1,2})/(\d{4})', text)
    if match:
        day, month, year = map(int, match.groups())
        try:
            return dt.date(year, month, day).isoformat()
        except ValueError:
            log.add(ref, 'تاريخ الولادة', 'تاريخ غير موجود، أُبقيت السنة', text)
            return f'{year}-01-01'
    log.add(ref, 'تاريخ الولادة', 'تاريخ غير مفهوم، تُرك فارغاً', text)
    return ''


# ------------------------------------------------------------------ الحفظ النصّي

# الأطول أولاً: «تبارك» تُستهلك قبل أن تُجرَّب «تبار» (خطأٌ إملائيٌّ شائع في الجدول).
JUZ_WORDS = {'تبارك': 29, 'تبار': 29, 'قد سمع': 28, 'عم': 30, 'الاول': 1}

# سورٌ تُذكر بأسمائها في «الحفظ» — تُكتب سوراً محفوظة لا أجزاءً كاملة.
SURAH_WORDS = {
    'السبع المنجيات': {18, 32, 36, 44, 55, 56, 67},  # الكهف، السجدة، يس، الدخان، الرحمن، الواقعة، الملك
    'الى آل عمران': {1, 2},  # بلغ آل عمران: الفاتحة والبقرة
    'البقرة': {1, 2},  # ومن يحفظ البقرة يحفظ الفاتحة
}


def parse_hifz(text: str) -> tuple[set[int], set[int], bool]:
    """الأجزاء والسور من نص «الحفظ» في الجدول، وهل فُهم النصّ كلُّه.

    «عم و تبارك 1---4» ← الأجزاء 30، 29، 1-4. و«السبع المنجيات» سورها السبع. أما الرقم
    المنفرد («16»، «جزء 12»، «إجازة 5») فلا يُعرف أهو عددُ الأجزاء أم الجزءُ الذي بلغه.
    """
    norm = key(text).replace('+', ' ').replace('،', ' ')
    juz: set[int] = set()
    surahs: set[int] = set()
    for word, numbers in SURAH_WORDS.items():
        pattern = rf'(?<!\S)و?{key(word)}(?!\S)'
        if re.search(pattern, norm):
            surahs |= numbers
            norm = re.sub(pattern, ' ', norm)
    for word, number in JUZ_WORDS.items():
        pattern = rf'(?<!\S)و?{word}(?!\S)'
        if re.search(pattern, norm):
            juz.add(number)
            norm = re.sub(pattern, ' ', norm)
    for a, b in re.findall(r'(\d+)\s*[-.]{2,}\s*(\d+)', norm):
        low, high = sorted((int(a), int(b)))
        juz.update(range(low, high + 1))
    norm = re.sub(r'(\d+)\s*[-.]{2,}\s*(\d+)', ' ', norm)
    # تسلسلٌ مفصول بفواصل أو نقاط: «30-29-28-1-2» أو «30.29»
    singles = re.findall(r'\d+', norm)
    if singles and (len(singles) >= 2 or juz):
        juz.update(int(n) for n in singles)
        norm = re.sub(r'\d+', ' ', norm)
    rest = re.sub(r'(?<!\S)و(?!\S)', ' ', norm)
    rest = re.sub(r'[\s\-.]+', '', rest)
    juz = {n for n in juz if 1 <= n <= 30}
    return juz, surahs, rest == '' and bool(juz or surahs)


# ------------------------------------------------------------------ النماذج


@dataclass
class Person:
    ref: str
    first_name: str = ''
    father_name: str = ''
    family_name: str = ''
    gender: str = 'ذكر'
    birth_date: str = ''
    grade: str = ''
    job: str = ''
    phone: str = ''
    address: str = ''
    father_job: str = ''
    father_phone: str = ''
    father_dead: bool = False
    mother_first: str = ''
    mother_family: str = ''
    mother_job: str = ''
    mother_phone: str = ''
    circle: str = ''
    juz: set[int] = field(default_factory=set)
    surahs: set[int] = field(default_factory=set)
    others: list[str] = field(default_factory=list)
    housing: str = ''
    # نصوص «الحفظ» التي لم تُفهم كلُّها — تبقى في الملاحظات.
    hifz_unclear: list[str] = field(default_factory=list)
    sheet_teacher: str = ''
    notes: list[str] = field(default_factory=list)
    sources: list[str] = field(default_factory=list)
    db_id: int | None = None
    father_code: str = ''
    mother_code: str = ''
    # رقم الأب من عمود «رقم الأب» أو من النظام، لا رقم وليّ أمرٍ رُفع مكانه.
    father_phone_explicit: bool = False
    # أرقام الأهل كما وردت في الجدول — بها يُعرف جوال طالبٍ هو في الحقيقة رقم أهله.
    guardian_numbers: set[str] = field(default_factory=set)
    birth_candidates: list[str] = field(default_factory=list)
    # بياناتٌ مشكوكٌ فيها لا تُستعمل إلا إن لم يأتِ غيرها (أبٌ في النظام باسمٍ غير اسم أب الطالب).
    fallback: dict[str, str] = field(default_factory=dict)

    @property
    def full(self) -> str:
        return ' '.join(p for p in (self.first_name, self.father_name, self.family_name) if p)

    @property
    def father_key(self) -> str:
        """«عليوي» و«العليوي» كنيةٌ واحدة في مطابقة العائلة."""
        family = ' '.join(re.sub(r'^ال', '', w) for w in key(self.family_name).split())
        return key(f'{self.father_name} {family}')

    @property
    def mother_key(self) -> str:
        return key(f'{self.mother_first} {self.mother_family}')

    @property
    def father_unknown(self) -> bool:
        return len(key(self.father_name)) < 2 or key(self.father_name) == 'بن'

    def phones(self) -> set[str]:
        return {p for p in (self.father_phone, self.mother_phone) if p}

    def evidence(self, other: Person) -> list[str]:
        """ما يشترك فيه طالبان غير الاسم: رقمٌ لأحد الوالدين، أو العنوان، أو عمل الأب."""
        found = [f'رقم {p}' for p in sorted(self.phones() & other.phones())]
        if self.address and key(self.address) == key(other.address):
            found.append(f'العنوان {self.address}')
        job = lambda p: re.sub(r'^ب', '', key(p.father_job))  # noqa: E731 — «بمعمل خياطة» = «معمل خياطة»
        if self.father_job and job(self) == job(other):
            found.append(f'عمل الأب {self.father_job}')
        return found


LABELS = {
    'birth_date': 'تاريخ الولادة', 'grade': 'الصف', 'job': 'عمل الطالب', 'phone': 'جوال الطالب', 'address': 'العنوان',
    'father_job': 'عمل الأب', 'father_phone': 'جوال الأب', 'mother_first': 'اسم الأم', 'mother_family': 'كنية الأم',
    'mother_job': 'عمل الأم', 'mother_phone': 'جوال الأم', 'circle': 'الحلقة', 'housing': 'السكن',
}

FIELDS = ['grade', 'job', 'phone', 'address', 'father_job', 'father_phone',
          'mother_first', 'mother_family', 'mother_job', 'mother_phone', 'circle', 'housing']


def merge_into(base: Person, other: Person, label: str):
    """يملأ فراغ base من other، ويسجّل التعارض حيث امتلأ الاثنان واختلفا."""
    if base.phone and other.phone and base.phone != other.phone and base.phone in other.guardian_numbers:
        log.add(base.ref, 'جوال الطالب', 'رقمه في النظام رقمُ وليّ أمرٍ في الجدول — أُخذ رقم الطالب من الجدول',
                f'{base.phone} ← {other.phone}')
        base.phone = other.phone
    for name in FIELDS:
        mine, theirs = getattr(base, name), getattr(other, name)
        if not mine and theirs:
            setattr(base, name, theirs)
        elif mine and theirs and key(mine) != key(theirs):
            log.add(base.ref, LABELS[name], f'تعارض — أُبقي ما في {label}', f'{mine} ≠ {theirs}')
    for name, value in other.fallback.items():
        base.fallback.setdefault(name, value)
    base.birth_candidates += other.birth_candidates
    base.guardian_numbers |= other.guardian_numbers
    base.father_dead = base.father_dead or other.father_dead
    base.father_phone_explicit = base.father_phone_explicit or other.father_phone_explicit
    added = sorted(other.juz - base.juz), sorted(other.surahs - base.surahs)
    if base.db_id and (base.juz or base.surahs) and (added[0] or added[1]):
        log.add(base.ref, 'الحفظ', 'المحفوظات اتّحاد النظام والجدول — أُضيف ما في الجدول',
                '، '.join([*(f'جزء {n}' for n in added[0]), *(SURAH_NAMES[n] for n in added[1])]))
    base.juz |= other.juz
    base.surahs |= other.surahs
    base.others = list(dict.fromkeys(base.others + other.others))
    base.hifz_unclear += other.hifz_unclear
    base.sheet_teacher = base.sheet_teacher or other.sheet_teacher
    base.sources += other.sources


def resolve_birth(p: Person):
    """السنة بأغلبية المصادر (التعادل لأوّلها: النظام)، ثم التاريخ الكامل داخلها يغلب «السنة وحدها»."""
    candidates = [d for d in p.birth_candidates if d]
    if not candidates:
        p.birth_date = ''
        return
    years = Counter(d[:4] for d in candidates)
    year = max(years, key=lambda y: (years[y], -next(i for i, d in enumerate(candidates) if d[:4] == y)))
    precise = [d for d in candidates if d[:4] == year and not d.endswith('-01-01')]
    chosen = precise[0] if precise else f'{year}-01-01'
    if len(set(candidates)) > 1:
        log.add(p.ref, 'تاريخ الولادة', 'حُسم بأغلبية المصادر والتاريخ الأكمل',
                f'{" | ".join(dict.fromkeys(candidates))} ← {chosen}')
    p.birth_date = chosen


# ------------------------------------------------------------------ القراءة


def read_backup(path: str):
    db = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
    db.row_factory = sqlite3.Row
    q = lambda sql: db.execute(sql).fetchall()  # noqa: E731

    institute = q('select * from institutes')[0]
    course = q('select * from courses where is_current = 1')[0]

    shifts = []
    for s in q('select * from shifts order by sort_order, id'):
        days = sorted({r['weekday'] for r in q(f'select weekday from shift_days where shift_id = {s["id"]}')})
        shifts.append({'id': s['id'], 'name': clean(s['name']), 'starts': s['starts_at'], 'ends': s['ends_at'],
                       'order': s['sort_order'], 'days': days})

    teachers = {t['id']: {'name': clean(t['display_name']), 'phone': phone(t['phone'], clean(t['display_name']), 'جوال الأستاذ')}
                for t in q('select * from teachers order by id')}

    circles = {}
    for c in q('select * from circles order by sort_order, id'):
        circles[c['id']] = {'name': clean(c['name']), 'active': bool(c['is_active']), 'shift': '', 'capacity': '',
                            'teacher': '', 'order': c['sort_order']}
    course_circle_of = {}
    for cc in q('select * from course_circles'):
        circle = circles[cc['circle_id']]
        if not circle['active']:
            log.add(circle['name'], 'حلقة', 'حلقة موقوفة لا تُشغَّل في الدورة', 'مكرّرةٌ باسم حلقةٍ مفعّلة')
            continue
        circle['shift'] = next(s['name'] for s in shifts if s['id'] == cc['shift_id'])
        circle['capacity'] = cc['capacity'] or ''
        course_circle_of[cc['id']] = cc['circle_id']
    for t in q('select * from course_circle_teachers where left_on is null'):
        if t['course_circle_id'] in course_circle_of:
            circles[course_circle_of[t['course_circle_id']]]['teacher'] = teachers[t['teacher_id']]['name']

    enrollment = {e['student_id']: circles[course_circle_of[e['course_circle_id']]]['name']
                  for e in q("select * from enrollments where status = 'active'") if e['course_circle_id'] in course_circle_of}

    progress = defaultdict(list)
    for p in q("select * from student_curriculum_progress where status in ('memorized', 'mastered')"):
        progress[p['student_id']].append(p['curriculum_item_id'])

    guardians = defaultdict(dict)
    for g in q('select g.*, gs.relation, gs.student_id from guardians g join guardian_student gs on gs.guardian_id = g.id'):
        guardians[g['student_id']][g['relation']] = g

    custom_fields = [dict(f) for f in q('select * from custom_fields where is_active = 1 order by sort_order')]

    students = []
    for s in q('select * from students order by id'):
        ref = f'نظام #{s["id"]}'
        p = Person(ref=ref, db_id=s['id'], sources=[ref])
        p.first_name = spell(clean(s['first_name']), ref, 'الاسم')
        p.father_name = spell(clean(s['father_name']), ref, 'اسم الأب')
        p.family_name = spell(clean(s['family_name']), ref, 'الكنية')
        p.gender = 'أنثى' if s['gender'] == 'female' else 'ذكر'
        birth = local_date(s['birth_date'])
        if birth and not '1990' < birth < '2026':
            log.add(ref, 'تاريخ الولادة', 'تاريخ غير معقول، تُرك فارغاً', birth)
            birth = ''
        p.birth_candidates = [birth] if birth else []
        p.grade = grade(clean(s['grade_level']), ref)
        p.job = clean(s['student_job'])
        p.phone = phone(s['phone'], ref, 'جوال الطالب')
        p.address = clean(s['current_address'] or s['permanent_address'])
        if s['notes']:
            p.notes.append(clean(s['notes']))
        p.circle = enrollment.get(s['id'], '')

        for item in progress.get(s['id'], []):
            kind, value = OLD_ITEMS[item]
            if kind == 'juz':
                p.juz.add(value)
            else:
                p.others.append(value)

        father = guardians[s['id']].get('father')
        if father is not None:
            job = clean(father['occupation'])
            if 'متوفى' in job:
                p.father_dead = True
                job = clean(job.replace('متوفى', '').strip(' -'))
                log.add(ref, 'الأب', 'الأب متوفى (من عمله)', clean(father['occupation']))
            father_phone = phone(father['phone'], ref, 'جوال الأب')
            derived = f'{p.father_name} {p.family_name}'
            if key(father['full_name']) == key(derived):
                p.father_job, p.father_phone = job, father_phone
                p.father_phone_explicit = bool(father_phone)
            else:
                # سجلُّ أبٍ باسم رجلٍ آخر: عملُه ورقمه لا يُعتمدان إلا إن لم يأتِ غيرهما من الجدول.
                p.fallback = {'father_job': job, 'father_phone': father_phone}
                log.add(ref, 'اسم الأب', 'سجلّ الأب في النظام باسمٍ آخر — الاسم يُشتق من بيانات الطالب، '
                        'وعمله ورقمه احتياطٌ للجدول', f'{clean(father["full_name"])} ← {derived}')

        mother = guardians[s['id']].get('mother')
        if mother is not None:
            name = spell(clean(mother['full_name']), ref, 'اسم الأم')
            p.mother_first, p.mother_family = split_first(name)
            p.mother_job = clean(mother['occupation'])
            p.mother_phone = phone(mother['phone'], ref, 'جوال الأم')
            if not p.mother_family:
                log.add(ref, 'كنية الأم', 'كنية الأم غير معروفة — بقي اسمها وحده', name)

        students.append(p)

    return {
        'institute': dict(institute), 'course': dict(course), 'shifts': shifts, 'teachers': list(teachers.values()),
        'circles': list(circles.values()), 'students': students, 'custom_fields': custom_fields,
    }


def grade(value: str, ref: str) -> str:
    if not value:
        return ''
    if value in GRADES:
        log.add(ref, 'الصف', 'توحيد', f'{value} ← {GRADES[value]}')
        return GRADES[value]
    if not re.search(r'[؀-ۿ]', value) or value in ('القالش',):
        log.add(ref, 'الصف', 'قيمة ليست صفاً، تُركت فارغة', value)
        return ''
    return value


def read_sheet(path: str) -> list[Person]:
    sheet = openpyxl.load_workbook(path, data_only=True).worksheets[0]
    people = []
    for number, row in enumerate(sheet.iter_rows(min_row=2, values_only=True), start=2):
        (name, father, mother, grade_, job, birth, guardian_phone, father_phone, student_phone,
         hifz, address, housing, father_job, mother_job, circle, teacher) = (list(row) + [None] * 16)[:16]
        if not clean(name):
            continue
        ref = f'جدول سطر {number}'
        p = Person(ref=ref, sources=[ref])
        p.first_name, p.family_name = split_person(spell(clean(name), ref, 'الاسم'))
        father = spell(clean(father), ref, 'اسم الأب')
        if father.endswith(' ' + p.family_name) and father != p.family_name:
            log.add(ref, 'اسم الأب', 'حُذفت الكنية من اسم الأب', f'{father} ← {father[: -len(p.family_name) - 1]}')
            father = father[: -len(p.family_name) - 1]
        p.father_name = father
        mother = spell(clean(mother), ref, 'اسم الأم')
        if mother:
            p.mother_first, p.mother_family = split_first(mother)
            if not p.mother_family:
                log.add(ref, 'كنية الأم', 'كنية الأم غير معروفة — بقي اسمها وحده', mother)
        p.grade = grade(spell(clean(grade_), ref, 'الصف'), ref)
        p.job = clean(job)
        birth = sheet_date(birth, ref)
        p.birth_candidates = [birth] if birth else []
        p.phone = phone(student_phone, ref, 'جوال الطالب')

        father_written = clean(father_phone) not in ('', '0', '9')
        father_phone = phone(father_phone, ref, 'رقم الأب')
        guardian = phone(guardian_phone, ref, 'رقم ولي الأمر')
        # رقم ولي الأمر جوال الأم إلا أن يطابق رقم الأب أو يغيب رقم الأب أصلاً — أما رقم أبٍ
        # مكتوبٌ خطأً فلا يجعل رقم ولي الأمر رقمَه.
        if guardian and guardian != father_phone and (father_phone or father_written):
            p.mother_phone = guardian
        p.father_phone = father_phone or ('' if father_written else guardian)
        p.father_phone_explicit = bool(father_phone)
        p.guardian_numbers = {n for n in (father_phone, guardian) if n}

        p.address = clean(address)
        housing = clean(housing)
        if housing:
            p.housing = HOUSING.get(housing, housing)
            if p.housing not in HOUSING.values():
                log.add(ref, 'السكن', 'قيمةٌ خارج الخيارات — أُضيفت إلى خيارات الواصفة', housing)
        father_job = clean(father_job)
        if 'متوفى' in father_job:
            p.father_dead = True
            father_job = clean(father_job.replace('متوفى', ''))
        p.father_job = father_job
        p.mother_job = clean(mother_job)
        p.circle = spell(clean(circle), ref, 'الحلقة')
        p.sheet_teacher = clean(teacher) if clean(teacher) not in ('لم يحدد', '') else ''

        hifz = clean(hifz)
        if hifz:
            p.juz, p.surahs, understood = parse_hifz(hifz)
            if p.surahs:
                log.add(ref, 'الحفظ', 'سورٌ بأسمائها كُتبت سوراً محفوظة',
                        f'{hifz} ← {"، ".join(SURAH_NAMES[n] for n in sorted(p.surahs))}')
            if not understood:
                p.hifz_unclear.append(hifz)
                log.add(ref, 'الحفظ', 'لا يُعرف منه حفظٌ بعينه — بقي نصُّه في الملاحظات'
                        + (' وأُخذ منه ما فُهم' if p.juz else ''), f'{hifz} ← {", ".join(map(str, sorted(p.juz))) or "لا شيء"}')
        people.append(p)
    return people


# ------------------------------------------------------------------ الدمج


def same_student(a: Person, b: Person) -> str:
    """'' إن لم يتطابقا، وإلا 'exact' أو 'near' (اسمٌ أوّل أطول عند أحدهما)."""
    if key(a.family_name) != key(b.family_name) or key(a.father_name) != key(b.father_name):
        return ''
    first_a, first_b = key(a.first_name), key(b.first_name)
    if first_a == first_b:
        return 'exact'
    words_a, words_b = set(first_a.split()), set(first_b.split())
    if words_a < words_b or words_b < words_a:
        return 'near'
    return ''


def merge(system: list[Person], sheet: list[Person]) -> list[Person]:
    merged: list[Person] = []

    for p in system:
        twin = next((m for m in merged if same_student(m, p) == 'exact'), None)
        if twin is not None:
            log.add(p.ref, 'طالب مكرّر في النظام', f'دُمج مع {twin.ref}', p.full)
            merge_into(twin, p, 'السجلّ الأول')
            continue
        merged.append(p)

    # الأسطر الأكمل أولاً: الأقدم في الجدول تكرارٌ ناقص لمثيلٍ أكمل بعده.
    filled = lambda p: sum(bool(getattr(p, f)) for f in FIELDS)  # noqa: E731
    for p in sorted(sheet, key=filled, reverse=True):
        match = next(((m, kind) for m in merged for kind in [same_student(m, p)] if kind), None)
        if match is None:
            merged.append(p)
            continue
        target, kind = match
        if kind == 'near':
            log.add(p.ref, 'مطابقة تقريبية', f'عُدّ هو نفسه {target.ref}', f'{p.full} ≈ {target.full}')
        elif target.db_id is None:
            log.add(p.ref, 'سطر مكرّر في الجدول', f'دُمج مع {target.ref}', p.full)
        merge_into(target, p, 'النظام' if target.db_id else 'السطر الأكمل')

    for p in merged:
        resolve_birth(p)
        p.surahs = {n for n in p.surahs if not SURAH_JUZ[n] <= p.juz}
        for name, value in p.fallback.items():
            if value and not getattr(p, name):
                setattr(p, name, value)
                log.add(p.ref, LABELS[name], 'أُخذ من سجلّ الأب المشكوك فيه لغياب غيره', value)

    return merged


def assign_families(students: list[Person]):
    """سجلّا الأب والأم المشتركان بين الإخوة — والقواعد في رأس الملف.

    اتّحادان منفصلان: من يتشاركون الأب، ومن يتشاركون الأم؛ والأشقّاء في الاثنين معاً.
    ولا تجتمع في «أمٍّ» واحدة أمّان معروفتان مختلفتان.
    """
    father_of = {id(p): id(p) for p in students}
    mother_of = {id(p): id(p) for p in students}
    known_mothers = {id(p): ({p.mother_key} if p.mother_first else set()) for p in students}

    def find(uf: dict, x: int) -> int:
        while uf[x] != x:
            uf[x] = uf[uf[x]]
            x = uf[x]
        return x

    def join_father(a: Person, b: Person):
        father_of[find(father_of, id(a))] = find(father_of, id(b))

    def join_mother(a: Person, b: Person) -> bool:
        ra, rb = find(mother_of, id(a)), find(mother_of, id(b))
        if ra == rb:
            return True
        if len(known_mothers[ra] | known_mothers[rb]) > 1:
            return False
        mother_of[ra] = rb
        known_mothers[rb] |= known_mothers[ra]
        return True

    by_father = defaultdict(list)
    for p in students:
        if not p.father_unknown:
            by_father[p.father_key].append(p)
    pairs = [(a, b) for group in by_father.values() for i, a in enumerate(group) for b in group[i + 1:]]

    # ١. أبٌ واحد وأمٌّ واحدة: الاسمان تقاطعان كافيان.
    for a, b in pairs:
        if a.mother_first and b.mother_first and a.mother_key == b.mother_key:
            join_father(a, b)
            join_mother(a, b)

    # ٢. أمّان مختلفتان: أخٌ لأب بقرينةٍ أخرى، وإلا فرجلان باسمٍ واحد.
    for a, b in pairs:
        if a.mother_first and b.mother_first and a.mother_key != b.mother_key:
            found = a.evidence(b)
            if found:
                join_father(a, b)
                log.add(a.ref, 'عائلة', f'أخٌ لأب مع {b.ref}: أمّان مختلفتان، واشتركا في {"، ".join(found)}',
                        f'{a.full} · {b.full}')
            else:
                log.add(a.ref, 'عائلة', f'اسم أبٍ واحد مع {b.ref} وأمّان مختلفتان بلا قرينة — رجلان باسمٍ واحد',
                        f'{a.full} · {b.full}')

    # ٣. أمٌّ غائبة عن أحدهما: لا إخوة لأب في المعهد، فاسم الأب الكامل الواحد أخوّةٌ شقيقة —
    # إلا أن يُكتب للأبوين رقمان صريحان مختلفان، فهما رجلان. والأقوى قرينةً أولاً، فيلحق
    # من غابت أمّه بأشقّائه الأقرب إن تنازعته أمّان.
    def strength(pair):
        a, b = pair
        same_father_phone = a.father_phone_explicit and b.father_phone_explicit and a.father_phone == b.father_phone
        return not same_father_phone, -len(a.evidence(b))

    for a, b in sorted((pair for pair in pairs if not (pair[0].mother_first and pair[1].mother_first)), key=strength):
        if a.father_phone_explicit and b.father_phone_explicit and a.father_phone != b.father_phone:
            log.add(a.ref, 'عائلة', f'اسم أبٍ واحد مع {b.ref} برقمين مختلفين للأب — رجلان باسمٍ واحد',
                    f'{a.full} ({a.father_phone}) · {b.full} ({b.father_phone})')
            continue
        join_father(a, b)
        if not join_mother(a, b):
            log.add(a.ref, 'عائلة', f'أخٌ لأب مع {b.ref}: الأم معروفةٌ في أحد الطرفين وغيرها في الآخر',
                    f'{a.full} · {b.full}')

    # ٤. أمٌّ واحدة بكنيتها وأبوان مختلفان: أخٌ لأم بقرينةٍ أخرى.
    by_mother = defaultdict(list)
    for p in students:
        if p.mother_first and p.mother_family:
            by_mother[p.mother_key].append(p)
    for group in by_mother.values():
        for i, a in enumerate(group):
            for b in group[i + 1:]:
                found = a.evidence(b)
                if a.father_key != b.father_key and found and join_mother(a, b):
                    log.add(a.ref, 'عائلة', f'أخٌ لأم مع {b.ref}: اشتركا في {"، ".join(found)}', f'{a.full} · {b.full}')

    def groups(uf: dict) -> list[list[Person]]:
        members = defaultdict(list)
        for p in students:
            members[find(uf, id(p))].append(p)
        return [m for m in members.values() if len(m) > 1]

    def share(members: list[Person], fields: tuple[str, ...], prefer=None):
        """بيانات الوليّ واحدةٌ لكل من يتشاركونه: أوّل قيمةٍ غير فارغة."""
        for name in fields:
            ordered = sorted(members, key=prefer) if prefer else members
            values = [getattr(m, name) for m in ordered if getattr(m, name)]
            if len({key(v) for v in values}) > 1:
                log.add(members[0].ref, 'عائلة', f'{LABELS[name]} يختلف بين الإخوة — أُخذت الأولى',
                        ' | '.join(dict.fromkeys(values)))
            for m in members:
                mine = getattr(m, name)
                # الرقم الذي لا يبقى لا يضيع: يُحفظ في ملاحظات صاحبه.
                if name.endswith('_phone') and mine and values and mine != values[0]:
                    m.notes.append(f'رقمٌ آخر لولي الأمر: {mine}')
                setattr(m, name, values[0] if values else '')

    for number, members in enumerate(groups(father_of), start=1):
        # رقم الأب الصريح يغلب رقم وليّ أمرٍ رُفع مكانه.
        share(members, ('father_job', 'father_phone'), prefer=lambda m: not m.father_phone_explicit)
        spellings = Counter(m.family_name for m in members)
        if len(spellings) > 1:
            family = max(spellings, key=lambda name: (spellings[name], name.startswith('ال')))
            log.add(members[0].ref, 'الكنية', 'توحيد كنية الإخوة', ' | '.join(spellings) + f' ← {family}')
            for m in members:
                m.family_name = family
        dead = any(m.father_dead for m in members)
        for m in members:
            m.father_dead = dead
            m.father_code = f'أ{number:03d}'
        log.add(members[0].ref, 'عائلة', f'يتشاركون سجلّ الأب (أ{number:03d})', ' · '.join(m.full for m in members))

    # أمٌّ لا يُعرف اسمها عند أحدٍ من أبنائها لا سجلَّ لها يُتشارك.
    mothers = [members for members in groups(mother_of) if any(m.mother_first for m in members)]
    for number, members in enumerate(mothers, start=1):
        inherited = [m for m in members if not m.mother_first]
        share(members, ('mother_first', 'mother_family', 'mother_job', 'mother_phone'))
        for m in members:
            m.mother_code = f'م{number:03d}'
        for m in inherited:
            log.add(m.ref, 'عائلة', 'أمٌّ مستدلّة من أشقّائه', f'{m.mother_first} {m.mother_family}'.strip())
        log.add(members[0].ref, 'عائلة', f'يتشاركون سجلّ الأم (م{number:03d})', ' · '.join(m.full for m in members))


def place_in_circles(students: list[Person], circles: list[dict], teachers: list[dict]):
    by_name = {key(c['name']): c for c in circles}
    teacher_names = {key(t['name']): t for t in teachers}

    # أساتذة الجدول غير المعروفين في النظام يُضافون.
    for p in students:
        if p.sheet_teacher and key(p.sheet_teacher) not in teacher_names:
            t = {'name': p.sheet_teacher, 'phone': ''}
            teachers.append(t)
            teacher_names[key(t['name'])] = t
            log.add(p.ref, 'أستاذ', 'أستاذٌ من الجدول ليس في النظام — أُضيف', p.sheet_teacher)

    # حلقات الجدول غير الموجودة تُنشأ بأستاذها وبدوام صفّ طلابها.
    for p in students:
        if p.circle and key(p.circle) not in by_name and p.db_id is None:
            c = {'name': p.circle, 'active': True, 'shift': 'إعدادي', 'capacity': 15, 'teacher': p.sheet_teacher, 'order': 99}
            circles.append(c)
            by_name[key(c['name'])] = c
            log.add(p.ref, 'حلقة', 'حلقةٌ من الجدول ليست في النظام — أُنشئت (دوام إعدادي)', f'{c["name"]} · {p.sheet_teacher}')

    # أستاذ حلقةٍ بلا أستاذ: إن اتّفق عليه اثنان فأكثر من طلابها المسجّلين في النظام ولم يخالف أحد.
    for c in circles:
        if c['teacher'] or not c['shift']:
            continue
        named = Counter(key(p.sheet_teacher) for p in students if key(p.circle) == key(c['name']) and p.sheet_teacher)
        if len(named) == 1 and sum(named.values()) >= 2:
            c['teacher'] = teacher_names[next(iter(named))]['name']
            log.add(c['name'], 'أستاذ الحلقة', 'استُنتج من أستاذ طلابها في الجدول', f'{c["teacher"]} ({sum(named.values())} طلاب)')
        elif named:
            log.add(c['name'], 'أستاذ الحلقة', 'لا قرينة كافية — يُسنَد لاحقاً', ' | '.join(named))

    circles_of = defaultdict(list)
    for c in circles:
        if c['teacher'] and c['shift']:
            circles_of[key(c['teacher'])].append(c)

    for p in students:
        if p.circle:
            p.circle = by_name[key(p.circle)]['name']
            continue
        if not p.sheet_teacher:
            continue
        options = circles_of.get(key(p.sheet_teacher), [])
        if len(options) == 1:
            p.circle = options[0]['name']
            log.add(p.ref, 'تسجيل', 'سُجّل في حلقة أستاذه في الجدول', f'{p.sheet_teacher} ← {p.circle}')
        else:
            log.add(p.ref, 'تسجيل', 'بلا حلقة — يُسنَد لاحقاً: لأستاذه في الجدول ' + ('أكثر من حلقة' if options else 'لا حلقة في الدورة'),
                    p.sheet_teacher)

    for c in circles:
        count = sum(1 for p in students if p.circle == c['name'])
        if c['capacity'] and count > int(c['capacity']):
            log.add(c['name'], 'طاقة الحلقة', 'رُفعت لتسع طلابها', f'{c["capacity"]} ← {count}')
            c['capacity'] = count


# ------------------------------------------------------------------ الكتابة

HEADER_FILL = PatternFill('solid', fgColor='7D0A0A')
HEADER_FONT = Font(bold=True, color='FFFFFF')


def write_sheet(book, title: str, headers: list[str], rows: list[list], widths: dict[int, int] | None = None):
    ws = book.create_sheet(title)
    ws.sheet_view.rightToLeft = True
    ws.append(headers)
    for cell in ws[1]:
        cell.fill, cell.font = HEADER_FILL, HEADER_FONT
        cell.alignment = Alignment(horizontal='center', vertical='center', wrap_text=True)
    for row in rows:
        ws.append(['' if v is None else str(v) for v in row])
    for row in ws.iter_rows(min_row=2):
        for cell in row:
            cell.number_format = '@'
    for index, header in enumerate(headers, start=1):
        width = (widths or {}).get(index) or max(12, min(40, max(len(str(r[index - 1])) for r in [headers, *rows]) + 2))
        ws.column_dimensions[openpyxl.utils.get_column_letter(index)].width = width
    ws.freeze_panes = 'B2'
    ws.auto_filter.ref = ws.dimensions


def write(path: str, data: dict, students: list[Person]):
    book = openpyxl.Workbook()
    book.remove(book.active)

    institute, course = data['institute'], data['course']
    settings = json.loads(institute['settings'] or '{}')
    write_sheet(book, 'المعهد', ['البند', 'القيمة'], [
        ['الاسم', clean(institute['name'])],
        ['الاسم المختصر', clean(institute['short_name'])],
        ['الدورة', clean(course['name'])],
        ['بداية الدورة', local_date(course['starts_on'])],
        ['نهاية الدورة', local_date(course['ends_on'])],
        ['الإعدادات', json.dumps(settings, ensure_ascii=False)],
    ], {1: 18, 2: 60})

    write_sheet(book, 'الدوامات', ['الدوام', 'البداية', 'النهاية', 'الترتيب', 'الأيام'], [
        [s['name'], s['starts'], s['ends'], s['order'], '، '.join(WEEKDAYS[d] for d in s['days'])] for s in data['shifts']
    ])

    write_sheet(book, 'الأساتذة', ['الاسم', 'الجوال'], [[t['name'], t['phone']] for t in data['teachers']])

    write_sheet(book, 'الحلقات', ['الحلقة', 'الدوام', 'الأستاذ', 'الطاقة', 'مفعّلة', 'الترتيب'], [
        [c['name'], c['shift'], c['teacher'], c['capacity'], 'نعم' if c['active'] else 'لا', c['order']]
        for c in sorted(data['circles'], key=lambda c: (not c['active'], c['order']))
    ])

    fields = data['custom_fields']
    housing_label = next((clean(f['label']) for f in fields if clean(f['label']) == 'السكن'), 'السكن')
    field_rows = []
    for f in fields:
        options = json.loads(f['options'] or '[]')
        if clean(f['label']) == housing_label:
            # ما ورد من سكنٍ خارج الخيارات («استضافة») حالةٌ حقيقية: يُضاف خياراً.
            options += sorted({p.housing for p in students if p.housing and p.housing not in options})
        group = clean(f['group']).replace('العئلية', 'العائلية')
        if group != clean(f['group']):
            log.add(clean(f['label']), 'مجموعة الواصفة', 'تصحيح إملائي', f'{clean(f["group"])} ← {group}')
        field_rows.append([clean(f['label']), f['key'], f['type'], '، '.join(options), group, 'نعم' if f['is_required'] else 'لا'])
    write_sheet(book, 'الواصفات', ['العنوان', 'المفتاح', 'النوع', 'الخيارات', 'المجموعة', 'مطلوبة'], field_rows)

    for p in students:
        if p.father_unknown:
            log.add(p.ref, 'اسم الأب', 'اسم الأب غير معروف — بقي كما كُتب ولا يُنشأ له وليّ أمر', p.full)
        if p.mother_phone and not p.mother_first:
            # لا تُنشأ أمٌّ بلا اسم، فيبقى الرقم في الملاحظات لا يضيع.
            p.notes.append(f'رقم ولي الأمر: {p.mother_phone}')
            log.add(p.ref, 'جوال الأم', 'رقمٌ بلا اسم أم — نُقل إلى الملاحظات', p.mother_phone)
            p.mother_phone = ''

    students = sorted(students, key=lambda p: (p.circle == '', p.circle, p.family_name, p.first_name))
    rows = []
    for number, p in enumerate(students, start=1):
        notes = list(p.notes) + [f'الحفظ في جدول التسجيل: {text}' for text in dict.fromkeys(p.hifz_unclear)]
        rows.append([
            f'ط{number:03d}', p.first_name, p.father_name, p.family_name, p.gender, p.birth_date, p.grade, p.job,
            p.phone, p.address, p.father_code, p.father_job, p.father_phone, 'نعم' if p.father_dead else '',
            p.mother_code, p.mother_first, p.mother_family, p.mother_job, p.mother_phone, p.circle,
            '، '.join(map(str, sorted(p.juz, reverse=True))), '، '.join(SURAH_NAMES[n] for n in sorted(p.surahs)),
            '، '.join(dict.fromkeys(p.others)), p.housing, ' — '.join(notes), p.sheet_teacher, ' + '.join(p.sources),
        ])
    write_sheet(book, 'الطلاب', [
        'المرجع', 'الاسم', 'اسم الأب', 'الكنية', 'الجنس', 'تاريخ الولادة', 'الصف', 'عمل الطالب', 'جوال الطالب',
        'العنوان', 'رمز الأب', 'عمل الأب', 'جوال الأب', 'الأب متوفى', 'رمز الأم', 'اسم الأم', 'كنية الأم', 'عمل الأم',
        'جوال الأم', 'الحلقة', 'الأجزاء المحفوظة', 'السور المحفوظة', 'محفوظات أخرى', housing_label, 'ملاحظات',
        'أستاذ الجدول', 'المصدر',
    ], rows, {25: 40, 27: 26})

    write_sheet(book, 'قرارات', ['المرجع', 'الموضوع', 'القرار', 'التفصيل'],
                [list(r) for r in log.rows], {1: 18, 2: 22, 3: 52, 4: 60})

    book.save(path)


def main(backup: str, sheet: str, output: str):
    data = read_backup(backup)
    students = merge(data['students'], read_sheet(sheet))
    assign_families(students)
    place_in_circles(students, data['circles'], data['teachers'])
    write(output, data, students)

    enrolled = sum(1 for p in students if p.circle)
    print(f'{len(students)} طالباً ({enrolled} في حلقات) · {len(data["teachers"])} أستاذاً · '
          f'{len(data["circles"])} حلقة · {len(log.rows)} قراراً في ورقة «قرارات»')
    print(f'كُتب: {output}')


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
