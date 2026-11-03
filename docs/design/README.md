# Design reference

The visual spec for Enso, exported from Claude Design. Reproduce it in Flutter; do not ship any of these HTML/JS files.

| Path | What it is |
| --- | --- |
| `style-sheet.md` | Extracted design tokens (colours, type, spacing, radii, elevation, components, motion). Source for `lib/ui/theme.dart` |
| `Enso App.dc.html` | The mockups: every screen at 412 × 915 dp in morning, afternoon and evening. Open it in a browser next to `support.js` to view |
| `support.js` | Runtime the mockup needs to render. Reference only |
| `sky.png`, `afternoon-cozy.png`, `night-plain.png` | Morning, afternoon and evening backgrounds used by the mockups |
| `night-sky.png`, `night-sky-soft.png` | Unused alternative night backgrounds |
| `screenshots/` | Review captures taken during design iteration (some predate the final colours) |
| `chats/` | Design conversation transcripts: why things look the way they do |
| `uploads/` | The original design brief and the user's source images |
| `HANDOFF.md` | The handoff bundle's own README |

Precedence: `docs/specs.md` wins on copy and behaviour; this folder wins on visuals.
