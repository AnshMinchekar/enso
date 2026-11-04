# Student

A day built around lectures and study. On a busy day, breaks and free time go first, then reading and the second study block.

```routine
bedtime: "23:30"
wake_target: "08:00"
day_types: [lectures, gym, rest]

blocks:
  - {id: breakfast, name: Breakfast, minutes: 25, category: food}
  - {id: walk_in, name: Walk to campus, minutes: 25, only_on: [lectures], category: rest}
  - {id: lectures, name: Lectures, minutes: 180, only_on: [lectures], category: focus}
  - {id: lunch, name: Lunch, minutes: 45, category: food}
  - {id: study, name: Study block, minutes: 120, min: 60, priority: 2, skip_on: [rest], category: focus}
  - {id: break, name: Break, minutes: 20, min: 0, priority: 9, category: rest, notify: false}
  - {id: gym, name: Gym, minutes: 75, min: 45, priority: 5, only_on: [gym], latest_start: "20:00", category: body}
  - {id: study_two, name: Study block, minutes: 90, min: 30, priority: 4, skip_on: [rest], category: focus}
  - {id: dinner, name: Dinner, minutes: 45, category: food}
  - {id: free, name: Free time, minutes: 120, min: 0, priority: 9, category: rest, notify: false}
  - {id: reading, name: Reading, minutes: 30, min: 15, priority: 6, category: leisure}
  - {id: winddown, name: Wind down, minutes: 45, category: rest}
```
