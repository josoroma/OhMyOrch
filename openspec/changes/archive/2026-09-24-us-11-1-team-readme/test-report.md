# Test Report — us-11-1-team-readme

Change: us-11-1-team-readme
Story: US-11.1
Verdict: pass
Coverage: 3/3 acceptance criteria evaluated

Backfilled acceptance record (2026-09-24, revision `ae11530`). Every row below was produced by
executing the command shown under Evidence Commands; the output is what was observed.
Regression-suite rows grep the output of one full suite run at this revision.

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | README explains installation | PASS | E-1 — inspection: README explains OpenSpec install, init for Claude Code, and workflow confirmation. Command and observed output under Evidence Commands. |
| 2 | README explains brownfield context and document-to-delivery flow | PASS | E-2 — inspection: README covers CODEBASE.md, PRD/SPECS generation, story selection, the opsx commands, and review/test loops. Command and observed output under Evidence Commands. |
| 3 | README explains resumption | PASS | E-3 — inspection: README explains resumption from repository artifacts. Command and observed output under Evidence Commands. |

## Evidence Commands

### E-1 — README explains installation

```bash
grep -nE '^## (1\. Install OpenSpec|2\. Initialize OpenSpec for Claude Code|3\. Enable the Verify Workflow)' README.md && grep -nF 'Confirm that `/opsx:verify` is available' README.md
```

```text
160:## 1. Install OpenSpec
174:## 2. Initialize OpenSpec for Claude Code
192:## 3. Enable the Verify Workflow
222:Confirm that `/opsx:verify` is available in Claude Code.
```

### E-2 — README explains brownfield context and document-to-delivery flow

```bash
grep -nE '^## ([5-9]|1[0-7])\. ' README.md && grep -nE 'changes requested --> Implementer|FAIL --> Implementer' README.md
```

```text
244:## 5. Bootstrap an Existing Codebase
329:## 6. Working with a Greenfield Project
370:## 7. Generate or Update PRD.md
406:## 8. Generate or Update SPECS.md
490:## 9. Before Starting Implementation
507:## 10. Start a Feature Iteration
526:## 11. Explore
548:## 12. Propose
570:## 13. Create the Planner Handoff
597:## 14. Implement
617:## 15. Review
656:## 16. Acceptance Test
... (3 more line(s))
```

### E-3 — README explains resumption

```bash
grep -nE '^## 18\. Resume Work in a New Claude Session' README.md && grep -nF 'scripts/status.sh --resume --change' README.md
```

```text
712:## 18. Resume Work in a New Claude Session
922:scripts/status.sh --resume --change <change-id>       # where to continue
936:$ scripts/status.sh --resume --change add-planner
```

## Result

All 3 criteria were exercised and passed. No criterion was scored without evidence.

## Handoff

All criteria pass. The change is eligible for the completion gate.
