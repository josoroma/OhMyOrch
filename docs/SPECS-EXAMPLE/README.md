# Currency Converter

This is the example project of the OhMyOrch [SPECS workspace](../../SPECS-APP.hml) and of the
walkthrough video "OhMyOrch 03". It is a small command-line
currency converter, specified in [PRD.md](PRD.md) and [SPECS.md](SPECS.md) and delivered with
OhMyOrch, one OpenSpec change per story. The record of each change is in
`openspec/changes/archive/`, the merged specs are in `openspec/specs/`, the last delivery goal is
`openspec/delivery/goal.md`, and [CODEBASE.md](CODEBASE.md) describes the delivered code.

```bash
./convert 20 USD EUR
```

prints the amount at today's reference rate from [Frankfurter](https://frankfurter.dev/),
with the rate and its date. Rates are kept in memory only. It needs Node.js 20 or later
and has no dependencies.

```bash
npm test
```

runs the tests against a stubbed API, so they need no network.

What the converter does when the API is unavailable is still an open question
(US-2.3 in SPECS.md).

## How it was delivered

The project was a separate Git repository, initialized with the plugin's `bootstrap --with-openspec`
and delivered with the plugin's `delivery` CLI, OpenSpec 1.13.2 and the plugin's Stop hook,
following the `deliver` skill. Its history, oldest first:

| Commit | What happened |
|--------|---------------|
| Start the currency converter | An empty project with this README |
| Initialize OhMyOrch and specify the converter | Bootstrap, then PRD.md and SPECS.md: two epics, five stories |
| US-1.1 Fetch a daily rate | Change `us-1-1-fetch-daily-rate`: proposal, delta adding `exchange-rates`, design, tasks; code and tests; archived; DONE |
| US-1.2 Keep rates in memory | Change `us-1-2-keep-rates-memory`: one requirement added to `exchange-rates`; EPIC-1 COMPLETE |
| US-2.1 Convert an amount | Change `us-2-1-convert-amount`: delta adding `currency-conversion` |
| US-2.2 Show the rate and its date | Change `us-2-2-show-rate-date`: delta MODIFYING "Print the result"; OpenSpec refused a first draft that dropped a scenario |
| EPIC-2 delivery stopped | US-2.3 is NEEDS CLARIFICATION: the loop escalated and the goal was recorded BLOCKED |
| Describe the project, CODEBASE.md, corrections | This README, a CODEBASE.md in the analyst's format, the rate-source wording, a path in the archived US-1.1 proposal |

The Git history itself is not kept here. The `CLAUDE.md` block and the `.claude/ohmyorch/` files
that bootstrap created are left out too: they are scaffolding the plugin writes in any project.
