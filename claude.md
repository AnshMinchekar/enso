# Enso

Flutter Android app that builds a daily plan from the user's wake time and notifies them at each block change. Full requirements are in `docs/spec.md`. Read it before starting any task.

## Rules

- No AI APIs, no backend, no accounts, no analytics. Everything runs on the device.
- `lib/engine/` is pure Dart with no Flutter imports. Every engine or parser change needs passing tests in `test/engine/`.
- Never shorten sleep, meals or any block without a `min`.
- Match `docs/design/` (screenshots and style sheet) exactly. All design tokens live in `lib/ui/theme.dart`.
- Keep the UI calm. No red warnings, streaks, badges or guilt copy.
- Never commit signing keys, `key.properties` or `local.properties`.
- Follow the build order in the spec. One pull request per step, each with a summary and phone testing instructions.
- If the spec is ambiguous, ask before building.

## Layout

```text
lib/
  main.dart
  engine/      models.dart, parser.dart, planner.dart (pure Dart)
  services/    notifications.dart, storage.dart
  ui/          theme.dart, screens/, widgets/
assets/templates/   generic starter schedules
assets/prompts/     create_with_ai.md (the copyable AI prompt, do not rewrite)
docs/               spec.md, design/
test/engine/        parser and planner tests
test/fixtures/      sample.md and workday.md (defined in the spec appendix)
```

## Commands

- `flutter test` runs all tests
- `flutter analyze` must report no issues before opening a pull request