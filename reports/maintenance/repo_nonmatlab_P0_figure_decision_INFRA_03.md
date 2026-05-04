# REPO-INFRA-03: P0 non-MATLAB figure quarantine and MATLAB conversion decision

## Governing policy

This decision record follows `reports/maintenance/repo_language_figure_policy_INFRA_01B.md` (REPO-INFRA-01B, repository-wide). INFRA-02 identified **two** P0 conversion rows (**CV06**, **CV07** in `tables/maintenance_repo_matlab_conversion_plan_INFRA_02.csv`). This task **inspects** those scripts **without editing** them and assigns **quarantine**, **MATLAB conversion / repair**, or **obsolete** outcomes.

## 1. Executive summary

| P0 entry | Script | Inspection finding | Primary disposition |
| --- | --- | --- | --- |
| CV06 | `scripts/run_switching_canonical_paper_figures.ps1` | **Figures are produced by MATLAB** code emitted into `scripts/tmp_run_switching_canonical_paper_figures.m` and executed via `tools/run_matlab_safe.bat`. PNG/PDF come from MATLAB `exportgraphics`. **Not** a PowerShell-drawn scientific figure pipeline. | **Manuscript quarantine until MATLAB export policy is complete**: add matching **`.fig`** for each scientific figure (INFRA-01B default). **Not obsolete.** **Not** a request to "convert PowerShell drawing to MATLAB" for the figure panels themselves. |
| CV07 | `tools/agent24h_render_figures.ps1` | **All raster output uses `System.Drawing`** (`Bitmap`, scatter panels, bar panels). Header states **CI/sandbox**. Writes PNG under `figures/` and `tables/agent24h_correlations.csv`. | **Quarantine for manuscript and canonical scientific figures** per INFRA-01B until replaced by **MATLAB** figure generation with **`.fig` and `.png`**. **Convert to MATLAB** if these visuals are ever promoted **without** explicit non-MATLAB approval. **Not obsolete** as a labeled accelerator for sandbox/CI. |

## 2. INFRA-02 P0 list confirmation

- **P0_FIGURE_PATHS_CONFIRMED:** The two P0 items from INFRA-02 are **CV06** and **CV07** only (see conversion plan CSV). No additional P0 rows were introduced in this task.

## 3. Policy interpretation used here

- INFRA-01B: **MATLAB is mandatory for scientific figure generation** unless the user **explicitly approves** another language for **that** task; scientific figure tasks should emit **both `.fig` and `.png`** unless overridden for that task.
- **Quarantine** means: **do not cite or ship** these artifacts as **canonical or manuscript** scientific figures until **lift conditions** in the quarantine table are met (or explicit approval is documented).

## 4. Per-path decisions (detail)

### 4.1 CV06 `scripts/run_switching_canonical_paper_figures.ps1`

**Figure engine:** **MATLAB** (generated inline script, wrapper execution).

**Why INFRA-02 flagged P0:** The **orchestrator** is PowerShell and outputs land as **PNG/PDF**; superficially similar to "non-MATLAB figures." Code inspection shows **drawing is MATLAB**.

**Remaining gap vs INFRA-01B:** The embedded MATLAB uses **`exportgraphics`** to **PNG and PDF** only. There is **no `savefig`** (or equivalent) for **`.fig`** in the inspected fragment. Therefore manuscript-grade **default completeness** is **not** met until **`.fig`** is added for the same figure objects (or the task is explicitly exempted).

**Obsolete:** **NO**.

**Primary recommendation:** Treat as **MATLAB compliance repair** (add **`.fig`** export for main and supplement figures; long-term, replace ephemeral `tmp_run_switching_canonical_paper_figures.m` with a **checked-in** runnable under repository rules when you implement changes).

### 4.2 CV07 `tools/agent24h_render_figures.ps1`

**Figure engine:** **PowerShell / System.Drawing** (true non-MATLAB scientific-style raster figures).

**Outputs:** `figures/latent_vs_observable_proxy_comparison.png`, `figures/phi1_phi2_in_experimental_language.png`, `figures/observable_replacement_summary.png`, plus `tables/agent24h_correlations.csv` (numeric mirror, not a figure).

**Obsolete:** **NO** (useful for CI/sandbox if **clearly non-canonical**).

**Primary recommendation:** **Quarantine** PNGs for **manuscript or canonical** use **unless** replaced by **MATLAB** (`.fig` + `.png`) or the user **explicitly approves** this script for a named figure task. **Convert to MATLAB** when those panels must become **inspectable scientific figures** in the default policy sense.

## 5. Manuscript relevance

- **CV06:** **YES** — paths and naming (`canonical_paper`, paper-candidate wording) are **manuscript-oriented** when inputs exist.
- **CV07:** **CONDITIONAL** — default intent is **CI/sandbox** per file header; manuscript relevance is **HIGH only if** a workflow cites these PNGs as evidence.

Aggregate flag interpretation is recorded in `tables/maintenance_repo_nonmatlab_P0_figure_decision_INFRA_03_status.csv`.

## 6. Quarantine and conversion artifacts

- Quarantine registry: `tables/maintenance_repo_nonmatlab_P0_figure_quarantine_INFRA_03.csv`
- Conversion / repair plan: `tables/maintenance_repo_nonmatlab_P0_figure_conversion_plan_INFRA_03.csv`
- Machine-readable decisions: `tables/maintenance_repo_nonmatlab_P0_figure_decision_INFRA_03.csv`

## 7. What was not done (guardrails)

- No scientific analysis reruns, no figure regeneration, no edits to existing scripts or prior artifacts, no git stage/commit/push (see status CSV).

## 8. Recommended next steps (implementation outside INFRA-03)

1. **CV06:** Add **`.fig`** export alongside existing PNG/PDF in the **MATLAB** block (future edit), then clear **quarantine** for manuscript use of those stems.
2. **CV07:** If any publication path needs these panels, **author MATLAB runners** that reproduce layout with **`.fig` and `.png`**; until then, keep **quarantine** labels on the PNG paths.
