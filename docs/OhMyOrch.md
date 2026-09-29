---
title: OhMyOrch Harness
description: A text-only Luma-style slide deck for the OhMyOrch Claude harness.
---

# OhMyOrch Harness

A portable Claude harness for spec-driven delivery.

OhMyOrch turns product intent, codebase context, and an OpenSpec backlog into small reviewed, tested, archived changes.

---

## Table of Contents

1. Why it exists
2. What it installs
3. Entry workflows
4. The delivery loop
5. Worked example: EPIC-12
6. Role separation
7. Files as handoffs
8. Hooks and gates
9. Namespaced distribution
10. Post-install adaptation
11. Reset and recovery
12. What developers get

---

## Why It Exists

Modern coding agents are good at motion. OhMyOrch makes that motion accountable.

| Friction | OhMyOrch response |
| --- | --- |
| Product intent gets mixed with code guesses | `PRD.md` and `SPECS.md` are written from product sources; `CODEBASE.md` is evidence only. |
| One session plans, implements, reviews, and approves itself | Separate agents own planning, implementation, review, and test artifacts. |
| Work disappears into chat history | Every handoff is a file under `openspec/changes/` or a root product document. |
| Done is ambiguous | `Status: DONE` requires review, test, completion evidence, archive, and synced specs. |

---

## What It Installs

The harness is a `.claude` operating layer with repo-local scripts and docs.

| Layer | Examples | Purpose |
| --- | --- | --- |
| Agents | `ohmyorch-planner`, `ohmyorch-implementer`, `ohmyorch-reviewer`, `ohmyorch-tester` | Keep duties separate. |
| Skills | `ohmyorch-deliver`, `ohmyorch-ingest-spec`, `ohmyorch-post-install` | Package reusable workflows. |
| Commands | `/ohmyorch:opsx:propose`, `/ohmyorch:opsx:apply`, `/ohmyorch:opsx:archive` | Give developers short operational entry points. |
| Rules | `ohmyorch-testing.md`, `ohmyorch-team-responsibilities.md` | Make standards durable. |
| Hooks | `PreToolUse`, `PostToolUse`, `Stop` | Block unsafe transitions before they land. |
| Scripts | `guard-*.sh`, `validate-*.sh`, `test-*.sh` | Make the harness testable outside chat. |

---

## Entry Workflows

Choose the path by repository state.

| Starting point | Run | Guard expectation |
| --- | --- | --- |
| Greenfield, no code | `/ohmyorch-generate-prd`, then `/ohmyorch-ingest-spec` | `CODEBASE Context: absent` is valid. |
| Brownfield, no PRD | `/ohmyorch-analyze-codebase`, then `/ohmyorch-generate-prd`, then `/ohmyorch-ingest-spec` | `CODEBASE Context: consumed` or an explicit skip. |
| PRD exists | `/ohmyorch-ingest-spec` | Product intent is already available. |
| SPECS exists | `/ohmyorch-product-iteration` or `/ohmyorch-deliver` | Pick a READY story and create one OpenSpec change. |

---

## The Delivery Loop

`/ohmyorch-deliver <EPIC-N | US-N.M | US-N.M#k | "task text">` runs the `ohmyorch-deliver` skill. The main session is the orchestrator, acting as the Product Manager. It delivers each story of the target as its own OpenSpec change, in `SPECS.md` order.

```text
Step 0  scripts/delivery.sh resolve <target>; scripts/delivery.sh start <target>   -> goal.md ACTIVE
Step 1  scripts/delivery.sh next        -> one action, its owner, its command (derived, never remembered)
Step 2  delegate the action to its owner, then:
        scripts/status.sh --change <id> --quiet; scripts/delivery.sh refresh
Step 3  repeat; the Stop hook guard-delivery-loop.sh refuses to end the turn while work remains
```

| Action | Owner | How |
| --- | --- | --- |
| `select` | Product Manager (main session) | `openspec new change <id>`, story `IN PROGRESS` |
| `propose`, `plan` | `ohmyorch-planner` | `/ohmyorch:opsx:explore`, `/ohmyorch:opsx:propose`, `/ohmyorch-plan-feature` |
| `implement` | `ohmyorch-implementer` | `/ohmyorch:opsx:apply` |
| `review` | `ohmyorch-reviewer` | `/ohmyorch-review-feature` (records `/ohmyorch:opsx:verify`) |
| `test` | `ohmyorch-tester` | `/ohmyorch-test-feature` |
| `reopen` | Product Manager | `scripts/delivery.sh reopen`: verdict to `history/`, one task per finding |
| `archive`, `mark-done` | Product Manager | `completion-gate.sh --record`, `openspec archive`, story `DONE` (guarded) |
| `escalate` / `complete` | human / — | goal `BLOCKED` with a reason / goal `COMPLETE` |

The orchestrator never writes `review.md` or `test-report.md`, and no gate has a loop exception.

---

## Worked Example: EPIC-12

EPIC-12 built the loop, then the loop delivered the rest of the epic. The run is recorded in `SPEC-LOGS/README-EPIC-12.md`. After a harness reset it is kept in git history at `34008f3`.

```text
start EPIC-12                 goal ACTIVE; US-12.1 already DONE
US-12.2  select -> propose -> plan -> implement -> review r1 -> R1.1-R1.4 -> review r2
         -> test 6/6 -> archive -> mark-done
US-12.3  select -> propose -> plan -> implement -> review -> test 2/2 -> archive -> mark-done
US-12.4  select -> propose -> plan -> implement -> review -> test 4/4 -> archive -> mark-done
next -> complete              goal COMPLETE
```

| Story | Tasks | Review rounds | Scenarios |
| --- | ---: | ---: | ---: |
| US-12.1 | 15 | 3 | 6/6 |
| US-12.2 | 17 | 2 | 6/6 |
| US-12.3 | 10 | 1 | 2/2 |
| US-12.4 | 8 | 1 | 4/4 |

The implementer subagent cannot write `scripts/` or `.claude/`, so for this harness-on-harness epic the main session implemented each change. Planning, review, and testing stayed with separate subagents.

---

## Role Separation

OhMyOrch treats self-approval as a defect.

| Role | Owns | Must not own |
| --- | --- | --- |
| Product Manager | Story selection, status, archive decision | Implementation, review, or test evidence |
| Planner | `proposal.md`, `tasks.md`, `implementation-plan.md` | Product source, code, review, test |
| Implementer | Product code, local tests, task ticks | Review or acceptance verdict |
| Reviewer | `review.md` | Implementation or test verdict |
| Tester | `test-report.md` | Implementation or review verdict |

Write-scope hooks enforce the boundary for the implementation, review, and test agents.

---

## Files as Handoffs

There is no hidden relay.

| Artifact | Written by | Read by | Why it matters |
| --- | --- | --- | --- |
| `CODEBASE.md` | Codebase Analyst | Product Specifier, Spec Ingestor | Existing-code evidence. |
| `PRD.md` | Product Specifier | Spec Ingestor | Product intent. |
| `SPECS.md` | Spec Ingestor, Product Manager | Delivery workflows | Backlog and status source. |
| `implementation-plan.md` | Planner | Implementer | Prevents unplanned code writes. |
| `review.md` | Reviewer | Product Manager | Independent engineering judgment. |
| `test-report.md` | Tester | Product Manager | Acceptance evidence. |
| `completion.md` | Product Manager | Archive guard | Final proof before DONE. |

---

## Hooks and Gates

Hooks make the rules executable.

| Event | Guard or validator | Blocks or reports |
| --- | --- | --- |
| `PreToolUse` on writes | `guard-planning-handoff.sh` | Product code before an implementation plan. |
| `PreToolUse` on PRD/SPECS writes | `guard-context-preflight.sh` | Product docs without valid codebase context. |
| `PreToolUse` on story status | `guard-story-done.sh` | `Status: DONE` before archive. |
| `PostToolUse` on product docs | `validate-product-artifacts.sh` | Malformed PRD, SPECS, or Gherkin criteria. |
| `Stop` | `guard-delivery-loop.sh` | Ending while an active delivery goal still has work. |

Guards block with exit code `2`; validators report malformed artifacts and keep the failure visible.

---

## Namespaced Distribution

The harness is designed to install into repositories that may already have Claude customizations.

| Surface | Namespacing rule |
| --- | --- |
| Agents | Use `ohmyorch-*` filenames and names. |
| Skills | Use `.claude/skills/ohmyorch-*`. |
| Commands | Use `.claude/commands/ohmyorch/...` and `/ohmyorch:*` command names. |
| Rules | Use `.claude/rules/ohmyorch-*.md`. |
| Scripts | Keep stable generic launchers only when required; harness internals remain under namespaced `.claude` skills or documented scripts. |
| Backups | Write pre-install backups to `docs/pre-install-backup/`. |

The install path is additive by default and avoids overwriting unrelated `.claude` agents, skills, commands, rules, and hooks.

---

## Post-Install Adaptation

After distribution, `/ohmyorch:post-install` adapts the harness to the host repository.

1. Back up current `.claude`, `README.md`, `CLAUDE.md`, and supported docs into `docs/pre-install-backup/`.
2. Read `PRD.md`, `CODEBASE.md`, and `SPECS.md` when present.
3. Update `.claude` rules to reflect the repository's standards and validation approach.
4. Create or refresh root `CLAUDE.md`, nested `CLAUDE.md` files, and README guidance.
5. Validate frontmatter, product artifacts, hooks, and fast project checks.

The goal is local fit without losing the collision guarantees of namespacing.

---

## Reset and Recovery

OhMyOrch can return itself to a canonical empty harness state.

| Operation | Behavior |
| --- | --- |
| `scripts/harness-reset.sh --dry-run` | Reports the root, backup path, and planned changes. |
| `scripts/harness-reset.sh` | Backs up first, verifies the manifest, then restores canonical harness files. |
| Backup location | `docs/resets/<timestamp>/` for reset; `docs/pre-install-backup/` for install adaptation. |
| Preservation | Host source, page docs, images, and configured preserved files stay outside reset scope. |

The reset is intentionally conservative: if backup verification fails, the tree is left unchanged.

---

## What Developers Get

OhMyOrch is not a bigger prompt. It is a working agreement encoded as files, commands, and tests.

| Developer need | Harness answer |
| --- | --- |
| "Where do I start?" | Follow the entry workflow based on PRD, CODEBASE, and SPECS state. |
| "What is being built?" | Read READY stories in `SPECS.md` and the active OpenSpec change. |
| "Who approved this?" | Review `review.md`, `test-report.md`, `completion.md`, and archive history. |
| "Can I ship this?" | Run the validators and confirm archive plus `Status: DONE`. |

The result is a repo that can explain what it is doing while it is doing it.
