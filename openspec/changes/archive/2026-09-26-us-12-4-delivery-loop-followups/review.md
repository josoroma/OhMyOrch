# Review — us-12-4-delivery-loop-followups

Change: us-12-4-delivery-loop-followups
Story: US-12.4
Verdict: pass
Blocking: None
Coverage: 4/4 acceptance criteria evaluated
OpenSpec verify: VERIFIED — `openspec validate us-12-4-delivery-loop-followups --strict` reports "Change 'us-12-4-delivery-loop-followups' is valid"; `openspec validate --all --strict` reports 23 passed, 0 failed. No blocking mismatch.

## Summary

The implementation satisfies all four acceptance criteria. The `stop` case in
`scripts/delivery.sh` now mirrors `block`: it probes the recorded target in a subshell
and, when the target no longer resolves, rewrites only the `Status`, `Reason`, and
`Updated` rows in place, preserving `Target`, `Started`, and `Notes`. The three
documentation corrections are accurate against the code they describe: the stall-limit
wording matches the `COUNT > MAX_STALLS` branch in `guard-delivery-loop.sh`, the two
added escalation causes exist in `derive_next`, and the `guard-archive.sh` index row
matches what the guard actually checks. No blocking findings.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| The stall limit is described accurately | PASS | `README.md` §18 no-progress row and `.claude/rules/delivery-loop.md` stop-condition table both say "blocked stop attempts", name the default (`3`) and the override (`--max-stalls <n>` / `DELIVERY_MAX_STALLS`); matches `guard-delivery-loop.sh:269` (`COUNT > MAX_STALLS`) |
| Every escalation cause is documented | PASS | `README.md` §18 `escalate` row lists all seven `derive_next` escalate branches, including "the gate reporter could not report" (`delivery.sh:407`) and "an unmapped gate" (`delivery.sh:424`) |
| Stop records a halt when the target no longer resolves | PASS | `scripts/delivery.sh:751-773`; throwaway-copy run: `stop` with `Target: US-9.9` exits 0, records `\| Status \| STOPPED \|`, preserves `Target`/`Started`, writes `Reason` |
| The script index describes the archive guard accurately | PASS | `scripts/README.md:25` reads "Reject archive while any completion condition is unmet \| US-8.2, US-10.1"; matches `guard-archive.sh` (delegates to `completion-gate.sh`, cites US-8.2 and US-10.1) |

## Blocking Issues

None.

## Observations

- **O-1 (environmental, not this change).** `scripts/test-completion.sh` reports 2
  failures on this machine — `openspec validate ran` and `invalid delta spec blocks` —
  because the `openspec` CLI is not on the default shell `PATH`. Both cases depend on
  `openspec validate`. This change does not touch `completion-gate.sh` or
  `test-completion.sh`, and both cases pass once `openspec` is on `PATH`. Not a finding
  against this change.
- **O-2 (scope-check default).** `scripts/check-scope.sh` with no `--diff` reports 294
  unaccounted files because the entire repository is untracked (`git diff HEAD` plus
  untracked files lists everything). Run with the change's explicit changed-file list,
  it reports `IN SCOPE` (6 changed, all predicted). Not a finding against this change.
- **O-3.** The `stop` fallback duplicates the `block` fallback's `awk` rewrite almost
  verbatim. A shared helper would remove the duplication, but the spec does not require
  it and the two branches differ in the status they write. Non-blocking.

## Handoff

No remediation requested. Control proceeds to acceptance testing.
