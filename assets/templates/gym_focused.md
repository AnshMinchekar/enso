# Gym-focused

Training first, meals around it, early nights. On a busy day, free time goes first, then mobility, the walk and the second work block.

```routine
bedtime: "22:00"
wake_target: "06:00"
day_types: [training, rest]

blocks:
  - {id: preworkout, name: Pre-workout snack, minutes: 15, only_on: [training], latest_start: "15:00", category: food}
  - {id: training, name: Training, minutes: 90, min: 60, priority: 3, only_on: [training], category: body}
  - {id: shower, name: Shower, minutes: 20, category: rest}
  - {id: breakfast, name: Breakfast, minutes: 30, category: food}
  - {id: work, name: Focus work, minutes: 180, min: 120, priority: 2, category: focus}
  - {id: lunch, name: Lunch, minutes: 45, category: food}
  - {id: walk, name: Walk, minutes: 30, min: 15, priority: 6, category: body}
  - {id: work_two, name: Focus work, minutes: 150, min: 60, priority: 5, category: focus}
  - {id: snack, name: Snack, minutes: 15, category: food}
  - {id: mobility, name: Mobility, minutes: 20, min: 10, priority: 7, category: body}
  - {id: free, name: Free time, minutes: 90, min: 0, priority: 9, category: rest, notify: false}
  - {id: dinner, name: Dinner, minutes: 45, category: food}
  - {id: winddown, name: Wind down, minutes: 60, category: rest}
```
