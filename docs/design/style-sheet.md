# Enso style sheet

Design tokens extracted from `Enso App.dc.html` (Claude Design handoff, section 10 "Style sheet" plus the token script at the bottom of the file). Everything here goes into `lib/ui/theme.dart` as `ThemeData` plus a `ThemeExtension`.

The mockups render with these Tweaks defaults: **background = sky, surfaces = glass, night = gradient, accent = dusk**. The "Resolved in the mockups" columns below are what the screens actually show. The "Base" columns are the solid values from the style sheet panel and `docs/specs.md`; they are the fallback when blur is unavailable.

Where this file and `docs/specs.md` disagree on copy or behaviour, `docs/specs.md` wins.

## Ambience by time of day

| Period | Time | Brightness | Background (mockup) |
| --- | --- | --- | --- |
| Morning | 04:00–11:59 | light | `sky.png`, cover, under a `rgba(245,242,236,.42)` wash |
| Afternoon | 12:00–17:59 | light | `afternoon-cozy.png`, cover, base colour `#F7CFAE` |
| Evening | 18:00–03:59 | dark | `night-plain.png`, cover, base colour `#0B1026` |
| Wind down | after the last block | follows period | solid `night` token (see below) |

Unused alternatives kept for reference: `night-sky.png` / `night-sky-soft.png` (the "photo" night option, drawn under `linear-gradient(rgba(10,12,28,.35), rgba(10,12,28,.72) 55%, rgba(10,12,28,.82))`). Afternoon uses the light tokens; only the background image changes. Period changes cross-fade over ~2 s (spec).

## Colours

### Core

| Token | Use | Light | Dark |
| --- | --- | --- | --- |
| background | Screen (plain fallback) | `#F5F2EC` | `#1B1A18` |
| ink | Primary text | `#2A2825` | `#EEEAE3` |
| ink2 | Secondary text, **over sky** (resolved) | `#45413B` | `#CFCAC1` |
| ink2 (base) | Secondary text, plain background | `#6B665E` | `#A8A299` |
| ink3 | Icons, dividers, radio outline, sheet handle | `#8E887F` | `#78726A` |
| line | Timeline rail (1 px) | `#E2DDD4` | `#34322E` |
| shadow (`--sh`) | Card and sheet shadows | `rgba(70,55,40,.06)` | `rgba(0,0,0,.30)` |

### Surfaces

| Token | Use | Glass (resolved) light | Glass (resolved) dark | Base light | Base dark |
| --- | --- | --- | --- | --- | --- |
| surface | Cards, sheets, hero | `rgba(255,255,255,.62)` | `rgba(26,28,44,.60)` | `#FCFAF6` | `#252420` |
| sunk | Chips, secondary buttons, icon wells, banners | `rgba(255,255,255,.42)` | `rgba(44,46,64,.55)` | `#ECE7DF` | `#2F2D29` |
| blur | Backdrop behind surface/sunk | `blur(24px) saturate(1.3)` | same | none | none |

Flutter: `ClipRRect` + `BackdropFilter(ImageFilter.blur(sigmaX: 12, sigmaY: 12))` (CSS blur radius 24 ≈ sigma 12) then the translucent fill. Primary buttons and the "now" highlight are never glass.

### Accent (dusk, default)

| Token | Use | Light | Dark |
| --- | --- | --- | --- |
| accent | "Now" dot, progress, primary button fill | `#5C6F8C` | `#9FB0CB` |
| accentInk | "Now" label text, accent text buttons ("Turn on") | `#475A76` | `#B7C5DB` |
| onAccent | Text on primary button | `#FFFFFF` | `#161C26` |
| accentSoft (base) | Now row, selected chips | `#E2E7EF` | `#2A303B` |
| accentSoft (glass, resolved) | same | `color-mix(in oklch, accent 24%, surface)` | same |

Alternative accent (sage, not default): accent `#5E7A62`/`#9CB79F`, soft `#E1E8DC`/`#2C362D`, ink `#4A644E`/`#B4CCB6`, on `#FFFFFF`/`#17211A`.

### Category tints (tint / dot)

| Category | Light | Dark |
| --- | --- | --- |
| focus | `#E5E9EF` / `#7A89A2` | `#252A31` / `#94A3BB` |
| body | `#F1E5DA` / `#B68767` | `#342B25` / `#C99E80` |
| food | `#F1EBD8` / `#B19A5F` | `#322E23` / `#C8B27A` |
| rest | `#EAE6EE` / `#958AA3` | `#2C2930` / `#ADA2BA` |
| leisure | `#F1E3E3` / `#B37F7F` | `#342828` / `#C99999` |
| errand | `#EAE7E2` / `#8E887F` | `#2D2C29` / `#8A847B` |

With glass surfaces the tint is resolved as `color-mix(in oklch, <dot> 20%, surface)`, i.e. 20 % of the dot colour over the translucent surface. Dots are always the solid values above.

### Overlays and special screens (sky mode, resolved)

| Token | Use | Light | Dark | Base light | Base dark |
| --- | --- | --- | --- | --- | --- |
| scrim | Behind bottom sheets | `rgba(20,26,48,.30)` | `rgba(4,6,18,.60)` | `rgba(30,25,20,.32)` | `rgba(0,0,0,.55)` |
| night | Wind down screen | `#D9DCE6` | `#070A1A` | `#E3DDD3` | `#121110` |
| nightCard | "Tomorrow" card on wind down | `#E6E8EF` | `#141A33` | `#EDE8E0` | `#1D1C1A` |
| notif | Lock-screen notification card | `rgba(252,250,246,.88)` | `rgba(46,44,40,.88)` | same | same |
| wall / wallHi | Lock-screen wallpaper gradient (mockup only) | `#C7D2E3` / `#E6ECF5` | `#0D1330` / `#1F2750` | `#D6CEC1` / `#EEE8DE` | `#1E1C19` / `#2C2A26` |

## Type

Manrope (bundle as an asset, weights 200–800). Tabular figures (`FontFeature.tabularFigures()`) on every time and duration.

| Style | Size / weight | Letter spacing | Line height | Example |
| --- | --- | --- | --- | --- |
| clock | 104 / 200 | −0.045 em | 1.0 | 22:30 on wind down |
| picker | 60 / 300 | −0.02 em | 72 px row | 06:05 wake picker |
| display | 42 / 300 | −0.025 em | 1.12 | Welcome headline |
| greeting | 48 / 300 | −0.03 em | 1.08 | "Good morning." |
| hero | 36 / 300 (38 in sheet) | −0.025 em | 1.1 | Career block |
| heading | 32 / 300 | −0.02 em | 1.15 | Onboarding step titles, sheet titles, "You woke up at" |
| title | 22 / 500 | −0.01 em | — | Today, Schedule file |
| bodyStrong | 17 / 500 | 0 | — | Cook & lunch, card titles |
| button | 17 / 600 (primary), 15–16 / 600 (secondary) | 0 | — | Build my day |
| body | 15–16 / 400 | 0 | 1.5 | Applications + portfolio |
| caption | 13–14 / 400 | 0 | 1.4–1.5 | Row details, helper lines |
| label | 13 / 600 | 0 | — | Up next, section labels |
| overline | 12 / 700 uppercase | +0.1 em | — | NOW · FOCUS, error card "LINE 42" (+0.08 em) |
| status bar | 14 / 600 | 0 | — | 10:52 |

Picker neighbours: ±1 row 32 / 300 at 45 % opacity (44 px row), ±2 rows 24 / 300 at 20 % (36 px row); separator ":" 52 / 200 in ink2.

## Spacing (8 pt grid)

| Value | Use |
| --- | --- |
| 8 | Chip gaps, icon to label |
| 12 | Card to card |
| 16 | Card margin from screen edge |
| 24 | Card padding, text margin |
| 32 | Onboarding margins |
| 48 | Bottom inset above the gesture bar |

## Radii (no borders)

| Value | Use |
| --- | --- |
| 6 | Dots, progress bars |
| 16 | Timeline rows, icon wells |
| 20 | Small cards (Up next, summary, banners, sheet detail groups) |
| 24 | Cards and groups |
| 28 | Hero card, picker card |
| 32 | Sheet top corners |
| pill | Buttons and chips |

## Elevation

- Hero card: `0 1 2` and `0 12 32` in the shadow colour.
- Sheets: `0 −12 40` in the shadow colour.
- Nothing else casts a shadow. Selection is a 1.5 px accent ring (`box-shadow: 0 0 0 1.5px accent`), not a border.

## Components

| Component | Spec |
| --- | --- |
| Primary button | Height 60, pill, accent fill, onAccent 17/600, margin 16 from edges, 48 above gesture bar |
| Secondary button | Height 56, pill, sunk (glass), ink 15–16/600; side by side in a 2-column grid, gap 12 |
| Copied state | Primary button becomes accentSoft fill with accentInk text + check icon, reverts after 2 s |
| Text button | Height 44–48, 14–15/600–700, ink2 or accentInk |
| Chip | Height 48, pill, padding 0 20 (0 20 0 16 with check icon), 15/600. Selected: accentSoft + accentInk + 18 px check. Unselected: sunk |
| Hero card | Margin 16, padding 24, radius 28, surface + shadows, gap 20. Ring 96 px, radius 42, stroke 4, track sunk, progress accent, round cap, starts at 12 o'clock |
| Up next | Padding 16 20, radius 20, category tint fill, label 12/600 ink2, name 17/500, time 17 ink2 |
| Timeline row | Grid `52 px | 20 px | 1fr`, gap 12, padding 12, radius 16. Time 14 ink2, dot 8 px category colour (now: 12 px accent), name 16/500 (now 600), detail 13 ink2. Past rows opacity .42, now row accentSoft fill. Rail 1 px `line` at x = 101 within the screen. List fades out at the bottom (mask from 55–65 %) |
| Summary card | Sunk (glass), radius 20, padding 16 8 16 20, 15/500 message, rows 14 with "2h 15 → 1h 15" in ink2, close icon 40 px in ink3 |
| Banner | Same shell as summary card; bell icon ink2, title 15/600, body 13 ink2, accentInk "Turn on" |
| Sheet | Radius 32 top, padding 12 24 40, surface (glass), gap 24; handle 36×4 ink3 at 50 %; scrim over the screen |
| Error card | Food tint, radius 24, padding 20, gap 8. Overline "LINE 42" 12/700, message 16/500, suggestion + keep-running note 14 ink2 |
| Status bar | Height 44, padding 0 28; gesture pill 108×4, ink at 30 % (20 % on wind down) |

## Motion

Springs, not curves. Nothing pops in.

| Transition | Spring |
| --- | --- |
| Check-in → Today | mass 1, stiffness 260, damping 28, ~380 ms |
| Card → sheet | stiffness 300, damping 30, ~320 ms, drag velocity carried over |
| Re-plan | stiffness 220, damping 26, ~400 ms, light tick haptic per tap |

Details of each transition are in `docs/specs.md` § Motion and haptics and in section 11 of the mockup.

## Known differences between the mockups and the spec

`docs/specs.md` wins on copy and behaviour. Notable differences to apply when building screens:

- Settings in the mockup shows a theme selector; the spec removes it (ambience is automatic).
- The colour table in the spec lists the base (solid) values; the mockups render glass surfaces and the darker sky-mode `ink2`. Which one ships is a step 3 decision.
- Error copy in the mockup ("Lunch says after Cook…") is sample text; real messages come from the parser.
- Mockup content (Cook & lunch, Walk, Reading, `ansh-routine.md`) is sample data only.
