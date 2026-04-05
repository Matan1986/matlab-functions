# Relaxation Pipeline Audit (Current State)

Date: 2026-03-30 (Asia/Jerusalem)
Scope: `C:\Dev\matlab-functions\Relaxation ver3\` with focus on:
- `run_relaxation_canonical.m`
- `main_relaxation.m`
- `importFiles_relaxation.m`
- `pickRelaxWindow.m`
- `fitAllRelaxations.m`
- `fitRelaxationModel.m`
- `relaxation_config_helper.m`

## 1) Current Pipeline (What It Actually Does)
1. Raw data loading:
- Files are discovered by `getFileList_relaxation` from `*.dat` and metadata (T/H/type) is inferred from filename patterns.
- Numeric columns are loaded in `importFiles_relaxation` by matching timestamp, temperature, field, moment columns.

2. Time axis definition:
- Per file, timestamps are sorted and deduplicated.
- Time is shifted to first sample: `t = tRaw - t0` (with optional `/1000` when ms is inferred).
- So stored `t=0` means first recorded point, not explicitly field-off event.

3. t0 used for fitting:
- Primary: first point where smoothed `|H| < Hthresh` and remains low (`pickRelaxWindow`).
- Fallback: index of minimum `dM/dt`, then take next 20% of trace.
- In canonical path this starts from imported time axis; in `main_relaxation` path `Plots_relaxation` can pre-shift time by field-drop if `alignByDrop=true`.

4. Window selection:
- Initial `[t_start,t_end]` from `pickRelaxWindow`.
- Optional fractional trims in `fitAllRelaxations` (`fitWindow_extraStart_percent`, `fitWindow_extraEnd_percent`).

5. Normalization / units:
- Optional mass normalization `M/(mass*1e-3)` in importer.
- Optional conversion to `mu_B/Co` in `main_relaxation` and canonical runner.

6. Observable computation:
- `fitRelaxationModel` dispatches to:
  - Log model: `M(t)=M0-S*log(t)`, returning `S`.
  - KWW model: `Minf + dM*exp(-(t/tau)^n)`, returning `tau,n` (and `Minf,dM`).
- Output table combines both model families into one schema (`S` may be NaN for KWW; `tau,n` NaN for log).

## 2) Consistency Check
The implemented behavior is clear enough to trace, but not internally consistent with its own configuration interface.

Major inconsistencies are listed in:
- `tables/relaxation_pipeline_inconsistencies.csv`

Highest-impact issues:
- Config fields (`time_origin_mode`, `fit_window_mode`, `baseline_mode`, etc.) are documented and reported but mostly not consumed by core fitting logic.
- Interactive path (`main_relaxation`) mutates `Time_table` in plotting before fitting when `alignByDrop=true`, creating behavior divergence from canonical path.
- No-relax accounting mismatch: fallback writes `tau=Inf` while canonical summary counts `isnan(tau)`.

## 3) Physical Check
### t0
Result: **not fully physical**.
- Physical branch exists (field-threshold drop), but default time origin is first sample.
- Derivative fallback (`dM/dt` minimum + fixed 20%) is heuristic and can be non-physical.
- Log-fit slope `S` depends on absolute time choice because fit uses `log(t)` without re-zeroing to window start.

### window
Result: **not fully physical**.
- Field-threshold windowing is physically motivated.
- Fallback window and fixed-length heuristic can include non-equilibrium or instrumentation transients.
- Threshold values vary across entry points.

### normalization
Result: **partly physical**.
- Mass normalization and `mu_B/Co` conversion are physically meaningful.
- However, configuration-to-execution drift and missing strict mass validity checks reduce reproducibility/traceability.

### observable
Result: **not physically unified**.
- Two different observables are mixed (log-model `S` vs KWW `tau,n`) under one output contract.
- Repository-level canonical observable `R_relax = -dM/dlog(t)` is not computed directly in the audited core path.

## 4) Minimal New Audit Status
Inconsistencies triggered the "new audit required" condition.

Runtime evidence used:
- Existing raw-trace robustness audit artifacts (latest completed set at 2026-03-29 18:42:51):
  - `tables/relaxation_measurement_robustness_summary.csv`
  - `tables/relaxation_measurement_robustness_status.csv`
  - `reports/relaxation_measurement_robustness_audit.md`
- Two wrapper re-runs were attempted on 2026-03-30; wrapper completed, but no new robustness artifacts were emitted to root tables/reports. Therefore, conclusions rely on current code-state analysis plus the latest completed raw-trace robustness outputs.

Those robustness outputs report strong sensitivity to `t0` and normalization choices and mark `RELAXATION_OBSERVABLE_PHYSICAL=false`, consistent with this code audit.

## Required Verdicts
- PIPELINE_CLEAR = YES
- PIPELINE_CONSISTENT = NO
- T0_PHYSICAL = NO
- WINDOW_PHYSICAL = NO
- NORMALIZATION_PHYSICAL = YES
- RELAXATION_OBSERVABLE_PHYSICAL = NO
- PIPELINE_BROKEN = YES
- NEW_AUDIT_REQUIRED = YES

## Final Answer
Is the current relaxation pipeline physically valid?

**No.**

What is wrong and is a new definition required?

- The implementation is traceable but configuration semantics and executed logic are misaligned.
- `t0` and window behavior are not robustly physical across all branches.
- The pipeline does not enforce a single physical relaxation observable.

**A new, explicit definition is required** for:
1. time origin (strictly tied to field-removal physics),
2. admissible fit window (with transient rejection rules),
3. single canonical relaxation observable and reporting contract.
