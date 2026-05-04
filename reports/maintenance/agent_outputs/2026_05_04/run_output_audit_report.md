# Run Output Audit Report

## RUN STATUS
- Advisory-only pre-governor audit executed.
- Run roots checked: `results/aging/runs`, `results/relaxation/runs`, `results/switching/runs`, `results/cross_experiment/runs`.
- No `results/<experiment>/runs/run_*` directories were accessible in this workspace.

## VALID RUNS
- 0 (no accessible run roots to validate).

## INCOMPLETE RUNS
- 0 directly observed (coverage-limited workspace prevented run-level completeness checks).

## SUSPICIOUS RUNS
- `RO_SUSPICIOUS_006` (MEDIUM, HIGH confidence): workspace coverage limitation for run-output audit.

## MISSING ARTIFACT GUIDANCE
- Provide an artifact-access route containing `results/<experiment>/runs/run_*` directories (local run environment, published snapshot branch, or PR artifact path) to enable full run-root and artifact-family validation.

## FINAL VERDICTS
AGENT_RUN_COMPLETED = YES
NORMALIZED_FINDINGS_EMITTED = YES
SIMPLIFIED_GOVERNOR_CSV_EMITTED = YES
ADVISORY_ONLY_PRE_GOVERNOR = YES
BACKLOG_MUTATED = NO
PUBLICATION_STATUS = PUBLICATION_OK
PUBLICATION_ROUTE = PR_BRANCH
PUBLICATION_URL = https://github.com/Matan1986/matlab-functions/tree/maintenance/status-pack-runner/reports/maintenance/agent_outputs/2026_05_04
