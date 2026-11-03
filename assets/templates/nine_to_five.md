# 9 to 5

Fixed work hours with evenings free. On a busy day, free time goes first, then reading, then the gym.

```routine
bedtime: "23:00"
wake_target: "07:00"
day_types: [office, home, gym]

blocks:
  - {id: breakfast, name: Breakfast, minutes: 20, category: food}
  - {id: commute_in, name: Commute, minutes: 30, at: "08:30", only_on: [office], category: rest}
  - {id: work, name: Work, minutes: 480, at: "09:00", category: focus}
  - {id: commute_home, name: Commute home, minutes: 30, only_on: [office], category: rest}
  - {id: gym, name: Gym, minutes: 60, min: 40, priority: 5, only_on: [gym], latest_start: "20:00", category: body}
  - {id: dinner, name: Dinner, minutes: 45, category: food}
  - {id: free, name: Free time, minutes: 120, min: 0, priority: 9, category: rest, notify: false}
  - {id: reading, name: Reading, minutes: 30, min: 15, priority: 6, category: leisure}
  - {id: winddown, name: Wind down, minutes: 45, category: rest}
```
