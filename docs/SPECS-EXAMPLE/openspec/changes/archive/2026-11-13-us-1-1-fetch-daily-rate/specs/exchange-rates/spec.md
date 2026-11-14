## Purpose

Get today's reference exchange rate for a currency pair, with the date of that rate,
from the Frankfurter API.

## ADDED Requirements

### Requirement: Fetch today's rate for a pair

The system SHALL get the rate for a currency pair, and the date of that rate, from the
Frankfurter v2 rate endpoint, sending the currency codes in upper case.

#### Scenario: Fetch today's rate for a pair

- **WHEN** the rate API returns 0.9022 for USD to EUR, dated 2026-11-14, and the USD to EUR rate is requested
- **THEN** the rate 0.9022 is returned with the date 2026-11-14

#### Scenario: Accept lower-case currency codes

- **WHEN** the usd to eur rate is requested
- **THEN** the rate API is asked for USD to EUR

### Requirement: Report an unknown currency

The system SHALL report a currency code that the rate API rejects as
`Unknown currency: <CODE>` and SHALL NOT return a rate.

#### Scenario: Report an unknown currency code

- **WHEN** the rate API rejects XYZ as an invalid currency and the USD to XYZ rate is requested
- **THEN** the error "Unknown currency: XYZ" is reported
- **AND** no rate is returned
