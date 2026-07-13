# Training Plan Requirements

## Starting Weekly Split

| Day | Session |
| --- | --- |
| Monday | Chest + triceps |
| Tuesday | Back + biceps, followed by swimming |
| Wednesday | Legs |
| Thursday | Swimming |
| Friday | Upper body |
| Saturday | Arms, followed by swimming |
| Sunday | Swimming |

This is the user's editable starting split. It is not yet implemented in the app.

## Manual Schedule Editing

The user must be able to change the routine without asking Coach:

- rename a session,
- move or copy a session to another day,
- add, remove, or reorder strength and swimming sessions,
- add a rest or recovery day,
- add, remove, substitute, and reorder exercises,
- edit sets, rep ranges, target effort, rest time, and notes,
- make a one-day exception without changing the repeating routine,
- pause a session for a date range,
- save the result as a new routine version,
- restore an earlier routine version.

Manual edits should show a summary before saving when they materially increase weekly volume or remove the only recovery day. They do not require AI approval; the user remains in control.

## Session Guidance

Each strength session should show:

- warm-up guidance,
- exercise order and substitutions,
- working sets and rep ranges,
- target RIR or RPE,
- rest time,
- technique notes,
- a progression rule based on recent completed sets.

Swimming sessions should record duration, distance when available, and easy/moderate/hard intensity. The routine contains nine weekly training exposures across seven days, so recommendations must consider accumulated fatigue rather than treating each session independently.

The app should not guess starting weights without performance history. It should suggest a rep range and effort target, let the user log the achieved load/reps, and then use a conservative double-progression rule for the next session.

## Coach Change Workflow

1. Coach reviews goals, experience, equipment, limitations, recent performance, sleep, soreness, adherence, and swimming load.
2. Coach returns a structured pending proposal.
3. The app displays exact before/after changes, reasons, and recovery impact.
4. The user selects Confirm, Edit, or Reject.
5. Confirm creates a new active routine version. Reject changes nothing. Edit creates a revised proposal for confirmation.
6. Previous routine versions remain available for review and rollback.

Coach chat must never silently modify the active routine.
