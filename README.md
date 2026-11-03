# Enso

A calm Android day planner. You tell it when you woke up, pick what kind of
day it is (gym, cook, rest, …) and add any errands; Enso lays out a realistic
timeline that ends at a fixed bedtime, shortens the least important blocks
when the day is tight, and lets you know each time a block ends.

Everything runs on the phone: no account, no server, no AI calls.
Built with Flutter.

## How it works

- **Your schedule is a Markdown file.** Blocks, lengths, priorities and rules
  live in one fenced code block marked `routine`. Start from a template, import
  a file, or have any AI assistant write one with the prompt in
  `assets/prompts/create_with_ai.md`. The format is in `docs/specs.md` § 1.
- **The engine** (`lib/engine/`, pure Dart) parses the file and plans the day:
  day-type filters, errands, pinned times, cuts by priority, re-planning after
  +15 min, Skip, Done or Running late, and previews of what an action changes.
- **The app** (`lib/ui/`) follows `docs/design/`: glass panels over a
  background that changes with the time of day (morning, afternoon, evening).
- **Reminders** (`lib/services/notifications.dart`) fire at each block start
  and a few minutes before each block ends.

## Develop

Requires Flutter (stable) and, for phone builds, the Android SDK.

```sh
flutter pub get
flutter test        # engine, services and widget tests
flutter analyze     # must report no issues
flutter run --profile   # on a connected phone; judge smoothness here, not in debug
```

Debug and profile builds have test tools: long-press **Today** to switch the
look (morning, afternoon, evening, wind down), and Settings → **Test builds
only** → Show onboarding.

## Layout

```text
lib/
  engine/      models, parser, planner, serialization (pure Dart, tested in test/engine/)
  services/    notifications, reminder plan, storage
  ui/          theme.dart (all design tokens), screens/, widgets/
assets/
  templates/   generic starter schedules
  prompts/     create_with_ai.md, the copyable AI prompt
  backgrounds/ time-of-day artwork and its pre-blurred glass copies
  fonts/       Manrope (OFL)
docs/
  specs.md     build spec
  design/      the visual reference and style sheet
  release.md   signing and release builds
test/          engine, services and UI tests; fixtures/
```

## Release

See `docs/release.md`. Signing keys are never committed.
