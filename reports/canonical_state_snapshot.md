# Canonical State Snapshot

## 1. Scope

Repository-based verification snapshot of canonical switching state using on-disk artifacts only.
No assumptions or memory-only claims were used.

## 2. IO Layer

- `readtable.m`: **NOT clean**. It still runs `enforce_partial_guard(...)` and can raise `PARTIAL_RUN_NOT_ALLOWED`.
- `load_local.m`: **clean passthrough behavior active** (`builtin('load', ...)`); prior enforcement logic is commented out.
- Hidden IO enforcement conclusion: **present** due to active `readtable` guard path.

## 3. Channel System

- Channel awareness exists in execution code: `switching_channel_physical` and `channel_type` are built in `run_switching_canonical.m`.
- Propagation is present in canonical outputs for verified run `run_2026_04_14_103149_switching_canonical`:
  - `tables/switching_canonical_S_long.csv`
  - `tables/switching_canonical_observables.csv`
  - `tables/switching_canonical_phi1.csv`
- Verified output columns include both `switching_channel_physical` and `channel_type`.

## 4. Canonical Execution

- Verified run directory: `results/switching/runs/run_2026_04_14_103149_switching_canonical`.
- `execution_status.csv` exists and reports:
  - `EXECUTION_STATUS=SUCCESS`
  - `INPUT_FOUND=YES`
  - `MAIN_RESULT_SUMMARY=switching_canonical completed`
- Required canonical tables (`S_long`, `observables`, `phi1`) exist and are non-empty.

## 5. Structural Integrity

- Required output files are physically present and non-empty in the verified run.
- CSV headers are valid and data rows are present.
- No obvious file-level corruption detected in required artifacts.

## 6. Analysis Stability

- `tables/switching_io_fix_audit.csv` exists.
- All listed analyses are `HOLD`:
  - `canonical_observables`
  - `phi1`
  - `kappa1`
  - `reconstruction`
- Drift conclusion from this audit table: **no drift indicated**.

## 7. XX Status (Basic)

- Is XX present? **NO**
- Does it flow through the pipeline? **NO (not verifiable from current canonical run artifacts)**
- Are outputs produced? **NO**

Evidence used:
- Repo scan across canonical run output CSV files under `results/switching/runs` found no `channel_type=XX` rows.
- Verified canonical run outputs (`run_2026_04_14_103149_switching_canonical`) contain `channel_type=XY` rows.
- Code path for XX exists in `run_switching_canonical.m`, but no XX-bearing canonical output artifact was found.

Optional note (evidence-based):
- `switching_canonical_S_long.csv` in the verified run contains trailing `NaN` rows at high current for channel `XY`; files are still structurally valid and non-empty.

## 8. Verdicts

- IO_LAYER_CLEAN = NO
- CHANNEL_SYSTEM_VALID = YES
- EXECUTION_TRUSTABLE = YES
- STRUCTURE_VALID = YES
- SCIENTIFIC_STABILITY = YES

- XX_PRESENT = NO
- XX_PIPELINE_WORKING = NO

- FINAL_STATE_TRUSTED = NO

## 9. 2026-04-26 Canonical Switching scientific state (append-only)

- This section is appended after the earlier snapshot content and does not delete or rewrite any prior material.
- The earlier sections remain preserved as historical snapshot context.
- This appended section records the current canonical Switching scientific interpretation boundary only.

### Canonical model status

- The current canonical Switching model is the leading-order interpretable hierarchy:
  `S ~= S_backbone + kappa1 Phi1 + kappa2 Phi2`.
- `S_backbone` is the PT/CDF-controlled backbone.
- Stage D4 resolved the current canonical mode relationship as:
  - `Phi1 = backbone_error`
  - `Phi2 = backbone_tail_residual`
  - `Kappa2 = tail_burden_tracker`
- Stage E validated canonical static observable mappings for `kappa1` and `kappa2`.

### Mandatory caveat

- This rank-2 canonical model is not a full closure.
- Stage E5 and E5B allow rank-2 as the current leading-order interpretable model only.
- Full-closure claims remain blocked.

### Rank-3 status

- Rank-3 remains an open branch classified as `weak_structured_residual`.
- Rank-3 is not promoted into the canonical interpreted model.
- Rank-3 is not to be summarized as a resolved physical mode.

### Canonical / historical separation

- Legacy or noncanonical `kappa`, `Phi`, and collapse results remain historical unless revalidated in the canonical pipeline.
- Historical/noncanonical Switching results are preserved elsewhere in the repository and must not be conflated with the canonical summary above.
- Any compressed snapshot reuse of this section must keep the non-closure caveat and the open-rank3 note attached.

