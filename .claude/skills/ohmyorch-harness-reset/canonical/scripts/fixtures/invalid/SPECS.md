### US-1.1: Duplicate and malformed stories

Status: READY

Source:
- PRD.md section 1

Acceptance Criteria:

```gherkin
Scenario: missing when
  Given a precondition
  Then an outcome
```

```gherkin
Scenario: complete
  Given a precondition
  When an action occurs
  Then an outcome
```

Tasks:
- [ ] t

Open Questions:
- None.

### US-1.1: Duplicate identifier

Status: BOGUS STATUS

Source:
- PRD.md section 2

### US-1.2: Ready but untraceable

Status: READY

Acceptance Criteria:

```gherkin
Scenario: no source
  Given a precondition
  When an action occurs
  Then an outcome
```

Tasks:
- [ ] t

Open Questions:
- None.

### US-1.3: No status line at all

As someone
I want something
So that value.

Tasks:
- [ ] t
