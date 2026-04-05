# Canonical Migration Strategy Audit (Switching, Read-Only)

## Scope
- Directory surveyed: `Switching/analysis/` (including `experimental/`)
- Scripts scanned (run_/switching_/analyze_): 82
- Excluded from migration scope by mandate: Aging and Relaxation pipelines

## A. Entrypoint Readiness
- Candidate: `Switching/analysis/analyze_phi_kappa_canonical_space.m`
- Runnable-script structure: **PARTIAL PASS** (pure script, starts `clear; clc;`, writes tables/status/report).
- Run-scoped outputs intent: **PARTIAL** (writes into `run_dir`, not dedicated run-scoped `tables/` and `reports/` subfolders).
- Aging/Relaxation reads in this file: **NONE DETECTED**.
- Blocker 1: entrypoint reads root precomputed inputs `tables/phi_kappa_stability_summary.csv` and `tables/phi_kappa_stability_status.csv`.
- Blocker 2: file calls `createRunContext(...)` but does not explicitly add `Aging/utils`; only detected definition is `Aging/utils/createRunContext.m`.

## B. Canonical Run Feasibility
- Creating exactly one canonical Switching run from the candidate script is **NOT feasible now** as a clean canonical starting point.
- Reason: run depends on pre-existing root tables (non-canonical source), and helper-path dependency is implicit.

## C. Old Switching Analyses Migration Feasibility
- Per-script classifications are in `tables/canonical_migration_readiness.csv`.
- `cross_pipeline_dependency=YES`: 72 / 82
- `switching_only=YES`: 10
- `ready_for_minimal_migration=YES` among switching_only: 9 / 10
- Cross-pipeline dependencies include explicit Aging path imports, relaxation-run inputs, and cross-experiment contexts.

## D. Strategy Validation
- Decision: **NOT_YET_EXECUTABLE**
- Justification: entrypoint is not a clean canonical source-of-truth in current repository state; scope cleanliness is also violated by many existing scripts.

## Final Question
Can the repository, in its current state, support the planned migration from old non-canonical Switching analyses to the new canonical Switching system using minimal data-loading changes only, without hidden conceptual or pipeline errors?

**Answer: NO. Current status: NOT_YET_EXECUTABLE.**

## Evidence Pointers
- `Switching/analysis/analyze_phi_kappa_canonical_space.m` (root table reads, createRunContext call, run_dir output target).
- `Aging/utils/createRunContext.m` (helper location dependency).
- `tables/canonical_migration_blockers.csv` (script-by-script blocker evidence).
