# REPO-INFRA-03B: Mandatory remediation plan for P0 figure governance (CV06, CV07)

## 1. Executive summary

REPO-INFRA-03 correctly classified **CV06** (`scripts/run_switching_canonical_paper_figures.ps1`) as MATLAB-driven via an orchestrator and **CV07** (`tools/agent24h_render_figures.ps1`) as a true **System.Drawing** PNG renderer. INFRA-03 wording for **CV07** was overly **conditional** (for example "if promoted"). This record **upgrades** governance to a **mandatory remediation** posture: **every figure-related output is treated as future-promotable scientific output unless explicitly retired**. **Quarantine is only a temporary gate**, not an acceptable endpoint. **CV06** must reach **MATLAB export compliance** (`.fig` plus `.png` per default policy). **CV07** must reach **MATLAB renderer replacement or formal retirement** with documentation. No scripts were edited in this task; no figures were regenerated.

## 2. User clarification (authoritative for INFRA-03B)

Record verbatim intent:

All figure-related outputs are to be treated as future-promotable scientific outputs unless explicitly retired. Therefore, every non-compliant figure path must receive a concrete remediation path. Quarantine is allowed only as a temporary gate, not as an endpoint.

## 3. Correction to INFRA-03 interpretation

| Topic | INFRA-03 emphasis | INFRA-03B correction |
| --- | --- | --- |
| CV07 optional promotion | Language allowed deferral until "promotion" | **No deferral:** non-compliant PNG paths require **mandatory** resolution (MATLAB replacement **or** documented retirement). |
| Quarantine | Described as blocking manuscript use | Quarantine remains **valid as a gate**, but **must** pair with a **defined final resolution** (this document and CSV tables). |
| CV06 | MATLAB engine noted; `.fig` gap noted | Same technical facts; remediation is **mandatory export compliance**, not optional. |

## 4. Mandatory remediation rule

Under REPO-INFRA-01B and the user clarification above:

1. **Assume future-promotability** for figure outputs unless a path is **explicitly retired** (documented, not implied).
2. **Every non-compliant figure path** gets a **concrete remediation** record (see CSV).
3. **Quarantine** states **what is blocked until fixed**; it does **not** replace fixing.

## 5. CV06 required resolution

**Script:** `scripts/run_switching_canonical_paper_figures.ps1`

**Nature:** PowerShell **orchestration** that writes a temporary MATLAB script and runs **`tools/run_matlab_safe.bat`**. Figure rendering and raster export are **MATLAB** responsibilities in the generated block.

**Mandatory final resolution:** **MATLAB export compliance fix** so that **Switching canonical paper-candidate figures** emit **both `.fig` and `.png`** for the same scientific figure content, preserving plotting and data logic. **PDF** may remain as a sidecar where policy allows; **default manuscript readiness** for this repo expects **`.fig` and `.png`** per INFRA-01B unless a task-specific override exists.

**Temporary quarantine:** Applies to treating outputs as **complete** for **default manuscript** packaging **until** `.fig` exists alongside `.png` for the corresponding panels (see INFRA-03 quarantine table for artifact stems).

## 6. CV07 required resolution

**Script:** `tools/agent24h_render_figures.ps1`

**Nature:** **System.Drawing** rasterization to **`figures/*.png`** without MATLAB figure objects.

**Mandatory final resolution:** **MATLAB renderer replacement** exporting **`.fig` and `.png`**, **or** **explicit retirement** of the figure path (documentation that the PNG bundle is not scientifically maintained and must not be cited), if truly not needed.

**Temporary quarantine:** **Canonical and manuscript scientific figure use** remains **blocked** until one of the final resolutions is completed.

## 7. Conversion and remediation queue

Machine-readable order: `tables/maintenance_repo_nonmatlab_P0_figure_mandatory_conversion_queue_INFRA_03B.csv`.

Summary:

| Order | Item | Action |
| --- | --- | --- |
| 1 | CV06 | Add MATLAB-side `.fig` export compliance to the figure export path used when the wrapper runs. |
| 2 | CV07 | Replace with MATLAB `.fig + .png` pipeline **or** formally retire with written scope. |

## 8. What is temporarily quarantined

- **CV06:** Use of **PNG (and PDF)** alone as a **complete** default manuscript figure package **until** matching **`.fig`** exports exist for the same figure objects. **Data and MATLAB logic** are not dismissed; **export completeness** is the gate.
- **CV07:** **`figures/*.png`** from this script for **canonical or manuscript scientific figure authority** until **MATLAB** outputs exist **or** the path is **formally retired**.

## 9. What counts as final resolution

**CV06 final resolution** is reached when:

- MATLAB code that owns the figure objects **writes `.fig` and `.png`** for each scientific figure stem in the canonical paper bundle (aligned with INFRA-01B defaults), and
- Orchestration may remain PowerShell **only** if it does not perform non-MATLAB rendering.

**CV07 final resolution** is reached when either:

- A **MATLAB** runner produces **`.fig` and `.png`** that supersede the System.Drawing PNG bundle for the same scientific intent, **or**
- The **System.Drawing** outputs are **explicitly retired** (documented non-use for scientific or manuscript promotion), with any residual files clearly outside canonical paths.

## 10. Recommended next concrete tasks (ordered)

1. **SW-FIG-INFRA-01** — Add **`.fig` export compliance** to the **Switching canonical paper figure MATLAB export path** used by **CV06** (the MATLAB block executed via the wrapper), preserving layout, labels, and data logic.
2. **REPO-FIG-INFRA-04** — Inspect **`tools/agent24h_render_figures.ps1`** and **replace** it with a **MATLAB `.fig + .png`** path **or** **formally retire** the figure path with documentation if no longer scientifically needed.
3. Continue **P1 MATLAB parity** tasks from REPO-INFRA-02 **after** **P0 figure compliance** for CV06 and CV07 is **closed or explicitly scoped** per this plan.

## Artifact index

| Artifact |
| --- |
| `reports/maintenance/repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B.md` (this file) |
| `tables/maintenance_repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B.csv` |
| `tables/maintenance_repo_nonmatlab_P0_figure_mandatory_conversion_queue_INFRA_03B.csv` |
| `tables/maintenance_repo_nonmatlab_P0_figure_mandatory_remediation_INFRA_03B_status.csv` |
