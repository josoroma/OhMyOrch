# CODEBASE — Currency Converter

Analyzed revision: fe7b6ae
Working tree: clean

This file describes the repository as it is at that revision. It follows the
`ohmyorch:codebase-analyst` format used by `/ohmyorch:analyze-codebase`. It is a
description of current state, not a source of product intent: that is [PRD.md](PRD.md)
and [SPECS.md](SPECS.md).

The converter it describes was built from those documents, one OpenSpec change per story,
with `/ohmyorch:deliver`; the walkthrough video "OhMyOrch 03"
shows the delivery. The code and the `openspec/` record it describes are in this folder.

## System Summary

A command-line currency converter in Node.js with no dependencies. `./convert <amount>
<from> <to>` gets the pair's rate from the Frankfurter API, keeps it in memory for the
day, and prints the converted amount with the rate and its date.

## Repository Map

| Path | Role |
|---|---|
| `convert` | Executable entry point (`#!/usr/bin/env node`). |
| `src/rates.js` | Gets a pair's rate from Frankfurter; keeps rates in memory by pair and day. |
| `src/convert.js` | Converts and rounds to the cent; formats the printed result. |
| `src/cli.js` | Parses `<amount> <from> <to>`, prints the result, returns the exit status. |
| `tests/` | `node:test` tests and `stub-api.js`, a stand-in for the API. |
| `openspec/specs/` | Merged specs: `exchange-rates`, `currency-conversion`. |
| `openspec/changes/archive/` | The four archived changes, one per delivered story. |
| `openspec/delivery/goal.md` | The last delivery goal (EPIC-2, BLOCKED). |
| `PRD.md`, `SPECS.md` | Product documents. |

## Runtime and Tooling

- Node.js 20 or later (`package.json` `engines`), ES modules (`"type": "module"`).
- No dependencies; the global `fetch` is used for HTTP.
- Tests: `node --test` through `npm test`.
- OpenSpec 1.13.2 project with the `spec-driven` schema (`openspec/config.yaml`).

## Architecture

Three small modules. `createRates({ fetch, today })` in `src/rates.js` returns
`getRate(base, quote)`; `fetch` and `today` are parameters so tests replace them.
`convert()` in `src/convert.js` asks it for a rate unless both currencies are the same.
`run()` in `src/cli.js` wires them for the command line.

## Entry Points

- `./convert <amount> <from> <to>`: exit status 0 on success, 1 for an unknown currency,
  2 for a missing argument.
- `npm test`.

## Data and Persistence

Rates are held in a `Map` keyed by `<BASE>/<QUOTE>/<YYYY-MM-DD>` (local date) for the
life of the process. No database and no files.

## External Integrations

- Frankfurter v2: `GET https://api.frankfurter.dev/v2/rate/{BASE}/{QUOTE}`, no API key.
  The response fields used are `rate` and `date`. HTTP 422 is read as an unknown
  currency; any other non-2xx status raises an error that is not handled.

## Authentication and Authorization

None.

## Existing Product Behavior

- `./convert 20 USD EUR` prints `<amount> EUR (1 USD = <rate> EUR on <date>)`.
- The same currency prints `<amount> <CODE> (same currency, no rate needed)` without
  calling the API.
- An unknown code prints `Unknown currency: <CODE>` and exits with status 1.
- A failing or unreachable API raises an uncaught error (US-2.3 is not decided).

## Tests and Quality Gates

12 tests in `tests/rates.test.js` and `tests/convert.test.js`, one per acceptance
scenario of US-1.1, US-1.2, US-2.1 and US-2.2, against `tests/stub-api.js`. They make no
network request. No linter or CI configuration is present.

## Common Commands

```bash
./convert 20 USD EUR
npm test
openspec list --specs
```

## Conventions

Small functions with injected dependencies; one test per scenario, named after it;
currency codes upper-cased at the boundary.

## Constraints and Technical Debt

- Behavior when the API fails is undefined until OQ-001 is answered.
- The in-memory cache does not outlive a single run of `./convert`.

## Evidence Paths

- `convert`, `src/rates.js`, `src/convert.js`, `src/cli.js`
- `tests/rates.test.js`, `tests/convert.test.js`, `tests/stub-api.js`
- `package.json`, `openspec/config.yaml`, `openspec/specs/*/spec.md`

## Unknowns

- How the converter should behave when the API is unavailable (OQ-001).
- Whether the default blended rates or one provider's rates are intended: the code uses
  the API's default.
