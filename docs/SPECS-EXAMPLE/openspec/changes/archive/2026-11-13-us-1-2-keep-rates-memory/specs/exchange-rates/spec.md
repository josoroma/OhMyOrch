## ADDED Requirements

### Requirement: Reuse a rate fetched the same day

The system SHALL keep each fetched rate in memory for the day it was fetched, and SHALL
NOT call the rate API again for the same pair on that day.

#### Scenario: Reuse a rate on the same day

- **WHEN** the USD to EUR rate was fetched today and it is requested again the same day
- **THEN** the rate API has been called once

#### Scenario: Fetch again on a new day

- **WHEN** the USD to EUR rate was fetched yesterday and it is requested today
- **THEN** the rate API is called again
