# Proposal

Story: US-2.1 Convert an amount (SPECS.md)

## Why

With today's rate available (US-1.1), a person can now convert an amount from the
terminal: `convert 20 USD EUR`.

## What Changes

- Convert an amount at the pair's rate, rounded to the nearest cent; a half cent rounds up.
- Converting a currency to itself returns the amount without calling the rate API.
- Add the command `convert <amount> <from> <to>`, which prints the converted amount and
  reports an unknown currency with exit status 1.

## Capabilities

### New Capabilities

- `currency-conversion`: converting an amount between two currencies and printing it.

### Modified Capabilities

- None

## Impact

- New modules `src/convert.js` and `src/cli.js`, the executable `convert`, and tests
  `tests/convert.test.js` against a stubbed API.
