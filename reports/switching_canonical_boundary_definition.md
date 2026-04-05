# Phase 2B — Switching canonical boundary and run trust

**Mode:** Constrained; claims trace to listed paths and directory listings only. **No MATLAB.** **Switching only** (Aging/Relaxation science excluded; `createRunContext` host path noted as technical only).

---

## Canonical boundary (definition)

**Inside the Switching canonical system**

1. **Execution entrypoint (analysis):** `Switching/analysis/run_switching_canonical.m` — defines **`Smap`**, PT row, SVD **φ₁/κ₁**, run-scoped outputs under **`results/switching/runs/<run_id>/`**.
2. **Execution entrypoint (automation):** `tools/run_matlab_safe.bat` — single-call wrapper mandated by `docs/repo_execution_rules.md`.
3. **Approved substrate:** `Switching/utils/`, `Switching ver12/` (including **`Switching_main.m`** raw-path string), `General ver2/` as referenced by the canonical script.
4. **Run identity utility (technical):** `Aging/utils/createRunContext.m` — **path-pinned** in-script; **not** Aging experiment logic.
5. **Boundary tables/reports:** `tables/switching_canonical_*.csv`, `tables/switching_layer1_robustness_*.csv`, `reports/switching_canonical_*.md`, `reports/switching_layer1_robustness_*.md`, `reports/ver12_canonical_audit.md` — **documentation and classification** artifacts for Switching.

**Outside (non-canonical for default Switching work)**

1. **Analysis scripts** under `Switching/analysis/` that are **not** `run_switching_canonical.m` — **reference-only** unless a task explicitly names them.
2. **`tables_old/`** — **historical** robustness numerics; **run IDs** referenced there are often **absent** from `results/switching/runs/` (see `reports/switching_layer1_robustness_reconciliation.md`).
3. **Runs** without **`execution_status.csv`** per signaling contract — **not** **TRUSTED_CANONICAL** for default loading.
4. **External raw paths** (e.g. drive **`L:`** parsed from **`Switching ver12/main/Switching_main.m`**) — **environment coupling**; not repo data.

---

## Classification labels (entities)

| Label | Meaning |
|-------|---------|
| **CANONICAL_CORE** | Required for normative Switching canonical execution or its documented boundary (entry script, wrapper, core run outputs, boundary docs/tables). |
| **CANONICAL_SUBSTRATE** | Required engines or utilities **on-path** for canonical execution (ver12, Switching/utils, General ver2, optional analysis scripts). |
| **LEGACY_HARMLESS** | Historical or auxiliary artifacts **not** invalidating canonical definition (e.g. `tables_old/` parameter CSVs). |
| **NONCANONICAL_RISK** | External or broken-chain dependencies (e.g. machine-specific raw root; runs failing signaling contract for trust). |

---

## Run trust labels

| Label | Criteria (artifact-backed) |
|-------|----------------------------|
| **TRUSTED_CANONICAL** | `run_switching_canonical` output tree: **`execution_status.csv`** present with **`WRITE_SUCCESS=YES`** (columns **`EXECUTION_STARTED`**, **`WRITE_SUCCESS`** inspected); **`switching_canonical_*.csv`** under **`tables/`**; **`run_manifest.json`** present. |
| **PRE_STABLE** | Execution proof present but **not** full **`switching_canonical`** science package (e.g. minimal pilot schema). |
| **UNVERIFIED** | **`execution_status.csv`** **missing** in **`run_dir`** (directory listing). |
| **NONCANONICAL** | Reserved for runs that **violate** policy if explicitly recorded; **none** so labeled in current table without further evidence. |

**Current `results/switching/runs` (inspected):** Three **`switching_canonical`** runs → **TRUSTED_CANONICAL**. One **`phi_kappa_canonical_space_analysis`** → **UNVERIFIED** (no **`execution_status.csv`**). One **`minimal_canonical`** → **PRE_STABLE**.

---

## Rules for loading data

1. **Default:** Load Switching **science** outputs only from **`TRUSTED_CANONICAL`** run directories listed in **`tables/switching_run_trust_classification.csv`**.
2. **Do not** treat **`tables_old/`** or **reports** citing **missing** **`run_id`** folders as **run-backed** without an existing **`results/switching/runs/<run_id>/`** path.
3. **Do not** assume **`Switching/analysis/*.m`** is canonical; only **`run_switching_canonical.m`** is the **default** canonical analysis entrypoint unless the task specifies another script.
4. **Raw data** paths outside the repo are **NONCANONICAL_RISK** for reproducibility; cite them from **run reports** (`run_switching_canonical_report.md`) when needed.

---

## Rules for future agents

1. Follow **`docs/repo_execution_rules.md`** — single wrapper call, signaling contract (**`execution_status.csv`**, **`run_dir`**).
2. Use **`tables/switching_canonical_boundary_and_runs.csv`** and **`tables/switching_run_trust_classification.csv`** before loading **historical** or **cross-run** inputs.
3. Distinguish **documentation artifacts** (boundary CSVs, audits) from **run outputs** — both can be **CANONICAL_CORE** class but **different** **`run_backed`** flags.

---

## Final verdicts

| Verdict | Value |
|---------|--------|
| **CANONICAL_BOUNDARY_DEFINED** | **YES** |
| **RUN_TRUST_ESTABLISHED** | **YES** (for enumerated runs; see trust table) |
| **SAFE_TO_LOAD_FROM_CANONICAL_ONLY** | **YES** — **if** agents restrict **default** science loads to **`TRUSTED_CANONICAL`** rows **only** |

---

## Machine-readable outputs

- `tables/switching_canonical_boundary_and_runs.csv`
- `tables/switching_run_trust_classification.csv`

---

*Documentation only; no code or pipeline changes.*
