# Aging F4A AFM physical tau replay

## Scope and constraints
- AFM-side only: `tau_AFM_physical_canon_replay`.
- No FM tau built.
- No AFM/FM tau comparison performed.
- No cross-module analysis and no mechanism closure claims.

## Input domain
- Signal: `Dip_depth_direct_TrackB`.
- Domain restricted to F3-approved AFM-eligible Tp rows.
- Per-Tp tw minimum gate: at least 3 finite points.

## Model families used
- Primary physical candidate: single exponential approach/saturation vs tw.
- Non-primary diagnostic context: log10(tw) linear model (explicitly non-primary).

## Selection policy
- tau selected only when primary model passes quality gates.
- Failed Tp rows are recorded with explicit failure reasons.

## Outcome summary
- Selected Tp count: 5
- Failed Tp count: 1
- AFM_TAU_MODEL_QUALITY_SUFFICIENT = PARTIAL

## Prohibition compliance
- FM tau build: NO.
- AFM/FM tau comparison: NO.
- Track A direct tau source: NO.
- Proxy promoted to physical tau: NO.
- Global mechanism claim: NO.
