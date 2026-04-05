# Switching replay — contamination guard rules

This document defines **mandatory** isolation and validation rules for any Switching-only canonical replay. It aligns with `docs/repo_execution_rules.md` (wrapper, signaling contract) and the **single default** trusted Switching run: `run_2026_04_03_000147_switching_canonical` (see `tables/switching_run_trust_classification.csv`).

---

## A. Module isolation rule

- **Scope:** Only **Switching** science and Switching `results/switching/runs/` artifacts.
- **Invalid:** Any analysis that **loads or depends on** Relaxation runs, Aging science runs, `results/relaxation/**`, `results/aging/**` (except where explicitly classified as out-of-scope reference), or **non-Switching** table pipelines.
- **Technical exception:** `Aging/utils/createRunContext.m` is used **only** for run identity and path allocation (per `tables/switching_canonical_boundary_and_runs.csv`). That is **not** Aging science; it remains allowed for the **canonical Switching entry script** when executed under the approved wrapper. Do **not** treat this as permission to import Aging results tables.
- **Rule of thumb:** If `tables/switching_analysis_inventory.csv` marks `uses_noncanonical_sources = YES`, treat the script as **out of bounds** for a strict Switching-only replay unless the dependency is removed or rewritten.

---

## B. Data loading rule

- **Default inputs:** Load observables and PT/SVD products **only** from **TRUSTED_CANONICAL** Switching runs listed in `tables/switching_run_trust_classification.csv` with `classification = TRUSTED_CANONICAL` and `usable_for_replay = YES`.
- **Primary default run_id for replay planning:** `run_2026_04_03_000147_switching_canonical`.
- **No mixing:** Do not combine outputs from a TRUSTED_CANONICAL run with tables produced under ad-hoc or legacy Switching runs in the same scientific claim.

---

## C. Forbidden sources (for strict canonical replay)

| Source | Status |
|--------|--------|
| `tables_old/**` | **Forbidden** as an execution input (reference-only for historical comparison). |
| Ad hoc **root-level `tables/*.csv`** when not produced by the current trusted run or an explicitly approved analysis pass | **Forbidden** unless the replay plan names them and they are run-backed or reproducible. |
| **Legacy run directories** under `results/**` that are not the selected TRUSTED_CANONICAL Switching run | **Forbidden** for default replay. |
| **Any non-run-backed artifact** presented as physics | **Forbidden** — must trace to a run_dir with signaling artifacts. |

---

## D. Detection rules (automated flags)

Flag **CONTAMINATION_RISK** when any of the following hold:

1. **Path contains `tables_old`** (or script references it).
2. **`execution_status.csv` missing** under the run directory used as evidence (violates signaling contract).
3. **`run_dir` missing or not recorded** in the manifest / status trail for that execution.
4. **Cross-module dependency** detected: e.g. `results/relaxation`, `results/aging`, `genpath(fullfile(repoRoot,'Aging'))` (full-tree), relaxation-specific `tables/*relaxation*` inputs, or hardcoded legacy Relaxation/Aging run paths.

The inventory CSV uses a **script-text detector** for `uses_noncanonical_sources` (see `tables/switching_analysis_inventory.csv`). It **allows** technical `Aging/utils` path adds without marking the script as mixed.

---

## E. Validation check (mandatory before accepting results)

Before accepting any replay output as valid:

1. **`run_id` exists** under `results/switching/runs/<run_id>/`.
2. **`execution_status.csv` is present** and consistent with the repo signaling contract.
3. **Artifacts are complete** for the script’s stated outputs (tables/reports under that `run_dir` or approved repo `tables/` / `reports/` paths declared by the script).
4. **Module tag** for the scientific claim is **Switching** (no blended Relaxation/Aging claims without separate validation).

---

## F. Fail conditions

- **Any** violation of sections A–E → **RUN INVALID** for strict canonical replay purposes.
- Do **not** use MATLAB exit codes or console text as proof of success; **disk artifacts + signaling** are the gate (`docs/repo_execution_rules.md`).

---

## Reference tables

- `tables/switching_analysis_inventory.csv` — per-script contamination flag.
- `tables/switching_analysis_gaps.csv` — gap fields per analysis.
- `tables/switching_replay_plan.csv` — `guard_status` column (`ALLOW_SWITCHING_ONLY` vs `EXCLUDE_MIXED_MODULE`).
