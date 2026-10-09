"""Builds the launcher icons, the native splash mark and the Windows icon from the v3 identity.

Run from the repo root: python scripts/build-app-icons.py

Why the adaptive layers are drawn here and not copied from v3/identity/app-icons: the delivered
`android-adaptive-*-432.png` files are shifted 60px to the right (the mark's centre sits at x=276 of 432
and the background has a white 60px strip on the left), so the icon would look off-centre on a device.
The layers below are rebuilt from `nuzuln_v3_logo_transparent_2048.png` with the mark centred.
"""
import pathlib

from PIL import Image, ImageChops, ImageDraw

ROOT = pathlib.Path('.')
V3 = ROOT / 'v3'
NIGHT = (10, 36, 31)
GROUND_LIGHT = (27, 60, 53)
LOGO = Image.open(V3 / 'nuzuln_v3_logo_transparent_2048.png').convert('RGBA')
BBOX = LOGO.getbbox()
MARK = LOGO.crop(BBOX)

DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def centred_mark(canvas: int, mark_height: float, tint_white=False) -> Image.Image:
    """The mark centred on a transparent square canvas."""
    h = round(mark_height)
    w = round(MARK.width * h / MARK.height)
    mark = MARK.resize((w, h), Image.LANCZOS)
    if tint_white:
        alpha = mark.getchannel('A')
        mark = Image.merge('RGBA', (Image.new('L', mark.size, 255),) * 3 + (alpha,))
    out = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    out.alpha_composite(mark, ((canvas - w) // 2, (canvas - h) // 2))
    return out


def gradient(size: int) -> Image.Image:
    """The ground: night with the diagonal light of the logo, bright at the top-right."""
    g = Image.new('RGB', (size, size))
    px = g.load()
    for y in range(size):
        for x in range(size):
            t = max(0.0, min(1.0, ((x / size) + (1 - y / size)) / 2))  # 0 bottom-left .. 1 top-right
            t = t ** 2.2
            px[x, y] = tuple(round(NIGHT[i] + (GROUND_LIGHT[i] - NIGHT[i]) * t) for i in range(3))
    return g


def rounded(img: Image.Image, radius_ratio: float) -> Image.Image:
    img = img.convert('RGBA')
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius=round(img.width * radius_ratio), fill=255)
    img.putalpha(mask)
    return img


adaptive_fg = centred_mark(432, 432 * 0.46)  # inside the 66% safe zone
adaptive_mono = centred_mark(432, 432 * 0.46, tint_white=True)
adaptive_bg = gradient(432)
store = Image.open(V3 / 'identity/app-icons/ios-app-icon-1024.png').convert('RGB')

XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""

COLORS = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Brand ground (night, v3 tokens: color.night). The native splash and the adaptive icon ground. -->
    <color name="nuzuln_ground">#0A241F</color>
</resources>
"""

for app in ('teacher', 'guardian', 'student'):
    res = ROOT / 'apps' / app / 'android/app/src/main/res'
    for name, scale in DENSITIES.items():
        mip = res / f'mipmap-{name}'
        layer = round(108 * scale)
        adaptive_fg.resize((layer, layer), Image.LANCZOS).save(mip / 'ic_launcher_foreground.png')
        adaptive_mono.resize((layer, layer), Image.LANCZOS).save(mip / 'ic_launcher_monochrome.png')
        adaptive_bg.resize((layer, layer), Image.LANCZOS).save(mip / 'ic_launcher_background.png')
        legacy = round(48 * scale)
        rounded(store.resize((legacy, legacy), Image.LANCZOS), 0.2).save(mip / 'ic_launcher.png')
        # native splash mark (Android 11 and below): 128dp tall, the gradient mark on transparent
        h = round(128 * scale)
        w = round(MARK.width * h / MARK.height)
        (res / f'drawable-{name}').mkdir(exist_ok=True)
        MARK.resize((w, h), Image.LANCZOS).save(res / f'drawable-{name}' / 'launch_mark.png')
    (res / 'mipmap-anydpi-v26' / 'ic_launcher.xml').write_text(XML, encoding='utf-8')
    (res / 'values' / 'colors.xml').write_text(COLORS, encoding='utf-8')
    old = res / 'drawable' / 'ic_launcher_background.xml'
    if old.exists():
        old.unlink()
    print('android icons:', app)

# Windows app icon (the desktop supervisor program)
ico = ROOT / 'apps/admin_desktop/windows/runner/resources/app_icon.ico'
sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
store.save(ico, format='ICO', sizes=sizes)
print('windows icon:', ico)
