# Canonical Candidate Discovery (Strict, Read-Only)

- Scope scanned: Switching/analysis/ (excluding any experimental or legacy subfolder)
- Total runnable scripts: **2**

## Top Candidates by candidate_score (no classification)

| script_path | candidate_score | uses_resolver | uses_direct_load | cross_pipeline(relaxation/aging) | references_legacy_run |
|---|---:|---|---|---|---|
| Switching/analysis/analyze_phi_kappa_canonical_space.m | 2 | NO | NO | NO | NO |
| Switching/analysis/run_minimal_canonical.m | 1 | NO | NO | YES | NO |

## Scripts with Cross-Pipeline Dependencies

- Switching/analysis/run_minimal_canonical.m (relaxation=NO, aging=YES)

## Scripts with Legacy Usage Signals

- None detected

## Detection Notes

- Runnable criterion: contains both `createRunContext` and `execution_status.csv`.
- `appears_in_recent_runs` is marked YES only when script name/path appears in discoverable `run_manifest.json` or `execution_status.csv` files.
- `referenced_by_other_scripts` uses conservative exact filename (`*.m`) mention detection.
- Discovery only: no canonical/non-canonical decision made.
