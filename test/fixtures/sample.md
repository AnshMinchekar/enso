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
