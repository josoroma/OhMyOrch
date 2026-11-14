# Design

## Context

Frankfurter v2 answers `GET https://api.frankfurter.dev/v2/rate/{base}/{quote}` with
`{"date", "base", "quote", "rate"}`, and an invalid currency with HTTP 422 and
`{"status": 422, "message": "invalid currency: XYZ"}`. Tests must run offline and be
repeatable (NFR-003); the project has no dependencies (NFR-004).

## Goals / Non-Goals

**Goals:** one function that returns a pair's rate and its date, with the HTTP call
replaceable in tests.

**Non-Goals:** keeping rates in memory (US-1.2), converting amounts (EPIC-2), and the
behavior when the API is down (US-2.3, not decided).

## Decisions

- The global `fetch` of Node.js is passed in, so a test replaces it with a stub that
  records each call. A mocking library was rejected: no dependencies.
- HTTP 422 becomes an `UnknownCurrencyError` whose message is `Unknown currency: <CODE>`,
  with the code taken from the API's message. Other failures are not handled here,
  because what to do when the API is down is still an open question.
- Codes are upper-cased before the request (BR-001).

## Risks / Trade-offs

- [The v2 endpoint changes shape] → one URL builder, and tests that pin the fields used.
