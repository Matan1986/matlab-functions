# AGING-TAU-FIX-06-READINESS-GATE

## 1. Scope and exclusions

- Scope: final governance readiness gate for baseline Dip/FM curve-fit tau lane, using committed evidence from FIX-01C through FIX-05 plus PRB02B/PRB03/fixplan artifacts.
- Exclusions: no MATLAB/Python/Node/replay; no tau recompute/refit; no ratios; no comparison runner; no figures; no code edits; no tau value edits.

## 2. Executive summary

Baseline Dip/FM governance lineage, pathway closure, sidecar metadata, and row-identity/co-registration semantics are documented and committed through FIX-05. Therefore the baseline lane is accepted as canonical governance evidence for controlled process decisions. However, row-level tau body links remain run-local and PRB03 still reports WARN lineage partial with zero comparison-eligible rows; canonical scientific tau-use and comparison runner execution remain blocked. Design-only follow-on for ratio/comparison planning is allowed; execution is not.

## 3. Commit hygiene / staging verification note

FIX-06 is staged via exact six-path allow-list only under `reports/aging` and `tables/aging`. Maintenance F01A file may remain tracked but is not staged in FIX-06.

## 4. Evidence chain summary FIX-01C through FIX-05

- FIX-01C: shared dataset lineage package promoted; blocker closed at evidence layer (`aging_tau_fix01c_status.csv`).
- FIX-02: Dip branch identity/method/artifact linkage documented; branch blocker closed with known downstream policy caveats (`aging_tau_fix02_dip_status.csv`).
- FIX-03: FM branch identity/method/artifact linkage documented; branch blocker closed with known policy caveats (`aging_tau_fix03_fm_status.csv`).
- FIX-04: sidecar required metadata inventory completed and mapped for Dip/FM; metadata blocker closed at committed evidence layer (`aging_tau_fix04_status.csv`).
- FIX-05: row identity key/co-registration semantics closed at metadata layer; body-level run-local caveat remains (`aging_tau_fix05_status.csv`, `aging_tau_fix05_row_identity_blocker_resolution.csv`).

## 5. Final blocker matrix

Final matrix is recorded in `tables/aging/aging_tau_fix06_blocker_matrix_final.csv`. Key disposition:
- Governance-documentation blockers from FIX-01C..FIX-05: closed or acceptable with explicit caveats.
- Row-level body provenance remains run-local: blocks scientific-canonical claims and runner execution.
- PRB03 pathway summary/status remain WARN partial and `rows_comparison_eligible_now=0`: blocks comparison execution.

## 6. Canonical governance evidence decision

Decision: baseline Dip/FM lane is ready as canonical governance evidence for repository policy and process-gating context (not scientific publication claims). Rationale: chain FIX-01C..FIX-05 is committed, coherent, and auditable.

## 7. Canonical scientific tau-use decision

Decision: not ready. Scientific canonical tau-use remains blocked due to run-local body-level dependence and unresolved PRB03 WARN lineage posture for baseline rows.

## 8. Ratio/comparison-runner eligibility decision

Decision split:
- ratio/comparison design: allowed as declarative planning only.
- ratio computation and comparison runner execution: not allowed.

## 9. Explicitly allowed next task

Allowed next task: a narrowly scoped design/planning task for ratio/comparison eligibility contract and guardrails, without executing ratios or runner and without scientific overclaim.

## 10. Explicitly forbidden tasks

- Running ratio computations from baseline Dip/FM tau.
- Running comparison runner implementation/execution.
- Any collapse optimizer pathway usage.
- Any old-fit forensic replay pathway usage.
- Any non-baseline tau pathway claim as canonical.

## 11. Remaining limitations

- Tau row bodies/sidecars referenced under run-local results paths are not committed as canonical repository artifacts.
- PRB03 baseline pathways still carry WARN lineage partial and comparison eligibility remains zero.
- FIX-06 does not alter numeric tau values or grant scientific canonical status.

## 12. Final verdicts

- Baseline Dip/FM lane ready as governance evidence: YES.
- Baseline Dip/FM tau ready as scientific canonical evidence: NO.
- Safe to run ratios now: PARTIAL (design-only).
- Safe to run comparison runner now: NO.
- Ready for archive commit of FIX-06 decision gate: YES.
