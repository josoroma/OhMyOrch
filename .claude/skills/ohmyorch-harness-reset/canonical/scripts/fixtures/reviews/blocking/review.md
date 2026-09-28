# Review — add-ohmyorch-codebase-analyst

Change: add-ohmyorch-codebase-analyst
Story: US-2.1
Verdict: changes-requested
Blocking: 2 findings
Coverage: 2/3 acceptance criteria evaluated

## Findings

### Finding F-1: analyst can write product code

Requirement: Scenario: Analyze an existing codebase — "it MUST NOT modify application source code"
Observed: the `tools` list includes `Write` and `Edit`, so the agent can modify source.
Expected: the tool list omits `Write` and `Edit`, making the boundary structural.
Remediation: remove `Write` and `Edit` from the frontmatter `tools` field and rely on the invoking skill to write CODEBASE.md.

### Finding F-2: evidence rule is unenforceable as written

Requirement: Scenario: Keep codebase claims evidence-backed
Observed: the prompt says "cite evidence" without defining what counts as evidence.
Expected: an explicit table of acceptable evidence per claim type.
Remediation: add the evidence-discipline table mapping claim types to acceptable evidence.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| Analyze an existing codebase | FAIL | `tools` includes Write/Edit — see F-1 |
| Keep codebase claims evidence-backed | FAIL | no evidence definition — see F-2 |
| Existing behavior is not promoted to product intent | PASS | §Core rules 2 and 3 |

## Handoff

Control returns to the Implementer. Both findings are blocking; the third scenario
was not affected and passed.
