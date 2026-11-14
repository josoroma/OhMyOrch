# Tasks

## 1. Rates in memory

- [x] 1.1 Keep fetched rates in memory, keyed by pair and calendar day, with the day taken from a clock that tests can set; verify with the "reuse a rate on the same day" test, which counts one API call
- [x] 1.2 Fetch again when the day changes; verify with the "fetch again on a new day" test, which counts two API calls
