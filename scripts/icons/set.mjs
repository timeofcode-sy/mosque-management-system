// The Nuzulan icon set: the 20 icons of the v3 identity plus extras drawn by the same rules.
// Rules (v3 README): 24px grid, 2px stroke, miter joins, square caps, only 0/35/45/90 degree lines,
// no curves (the crescent in `moon` is the single exception, as in the logo).
// `paths` are stroked, `solid` paths are filled. Commands: M L H V Z (absolute and relative) plus A for the moon.
import { readFileSync } from 'node:fs';

const v3 = (name) => {
  const svg = readFileSync(`v3/identity/icons/icon-${name}.svg`, 'utf8');
  const inner = svg.replace(/<svg[^>]*>/, '').replace(/<\/svg>/, '').replace(/<title>[^<]*<\/title>/, '');
  const paths = [];
  const solid = [];
  for (const m of inner.matchAll(/<path d="([^"]+)"([^>]*)\/>/g)) {
    (m[2].includes('fill="#0A241F"') ? solid : paths).push(m[1]);
  }
  return { paths, solid };
};

const base = Object.fromEntries(
  ['home', 'halaqa', 'students', 'attendance', 'mushaf', 'review', 'calendar', 'reports', 'bell', 'settings',
    'certificate', 'mosque', 'clock', 'note', 'star', 'check', 'close', 'plus', 'search', 'back'].map((n) => [n, v3(n)]),
);

const hex = 'M12 3l7.5 5.25v7.5L12 21l-7.5-5.25v-7.5z';

export const icons = {
  ...base,
  menu: { paths: ['M4 8.5H20M4 15.5H20'] },
  trend: { paths: ['M3 20.5h18', 'M4.5 16l5-5 3.5 3.5 6.5-8'] },
  'chevron-left': { paths: ['M14.5 4.5 9 12l5.5 7.5'] },
  'chevron-down': { paths: ['M4.5 9.5 12 15l7.5-5.5'] },
  'chevron-up': { paths: ['M4.5 14.5 12 9l7.5 5.5'] },
  'chevrons-up-down': { paths: ['M8 9.5l4-4 4 4M8 14.5l4 4 4-4'] },
  more: { paths: [], solid: ['M4 10.5h3v3H4z', 'M10.5 10.5h3v3h-3z', 'M17 10.5h3v3h-3z'] },
  'more-vertical': { paths: [], solid: ['M10.5 4h3v3h-3z', 'M10.5 10.5h3v3h-3z', 'M10.5 17h3v3h-3z'] },
  edit: { paths: ['M4 20v-3.5L16 4.5l3.5 3.5-12 12z', 'M13 7.5l3.5 3.5'] },
  trash: { paths: ['M4 6.5h16', 'M9.5 6.5V4h5v2.5', 'M6.5 6.5v14h11v-14', 'M10 10.5v6M14 10.5v6'] },
  key: { paths: ['M8 3.5l4 4-4 4-4-4z', 'M10.8 10.3 20.5 20', 'M16.5 16l2.5-2.5M13.5 13l2-2'] },
  printer: { paths: ['M6.5 9V3.5h11V9', 'M6.5 17.5h-3V9h17v8.5h-3', 'M6.5 14h11v6.5h-11z'] },
  'lock-closed': { paths: ['M5 10.5h14v10H5z', 'M8 10.5V7l2.5-2.5h3L16 7v3.5', 'M12 14v3'] },
  'lock-open': { paths: ['M5 10.5h14v10H5z', 'M8 10.5V7l2.5-2.5h3L16 7v1.5', 'M12 14v3'] },
  'arrow-right': { paths: ['M4 12h16', 'M13.5 5.5 20 12l-6.5 6.5'] },
  'arrow-left': { paths: ['M20 12H4', 'M10.5 5.5 4 12l6.5 6.5'] },
  'arrow-up': { paths: ['M12 20.5v-16', 'M6.5 10 12 4.5l5.5 5.5'] },
  'arrow-down': { paths: ['M12 3.5v16', 'M6.5 14 12 19.5l5.5-5.5'] },
  download: { paths: ['M12 3.5v12', 'M7 10.5l5 5 5-5', 'M4 20.5h16'] },
  upload: { paths: ['M12 15.5v-12', 'M7 8.5l5-5 5 5', 'M4 20.5h16'] },
  eye: { paths: ['M2.5 12 8.9 7.5h6.2l6.4 4.5-6.4 4.5H8.9z'], solid: ['M12 9.9l2.1 2.1-2.1 2.1-2.1-2.1z'] },
  'eye-slash': { paths: ['M2.5 12 8.9 7.5h6.2l6.4 4.5-6.4 4.5H8.9z', 'M4.5 19.5l15-15'] },
  warning: { paths: ['M12 2.5 21.5 12 12 21.5 2.5 12z', 'M12 7.5v6', 'M12 16.5v.5'] },
  'exclamation-circle': { paths: [hex, 'M12 7.5v5', 'M12 15.5v.5'] },
  'information-circle': { paths: [hex, 'M12 11v5', 'M12 8v.5'] },
  'check-circle': { paths: [hex, 'M8.5 12.5l2.5 2.5 4.5-5'] },
  'x-circle': { paths: [hex, 'M9 9l6 6M15 9l-6 6'] },
  copy: { paths: ['M9 9V3.5h11.5V15H15', 'M3.5 9H15v11.5H3.5z'] },
  badge: { paths: ['M3 5.5h18v13H3z', 'M7 10.5h4M7 14h6', 'M15 9.5h3v4h-3z'] },
  undo: { paths: ['M8 4.5 4 8.5l4 4', 'M4 8.5h11.5L20 13v6'] },
  logout: { paths: ['M10 4.5H4.5v15H10', 'M9 12h11', 'M15.5 7.5 20 12l-4.5 4.5'] },
  login: { paths: ['M14 4.5h5.5v15H14', 'M15 12H4', 'M8.5 7.5 4 12l4.5 4.5'] },
  user: { paths: ['M12 3.5 15 6.5 12 9.5 9 6.5z', 'M5 20.5v-3l3.5-2.5h7l3.5 2.5v3'] },
  'user-plus': { paths: ['M9 3.5l3 3-3 3-3-3z', 'M3 20.5v-3L6.5 15h5l3.5 2.5v3', 'M18 9v6M15 12h6'] },
  'user-minus': { paths: ['M9 3.5l3 3-3 3-3-3z', 'M3 20.5v-3L6.5 15h5l3.5 2.5v3', 'M15 12h6'] },
  sun: { paths: ['M12 8l4 4-4 4-4-4z', 'M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3', 'M5.3 5.3l2 2M16.7 16.7l2 2M18.7 5.3l-2 2M7.3 16.7l-2 2'] },
  moon: { paths: ['M17.5 17.7A8.5 8.5 0 1 1 9.5 3.5 6.8 6.8 0 1 0 17.5 17.7Z'] },
  desktop: { paths: ['M3 4.5h18v12H3z', 'M12 16.5v4', 'M8 20.5h8'] },
  phone: { paths: ['M7 2.5h10v19H7z', 'M10.5 18.5h3'] },
  'qr-code': { paths: ['M3.5 3.5h7v7h-7z', 'M13.5 3.5h7v7h-7z', 'M3.5 13.5h7v7h-7z', 'M13.5 13.5h3v3h-3z', 'M17.5 17.5h3v3h-3z'] },
  play: { paths: ['M7 3.6v16.8L19 12z'] },
  pause: { paths: ['M7 4.5h3.5v15H7z', 'M13.5 4.5H17v15h-3.5z'] },
  megaphone: { paths: ['M3.5 9.5h4L15.5 3.9v16.2L7.5 14.5h-4z', 'M18.5 9.5H21M18.5 14.5H21'] },
  list: { paths: ['M4 7h2M9 7h11M4 12h2M9 12h11M4 17h2M9 17h11'] },
  shield: { paths: ['M12 3l7.5 3v7.5L12 21l-7.5-7.5V6z', 'M9 11.5l2 2 4-4.5'] },
  envelope: { paths: ['M3 5.5h18v13H3z', 'M3 5.5 12 11.8l9-6.3'] },
  'envelope-open': { paths: ['M3 9 12 3.6 21 9v11.5H3z', 'M3 9l9 6.3L21 9'] },
  bookmark: { paths: ['M6.5 3.5h11V21L12 15.5 6.5 21z'] },
  archive: { paths: ['M3 4.5h18v4.5H3z', 'M4.5 9v11.5h15V9', 'M9.5 13h5'] },
  grid: { paths: ['M3.5 3.5h7v7h-7z', 'M13.5 3.5h7v7h-7z', 'M3.5 13.5h7v7h-7z', 'M13.5 13.5h7v7h-7z'] },
  minus: { paths: ['M4.5 12h15'] },
  funnel: { paths: ['M3.5 4.5h17L14 11v8.5l-4 1.5V11z'] },
  'external-link': { paths: ['M10 5.5H4.5v14h14V14', 'M13.5 4.5h6v6', 'M19.5 4.5 11 13'] },
};

// Flux icon name -> icon in the set. Names Flux uses internally are included.
export const flux = {
  home: 'home', 'squares-2x2': 'halaqa', users: 'students', 'user-group': 'students', 'clipboard-document-check': 'attendance',
  'book-open-text': 'mushaf', 'book-open': 'mushaf', 'arrows-right-left': 'review', 'arrow-path': 'review', 'calendar-days': 'calendar',
  calendar: 'calendar', 'chart-bar': 'reports', 'document-chart-bar': 'note', 'presentation-chart-line': 'trend', bell: 'bell',
  cog: 'settings', 'cog-6-tooth': 'settings', 'adjustments-horizontal': 'settings', 'academic-cap': 'user', 'building-library': 'mosque',
  'building-office-2': 'mosque', clock: 'clock', 'document-text': 'note', star: 'star', sparkles: 'star', check: 'check', 'x-mark': 'close',
  plus: 'plus', 'magnifying-glass': 'search', 'chevron-right': 'back', 'bars-2': 'menu', 'bars-3': 'menu', 'layout-grid': 'grid',
  'chevron-left': 'chevron-left', 'chevron-down': 'chevron-down', 'chevron-up': 'chevron-up', 'chevrons-up-down': 'chevrons-up-down',
  'ellipsis-horizontal': 'more', 'ellipsis-vertical': 'more-vertical', pencil: 'edit', 'pencil-square': 'edit', trash: 'trash', key: 'key',
  printer: 'printer', 'lock-closed': 'lock-closed', 'lock-open': 'lock-open', 'arrow-right': 'arrow-right', 'arrow-left': 'arrow-left',
  'arrow-up': 'arrow-up', 'arrow-down': 'arrow-down', 'arrow-down-tray': 'download', 'arrow-up-tray': 'upload', eye: 'eye',
  'eye-slash': 'eye-slash', 'exclamation-triangle': 'warning', 'exclamation-circle': 'exclamation-circle',
  'information-circle': 'information-circle', 'check-circle': 'check-circle', 'x-circle': 'x-circle', 'document-duplicate': 'copy',
  identification: 'badge', 'arrow-uturn-left': 'undo', 'arrow-right-start-on-rectangle': 'logout', 'arrow-left-end-on-rectangle': 'login',
  'arrow-right-end-on-rectangle': 'logout', user: 'user', 'user-plus': 'user-plus', 'user-minus': 'user-minus', sun: 'sun', moon: 'moon',
  'computer-desktop': 'desktop', 'device-phone-mobile': 'phone', 'qr-code': 'qr-code', play: 'play', pause: 'pause', megaphone: 'megaphone',
  'list-bullet': 'list', 'finger-print': 'shield', 'shield-check': 'shield', envelope: 'envelope', 'envelope-open': 'envelope-open',
  bookmark: 'bookmark', 'archive-box': 'archive', minus: 'minus', funnel: 'funnel', 'arrow-top-right-on-square': 'external-link',
  'arrow-up-right': 'external-link', 'folder-git-2': 'note',
};
