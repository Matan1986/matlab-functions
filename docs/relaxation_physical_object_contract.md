# Relaxation Physical Object Contract (RF1)

## Purpose

Freeze the physical definition and required canonical-object gates before any repair implementation.

## Canonical Physical Object

The Relaxation canonical curve object is:

`ΔM(t - t_field_off; T)`

This is a post-field-off object only.

## Contract Fields

### 1) Raw observables (required)

- Time channel: raw timestamp/elapsed-time column used by loader.
- Field channel: magnetic field channel in Oe (or known convertible unit).
- Magnetization channel: moment/magnetization column in emu (or contract-converted unit).
- Temperature channel: sample temperature column in K.

### 2) Field-off event definition (required)

- Primary event: first index entering relaxation field state (near-zero field band) after prior high-field state.
- Fallbacks (if needed) must be explicitly versioned and logged; no silent heuristic switching.
- Event detection output must include: event index, event time, rule ID, confidence/status.

### 3) Time-origin rule (required)

- Canonical time axis is `t_rel = t_raw - t_field_off`.
- Canonical first point must satisfy `t_rel = 0` (within numeric tolerance).
- No alternative time-zero definitions allowed in canonical object.

### 4) Post-field-off segment rule (required)

- Canonical curve must include only points with `t_rel >= 0`.
- Pre-field points are forbidden in canonical curve construction.
- Minimum post-field-off point count gate is required for validity.

### 5) Baseline/reference rule (required)

- Baseline definition at/near field-off must be explicit and versioned.
- Whether `ΔM` is computed from field-off reference, endpoint reference, or fit-offset reference must be declared.
- Canonical metadata must expose baseline rule ID and applied parameters.

### 6) Sign convention rule (required)

- Sign orientation must be deterministic and documented.
- Any sign lock applied for diagnostics must be traceable and reversible.

### 7) Allowed diagnostic normalizations (diagnostic-only)

- Raw map value (no normalization)
- Per-trace `ΔM` normalization
- Per-trace z-score normalization

These are diagnostic transforms only and do not redefine canonical physical object.

### 8) Required per-trace metadata

Each trace must record at minimum:

- file identity (`file_name`, `trace_id`, source path)
- column mapping used (time/field/moment/temperature column names)
- `has_field_column`
- `field_off_detected`
- `field_off_index`, `field_off_time`
- `canonical_start_time`
- `canonical_start_minus_field_off`
- `contains_pre_field_off_points`
- `post_field_off_points_available`
- baseline rule ID and parameters
- event-origin validation status

### 9) Required validation gates before replay

All must pass before any R6.2 replay restarts:

1. Field column available (or formally approved metadata alternative).
2. Field-off event detected with declared rule.
3. Canonical start aligned to field-off.
4. Canonical curve contains no pre-field-off points.
5. Time-zero at field-off confirmed.
6. Baseline rule explicitly applied and recorded.
7. Event-origin audit status = PASS for included traces.

## Hard Constraints

- No cross-module interpretation.
- No promotion to canonical scalar/mode claims from diagnostic transforms.
- Replay remains blocked until repaired canonical object satisfies this contract.

## Event-origin failure and foundation reset

This contract is the RF1 response to event-origin failure: the previous canonical curve-first run used full traces and was not strictly anchored to post-field-off relaxation.

- Quarantined families include R6.2A/B/B2/B3/V and prior physical synthesis derived from the full-trace object.
- Earlier outputs are reusable only as infrastructure/reference patterns, never as physical validation.
- Collapse/SVD/time-mode replay and cross-module analysis remain blocked until RF3-RF5 gates pass.

Repair sequence tracked by governance:

1. RF0/RF1 quarantine + contract — complete
2. RF-backfill lineage quarantine — complete
3. RF2 old-analysis physical witness audit — current
4. RF3 event-origin-correct canonical implementation
5. RF4 visual proof of corrected object
6. RF5 minimal replay on corrected object
7. Future collapse/time-mode and cross-module gates only after RF5
