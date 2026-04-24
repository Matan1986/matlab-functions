# MT Stage 1.5 Physics Definition Audit (Design-Only)

Date: 2026-04-24  
Scope: `MT ver2/` static audit only (no MT code changes, no full run)

## Canonical physics definitions (locked)

1. **Primary canonical measured object (raw truth):**
   - `M_raw_emu(T_K, H_Oe, time_s, file_id)`.
   - Evidence: import returns raw magnetization and axis vectors; cleaning function preserves raw copies (`T_raw`, `M_raw`).

2. **Primary canonical processed object (processed truth):**
   - `M_clean_emu(T_K, H_Oe, time_s, file_id)`.
   - Definition: post outlier detection + optional interpolation, before/after smoothing tracked as documented transforms.

3. **`M/H`, `M/mass`, `muB/Co` classification:**
   - **Derived variables**, not primary observables.
   - They are computed from raw/clean magnetization and metadata/scalars (`H`, `mass`, composition constants), and are currently applied inside plotting/labeling pathways.

4. **ZFC/FCW segmentation layer:**
   - **Derived extraction layer** (indexing/partitioning over `T(t)` behavior), not raw truth.

5. **Cleaning role:**
   - Cleaning is a **documented preprocessing transform** from raw to clean, not a hidden replacement of raw truth.
   - Canonical requirement: preserve both raw and clean columns side-by-side.

## Explicit answers to required questions

### Q6: Invariants under cleaning/smoothing
Required invariants:
- File-level sample cardinality preserved unless points explicitly masked; all removals/replacements auditable.
- `T_raw/M_raw` must remain immutable.
- `M_clean` must be derivable from declared parameters only.
- No polarity/sign inversions introduced by smoothing.
- Smoothing must not alter segmentation membership unless explicitly configured and audited.

### Q7: Invariants under segmentation-threshold perturbations
Required invariants:
- Segment count and boundaries should change smoothly under small threshold perturbations.
- Major observables (`M(T)` branch means, FCW-ZFC deltas) must remain within predefined tolerance bands.
- Empty/degenerate segment outcomes must fail explicitly or be status-flagged.

### Q8: Cleaning uniformity across fields
**Finding: NOT uniform.**
- `clean_MT_data` bypasses all cleaning when `fieldOe < field_threshold`, returning raw data directly.
- Therefore different fields can undergo different preprocessing regimes in the same run.

### Q9: Time-axis assumption in segmentation
**Finding: assumption present and fragile.**
- Both increasing/decreasing segment detectors compute expected ramp from `Timems(2)-Timems(1)` and apply that cadence globally.
- This assumes near-uniform time sampling and valid first-step cadence; irregular sampling can bias segment detection.

### Q10: Minimum contamination tests before trusting observables
Minimum pre-trust checks:
1. Schema and units validation (`T`, `H`, `M`, `time`) and finite-rate sanity checks.
2. Field/mass provenance checks (header-vs-filename consistency, missing metadata hard-fail policy).
3. Cleaning audit counts per file/field (temp jumps, mag spikes, hampel replacements, interpolation and long-gap preserves).
4. Segmentation stability sweep over threshold neighborhood.
5. Branch completeness checks (both ZFC/FCW presence where expected).
6. Derived-variable sanity checks (`M/H` finite where `H != 0`, no impossible scaling outliers).

## Physics-definition blockers/warnings

- Low-field cleaning bypass produces non-uniform preprocessing across fields (blocker for strict comparability).
- Segmentation cadence assumption uses first two time points only (blocker for irregularly sampled data).
- File metadata inferred from filenames can redefine derived observables (`M/mass`, `muB/Co`) if naming is inconsistent.
- Import loop continues after per-file failures, risking silent partial-physics conclusions.

## Stage 1.5 physics verdicts

- `MT_CANONICAL_VARIABLE_DEFINED=YES`
- `MT_RAW_OBJECT_DEFINED=YES`
- `MT_CLEAN_OBJECT_DEFINED=YES`
- `MT_DERIVED_VARIABLES_SEPARATED=YES`
- `MT_SEGMENTATION_LAYER_DEFINED=YES`
- `MT_CLEANING_UNIFORMITY_OK=NO`
- `MT_TIME_AXIS_ASSUMPTION_OK=NO`
- `MT_READY_FOR_CANONICAL_WRAPPER=NO` (superseded by script-level readiness verdict in canonical-execution design)
