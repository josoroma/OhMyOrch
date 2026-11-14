# Proposal

Story: US-1.1 Fetch a daily rate (SPECS.md)

## Why

The converter needs today's reference rate for a currency pair before it can convert
anything. A currency code the API does not know must fail clearly instead of producing
a number.

## What Changes

- Get a pair's rate and the date of that rate from the Frankfurter v2 rate endpoint.
- Accept currency codes in any case and send them in upper case.
- Report a currency the API rejects as `Unknown currency: <CODE>`, with no rate.

## Capabilities

### New Capabilities

- `exchange-rates`: getting today's reference rate for a currency pair.

### Modified Capabilities

- None

## Impact

- New module `src/rates.js` and tests `tests/rates.test.js` against a stubbed API.
- New external dependency: the Frankfurter API (no key, no account).
