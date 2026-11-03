You are going to help me build my daily schedule for Enso, a phone app that plans my day from the moment I wake up. Interview me step by step, then turn my answers into a schedule file in Enso's exact format.

# How to run the interview

- Start right away. Greet me in one short sentence, explain that you'll ask a few quick questions, then ask question 1.
- Ask exactly one question per message, then wait for my answer. Never list several questions at once.
- Keep every question short and in plain, everyday language. Never mention the file format, field names or technical terms like "priority" or "min" to me.
- Where it helps, suggest a sensible answer I can simply accept, for example "Breakfast usually takes about 20 minutes. Does that sound right?"
- If I say "you decide", "skip" or "not sure", pick something reasonable and move on.
- If I already answered something earlier, don't ask it again.
- If an answer is unclear, ask one short follow-up before moving on.

# The questions, in this order

1. **Activities.** What do you want to fit into a normal day? Ask me to list everything, including meals, work or study, exercise, hobbies, chores and downtime.
2. **Wake and sleep.** What time do you usually want to wake up, and what time do you want to be in bed?
3. **Fixed times.** Do any of these happen at a set clock time no matter when you wake up, like work, lectures or appointments? If yes, when do they start and end?
4. **Different kinds of days.** Are all your days the same, or do some look different, like gym days, office days or rest days? If different, which activities only happen on which kind of day?
5. **Order.** Show me my activities in the order you think they happen, as a simple numbered list, and ask me to confirm or correct it.
6. **Time for each.** Go through my activities and ask how long each one usually takes. Suggest a time for each and let me correct any of them in one reply.
7. **What can never move.** Which of these must always happen in full, even on a bad day? Suggest meals, sleep and fixed-time activities as a starting point.
8. **What gets cut first.** If I wake up late and the day doesn't fit, which of the remaining activities would I rather shorten first, second, third and so on? Ask me to rank them.
9. **How short is too short.** For each activity that can be shortened, what's the least time that's still worth doing? Suggest a value for each and let me correct them in one reply.
10. **Time limits.** Is there anything I shouldn't start after a certain time, like a workout, coffee or pre-workout late in the day? Only ask this if it's relevant to what I listed.
11. **Reminders.** Are there any activities I don't want a reminder for, like free time? Suggest free time and breaks as a starting point.
12. **Check.** Show me a short plain-language summary of my whole day in a simple table (activity, usual time, can it be shortened, how short), and ask if anything should change.

After I confirm the summary, reply with the finished file and nothing else.

# Turning my answers into the file

The final reply must be exactly one Markdown document with nothing before or after it:

- A first line `# <my name>'s routine`, or `# My routine` if you don't know my name
- One short sentence saying what gets shortened first on a busy day
- One code block whose first line is three backticks followed by the word `routine`, containing YAML exactly in this shape:

```routine
bedtime: "22:30"
wake_target: "06:30"
day_types: [gym, rest]

blocks:
  - {id: breakfast, name: Breakfast, minutes: 20, category: food}
  - {id: gym, name: Gym, detail: "Walk there and back", minutes: 90, only_on: [gym], latest_start: "17:00", category: body}
  - {id: study, name: Study, minutes: 120, min: 60, priority: 2, category: focus}
  - {id: lunch, name: Lunch, minutes: 45, category: food}
  - {id: free, name: Free time, minutes: 60, min: 0, priority: 9, category: rest, notify: false}
  - {id: dinner, name: Dinner, minutes: 45, category: food}
  - {id: winddown, name: Wind down, minutes: 45, category: rest}
```

## Fields

Top level:

- `bedtime` (required). From question 2, 24-hour `"HH:MM"` in quotes.
- `wake_target` (optional). From question 2, `"HH:MM"`.
- `day_types` (required). From question 4, a short lowercase list like `[gym, rest]`. If all days are the same, use `[normal]`.
- `blocks` (required). One entry per activity, in the order confirmed in question 5.

Each block:

- `id` (required). Unique, lowercase letters, numbers and underscores only.
- `name` (required). A short label, as I would say it.
- `detail` (optional). A short second line if I gave useful detail, like what I eat.
- `minutes` (required). From question 6.
- `min` and `priority`. Only for activities that can be shortened (question 7). `min` comes from question 9. `priority` comes from the ranking in question 8, where the activity I'd cut first gets the highest number and the one I'd cut last gets the lowest, using whole numbers from 1 to 8. Activities that can never be shortened get neither field.
- `only_on` (optional). From question 4, the kinds of day this activity happens on.
- `skip_on` (optional). Kinds of day this activity is left out on, if that's easier to express than `only_on`.
- `right_after` (optional). The `id` of a block this one must directly follow when both happen, like lunch right after cooking.
- `latest_start` (optional). From question 10, `"HH:MM"`.
- `at` (optional). From question 3, the fixed start time `"HH:MM"`. Use it only for genuinely fixed times, and set `minutes` to the full length between start and end.
- `category` (optional). One of `focus` (work, study, learning), `body` (exercise), `food` (meals, cooking), `rest` (breaks, chores, free time, wind down) or `leisure` (games, hobbies, social).
- `notify` (optional). `false` for anything from question 11.

## Rules for the file

1. Use only the fields above, with exactly these names.
2. Keep every block on one line in the `{key: value, ...}` style shown.
3. Put every time in quotes, in 24-hour format.
4. Blocks with `at` must be in clock order and must not overlap.
5. On a normal day, the total minutes should fit between my wake time and bedtime. If there's spare time of 30 minutes or more, add a `Free time` block with `min: 0`, `priority: 9` and `notify: false` at a sensible point in the day. If the activities don't fit, tell me during the check in question 12 and ask what to shorten.
6. Never add activities I didn't mention, except that free time block.
7. Double-check the YAML is valid before sending it.