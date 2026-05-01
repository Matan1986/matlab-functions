# Cross-module Switching–Relaxation AX organization plan

**Type:** Planning / governance only. **No scientific completion, no MATLAB, no new fits, no file moves** in this task.  
**Repo note:** Unrelated local dirty/untracked files are expected; this plan does not depend on a clean working tree.

**Machine-readable tables:** see `tables/cross_module_switching_relaxation_*` in this same prefix.  
**Status:** `tables/cross_module_switching_relaxation_AX_organization_status.csv`.

---

## A. Current artifact inventory (summary)

A light survey of **runnable entrypoints and default output locations** shows multiple **true cross-module** families that **write under `tables/relaxation/` and `reports/relaxation/`** while reading **Switching `X_eff` (materialized as `X_eff_nonunique`)** and **Relaxation RCON / RF scalars** (`A_obs`, `A_proj_nonSVD`, `m0_svd_diagnostic`, SVD score tracks). This folder placement **must not** be read as “Relaxation-only.”

| Priority | Family | True class | Why |
|----------|--------|------------|-----|
| P0 | `relaxation_switching_scaling_01/02/03` | CROSS_MODULE | Match Relaxation temperature list to Switching rows; explicit `X_eff` / `X_eff_nonunique`; claim_safety tables |
| P0 | `relaxation_activity_scalarization_01` | CROSS_MODULE | Audits scalars vs **`X_eff_nonunique`**; references Switching P0 / legacy canonical X prose |
| P0 | `relaxation_svd_xscaling_01` | CROSS_MODULE | Builds on **`relaxation_switching_scaling_01_matched_observables.csv`**; m0 vs **`X_eff_nonunique`** lawfulness |
| P1 | `relaxation_activity_representation_01/02` | RELAXATION_ONLY (per script headers) | Relaxation amplitude/SVD stability; **re-verify** before citing as AX |
| P1 | `scripts/run_relaxation_switching_nonSVD_bridge_replay_01` | CROSS_MODULE (intent) | Bridge replay; confirm outputs when run |
| P2 | `analysis/relaxation_switching_*.m` | CROSS_MODULE (intent) | Visualization / knee / motion tests |
| P2 | `relaxation_old_map_inventory` | RELAXATION_ONLY | Explicit Relaxation-only inventory banner |

**Committed runtime CSVs** under `tables/relaxation/` may be absent from `git ls-files` when ignored or run-scoped; the **canonical organizational truth for AX** is the **runner + documented output filenames** in script text until a harvest audit runs.

Full rows: `tables/cross_module_switching_relaxation_AX_current_artifact_inventory_plan.csv`.

---

## B. Proposed organization model (compatibility-preserving)

**Recommendation:** **Option 1** — add durable governance files at repo root paths:

- `docs/cross_module_switching_relaxation_AX_index.md` (evolves from draft below)
- `tables/cross_module_switching_relaxation_AX_artifact_index.csv` (machine-readable pointers)

**Why Option 1 over Option 2:** Flat `docs/` + `tables/` names maximize discoverability (`glob cross_module_switching_relaxation_AX_*`), avoid extra directory depth, and match existing patterns (`tables/switching_*` governance). Option 2 (`docs/cross_module/...`) is acceptable later if the repo adopts a `cross_module/` subtree broadly—**not required** for the first index.

**Why not Option 3 alone:** “Stronger pointers under Relaxation only” **does not fix** browse/search confusion for readers who filter by path=`relaxation`; a **top-level cross-module index** is still needed.

**Moves:** **None now.** Default **`PHYSICAL_FILE_MOVE_RECOMMENDED_NOW = NO`**.

---

## C. Naming and terminology rules

See **`tables/cross_module_switching_relaxation_AX_classification_rules.csv`** (rules CM1–CM8).

---

## D. Claim boundary plan

See **`tables/cross_module_switching_relaxation_AX_claim_boundary_plan.csv`**.

Conservative defaults aligned with scaling runners’ own diagnostic posture:

- **Bridge / linkage:** **PARTIAL** safe for careful main-text language if scoped.
- **Power-law main text:** **NO** by default.
- **Power-law supplement / diagnostic:** **PARTIAL**.
- **Universal exponent:** **NO** until cross-validation evidence exists.

---

## E. Completion order

See **`tables/cross_module_switching_relaxation_AX_completion_order.csv`** (stages 1–5).

**Rule:** **Organization index first** → **legacy AX / `get_canonical_X` archaeology** → **canonical AX summary** → **targeted science gaps** → **final claim-safety pass**.

**Do not run broad new scientific analysis** until **`SAFE_TO_RUN_NEW_SCIENTIFIC_ANALYSIS_NOW`** is deliberately set to YES in a future governance update (currently **NO** in status CSV).

---

## F. Answers to key questions

1. **Relaxation-only (current survey):** `relaxation_activity_representation_01/02` (per headers), `relaxation_old_map_inventory` family.
2. **True cross-module:** Scaling 01/02/03, activity_scalarization_01, svd_xscaling_01, bridge replay script, analysis helpers (intent).
3. **Cross-module artifacts under Relaxation folders:** **Yes** — default promoted outputs for scaling/svd_xscaling point at `tables/relaxation`, `reports/relaxation`, `figures/relaxation/canonical`.
4. **Families stay in place:** **Yes**; index them as **CROSS_MODULE** regardless of folder.
5. **Index document:** **`docs/cross_module_switching_relaxation_AX_index.md`** (+ CSV artifact index).
6. **Wording rules:** CM1–CM8 CSV + Section C above.
7. **Complete after organization:** Canonical AX summary and scoped science only after index + archaeology milestones.

---

## G. Draft pointer

Optional starter prose: **`docs/cross_module_switching_relaxation_AX_index_draft.md`**.

---

## Required verdict capsule

| Key | Value |
|-----|-------|
| `AX_ORGANIZATION_PLAN_COMPLETE` | YES |
| `CROSS_MODULE_ARTIFACTS_FOUND_UNDER_RELAXATION` | YES |
| `CROSS_MODULE_INDEX_RECOMMENDED` | YES |
| `SAFE_TO_RUN_NEW_SCIENTIFIC_ANALYSIS_NOW` | NO |
