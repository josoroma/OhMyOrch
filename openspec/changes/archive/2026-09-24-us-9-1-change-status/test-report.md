# Test Report — us-9-1-change-status

Change: us-9-1-change-status
Story: US-9.1
Verdict: pass
Coverage: 2/2 acceptance criteria evaluated

Backfilled acceptance record (2026-09-24, revision `ae11530`). Every row below was produced by
executing the command shown under Evidence Commands; the output is what was observed.
Regression-suite rows grep the output of one full suite run at this revision.

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | Persist workflow state | PASS | E-1 — status.md records state, owner, and blockers, and preserves blockers across refreshes. Command and observed output under Evidence Commands. |
| 2 | Resume after session restart | PASS | E-2 — a new session reads status.md, names the first incomplete gate and owner, and detects staleness. Command and observed output under Evidence Commands. |

## Evidence Commands

### E-1 — Persist workflow state

```bash
scripts/test-status.sh | grep -E 'writes status.md|state reflects the failing gate|owner is the gate.s owner|blocker survives refresh'
```

```text
ok    writes status.md                                       exit=0
  ok    state reflects the failing gate                        found
  ok    owner is the gate's owner                              found
  ok    blocker survives refresh                               found
```

### E-2 — Resume after session restart

```bash
scripts/test-status.sh | grep -E 'resume names the (gate|owner)|advanced change makes status stale|refresh resolves the staleness'
```

```text
ok    advanced change makes status stale                     exit=1
  ok    refresh resolves the staleness                         exit=0
  ok    resume names the gate                                  found
  ok    resume names the owner                                 found
```

## Result

All 2 criteria were exercised and passed. No criterion was scored without evidence.

## Handoff

All criteria pass. The change is eligible for the completion gate.
