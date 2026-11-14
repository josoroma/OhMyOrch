# Tasks

## 1. Rates

- [x] 1.1 Get a pair's rate and date from `https://api.frankfurter.dev/v2/rate/{BASE}/{QUOTE}` with the codes upper-cased; verify with the "fetch today's rate" and "lower-case codes" tests against a stubbed API
- [x] 1.2 Turn HTTP 422 into the error `Unknown currency: <CODE>` with no rate; verify with the "unknown currency" test

## 2. Project

- [x] 2.1 Add `package.json` whose `npm test` runs `node --test` with no dependencies; verify `npm test` passes offline
