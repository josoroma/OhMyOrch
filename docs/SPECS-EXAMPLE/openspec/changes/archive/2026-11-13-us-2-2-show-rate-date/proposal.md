# Proposal

Story: US-2.2 Show the rate and its date (SPECS.md)

## Why

A converted amount alone does not say where it comes from. Showing the rate and its date
tells the person which reference rate was used and how current it is.

## What Changes

- The printed result adds the rate used and the date of that rate:
  `18.04 EUR (1 USD = 0.9022 EUR on 2026-11-14)`.
- A same-currency result says that no rate was needed:
  `20.00 USD (same currency, no rate needed)`.

## Capabilities

### New Capabilities

- None

### Modified Capabilities

- `currency-conversion`: the requirement "Print the result" changes.

## Impact

- `src/convert.js` (the printed format) and the output tests in `tests/convert.test.js`.
