# Guardias

Desktop app to manage the duty (guard) calendar of a team.

## Workers

- [ ] Add, edit and delete workers
- [ ] Order the workers list manually (this order drives auto-assignment)
- [ ] Two-step removal: a worker is first laid off, and only then can be deleted
  - **Layoff:** keeps past assignments; deletes future assignments (including the current day) and the worker's absences
  - **Deletion:** only available for laid-off workers; deletes all their assignments, past included

## Calendar

- [ ] Monthly view with navigation by month and year
- [ ] Assign one worker to a day (a day has at most one worker)
- [ ] Remove the assignment of a day

## Absences

- [ ] Define vacation periods (date range) for a worker
- [ ] Define license periods (non-paid, date range) for a worker
- [ ] Notify the user when a worker is assigned to a day of their vacation or license
  - when assigning: ask for confirmation, and allow it if confirmed
  - when defining an absence over existing assignments: say how many days conflict
  - keep conflicting days marked in the calendar until resolved

## Auto-assignment

Typical flow: the user assigns a worker to the first day, then runs auto-assignment to fill the rest of the month following the workers list order.

- [ ] Fill the current month, from the selected day to the end of the month
- [ ] Follow the order of the workers list, cycling back to the first after the last
- [ ] For each day, infer the next worker from the previous day's assignment; if there is none, or that worker is no longer active (laid off), start with the first worker in the list
- [ ] Skip workers who are absent that day
- [ ] Two modes:
  - **Fill empty days** (default): keeps existing assignments and continues the order from them
  - **Replace from this day**: overwrites the existing assignments from the selected day to the end of the month (e.g. after changing the order); asks for confirmation saying how many assignments will be replaced
- [ ] Never touch days before the selected day

## Summary

- [ ] Panel with the working days of the current month for each active (not laid-off) worker
- [ ] Show vacation and license days of the month next to them
