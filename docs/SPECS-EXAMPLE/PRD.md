# PRD — PocketTasks

CODEBASE Context: consumed (pockettasks-docs-v1)

This is an illustrative project, not a specification for OhMyOrch. It follows the
`ohmyorch:product-specifier` format used by `/ohmyorch:generate-prd`. Read it alongside
[CODEBASE.md](CODEBASE.md) and [SPECS.md](SPECS.md).

## Example Product Brief

Build a small personal task list on one browser page. A person can add a task,
complete it, and reopen it. The page starts empty. Tasks exist only until the page
is reloaded; there are no accounts, remote services, or saved data.

The title input is labelled "Task title". Clicking "Add task" or pressing Enter in
that input adds the trimmed title at the bottom of the list and clears the input.
Empty or whitespace-only titles produce "Enter a task." without adding an item.
Titles appear as plain text. Duplicate titles are allowed as separate tasks.

Each new task has an unchecked completion checkbox and an "Active" label. Checking
it changes its label to "Done"; unchecking it restores "Active". Completing a task
does not remove it or change its position. Each checkbox is labelled with its task
title and works with the keyboard, including Space to toggle it.

These example product decisions are the source of the requirements below. They are
not claims that a human has approved a real application or that any work is done.

## 1. Product Summary

PocketTasks helps one person keep a short task list during a browser session.

## 2. Problem

Someone needs a quick place to record a few tasks and see which are finished.

## 3. Goals

- Add tasks without leaving the page.
- Complete and reopen individual tasks.

## 4. Non-Goals

Accounts, persistence, synchronization, editing, deletion, filtering, due dates,
notifications, and collaboration.

## 5. Users and Actors

One person using the page with a mouse or keyboard. No administrative role.

## 6. Product Principles

| ID | Rule | Source |
|---|---|---|
| BR-001 | Trim titles; reject empty results with "Enter a task." | [Example Product Brief](#example-product-brief) |
| BR-002 | Allow duplicate titles as independent tasks; preserve insertion order. | [Example Product Brief](#example-product-brief) |
| BR-003 | Reloading starts a new, empty list. | [Example Product Brief](#example-product-brief) |

## 7. Core Workflow

Open the page → add a task → mark it Done → optionally reopen it.

## 8. Functional Requirements

| ID | Required behavior | Source |
|---|---|---|
| FR-001 | Show a labelled title input and "Add task" button. Accept click or Enter submission. Add each valid, trimmed title as plain text at the end of the list, initially Active with an unchecked checkbox. Clear the input after a successful addition; reject invalid titles as BR-001 specifies. | [Example Product Brief](#example-product-brief) |
| FR-002 | Check a task to show Done; uncheck it to show Active. Keep its title and position, and leave other tasks unchanged, including tasks with identical titles. | [Example Product Brief](#example-product-brief) |

## 9. Non-Functional Requirements

| ID | Required behavior | Source |
|---|---|---|
| NFR-001 | Run on one browser page with in-memory task state. Require no login, remote service, or persistent storage. Start empty on reload. | [Example Product Brief](#example-product-brief) |
| NFR-002 | Label the input and each completion checkbox. Support Enter to add and Space to toggle a focused checkbox. | [Example Product Brief](#example-product-brief) |

## 10. Current-State Context

[CODEBASE.md](CODEBASE.md) describes a documentation-only starting snapshot. It
contains no PocketTasks application, test suite, or implemented capabilities.
Publisher tooling in the surrounding OhMyOrch repository is not this application's
runtime. The brief above supplies desired behavior; the codebase report does not.

## 11. Constraints and Dependencies

Epic 1 provides task creation. Epic 2 depends on Epic 1 being delivered and archived.
Implementation details and test tooling will be selected during planning; no
existing stack or application commands are claimed.

## 12. Gaps Between Current State and Desired Behavior

Both functional requirements are unimplemented. No execution or acceptance evidence
exists for this sample.

## 13. Open Questions

None for this illustrative scope. For a real project, get approval of the brief
before treating its stories as READY. Analyze the actual application once code
exists, and regenerate the context markers against that real snapshot.
