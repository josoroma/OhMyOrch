# currency-conversion Specification

## Purpose
Convert an amount between two currencies at today's reference rate, from the command
line, and print the result.

## Requirements

### Requirement: Convert an amount

The system SHALL convert an amount at the pair's rate and round the result to the nearest
cent, a half cent rounding up.

#### Scenario: Convert and round to the cent

- **WHEN** the USD to EUR rate is 0.9022 and `convert 20 USD EUR` is run
- **THEN** the converted amount is 18.04 EUR

#### Scenario: Round a half cent up

- **WHEN** the USD to EUR rate is 0.90225 and `convert 20 USD EUR` is run
- **THEN** the converted amount is 18.05 EUR

### Requirement: Same currency needs no rate

The system SHALL return the amount unchanged when both currencies are the same, without
calling the rate API.

#### Scenario: Same currency needs no rate

- **WHEN** `convert 20 USD USD` is run
- **THEN** the converted amount is 20.00 USD
- **AND** the rate API is not called

### Requirement: Print the result

The system SHALL print the converted amount with two decimals and the currency code,
followed by the rate used and the date of that rate. When no rate was needed, the
system SHALL say so instead.

#### Scenario: Print the converted amount

- **WHEN** 10 EUR converts to 11.08 USD at the rate 1.1084, dated 2026-11-14
- **THEN** it prints "11.08 USD (1 EUR = 1.1084 USD on 2026-11-14)"

#### Scenario: Show the rate and its date

- **WHEN** the USD to EUR rate is 0.9022, dated 2026-11-14, and `convert 20 USD EUR` is run
- **THEN** it prints "18.04 EUR (1 USD = 0.9022 EUR on 2026-11-14)"

#### Scenario: Same currency says no rate was used

- **WHEN** `convert 20 USD USD` is run
- **THEN** it prints "20.00 USD (same currency, no rate needed)"

### Requirement: Report an unknown currency on the command line

The system SHALL print `Unknown currency: <CODE>` and exit with status 1 when the rate API
rejects a currency code.

#### Scenario: Unknown currency

- **WHEN** the rate API rejects XYZ as an invalid currency and `convert 20 USD XYZ` is run
- **THEN** it prints "Unknown currency: XYZ"
- **AND** it exits with status 1
