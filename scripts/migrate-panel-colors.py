"""One-off migration: legacy Tailwind palette classes -> Nuzuln v3 semantic tokens (see backend/resources/css/app.css).

Run from the repo root: python scripts/migrate-panel-colors.py
Safe to re-run: every rule is idempotent.
"""
import pathlib
import re

ROOT = pathlib.Path('backend/resources/views')
SKIP = ('welcome.blade.php', 'layouts/auth', 'flux/', 'layouts/app/header.blade.php', 'layouts/app/sidebar.blade.php')

# order matters: more specific first
LIGHT = [
    (r'\bhover:bg-sand-50\b', 'hover:bg-sunken'),
    (r'\bhover:bg-brand-50\b', 'hover:bg-sunken'),
    (r'\bhover:bg-brand-700\b', 'hover:bg-primary-hover'),
    (r'\bhover:text-brand-\d+\b', 'hover:text-primary'),
    (r'\bborder-(?:sand-(?:100|200|300|400)|zinc-(?:200|300))\b', 'border-line'),
    (r'\bdivide-(?:sand-\d+|zinc-200)\b', 'divide-line'),
    (r'\bborder-ink-900/40\b', 'border-ink/40'),
    (r'\bborder-brand-600\b', 'border-primary'),
    (r'\bbg-white\b(?![/-])', 'bg-raised'),
    (r'\bbg-sand-50\b', 'bg-surface'),
    (r'\bbg-sand-(?:100|200)\b', 'bg-sunken'),
    (r'\bbg-zinc-(?:50|100|200)\b', 'bg-sunken'),
    (r'\btext-ink-(?:400|500)\b', 'text-muted'),
    (r'\btext-ink-(?:700|900)\b', 'text-ink'),
    (r'\btext-zinc-(?:400|500)\b', 'text-muted'),
    (r'\btext-zinc-800\b', 'text-ink'),
    (r'\btext-brand-(?:500|600|700)\b', 'text-primary'),
    (r'\btext-gold-(?:500|600|700)\b', 'text-bronze-ink'),
    (r'\btext-red-(?:500|600)\b', 'text-danger'),
    (r'\btext-green-(?:500|600)\b', 'text-success'),
    (r'\bbg-brand-(?:500|600|700)\b', 'bg-primary'),
    (r'\bstroke-brand-\d+\b', 'stroke-primary'),
    (r'\bstroke-sand-\d+\b', 'stroke-line'),
    (r'\bfill-brand-500/10\b', 'fill-primary/10'),
    (r'\bfill-white\b', 'fill-raised'),
]

# dark: variants that the semantic tokens now cover on their own
DARK = [
    r'\s*\bdark:border-(?:zinc-(?:600|700|800)|stone-(?:600|700|800))\b',
    r'\s*\bdark:bg-zinc-(?:700|800|900)(?:/\d+)?\b',
    r'\s*\bdark:text-zinc-(?:100|200|400|500)\b',
    r'\s*\bdark:text-(?:brand-300|gold-400|red-400|green-400)\b',
    r'\s*\bdark:stroke-(?:brand-\d+|zinc-\d+)\b',
    r'\s*\bdark:fill-zinc-\d+\b',
    r'\s*\bdark:divide-(?:zinc|stone)-\d+\b',
    r'\s*\bdark:hover:bg-zinc-800\b',
    r'\s*\bdark:text-white/80\b',
]

changed = 0
for path in ROOT.rglob('*.blade.php'):
    rel = path.as_posix().split('resources/views/')[1]
    if any(rel.startswith(s) or s in rel for s in SKIP):
        continue
    text = path.read_text(encoding='utf-8')
    new = text
    for pattern, repl in LIGHT:
        new = re.sub(pattern, repl, new)
    for pattern in DARK:
        new = re.sub(pattern, '', new)
    new = re.sub(r'(class="[^"]*?)[ ]{2,}', r'\1 ', new)
    if new != text:
        path.write_text(new, encoding='utf-8')
        changed += 1
print('files changed:', changed)
