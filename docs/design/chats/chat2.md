# App background sky design

_Started 2026-10-27 09:31 UTC_

---

## User

<artifact-content-authored-by-others/>
Continuing from "Mobile app design".

## Assistant

We were designing a mobile app called Routine—a task and habit tracker with a focus on daily check-ins and time-blocking. The goal was to create a cohesive, high-fidelity design system ready for handoff.

I consolidated all seven screens (normal, shortened, wind-down, and pre-check-in states of Today, plus Habits, Check-in, and Lock-screen notifications) into a single canvas in Routine App.dc.html, with both light and dark modes. Alongside this, I built out a complete style sheet with hex values, type scale, spacing values, border radii, and the four category tints.

Key decisions made:
- Swapped Inter for Manrope (humanist sans with better light weights and tabular figures support) to match the design brief's intent while improving readability.
- Set sage as the default accent colour, with dusk blue as a toggle option via Tweaks—both update globally across all screens.
- Used the warm food tint for error states instead of red, to keep the palette consistent and less harsh.
- Documented the three main transitions (check-in flow, Today state changes, block sheet overlay) with notes on timing and easing.

Current state: All mockups are static and complete. The file is fully pannable and shows the complete design system in one place.

Next steps: You can request a clickable prototype for the check-in flow, Today state transitions, and block-sheet overlay to see the movement and interaction in action—this would give stakeholders a better sense of the experience before development.

Files involved: Routine App.dc.html, support.js

## User

Do you see the background? Blue sky and clouds? I was thinking if its possible to have the app background be just that?

## Assistant

_[tool: grep]_

_[tool: run_script]_

_[tool: view_image]_

_[tool: run_script]_

_[tool: view_image]_

Cached view; saving under a new name.

_[tool: copy_files]_

_[tool: view_image]_

_[tool: run_script]_

_[tool: delete_file]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: run_script]_

_[tool: grep]_

_[tool: view_image]_

Clean enough. Wiring it in as a tweakable background.

_[tool: run_script]_

_[tool: ready_for_verification]_

Yes, it's possible. All 10 app screens now sit on the sky and clouds from your screenshot, in both light and dark mode. The wind-down and lock screens keep their own backgrounds.

- **Making the background:** I cropped the clean right side of the image and painted out the ribbons and the pink fish. I then blurred it so the patched spots don't show. The result is `sky.png`.
- **Keeping text readable:** I laid a cream wash over the sky in light mode and a navy one in dark mode. I also darkened the secondary text slightly while the sky is on.
- **Switching it off:** there's a new **background** setting in Tweaks (sky or plain). The plain option brings back the original off-white.

The patched areas look slightly flat because there wasn't much clean sky to work from. If you have a sky-only image, replace `sky.png` with it for a sharper result.

## User

Okay let's have that for light mode and for dark mode, I was thinking of a background like this

## Assistant

_[tool: copy_files]_

_[tool: run_script]_

_[tool: ready_for_verification]_

Light mode keeps the blue sky, and dark mode now uses your night sky across all 10 app screens. I darkened the night image a little, more towards the bottom, so the bright sunset near the buttons doesn't fight with them. The **plain** option in Tweaks still switches both modes back to the solid background.

## User

Found issues — fixing…

## Assistant

_[tool: run_script]_

_[tool: ready_for_verification]_

I fixed the hard-to-read text on the dark screens. The night sky is now slightly blurred, so the poles and wires no longer run through the timeline text. The lower half is also darker, so the pink clouds don't wash out the smaller grey text. The stars and colours are still visible near the top. It's out for a final check now.

## User

Do you think having glass panels like they have on iOS, would be better design

## Assistant

Yes, I think it would look better. The solid cream cards look stuck on top of the sky. Frosted glass would let the sky show through and make each screen feel like one piece.

A few things to watch:

- **This is an Android app.** Android can do the blur, but it costs more on older phones. The developers would need a fallback, like a plain see-through panel without the blur.
- **Readability.** Glass that's too clear makes text hard to read, especially over the bright clouds and sunset. The panels would need to stay fairly solid (about 70–80% opaque, heavily blurred) to keep the text readable.
- **Calm look.** Thin borders, strong shadows and shine would make it noisy. A soft frost with a faint edge fits Routine better.
- **Not everything should be glass.** Main buttons and the current-task highlight should stay solid so they stand out.

Want me to add it as a third Tweaks option (sky + glass) so you can compare it with the current cards?

## User

Let's give it a go

## Assistant

_[tool: run_script]_

_[tool: run_script]_

_[tool: ready_for_verification]_

The cards, chips and the block sheet are now frosted glass. It's switched on by default, and there's a new **surfaces** setting in Tweaks (glass or solid) so you can compare. The main buttons and the current-task highlight stay solid so they still stand out. The glass is fairly solid: about 70% opaque on cards, a little less on chips. It's out for a final check now.

## User

Do you have a better design for the dark mode background? I am open to suggestions.

## Assistant

Your night image has two problems behind a timeline: the poles and wires, and the bright sunset in the lower half where most of the text sits. Three options:

1. **Stars only.** Crop to the top half of your image: the Milky Way, stars and the tops of the clouds, without poles or sunset. It keeps the mood and is much calmer behind text. This is my pick.
2. **Same sky, after dark.** Colour-grade the light-mode sky into a deep dusk blue with dim clouds. Light and dark mode then feel like the same place at different times of day, which suits an app built around your day.
3. **No photo.** A deep navy-to-indigo gradient with a faint scatter of stars. It's the easiest to read and uses the least battery on OLED screens, but it has the least character.

Want me to build all three as Tweaks options so you can switch between them on the real screens?

## User

Show me what 3 might look like

## Assistant

_[tool: run_script]_

_[tool: ready_for_verification]_

Dark mode now shows option 3: deep navy fading to indigo, with a faint blue glow top right and soft stars that thin out towards the bottom. Behind the frosted cards it stays quiet, and the text should be easy to read. Your photo is still there: set **night** to "photo" in Tweaks to compare.

## User

That's much better actually. Also just go over and see if there's any improvements that can be made for the element colors in both light and dark mode

## Assistant

_[tool: save_screenshot]_

_[tool: save_screenshot]_

_[tool: run_script]_

_[tool: save_screenshot]_

_[tool: show_html]_

_[tool: get_webview_logs]_

_[tool: save_screenshot]_

_[tool: eval_js]_

_[tool: grep]_

The file is correct; the preview was stale. Checking it now.

_[tool: ready_for_verification]_

I went through the screens in both modes and changed the colours below. I haven't seen the final result rendered yet, so it's out for a check now.

- **Accent is now dusk blue by default.** Sage green clashed with both skies, while dusk blue blends with them. Sage is still available in Tweaks.
- **Coloured highlights are now see-through.** The "Up next" card, the current-task row and the selected chips were solid browns and greens that looked muddy on navy. They now let the glass and sky show through.
- **Light-mode glass is whiter.** The cream glass looked grey over blue sky, so I switched it to a clean white frost.
- **Wind-down and lock screens match the rest.** They were warm beige and near-black brown. Light mode is now a soft blue-grey, and dark mode a deep navy like the new night sky. The dimmed overlay behind the block sheet is also cool-toned now.
- **Nothing changes in plain mode.** If you switch back to the plain background, all the original colours return.

The colour list on the style sheet still shows the old values. Want me to update it to match?

## User

Found issues — fixing…

## Assistant

_[tool: grep]_

_[tool: str_replace_edit]_

_[tool: ready_for_verification]_

I fixed the page intro, which still called sage the default: it now names dusk blue as the default and sage as the alternative in Tweaks. Nothing else in the file still named sage as the default.

The layout checker flagged some overlapping and cut-off text. As far as I can tell these are intentional, not bugs: the block sheet sits on top of the timeline behind it, and scrolling lists are cut off at the screen edge.

## User

So right now we have design for light and dark theme. But what if it were to change through out the day? For example, in the morning it had the light mode design and in the evening it had the dark mode design. We need one for afternoon.

## Assistant

_[tool: grep]_

_[tool: run_script]_

_[tool: view_image]_

_[tool: grep]_

_[tool: dc_html_str_replace]_

_[tool: ready_for_verification]_

I've added an afternoon version, so every screen now shows morning, afternoon and evening side by side. I haven't seen it rendered on the screens yet; it's out for a check now.

- **Morning:** the blue sky, unchanged.
- **Afternoon:** the same sky, recoloured warmer. It's soft blue at the top, fading to peach and gold near the bottom, with a glow on the lower right. I put a light cream wash over it so text stays easy to read.
- **Evening:** the navy gradient with stars, unchanged.

Afternoon keeps the light-mode cards and text colours, so it reads as one theme drifting from cool to warm through the day.

There are two things to know:
- **Grey patch:** the middle-left of the afternoon sky looks a bit grey, and there's a faint line where I painted out the ribbons. A real golden-hour photo would look cleaner if you have one.
- **Wind-down and lock screens:** in the afternoon these still use the morning's cool blue-grey. Say if you want them warmed up too.

## User

It looks the same as the morning one, it needs to be different. Also, all of them say good morning, correct that too

## Assistant

_[tool: grep]_

_[tool: run_script]_

_[tool: view_image]_

_[tool: delete_file]_

Clearly distinct now. Fixing the clock times too, so afternoon/evening screens don't show 06:07.

_[tool: grep]_

_[tool: run_script]_

_[tool: ready_for_verification]_

I haven't seen either change on the actual screens yet; they're out for a check now.

- **Afternoon background:** it now has a strong warm sunset look: terracotta and apricot fading to bright cream clouds, with a warm glow on the right. There's no blue left, so it's clearly different from the morning.
- **Greetings:** the pre-check-in screen now says "Good morning", "Good afternoon" and "Good evening" on each version. That was the only screen with a greeting.
- **Clock times:** on that screen the time changed with them (06:07, 13:40, 19:30), and I removed "06:07" from its title.

Other screens still show their original morning times (10:52, 11:02 and so on) in all three versions.

## User

Nope,  try a different background design for afternoon. I like the addition of more orange though in the current one

## Assistant

_[tool: run_script]_

_[tool: view_image]_

_[tool: delete_file]_

_[tool: ready_for_verification]_

The afternoon background is now a new design instead of a recoloured photo. I haven't seen it behind the actual screens yet; it's out for a check now.

- **The look:** a warm gradient, pale apricot at the top deepening to coral at the bottom, with soft haze bands near the horizon and a fine grain. It keeps the orange you liked.
- **The sun:** a glowing sun sits top right. That's roughly where it would be on a timeline that runs from morning at the top to evening at the bottom.
- **Fits the evening version:** it's made the same way as the evening night sky, so afternoon and evening feel like one set.

## User

The current vibe that the afternoon design is giving is like a desert. That's not what we are aiming for, we want something cozy.

## Assistant

_[tool: run_script]_

_[tool: view_image]_

_[tool: delete_file]_

_[tool: ready_for_verification]_

I've redone the afternoon background to feel cozier, like soft sunlight coming into a room. I haven't seen it behind the actual screens yet; it's out for a check now.

- **Colours:** cream and soft peach at the top, blending into blush pink and a dusty rose-mauve at the bottom. It's paler than the last version, with the harsh orange gone.
- **Light:** a warm honey glow in the top left, with faint diagonal beams, as if sun is coming through a window.
- **Texture:** a few large, soft blurred circles of light, plus a fine grain so it doesn't look flat.

If it's still not quite right, the easiest things to adjust are the amount of pink versus peach, or the strength of the light beams.

## User

That's much better.

## Assistant

Good, the cozy afternoon background stays. Next, I can update the colour list on the style sheet so it includes all three times of day, or warm up the afternoon wind-down and lock screens to match.

## User

Add the "Make one with AI" flow to the existing design, in the same style,
tokens and three time-of-day variants. The app is called Enso (replace
"Routine" everywhere).

1. Onboarding template step: add a row "Make one with AI" with a subtitle
   "Describe your day to any AI assistant, paste the result back", next to
   "Import a schedule file".
2. Schedule file screen: three actions, "Import file", "Paste from
   clipboard" and "Make one with AI".
3. New bottom sheet "Make one with AI" with three short numbered steps:
   copy the prompt, paste it into any AI assistant and describe your day,
   copy the answer back. Primary button "Copy prompt" with a gentle
   "Copied" confirmation, secondary button "Paste schedule".
4. Paste result states:
   - Valid: readable block summary (as on the schedule file screen) with
     "Use this schedule".
   - No schedule found: calm message that the copied text has no Enso
     schedule in it, with "Try again".
   - Errors: the existing error cards with line numbers and "Did you
     mean...?".
Keep it calm. No AI sparkle icons or gradients that break the existing look.

## Assistant

_[tool: grep]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: grep]_

_[tool: read_file]_

_[tool: run_script]_

_[tool: copy_files]_

_[tool: set_project_title]_

_[tool: ready_for_verification]_

I've added the "Make one with AI" flow, with all three time-of-day versions. I haven't seen the new screens rendered yet; they're out for a check now.

- **Onboarding:** a "Make one with AI" row with your subtitle now sits under "Import a schedule file", with a plain speech-bubble icon.
- **Schedule file:** "Import file" is the main button, with "Paste from clipboard" and "Make one with AI" side by side above it.
- **New section 07, Make one with AI:** the bottom sheet with three numbered steps, "Copy prompt" and "Paste schedule". I also drew the copied state: step 1 shows a check and the button softens to "Copied", then switches back after 2 seconds.
- **New section 08, Paste result:** three versions.
  - Valid: a blocks and rules summary with "Use this schedule".
  - No schedule found: a calm message with "Try again".
  - Errors: the existing error cards with line numbers and "Did you mean…?" suggestions.
- **Renamed to Enso:** the file is now `Enso App.dc.html`, and every mention of "Routine" in the design now says Enso. Settings and the later sections moved down by two numbers.

The project name couldn't be changed from here; it still shows as "Routine app design mockups", so rename it yourself if you want it to match. Several things in the flow are my own wording:
- The sheet's subtitle and the hints under each step.
- The extra error examples on lines 23 and 31.
- The "Cancel" and "See the steps" text buttons.

The sample file is still called `ansh-routine.md`, because "routine" there describes the user's own day, not the app.

