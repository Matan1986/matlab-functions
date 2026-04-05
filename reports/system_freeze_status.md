# System freeze status

**STATUS: FREEZE_ACTIVE**

This report records an explicit repository **system freeze** intended to prevent unintended changes before boundary definition and audit work proceeds.

## What is frozen

- **Execution and change scope:** No further code edits, pipeline runs, cleanup passes, leakage remediation, or legacy-module modifications are authorized under this freeze except as listed under *What is allowed*.
- **Canonical entrypoint posture:** The canonical Switching entrypoint and related execution posture are treated as **locked** for the duration of the freeze (see `tables/system_freeze_status.csv`: `CANONICAL_ENTRYPOINT_LOCKED = YES`). Agents must not re-route, rename, or substitute entrypoints heuristically; follow `docs/repo_execution_rules.md` and registry-backed definitions when the freeze lifts.
- **Cleanup and analysis operations:** Cleanup workflows and analysis execution are **disabled** for freeze purposes (`CLEANUP_DISABLED = YES`, `ANALYSIS_DISABLED = YES`).

## What is allowed

During the freeze, only the following classes of activity are permitted:

- **Audit:** Read-only review of documentation, tables, reports, and configuration as needed to define boundaries and record findings.
- **Classification:** Labeling, triage, and categorization of issues or assets **without** changing implementation or deleting/moving artifacts except where rollback explicitly requires it.
- **Rollback:** Reverting documented unintended changes when required to restore a known-good state, strictly for audit safety and **without** introducing new logic or refactors.

## What is forbidden

The following are **forbidden** until the freeze is explicitly lifted:

- **Cleanup** runs or scripts that delete, bulk-move, or normalize artifacts for “hygiene” without a scoped, approved rollback plan.
- **Analysis** execution (including MATLAB batch runs and automated pipelines that mutate `results/`, `runs/`, or analysis outputs).
- **Legacy changes:** edits to legacy paths, compatibility shims, or historical modules except pure documentation that does not alter behavior.
- **Inference-driven changes:** selecting entrypoints, backends, or behaviors by guessing instead of registry and documented sources (`docs/repo_execution_rules.md`).

## Why this freeze is required before boundary audit

Boundary definition and audit require a **stable baseline**. Without a documented freeze, concurrent cleanup, analysis, or legacy edits can shift paths, outputs, and dependencies while boundaries are still being written—producing **moving targets**, ambiguous diffs, and unreliable audit conclusions. The freeze makes the **current system state** explicit and **locked for classification and rollback**, so boundary documents and audits refer to a single agreed posture.

## Machine-readable status

See **`tables/system_freeze_status.csv`** for the authoritative flag row (`FREEZE_ACTIVE`, timestamps, and related locks).
