# Enso: Build Spec

Enso is an Android app (Flutter) that builds a realistic daily timeline from one input, the time the user woke up, and notifies them when each block ends and the next begins. Each user's routine lives in a structured Markdown schedule file, so anyone can use the app with their own rules.

The app is called **Enso** everywhere, in the UI, onboarding copy, notifications and the notification channel. The mockups in `docs/design/` say "Routine" in places. Replace it with "Enso".

## Hard constraints

- Android only, Flutter, Material 3 underneath but visually customised to `docs/design/`.
- No AI APIs, no backend, no accounts, no analytics. Everything runs on the device and works offline.
- `lib/engine/` is pure Dart with no Flutter imports, fully covered by unit tests.
- Sleep (the bedtime), meals and any block without a `min` are never shortened.
- Calm UI. No red warnings, streaks, badges, scores or guilt copy.

## Build order

Work in this order. One pull request per step, each with a short summary and clear instructions for testing it on a real phone.

1. Schedule file format, models and parser (with tests)
2. Scheduling engine, including preview mode (with tests)
3. Theme and screens
4. Notifications
5. Block actions, re-planning and persistence
6. File import, onboarding and starter templates
7. App name, icon and release build config (no signing secrets in the repo)

## 1. Schedule file format

A schedule file is ordinary Markdown containing exactly one fenced code block whose info string is `routine`. The app reads only that block, which is YAML. Blocks are placed in the order they appear in the file.

### Top-level fields

| Field | Required | Meaning |
| --- | --- | --- |
| `bedtime` | yes | `"HH:MM"`, the time the day must end |
| `wake_target` | no | `"HH:MM"`, the intended wake time, shown on the wind down screen. Default is `bedtime` minus 8 hours |
| `day_types` | yes | List of toggles shown at check-in, for example `[gym, cook, rest]`. More than one can be selected per day |
| `blocks` | yes | Ordered list of block definitions |

### Block fields

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Unique short name, used by other rules |
| `name` | yes | Shown on screen and in notifications |
| `detail` | no | Second line, for example what to eat |
| `minutes` | yes | Normal length |
| `min` | no | Shortest length the engine may squeeze it to. Absent means never shortened |
| `priority` | if `min` set | 1 is cut last, 9 is cut first |
| `only_on` | no | Block exists only when one of these day types is selected |
| `skip_on` | no | Block is removed when one of these day types is selected |
| `right_after` | no | When both blocks exist that day, move this block to directly after the named block |
| `latest_start` | no | `"HH:MM"`. If the block would start later, drop it |
| `at` | no | `"HH:MM"`. Pins the block to a fixed clock time, for fixed commitments like work, lectures or appointments. Pinned blocks never move and never shrink, except when the user wakes after their start |
| `category` | no | `focus`, `body`, `food`, `rest` or `leisure`. Drives the colour tint. `errand` is reserved for errands added at check-in |
| `notify` | no | Default `true`. `false` means no notification for this block |

The user's personal schedule is not part of the repo. They will create or import it through the app. Tests use the fixtures defined in the appendix at the end of this spec.

### Parser

- Lives in `lib/engine/parser.dart`, returns `ParseResult { Schedule? schedule; List<ScheduleError> errors; }`.
- `ScheduleError { int line; String message; String? suggestion; }` where `line` is the line number in the original `.md` file (fence start line plus the YAML node's `span.start.line`).
- Collect all errors, never stop at the first, never guess.
- Validation rules:
  - exactly one `routine` block exists
  - `bedtime`, `wake_target`, every `latest_start` and every `at` are valid `HH:MM`
  - pinned blocks (`at`) appear in clock order in the file, don't overlap, and end before `bedtime`
  - every block has `id`, `name`, `minutes`, and ids are unique
  - `min` is not larger than `minutes`, and `priority` is present whenever `min` is
  - `right_after` references an existing id
  - `only_on` and `skip_on` only use values from `day_types`
  - `category` is one of the allowed values (`errand` is not allowed in files)
- Messages are plain, specific sentences, for example "Lunch says right_after: cook, but there's no block with id cook."
- When a reference doesn't match, set `suggestion` to the closest existing id or name by edit distance, shown as "Did you mean ...?" on the error card. Only suggest when the match is close.

## 2. Scheduling engine

`Plan buildPlan(Schedule s, DayInput input)` in `lib/engine/planner.dart`.

- `DayInput`: wake time (DateTime), selected day types (Set<String>), errands (name + minutes), bedtime override (optional), optional `now` and list of finished or in-progress blocks for re-planning.
- `Plan`: ordered `PlannedBlock { BlockDef block; DateTime start; DateTime end; }`, plus `List<Cut> { blockId; fromMinutes; toMinutes; dropped }`, plus `overflowMinutes` (0 when the day fits).

Algorithm:

1. Filter blocks by `only_on` and `skip_on` against the selected day types.
2. Insert errands as fixed blocks with category `errand`, replacing the position of the first block with category `rest` and `min: 0`. If none exists, place them directly after the block with id `lunch`, else before the last block.
3. Apply `right_after` moves.
4. Start time is wake time plus 5 minutes. Available minutes run from start to the bedtime (override if set, else from the file).
5. While total minutes exceed available, pick the shrinkable block with the highest `priority` number (ties go to the later block), shorten it towards its `min`, and record the cut.
6. If still over, remove blocks whose `min` is 0, recording them as dropped. If still over, stop and report `overflowMinutes`. Never shorten blocks without `min`.
7. If there is spare time, add it to the last block with `min: 0` (free time). If none exists, add it to the last shrinkable block.
8. Assign start and end times in order.
9. If any block with `latest_start` starts too late, drop it and repeat from step 4.

### Pinned blocks

Blocks with `at` start at that clock time and keep their full length. They split the day into segments: from the start to the first pinned block, between pinned blocks, and from the last pinned block to bedtime. Every unpinned block belongs to the segment it sits in by file order (after `right_after` moves). Steps 4 to 9 run separately for each segment, with the segment's own start and end in place of the start time and bedtime.

If the user wakes after a pinned block has started, that block starts at wake time plus 5 minutes and keeps its original end time, recorded as a cut. Unpinned blocks in segments that are already over are recorded as missed and left out of the plan.

### Re-planning

Re-planning calls the same function with `now` set. Finished and in-progress blocks keep their times. The remaining blocks are planned from `now`.

### Preview mode

`List<PlanChange> previewAction(Plan current, Action action, DateTime now)` runs a re-plan without applying it and returns what would change (moved start times, shortened or dropped blocks). Actions are `extend(minutes)`, `skip(blockId)`, `done(blockId)` and `runningLate`. The block sheet uses this to show text like "With +15 min, lunch moves to 12:45 and the walk becomes 15 min."

### Required tests (`test/engine/`)

Use the fixtures from the appendix, saved as `test/fixtures/sample.md` and `test/fixtures/workday.md`.

`sample.md` (bedtime 22:30):

- Wake 06:15, day types gym: plan fits, no cuts, last block ends 22:30.
- Wake 07:55, gym + cook: lunch comes directly after cook, free blocks cut first, side_project cut before deep_work, deep_work never below 105 minutes.
- Wake 10:00, gym: plan ends by 22:30, all meals present, cuts listed.
- Wake 13:30, gym: preworkout is dropped (latest_start 14:00).
- Rest day: gym and preworkout absent, spare time goes to free time.
- Errand "Haircut 60 min" on a normal day: placed where the first free block was, category `errand`.
- Re-plan at 12:00 with +30 minutes on the current block: earlier blocks unchanged, later blocks shifted, cuts recomputed.
- Preview of +15 min matches the result of actually applying +15 min.
- Bedtime override of 23:00 gives 30 more minutes to the plan.

`workday.md` (bedtime 23:00, pinned commute and work):

- Wake 07:00: commute_in starts 08:30, work runs 09:00 to 17:00, no cuts.
- Wake 08:45: commute_in starts 08:50 and still ends 09:00, breakfast is recorded as missed, work unchanged.
- Any wake time: the evening segment fits by shortening free time first, and gym is not shortened before free time reaches 0.

Parser:

- Both fixtures parse with zero errors.
- A copy of `sample.md` with a misspelt `right_after` target returns one error with the correct line number and a suggestion.
- A copy with a missing `minutes` returns one error with the correct line number.
- A copy of `workday.md` with overlapping pinned blocks returns one error.

## 3. Theme and screens

Match `docs/design/` exactly. Put all tokens below in `lib/ui/theme.dart` as `ThemeData` plus a `ThemeExtension` for the custom tokens. If missing, they will be handed off via Claude Design.

### Ambience by time of day (fully automatic)

There is no theme setting. The look follows the time of day:

| Period | Time | Look |
| --- | --- | --- |
| Morning | 04:00 to 11:59 | Light tokens, cool morning sky background as in the mockups |
| Afternoon | 12:00 to 17:59 | Light tokens, warm afternoon background as in the mockups |
| Evening | 18:00 to 03:59 | Dark tokens, evening background as in the mockups |
| Wind down | After the last block before bedtime | Night colour screen |

Switching between periods cross-fades over about 2 seconds while the app is open, never a hard jump. The Settings theme selector shown in the mockups is removed.

### Colours

| Token | Use | Light | Dark |
| --- | --- | --- | --- |
| background | Screen | #F5F2EC | #1B1A18 |
| surface | Cards, sheet | #FCFAF6 | #252420 |
| sunk | Chips, secondary buttons | #ECE7DF | #2F2D29 |
| ink | Primary text | #2A2825 | #EEEAE3 |
| ink2 | Secondary text | #6B665E | #A8A299 |
| ink3 | Icons, dividers | #8E887F | #78726A |
| line | Timeline rail | #E2DDD4 | #34322E |
| accent | Now, primary action | #5C6F8C | #9FB0CB |
| accentSoft | Now row, selected chips | #E2E7EF | #2A303B |
| night | Wind down screen | #E3DDD3 | #121110 |

The accent only marks "now" and the primary action.

### Category tints (tint / dot)

| Category | Light | Dark |
| --- | --- | --- |
| focus | #E5E9EF / #7A89A2 | #252A31 / #94A3BB |
| body | #F1E5DA / #B68767 | #342B25 / #C99E80 |
| food | #F1EBD8 / #B19A5F | #322E23 / #C8B27A |
| rest | #EAE6EE / #958AA3 | #2C2930 / #ADA2BA |
| leisure | #F1E3E3 / #B37F7F | #342828 / #C99999 |
| errand | #EAE7E2 / #8E887F | #2D2C29 / #8A847B |

### Type

Manrope (bundled as an asset), tabular figures on every time.

| Style | Size / weight | Example |
| --- | --- | --- |
| clock | 104 / 200 | 22:30 on wind down |
| picker | 60 / 300 | 06:05 wake picker |
| hero | 36 / 300 | Career block |
| title | 22 / 500 | Today |
| bodyStrong | 17 / 500 | Cook & lunch |
| body | 15 to 16 / 400 | Applications + portfolio |
| label | 13 / 600 | Up next · 12:30 |

### Spacing, radii, elevation

- Spacing on an 8 pt grid: 8 chip gaps and icon to label, 12 card to card, 16 card margin from screen edge, 24 card padding, 32 onboarding margins, 48 bottom inset above the gesture bar.
- Radii: 6 dots and bars, 16 timeline rows, 20 small cards, 24 cards and groups, 28 hero card, 32 sheet top, pill for buttons and chips. No borders.
- Elevation: cards use two shadows (offset 0,1 blur 2 and offset 0,12 blur 32) in the shadow colour. The sheet uses offset 0,-12 blur 40. Nothing else casts a shadow.

### Screens

1. **Onboarding (3 steps).** Welcome ("Your whole day, built from the moment you wake. Tell Enso when you got up..."), choose a starter template (Student, 9 to 5, Gym-focused) or import a file, then grant notification and exact-alarm permissions with Allow and Not now.
   The template step also offers "Make one with AI" (see Create with AI below).
2. **Morning check-in.** Date, scrolling wake-time picker prefilled with now, a helper line with time until lights out, day-type chips (multi-select), errands (name + minutes, "Add errand"), one primary button "Build my day".
3. **Today.** Header with date and title. Hero card for the current block (category label, name, detail, time range, slow progress ring with time left). "Up next" row. A summary card when anything was cut, for example "You started at 07:40, so two blocks are a little shorter today" with each change as "Coding 2h 15 → 1h 15". Then "Your day" with a "Running late?" action and the vertical timeline. Past blocks faded, current accented, the list scrolled to now.
4. **Block sheet.** Opens from a tapped row or the hero card. Shows category, name, time range, time spent and time left, detail, "Can shrink to ..." (or fixed), "Comes after ...", the preview line from preview mode, and the actions +15 min, Skip and Done. The timeline re-plans live behind it.
5. **Schedule file.** Actions "Import file", "Paste from clipboard" and "Make one with AI". Current file name, "Running since <date> · N blocks · N rules", error cards (line number, message, "Did you mean ...?", and the note that the previous schedule keeps running), then a readable list of blocks with their length and rule ("fixed", "gym days", "min 1h 30").
6. **Settings.** Bedtime (defaults to the file value, a local override wins), heads-up before a block ends (default 5 min), notification sound (default "Soft chime"), link to the schedule file screen, and the line "Everything runs on this phone. No account, no server." No theme selector.

### Create with AI

The app itself never calls any AI. It helps users get a schedule file from an AI assistant they already use.

1. "Make one with AI" opens a sheet with three short steps: copy the prompt, paste it into any AI assistant and describe your day, then copy the answer back.
2. "Copy prompt" copies the contents of `assets/prompts/create_with_ai.md` to the clipboard (Flutter's `Clipboard`, no extra package) and shows a gentle confirmation.
3. "Paste schedule" reads the clipboard and runs the parser. If the text has no `routine` block, say so plainly. If it has errors, show the usual error cards. If it is valid, show the readable block summary with "Use this schedule".
4. Accepted schedules are saved as a `.md` file in the app documents directory, exactly like an imported file.

Style the sheet with the same tokens and components as the rest of the app. It isn't in the mockups, so follow the onboarding template step's look.

### States

- Before check-in: greeting by time of day ("Good morning.", "Good afternoon.", "Good evening."), "When did you wake up?", a Check in button.
- Notifications denied: soft inline banner "Reminders are off. You'll only see changes while the app is open." with Turn on.
- Shortened day: summary card as above.
- Overflow (day cannot fit): calm note with the minutes over, no colour change.
- Wind down: night screen with "Lights out at 22:30", minutes left, and "Tomorrow, wake around <wake_target>, <hours> of sleep".
- Invalid file: keep running the last valid schedule, show the error on the schedule file screen.

### Motion and haptics

Springs, not curves. Nothing pops in.

| Transition | What happens | Spring |
| --- | --- | --- |
| Check-in → Today | Button label fades and the button morphs into the hero card (Hero, shared bounds). Picker and chips slide down 24 dp and fade over 200 ms. Timeline rows stagger in from 12 dp below, 30 ms apart. The list settles on now with one soft confirmation haptic | mass 1, stiffness 260, damping 28, about 380 ms |
| Card → sheet | The tapped row or hero card grows into the sheet. Title and time are shared elements. Radius 16 → 32, scrim fades in on the same spring. Detail rows and actions fade in once the sheet passes 70% height. Drag down reverses, a fast release dismisses | stiffness 300, damping 30, about 320 ms, drag velocity carried over |
| Re-plan | Blocks after now slide to their new positions together (AnimatedList with implicit offsets). Changed times cross-fade digit by digit. A skipped block fades and collapses, and the next flexible block grows into the space. The summary card eases in if something got shorter | stiffness 220, damping 26, about 400 ms, light tick haptic per tap |

Edge to edge layout throughout.

## 4. Notifications

- `flutter_local_notifications` with `timezone` and `flutter_timezone`. Follow the package README for the installed version.
- Manifest: `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, plus the receivers the README lists so alerts survive a reboot.
- Request notification permission (Android 13+) and exact-alarm permission (Android 14+) during onboarding.
- One calm channel named "Enso", default importance, using the sound chosen in Settings.
- On every plan change, cancel all and reschedule: one notification at each block start (skip blocks with `notify: false`), and a heads-up before the current block ends (length from Settings).
- Block change text: title "Enso · now", body "Career block, until 12:30. Next, Lunch." Actions "Start" (opens Today) and "+10 min" (re-plans and reschedules).
- Heads-up text: "5 minutes left in Gym. Shower + shake next."

## 5. Persistence

- Store the active schedule file in the app documents directory (`path_provider`), whether it came from a file, the clipboard or a template.
- Store today's plan, day input and finished blocks so a restart restores the day.
- Settings (bedtime override, heads-up minutes, sound) in `shared_preferences`.

## 6. Templates

Ship three generic starters matching onboarding, plus the AI prompt at `assets/prompts/create_with_ai.md` (already in the repo, do not rewrite it): `student.md` (lectures, study blocks, a later start), `nine_to_five.md` (commute, work hours, evenings free) and `gym_focused.md` (training first, meals around it, early nights). Generic templates must contain no personal details.

## Notes on the mockups

The mockup content (Cook & lunch as one block, Walk, Reading, push day detail, a 06:05 wake) is sample data only. The user's own schedule, imported later, is the source of truth for real blocks.

## Out of scope

iOS, cloud sync, accounts, AI features, statistics screens, streaks, a manual theme switch.

## Appendix: test fixtures

### `test/fixtures/sample.md`

````markdown
# Sample routine

```routine
bedtime: "22:30"
wake_target: "06:15"
day_types: [gym, cook, rest]

blocks:
  - {id: breakfast, name: Breakfast, minutes: 20, category: food}
  - {id: language, name: Language practice, minutes: 35, min: 20, priority: 3, category: focus}
  - {id: preworkout, name: Pre-workout, minutes: 15, only_on: [gym], latest_start: "14:00", category: body}
  - {id: gym, name: Gym, minutes: 120, only_on: [gym], category: body}
  - {id: shower, name: Shower + snack, minutes: 30, category: food}
  - {id: cook, name: Cook, minutes: 120, only_on: [cook], category: food}
  - {id: lunch, name: Lunch, minutes: 45, right_after: cook, category: food}
  - {id: deep_work, name: Deep work, minutes: 165, min: 105, priority: 2, category: focus}
  - {id: free1, name: Free, minutes: 45, min: 0, priority: 9, category: rest, notify: false}
  - {id: side_project, name: Side project, minutes: 135, min: 45, priority: 5, category: focus}
  - {id: snack, name: Snack, minutes: 20, category: food}
  - {id: free2, name: Free, minutes: 85, min: 0, priority: 9, category: rest, notify: false}
  - {id: dinner, name: Dinner, minutes: 45, category: food}
  - {id: gaming, name: Gaming, minutes: 90, min: 60, priority: 7, category: leisure}
  - {id: late_snack, name: Late snack, minutes: 15, category: food}
  - {id: review, name: Review, minutes: 30, min: 15, priority: 4, category: focus}
  - {id: winddown, name: Wind down, minutes: 60, category: rest}
```
````

### `test/fixtures/workday.md`

````markdown
# Workday routine

```routine
bedtime: "23:00"
wake_target: "07:00"
day_types: [gym, rest]

blocks:
  - {id: breakfast, name: Breakfast, minutes: 20, category: food}
  - {id: commute_in, name: Commute, minutes: 30, at: "08:30", category: rest}
  - {id: work, name: Work, minutes: 480, at: "09:00", category: focus}
  - {id: commute_home, name: Commute home, minutes: 30, category: rest}
  - {id: gym, name: Gym, minutes: 90, min: 60, priority: 5, only_on: [gym], category: body}
  - {id: dinner, name: Dinner, minutes: 45, category: food}
  - {id: free, name: Free, minutes: 120, min: 0, priority: 9, category: rest, notify: false}
  - {id: reading, name: Reading, minutes: 45, min: 15, priority: 6, category: leisure}
  - {id: winddown, name: Wind down, minutes: 45, category: rest}
```
````