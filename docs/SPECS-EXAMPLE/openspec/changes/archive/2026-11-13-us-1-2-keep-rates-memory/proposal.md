# Proposal

Story: US-1.2 Keep rates in memory (SPECS.md)

## Why

Asking for the same pair twice should not cost a second call to the rate API: the
reference rate changes once a day.

## What Changes

- Keep each fetched rate in memory, by pair and day, for as long as the program runs.
- Asking for a pair already fetched today returns the rate from memory without
  calling the API; on a new day the API is called again.

## Capabilities

### New Capabilities

- None

### Modified Capabilities

- `exchange-rates`: adds the requirement to reuse a rate fetched the same day.

## Impact

- `src/rates.js` keeps a map of fetched rates; `tests/rates.test.js` counts API calls.
- No database and no files (NFR-001).
