# Change Status — malformed-change

<!--
INVALID FIXTURE — several independent contract violations:

  * State is "ALMOST_DONE", which is not in the defined change-state vocabulary.
    Inventing intermediate states is explicitly prohibited.
  * The Gates table has six rows, not seven: gate 4 (implementation) is missing,
    so the table cannot be read positionally.
  * The Blockers section has no AUTHORED markers, so a refresh would destroy it.
  * The Resume line is absent entirely.
-->

| Field | Value |
|---|---|
| Story | not-a-story-id |
| Change | malformed-change |
| State | ALMOST_DONE |
| Updated | 2026-09-24 |

## Gates

| # | Gate | Status | Detail | Owner |
|---|---|---|---|---|
| 1 | selection | pass | change exists | ohmyorch:product-manager |
| 2 | planning | pass | proposal.md, specs/, tasks.md present | ohmyorch:planner |
| 3 | plan-handoff | pass | plan satisfies the contract | ohmyorch:planner |
| 5 | review | fail | review.md missing | ohmyorch:reviewer |
| 6 | testing | fail | test-report.md missing | ohmyorch:tester |
| 7 | acceptance | fail | artifact contracts not yet satisfied | ohmyorch:product-manager |

## Blockers

The CI runner is down.
