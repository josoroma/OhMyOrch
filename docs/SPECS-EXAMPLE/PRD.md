# PRD — Currency Converter

CODEBASE Context: consumed (fe7b6ae)

This is an illustrative project. It follows the `ohmyorch:product-specifier` format
used by `/ohmyorch:generate-prd` and is the product source of [SPECS.md](SPECS.md).
The converter was built from these documents, one OpenSpec change per story, with
`/ohmyorch:deliver`; the walkthrough video "OhMyOrch 03"
shows the delivery. Its code and its `openspec/` record are in this folder: see [README.md](README.md).

## Example Product Brief

Build a small command-line currency converter. `convert 20 USD EUR` prints 20 US
dollars in euros, using today's rate from Frankfurter, a free exchange-rate API of daily
reference rates from central banks that needs no API key.

Rates are kept in memory only: there is no database and nothing is written to disk.
Asking for the same pair again on the same day uses the rate already in memory
instead of calling the API. An unknown currency code gives a clear error. Amounts are
rounded to the cent. Converting a currency to itself returns the amount without
calling the API. The result shows the rate used and the date of that rate.

What the converter does when the API is unavailable is not decided yet.

## 1. Product Summary

Currency Converter converts an amount between two currencies at today's reference
rate, from a terminal.

## 2. Problem

Converting an amount usually means opening a website. A command that prints the
converted amount, with the rate and its date, is faster and shows where the number
comes from.

## 3. Goals

- Convert an amount between two currencies at today's reference rate.
- Show which rate was used and from which day.
- Call the rate API no more than needed.

## 4. Non-Goals

- Storing rates or results across runs: no database, no files.
- Historical rates, charts or rate alerts.
- Accounts, configuration or API keys.
- Converting more than one pair per command.

## 5. Users and Actors

- A person at a terminal who types one conversion at a time.
- Frankfurter, the external rate API.

## 6. Product Principles

- BR-001: A currency code is three letters; input is case-insensitive and shown in
  upper case.
- BR-002: A converted amount is rounded to the nearest cent; a half cent rounds up.
- BR-003: A rate fetched today is reused for the rest of the day while the program
  runs.
- BR-004: Converting a currency to itself needs no rate.

## 7. Core Workflow

1. The person runs `convert <amount> <from> <to>`.
2. The converter gets today's rate for the pair, from memory or from the API.
3. It prints the converted amount, the rate and the rate's date.

## 8. Functional Requirements

- FR-001: Fetch today's rate for a currency pair from Frankfurter.
- FR-002: An unknown currency code is reported as `Unknown currency: <CODE>`, with no
  converted amount.
- FR-003: Keep fetched rates in memory; asking for the same pair again on the same
  day does not call the API.
- FR-004: Convert an amount at the pair's rate, rounded to the cent; converting a
  currency to itself returns the amount without calling the API.
- FR-005: Show the rate and its date with the result. This changes the output
  required by FR-004.
- FR-006: Behavior when the API is unavailable: not decided (OQ-001).

## 9. Non-Functional Requirements

- NFR-001: Memory only: no database and no files.
- NFR-002: No API key or account.
- NFR-003: Tests use a stubbed API, run offline and are repeatable.
- NFR-004: Runs on Node.js 20 or later with no dependencies.

## 11. Constraints and Dependencies

- Frankfurter v2: `GET https://api.frankfurter.dev/v2/rate/{base}/{quote}` returns
  `{"date", "base", "quote", "rate"}`; an invalid currency returns HTTP 422 with
  `{"status": 422, "message": "invalid currency: XYZ"}`.
- These are reference rates, not live market quotes. By default Frankfurter blends the
  rates of its providers; the European Central Bank is one of them.

## 13. Open Questions

- OQ-001: When the API is unavailable, should the converter use the last known rate
  (and say how old it is), or refuse with an error? Blocks FR-006.
