# Routine App: Design Brief

Oct 26, 2026 · @Ansh

## The product

An Android app that builds your whole day from one input, the time you woke up. Each morning you enter your wake time, mark the day as a gym, cook or rest day, add any one-off errands, and the app lays out a realistic timeline that ends at a fixed bedtime. It then notifies you each time a block ends and the next one begins.

Everyone runs on their own schedule file. Rules, block lengths and priorities live in a structured Markdown file that the app loads, so anybody can use it, not only the first user. When a day does not fit, the app shrinks lower-priority blocks first and tells you what it cut. Sleep, meals and fixed commitments are never cut.

No AI, no account, no server. Everything runs on the phone, works offline and schedules notifications locally. Built in Flutter.

## Design direction

Calm first, polished always. The app should feel like a quiet companion that keeps the day moving, never a productivity dashboard that nags. Think the restraint and finish of Apple's own apps, with the fluid, seamless transitions of Revolut, where every screen flows into the next without a jolt.

- **One thing at a time.** The current block is the hero. Everything else is secondary and visually quieter.
- **Glanceable.** The answer to "what am I doing now, and what's next" should take under two seconds to read.
- **Gentle, not urgent.** Running late is normal. The app re-plans without red warnings, guilt or exclamation marks.
- **Continuous motion.** Transitions are shared-element and spring-based, so a block card expands into its detail sheet rather than a new page appearing.
- **Generous space.** Few elements per screen, large touch targets, lots of breathing room.
- **Native to Android.** Edge to edge, gesture navigation, Material 3 underneath but customised so it doesn't look like a stock Material app.

## Visual language

| Element | Direction |
| --- | --- |
| Colour | Soft warm neutrals (off-white, stone, charcoal) with one muted accent, such as sage or dusk blue. Accent only marks "now" and primary actions. |
| Category tints | Very subtle tints per block type (focus work, body, food, rest, leisure), readable in both themes, never saturated. |
| Themes | Light and dark designed together. Dark mode is deep charcoal, not pure black. Follows the system setting. |
| Typography | One clean sans family (for example Inter or a similar humanist sans). Large, light weight for the current block and times, regular for body. Tabular figures for all times. |
| Spacing | 8 pt grid, wide margins, rounded cards (around 20 to 24 pt radius), no hard borders, separation through space and soft elevation. |
| Motion | Spring curves, 250 to 400 ms. Card to sheet expansion, smooth timeline scroll to "now", a slow progress ring on the current block. |
| Haptics | Light tick on toggles and time changes, a soft confirmation when the day is built. |
| Icons | Thin, rounded line icons. Minimal, used only where a word alone is slower to read. |

## Screens

Seven screens, with the morning check-in and today's timeline carrying most of the experience.

1. **Onboarding (3 short steps).** A one-line welcome, then pick a starter template (student, 9 to 5, gym-focused) or import a schedule file, then grant notification and exact-alarm permissions with a plain explanation of why.
2. **Morning check-in.** Shown on the first open each day. A large, calm wake-time picker prefilled with the current time, day-type chips (Gym, Cook, Rest, combinable), and an "Add errand" row with name and duration (for example Haircut, 60 min). One primary button, "Build my day".
3. **Today.** The main screen.
   - Hero card for the current block with its name, a short detail line ("Muesli + Skyr"), time remaining and a slow progress ring.
   - "Up next" directly under it.
   - A vertical timeline of the rest of the day. Past blocks fade, the current one is accented, future ones are quiet.
   - A small, dismissible note when something was shortened ("Coding shortened to 1h 15").
   - A subtle "Running late?" action that shifts the rest of the day from now.
4. **Block sheet.** Tapping a block expands it into a bottom sheet with its details and three actions: Done, +15 min, Skip. The rest of the day re-plans live behind the sheet.
5. **Notifications.** A calm lock-screen style, for example "Career block, until 12:30. Next, Lunch." Actions on the notification are Start and +10 min. One gentle heads-up 5 minutes before a block ends.
6. **Schedule file.** Shows the loaded file's name and a readable summary of its blocks and rules. "Import" opens the system file picker. Errors appear as friendly, specific cards ("Lunch says after Cook, but there's no block called Cook") with the line number.
7. **Settings.** Bedtime, notification timing, theme, and a link to the schedule file screen. Kept short.

## Key states

| State | What the user sees |
| --- | --- |
| Before check-in | Today screen shows a single calm prompt, "Good morning. When did you wake up?" |
| Normal day | Full timeline, nothing shortened, no notes. |
| Late start or overloaded day | The day still builds. A quiet summary card lists what was shortened and by how much. No red, no warnings. |
| Running late mid-day | "Running late?" or +15 min re-plans everything after now, with a short animation as blocks slide. |
| Block skipped | It fades out of the timeline. The freed time goes to the next flexible block. |
| Wind down | After the last block, the screen dims to a calm night view with the bedtime and tomorrow's wake target. |
| File error | The previous working schedule keeps running. The schedule file screen shows the error cards. |
| Permissions denied | A soft inline banner explaining that reminders are off, with one button to fix it. |

## What to avoid

- Streaks, scores, badges or any gamification. The app is calm, not competitive.
- Red alerts, guilt copy ("You missed...") or countdowns that feel urgent.
- Dense dashboards, charts or stats on the main screen.
- Stock Material look, heavy shadows, bright saturated colours.
- More than one primary action per screen.
- Calendar-grid layouts. The day reads as a single vertical flow.

## Deliverables from Claude Design

- [ ] High-fidelity mockups of all seven screens, in light and dark mode, at a typical Android phone size (around 412 by 915 dp).
- [ ] The Today screen in three states (normal day, shortened day with summary card, wind down).
- [ ] The block sheet expanded over the timeline.
- [ ] A notification mockup on the lock screen.
- [ ] A small style sheet covering colours with hex values, type scale, spacing, corner radii and the category tints, so the Flutter build can match it exactly.
- [ ] Short notes on the key transitions (check-in to Today, card to sheet, re-plan animation).

Use realistic sample content from a real day, for example Muesli + Skyr at 06:20, Gym 07:30 to 09:15, Career block 09:45 to 12:30, Coding 14:00 to 16:15, Gaming 18:45 to 20:15, Lights out 22:30.
