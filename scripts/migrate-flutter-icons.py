"""One-off migration: Material `Icons.x` -> the Nuzulan icon set (`NzIcons.y`), see packages/nuzul_ui.

Run from the repo root: python scripts/migrate-flutter-icons.py
Also rewrites `Icon(Icons.x ...)` to `NzIcon(NzIcons.y ...)` and the few `IconData` typed fields to `String`.
"""
import pathlib
import re

MAP = {
    'lock_outline': 'lockClosed', 'lock': 'lockClosed', 'lock_open_outlined': 'lockOpen',
    'refresh': 'review', 'sync': 'review', 'cloud_sync_outlined': 'review', 'swap_horiz': 'review', 'swap_horiz_outlined': 'review',
    'edit_outlined': 'edit', 'edit_note': 'edit', 'edit_calendar_outlined': 'edit',
    'star_outline': 'star', 'groups_2_outlined': 'halaqa', 'groups_outlined': 'students', 'co_present_outlined': 'students',
    'person_search_outlined': 'students', 'chevron_left': 'chevronLeft', 'chevron_right': 'back', 'expand_more': 'chevronDown',
    'arrow_drop_down': 'chevronDown', 'unfold_more': 'chevronsUpDown', 'percent': 'percent', 'logout': 'logout',
    'cloud_upload_outlined': 'upload', 'cloud_done_outlined': 'checkCircle', 'cloud_off_outlined': 'offline', 'wifi_off_outlined': 'offline',
    'search': 'search', 'search_off_outlined': 'search', 'school_outlined': 'certificate', 'save_outlined': 'save', 'save_alt_outlined': 'save',
    'person_outline': 'user', 'account_circle_outlined': 'user', 'menu_book_outlined': 'mushaf', 'record_voice_over_outlined': 'mushaf',
    'history_edu_outlined': 'note', 'fact_check_outlined': 'attendance', 'rule_folder_outlined': 'attendance',
    'sticky_note_2_outlined': 'note', 'schedule': 'clock', 'schedule_outlined': 'clock', 'timer_outlined': 'clock', 'history': 'clock',
    'radio_button_unchecked': 'radioOff', 'radio_button_checked': 'radioOn', 'event_outlined': 'calendar', 'event': 'calendar',
    'calendar_today_outlined': 'calendar', 'calendar_month_outlined': 'calendar', 'date_range_outlined': 'calendar',
    'event_note_outlined': 'calendar', 'event_busy_outlined': 'calendar', 'event_available_outlined': 'calendar',
    'error_outline': 'exclamationCircle', 'apartment_outlined': 'mosque', 'add_business_outlined': 'mosque',
    'print_outlined': 'printer', 'person_off_outlined': 'userMinus', 'person_add_alt_1_outlined': 'userPlus',
    'more_horiz': 'more', 'mark_email_read_outlined': 'envelopeOpen', 'key_outlined': 'key', 'password_outlined': 'key',
    'help_outline': 'informationCircle', 'delete_outline': 'trash', 'copy': 'copy', 'close': 'close', 'clear': 'close',
    'check_circle_outline': 'checkCircle', 'badge_outlined': 'badge', 'add': 'plus', 'visibility_outlined': 'eye',
    'visibility_off_outlined': 'eyeSlash', 'tune_outlined': 'settings', 'construction_outlined': 'settings',
    'space_dashboard_outlined': 'grid', 'smartphone_outlined': 'phone', 'send_outlined': 'send', 'report_outlined': 'warning',
    'playlist_add': 'plus', 'leaderboard_outlined': 'reports', 'inventory_2_outlined': 'archive', 'inbox_outlined': 'archive',
    'image_outlined': 'image', 'filter_alt_off_outlined': 'funnel', 'done_all': 'check', 'check': 'check',
    'dns_outlined': 'server', 'campaign_outlined': 'megaphone', 'block': 'xCircle', 'arrow_forward': 'arrowRight',
    'add_moderator_outlined': 'shield', 'home_outlined': 'home', 'how_to_reg_outlined': 'attendance',
}

ROOTS = ['apps/admin_desktop/lib', 'apps/guardian/lib', 'apps/student/lib', 'apps/teacher/lib', 'packages/mousqe_ui/lib']
missing = set()

for root in ROOTS:
    for path in pathlib.Path(root).rglob('*.dart'):
        text = path.read_text(encoding='utf-8')
        new = text

        def repl(m):
            name = m.group(1)
            if name not in MAP:
                missing.add(name)
                return m.group(0)
            return 'NzIcons.' + MAP[name]

        new = re.sub(r'\bIcons\.([a-z0-9_]+)', repl, new)
        new = re.sub(r'\bIcon\(\s*NzIcons\.', 'NzIcon(NzIcons.', new)
        new = re.sub(r'\bIconData\b', 'String', new)
        if new != text:
            if 'package:nuzul_ui/nuzul_ui.dart' not in new and 'package:mousqe_ui/mousqe_ui.dart' not in new and not root.startswith('packages/mousqe_ui'):
                new = new.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:mousqe_ui/mousqe_ui.dart';", 1)
            if root.startswith('packages/mousqe_ui') and 'package:nuzul_ui/nuzul_ui.dart' not in new:
                new = new.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:nuzul_ui/nuzul_ui.dart';", 1)
            path.write_text(new, encoding='utf-8')
            print('migrated', path.as_posix())

print('unmapped:', sorted(missing))
