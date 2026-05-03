# CM-SW-RLX-AX-20C — Commit-readiness audit (AX-18C / 18D / 20A / 20B package)

**Audit-only.** No staging, commit, push, or analyses performed in this task.

## Git gate

- **`git diff --cached --name-only`:** **empty** (safe to proceed with an explicit staging plan).
- **`.gitignore` impact:** Repository rules ignore **`reports/**`** and **`tables/**`** (and **`tables/*status*`** matches many status CSVs). **All** `reports/…` and `tables/…` artifacts in this package **must** be added with **`git add -f "<path>"`** so they are not silently skipped. **`docs/cross_module_switching_relaxation_AX_index.md`** and **`scripts/run_cm_sw_rlx_ax_18c_t_scaling_baseline.mjs`** are **not** ignored (normal `git add` works).

## 1. Expected files — existence

**All 22 paths** listed in the task exist on disk (verified with `Test-Path`).

## 2. Status CSV — `TASK_COMPLETED`

| Audit | File | `TASK_COMPLETED` |
|-------|------|------------------|
| AX-18C | `…_AX_18C_status.csv` | **YES** |
| AX-18D | `…_AX_18D_status.csv` | **YES** |
| AX-20A | `…_AX_20A_status.csv` | **YES** |
| AX-20B | `…_AX_20B_index_registration_status.csv` | **YES** |

## 3. Physical scaling law — forbidden in status artifacts

- **AX-18C:** `PHYSICAL_SCALING_LAW_SUPPORTED` = **NO**; `SAFE_TO_SAY_PHYSICAL_SCALING_LAW` = **NO**
- **AX-18D:** `PHYSICAL_SCALING_LAW_ESTABLISHED` = **NO**
- **AX-20A:** `PHYSICAL_SCALING_LAW_ESTABLISHED` = **NO**; `SAFE_TO_CLAIM_PHYSICAL_POWER_LAW` = **NO**
- No status file asserts a physical scaling law as **established**.

## 4. AX-20A / AX-20B — classification and alphas

**AX-20A status (`…_AX_20A_status.csv`):**

- `FINAL_RELATIONSHIP_CLASSIFICATION` = **`EMPIRICAL_INVD_POWERLIKE_SCALING`**
- `POWERLAW_ALPHA_AOBS` = **0.562460847**
- `POWERLAW_ALPHA_ASVD` = **0.558279495**
- `PHYSICAL_SCALING_LAW_ESTABLISHED` = **NO**
- `SAFE_FOR_MANUSCRIPT_DISCUSSION` = **`YES_WITH_BOUNDED_WORDING`**

**AX-20B:** The registration status CSV does not duplicate numeric alphas; **`docs/cross_module_switching_relaxation_AX_index.md`** records **`EMPIRICAL_INVD_POWERLIKE_SCALING`**, **`POWERLAW_ALPHA_AOBS` / `POWERLAW_ALPHA_ASVD`**, and **`PHYSICAL_SCALING_LAW_ESTABLISHED = NO`** in prose (aligned with AX-20A). Manuscript boundary flags are recorded (`MANUSCRIPT_BOUNDARY_RECORDED` = YES).

**Note:** AX-18D uses `SCALING_CLAIMS_MANUSCRIPT_SAFE` = **`YES_WITH_SMALL_N_CAVEATS`** — equivalent bounded-discussion intent vs AX-20A wording.

## 5. Canonical AX index — no duplicate “official” file

- **Canonical index:** `docs/cross_module_switching_relaxation_AX_index.md` (this filename is unique for the **official** index).
- **Separate drafts:** `docs/cross_module_switching_relaxation_AX_index_draft.md` and `docs/cross_module_switching_relaxation_index_draft.md` — **different paths**; **not** duplicates of the canonical file.

## 6. Index content — AX-20A section and upstream links

Confirmed in **`docs/cross_module_switching_relaxation_AX_index.md`:**

- Section **“Manuscript evidence path — CM-SW-RLX-AX-20A”**
- Links to **AX-17B**, **XEFF width audit 18**, **AX-18B**, **AX-18C**, **AX-18D**, **AX-19A** report paths.

## 7. Unrelated repo changes

Full `git status` shows many **untracked** and **modified** paths unrelated to this package. **Do not** use `git add .` — only the **explicit paths** in `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20C_explicit_staging_plan.csv`.

## 8. Index — untracked and safe to include

At audit time, **`docs/cross_module_switching_relaxation_AX_index.md`** was **untracked** (`??`) and **should be included** in the AX documentation commit (valid structure; links resolve to repo-relative paths).

## 9. Outputs of this audit

- This report: `reports/cross_module_switching_relaxation_CM_SW_RLX_AX_20C_commit_readiness.md`
- Inventory: `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20C_package_inventory.csv`
- Staging plan: `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20C_explicit_staging_plan.csv`
- Status: `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20C_status.csv`

## 10. Optional companion (not in the 22-file core list)

- **`scripts/run_cm_sw_rlx_ax_18c_t_scaling_baseline.mjs`** — regenerates AX-18C tables/reports; **untracked** at audit time; **recommended** for reproducibility as a **separate explicit `git add`** (see staging plan optional row).

**END**
