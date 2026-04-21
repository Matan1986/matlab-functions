### Title

Switching Canonical System — Direction Lock

### Final Decision

CHANNEL_MODEL = SINGLE_PIPELINE_WITH_CHANNEL_AWARENESS

### Explanation

- The system uses a single canonical Switching pipeline
- Differences previously interpreted as "multiple channels"
  correspond to:
  - different measurement readouts (e.g., XX, XY)
  - and channel-dependent processing rules
- These differences do NOT constitute separate canonical pipelines

### Rejected Interpretation

MULTI_PIPELINE_MODEL = REJECTED (CURRENT SCOPE)

Reason:

- High structural overlap
- Shared pipeline logic
- Differences are behavioral, not architectural

### Operational Definition

System structure:

canonical_pipeline(S)
+ channel_type (XX / XY)
+ channel-aware processing rules

### Status

DIRECTION_LOCKED = YES
