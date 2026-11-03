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
