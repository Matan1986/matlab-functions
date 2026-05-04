# REPO-FIG-INFRA-04D — CV07 canonical-only governance path (after INFRA-04C and INFRA-04C-CLEAN)

## 1. Executive summary

From a **canonical-only** perspective, **CV07** (`tools/agent24h_render_figures.ps1` and the three legacy PNG stems under `figures/`) is **not** part of the active Switching **paper-candidate** or **reader-hub manuscript** chain. References to those PNGs appear in **maintenance, quarantine, INFRA audits, and renderer code** — not in `reports/switching_canonical_paper_figures.md` or `docs/switching_canonical_reader_hub.md` as primary evidence paths.

**Recommended routing:** **Supersession (B)** of manuscript-style Switching visualization by **`results/switching/figures/canonical_paper/**`** and **namespace registers** (`docs/switching_canonical_reader_hub.md`, corrected-old artifact index); **formal retirement of canonical authority (C)** for CV07 legacy System.Drawing outputs under INFRA-01B/03B unless a **separately chartered** MATLAB or governance task promotes a different outcome; **keep technical MATLAB-replacement closure blocked (D)** until approved contracts exist — **without** repairing legacy March-2026 run folders or old generators.

**Retarget (A)** is **not** recommended as a default: swapping inputs to current canonical tables would **mix namespaces** and change semantics unless a **new** mapping charter is written.

## 2. INFRA-04C blocked-state recap

Per `reports/maintenance/repo_agent24h_matlab_replacement_INFRA_04C.md`, materialization of `tables/alpha_structure.csv`, valid `phi2_structure_metrics.csv`, and `tables/kappa1_from_PT.csv` **failed** because upstream pipelines depend on **missing legacy** `results/switching/runs/**` artifacts (`switching_alignment_core_data.mat`, default `PT_matrix.csv` paths, and related inputs). The MATLAB replacement errored on missing `alpha_structure.csv`. No `figures/infra_04_agent24h_replacement/**` outputs were produced. Legacy CV07 PNGs were **not** modified.

## 3. INFRA-04C-CLEAN recap

Per `reports/maintenance/repo_agent24h_infra04c_side_effect_cleanup.md`, invalid **placeholder** outputs from the failed phi2 generator run were **removed** from the working tree: `tables/phi2_structure_metrics.csv`, `tables/phi2_kernel_comparison.csv`, `tables/phi2_regime_stability.csv`, `reports/run_phi2_shape_physics_test.md`. **No** analysis scripts, legacy PNGs, or INFRA-04C maintenance evidence were edited. **`matlab_error.log`** was **preserved** as optional diagnostic (not deleted in this audit series). The cleanup **does not** change CV07 governance: it only prevents mistaken use of NaN/FAIL stubs.

## 4. Why old-chain repair is out of scope

Repairing or regenerating **legacy alignment-era** run artifacts **only** to feed CV07 or its CSV inputs would invert policy priority: current manuscript routing is defined by **reader hub** vocabulary and **corrected-old** gates, not by rescuing fixed **March 2026** `decCfg` run IDs inside old generators. **Do not** patch generators or rerun old chains as the **default** path to close CV07.

## 5. CV07 legacy renderer purpose

`tools/agent24h_render_figures.ps1` uses **System.Drawing** to build:

1. Four **scatter panels** from `tables/alpha_structure.csv` (latent scalars vs proxies; `T_K` as color driver).
2. **Phi2 metric bars** and narrative text from the first row of `tables/phi2_structure_metrics.csv`.
3. A **two-panel bar summary** using **hard-coded numeric literals** in source (not CSV) for LOOCV-style comparisons.
4. **`tables/agent24h_correlations.csv`** as a Pearson mirror (renderer-emitted).

Header framing is **CI/sandbox** — INFRA-01B/03B still **quarantine** System.Drawing PNGs for default canonical or manuscript authority until MATLAB `.fig`+`.png` or documented retirement.

## 6. Current references to CV07 outputs

**Located:** INFRA maintenance (`repo_nonmatlab_P0_*`, INFRA-03/04/04B), **quarantine CSV rows** (Q03-05..07), `tools/agent24h_render_figures.ps1`, `tools/agent24h_render_figures_matlab_replacement.m`, `analysis/run_agent24h_figures.m`, INFRA-04C tables.

**Not located in inspected canonical docs:** `docs/**/*.md` hits for the three basenames; **`reports/switching_canonical_paper_figures.md`** lists **`results/switching/figures/canonical_paper/**`** outputs only — **no** CV07 stems.

**Conclusion:** **CV07_ACTIVE_CANONICAL_USE_FOUND = NO** for the Switching canonical paper / reader-hub primary chain; references are **policy and tooling**, not endorsed manuscript figure IDs.

## 7. Canonical and current replacement candidates

| Artifact / doc | Role vs CV07 |
| --- | --- |
| `results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.{fig,png,pdf}` | Paper-candidate **main** figure from closed P0/P1/P2 + `switching_canonical_S_long` path per `reports/switching_canonical_paper_figures.md`. **Different** product than CV07 scatter bundle. |
| `results/switching/figures/canonical_paper/switching_supp_Xeff_components.{fig,png,pdf}` | Supplement **X_eff** governance visuals; not a panel-for-panel substitute for CV07. |
| `docs/switching_canonical_reader_hub.md` | **Router** for namespaces (`CANON_GEN_SOURCE`, corrected-old, replay vs diagnostic). |
| `tables/switching_corrected_old_authoritative_artifact_index.csv` | **Authoritative table paths** for `CORRECTED_CANONICAL_OLD_ANALYSIS` — not the same CSV contracts as `alpha_structure.csv` / phi2 agent metrics / kappa1-from-PT for CV07. |
| `docs/switching_analysis_map.md`, `docs/switching_artifact_policy.md` (cited from hub) | **Prevent** silent mixing of legacy decomposition semantics with manuscript claims. |

These artifacts **supersede** CV07 for **endorsed** Switching communication; they **do not** supply drop-in files for the CV07 renderer without **new** derivation work.

## 8. Whether semantic-preserving retargeting is possible

**Not as a path-only swap.** Current canonical **S_long** and P0/P1/P2 ladders differ in **contract and namespace** from the **legacy-run-bound** tables the CV07 generators expect. Retargeting would **reinterpret** variables or blend families unless a **chartered** mapping ties explicit column semantics to approved run IDs. **SEMANTIC_PRESERVING_RETARGET_POSSIBLE = NO** without that charter.

## 9. Options considered

| Option | Assessment |
| --- | --- |
| **A — Retarget MATLAB replacement to current canonical exports** | **Default NO.** Semantic and namespace collision risk; requires **future separate task** with explicit contracts. |
| **B — Supersede CV07 by canonical paper figures and registers** | **YES.** Align manuscript visuals with `canonical_paper/**` and hub/index discipline. |
| **C — Formal retirement of CV07 as canonical-authoritative** | **YES** for **promotion authority** (files may remain as historical/sandbox; INFRA-03B closure via documentation + supersession). |
| **D — Keep blocked** | **YES** for **technical** MATLAB replacement completion until inputs exist under an **approved** spec — **not** via silent old-run regeneration. |

## 10. Recommended governance decision

1. Treat CV07 PNG stems as **non-authoritative** for default manuscript or canonical Switching proof unless a **future** MATLAB run under policy **supersedes** them with validated inputs.
2. Use **`canonical_paper/**`** and **reader-hub read order** for Switching figure narrative ownership.
3. Record **KEEP_BLOCKED** for **MATLAB replacement execution** until a **chartered** input pipeline exists; **do not** restore legacy `results/switching/runs/**` folders **solely** for CV07.

## 11. Risks

- **Mis-citation:** Filename confusion between diagnostic and authoritative Phi1/kappa families — mitigate with hub + terminology contract.
- **Policy drift:** CV07 quarantine rows remain valid; do not treat INFRA-04C-CLEAN as relaxing INFRA-03B.

## 12. What not to do next

- Do **not** regenerate **legacy** March-2026 run artifacts to refill CV07 inputs.
- Do **not** edit old generators or CV07 scripts in opportunistic **repair**.
- Do **not** treat repo-wide cleanup or dependency patching as CV07 closure.
- Do **not** delete **`matlab_error.log`** in this decision series (optional operator choice only).

## 13. Recommended next step

If stakeholders still want **CV07-style** layouts, open a **new chartered task**: explicit **canonical column mapping**, run IDs, and figure-three literal provenance — **outside** this maintenance-only routing. Until then, cite **`canonical_paper/**`** and index-backed tables for Switching manuscript visuals.

---

**Audit metadata:** Read-only inspection; no MATLAB, Python, Node, or PowerShell; no deletion in this task; no stage, commit, or push; ASCII only.
