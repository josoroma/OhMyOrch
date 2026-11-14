# Tasks

## 1. Conversion

- [x] 1.1 Convert an amount at the pair's rate, rounded to the nearest cent with a half cent rounding up; verify with the "convert and round to the cent" and "round a half cent up" tests
- [x] 1.2 Return the amount for the same currency without calling the rate API; verify with the "same currency needs no rate" test, which counts zero API calls

## 2. Command

- [x] 2.1 Add the executable `convert <amount> <from> <to>` that prints the result, and prints `Unknown currency: <CODE>` with exit status 1; verify with the "print the converted amount" and "unknown currency" tests
