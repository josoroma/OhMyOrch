## MODIFIED Requirements

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
