# Collapse Definition Trace (No-w Assumption)

## Scope and Method
- Scope followed: trace-only extraction from existing scripts, run reports, and run tables.
- No new computation was performed.
- No reinterpretation beyond explicit repository evidence.

## Candidate Artifacts Reviewed
- Script source:
  - `Switching/analysis/switching_alignment_audit.m`
  - `Switching/analysis/switching_energy_scale_collapse_filtered.m`
  - `Switching/analysis/switching_full_scaling_collapse.m`
- Run reports/tables:
  - `results/switching/runs/run_2026_03_12_231143_switching_energy_scale_collapse_filtered/reports/switching_energy_scale_collapse_filtered.md`
  - `results/switching/runs/run_2026_03_12_231143_switching_energy_scale_collapse_filtered/tables/switching_energy_scale_collapse_temperature_decisions.csv`
  - `results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/reports/switching_full_scaling_collapse.md`
  - `results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_parameters.csv`
  - `results/switching/runs/run_2026_03_10_112659_alignment_audit/alignment_audit/switching_alignment_observables_vs_T.csv`

## Extracted Axis Definitions

### 1) run_2026_03_10_112659_alignment_audit (energy-scale collapse)
- x-axis: x = I / I_peak(T)
- y-axis: y = S(T,I) / S_peak(T)
- Normalization/scaling:
  - Current normalized by I_peak(T)
  - Amplitude normalized by S_peak(T)
- w presence:
  - Explicit: NO
  - Implicit: NO (for this collapse axis construction and inclusion condition)

### 2) run_2026_03_10_112659_alignment_audit (threshold-collapse test)
- x-axis: x = I - I_peak(T)
- y-axis: y = S(T,I)
- Normalization/scaling:
  - Shift-only alignment by I_peak(T)
  - No amplitude normalization
- w presence:
  - Explicit: NO
  - Implicit: NO

### 3) run_2026_03_12_231143_switching_energy_scale_collapse_filtered
- x-axis: x = I / I_peak(T)
- y-axis: y = S(T,I) / S_peak(T)
- Normalization/scaling:
  - Same no-w axis pair as alignment energy-scale collapse
  - Additional temperature filtering before collapse metric
- w presence:
  - Explicit: NO
  - Implicit: YES
- Explicit evidence of implicit w path:
  - Decision logic uses width_missing and width-based exclusion criteria (see temperature decision table and script selection rules).

### 4) run_2026_03_12_234016_switching_full_scaling_collapse
- x-axis: x = (I - I_peak(T)) / width(T)
- y-axis: y = S(T,I) / S_peak(T)
- Normalization/scaling:
  - Shift-and-scale in current by width(T)
  - Amplitude normalization by S_peak(T)
- w presence:
  - Explicit: YES
  - Implicit: YES (width extraction pipeline: FWHM preferred, sigma fallback)

## Variant Comparison Table

| run_id | x_definition | y_definition | uses_w_explicit | uses_w_implicit | notes |
|---|---|---|---|---|---|
| run_2026_03_10_112659_alignment_audit::energy_scale | x = I / I_peak(T) | y = S(T,I) / S_peak(T) | NO | NO | No-w normalized collapse in alignment audit output set. |
| run_2026_03_10_112659_alignment_audit::threshold_shift | x = I - I_peak(T) | y = S(T,I) | NO | NO | Shift-only alignment test without width normalization. |
| run_2026_03_12_231143_switching_energy_scale_collapse_filtered | x = I / I_peak(T) | y = S(T,I) / S_peak(T) | NO | YES | Width enters pre-collapse filtering (temperature inclusion), not axis formula. |
| run_2026_03_12_234016_switching_full_scaling_collapse | x = (I - I_peak(T)) / width(T) | y = S(T,I) / S_peak(T) | YES | YES | Full shift-and-scale variant with explicit width coordinate. |

## Canonical No-w Collapse Verdict
- CANONICAL_NO_W_COLLAPSE_FOUND = YES
- Evidence used:
  - Full-scaling report states comparison is against the previous I/I_peak alignment.
  - Alignment-audit and filtered-collapse scripts/reports implement the same no-w axis pair.
- Canonical no-w formula (repo evidence):
  - x = I / I_peak(T)
  - y = S(T,I) / S_peak(T)

## Removal of w: Final Trace Verdict
- W_FULLY_REMOVED = NO
- W_PRESENT_IMPLICITLY = YES
- Reason:
  - In the filtered no-w collapse run, width is still used in temperature-selection logic (width_missing and related exclusion rules), even though w is absent from the collapse axes.

## Unambiguity Assessment
- COLLAPSE_DEFINITION_UNAMBIGUOUS = YES
- Basis:
  - The no-w collapse axis definitions are consistent across the traced alignment and filtered artifacts.
  - A separate shift-and-scale variant exists and is clearly distinguished by explicit width in x.
