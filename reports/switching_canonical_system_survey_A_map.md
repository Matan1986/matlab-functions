# SW-CANON-SURVEY-A — Switching canonical analysis system map

**Survey ID:** `switching_canonical_system_survey_A`  
**Mode:** Read-only topology and organization (no scientific correctness review).  
**Execution:** No MATLAB, Python, or Node runs for this survey.  
**Repo hygiene (pre-survey):** `git diff --cached --name-only` was **empty** (no staged changes). Working tree contained many unrelated untracked/modified paths; see git snapshot in inventory `notes` where relevant.

**Governance reference followed:** `docs/repo_execution_rules.md` (wrapper-only execution policy for any future runs; this document does not execute code).

---

## 1. Executive summary

The Switching “canonical analysis system” in this repository is **not a single pipeline name** but a **layered governance stack**: a **registered canonical producer** (`run_switching_canonical.m`) that emits **mixed-semantics columns**, overlaid with a **manuscript narrative contract** favoring **`CORRECTED_CANONICAL_OLD_ANALYSIS`** (old centered collapse + residual recipe on canonical `S`), plus **large parallel corpora** of **tables** (~801 `tables/switching*.csv`) and **reports** (200+ `reports/switching*.md`) that record audits, phase gates (P0–P5, phase4A–4D, etc.), quarantine, and replay status.

**Primary source-of-truth entry (human):** `reports/switching_corrected_canonical_current_state.md` (also cited from `run_switching_canonical.m` header and `docs/switching_governance_persistence_manifest.md`).

**Primary structural map (namespace landscape):** `docs/switching_analysis_map.md` (binds narrative namespaces to technical namespaces and lists downstream tables/reports).

**Canonical execution entrypoint (machine registry):** `tables/switching_canonical_entrypoint.csv` → **`Switching/analysis/run_switching_canonical.m`**.

**Validation / `Switching/validation/`:** No dedicated `Switching/validation/` tree was found; validation materializes as **analysis and diagnostics scripts** under `Switching/analysis/` and `Switching/diagnostics/`, plus **reports/tables** status artifacts.

---

## 2. Repository layout (Switching-relevant)

| Area | Role |
|------|------|
| `Switching/analysis/` | Core MATLAB analysis scripts including **`run_switching_canonical.m`**, collapse hierarchy/visualization, phase4B C01/C02/C02B audits, corrected-old builder readiness, legacy inventories, mode audits. |
| `Switching/diagnostics/` | Targeted audits (e.g. CDF backbone repair aggressiveness, corrected-old task QA). |
| `Switching/utils/` | Run roots, table writers, identity helpers (e.g. `switchingCanonicalRunRoot.m`, `switchingWriteTableBothPaths.m`). |
| `Switching/analysis/experimental/` | Explicitly non-canonical / experimental runners (per map docs). |
| `scripts/` | ~40 `run_switching*.ps1` / `.m` **orchestrators** (P0/P1/P2/P4, old replay, gauge atlas, phase4C stress, canonical map spine, corrected-old builder, etc.). |
| `docs/switching_*` + `docs/decisions/` + `docs/observables/` + `docs/templates/` | Contracts, boundaries, phi1 terminology, namespace headers, **decision records**. |
| `tables/switching*.csv` | Extensive machine-readable governance, inventories, phase status, quarantine indexes, backbone maps, X_eff atlases. |
| `reports/switching*.md` | Human-readable counterparts and narrative audits (very large set). |
| `results/switching/` | Present on disk; canonical run outputs and separated views are referenced from governance tables (e.g. authoritative artifact index cites `run_*_switching_canonical`). |
| `results_old/switching/` | Present; **legacy / template** runs (e.g. barrier map `PT_matrix` routes) cited in authoritative artifact index. |
| `analysis/switching/xy/`, `analysis/switching/xx/` | Deprecated status stubs pointing at `canonical/xy_switching/` (that path **not found** in this workspace snapshot — **stale pointer risk**). |
| `figures/switching/` | Directory exists; **current git status showed deleted** tracked figure files under `figures/switching/` (orientation/range lock assets) — **working-tree / publication hygiene issue**, not surveyed for pixel content. |
| `reports/maintenance/*switching*` | Identity resolver, SoT owner audits, boundary remediation — **cross-cutting maintenance**, not only Switching science. |

---

## 3. Conceptual groups (main)

1. **Canonical generation / decomposition** — `run_switching_canonical.m` (mixed producer); `run_switching_canonical_collapse_hierarchy.m`, decomposition audits, `CANON_GEN_SOURCE` vs `EXPERIMENTAL_PTCDF_DIAGNOSTIC` split per `docs/switching_analysis_map.md`.
2. **Canonical replay / figure replay** — `CANON_FIGURE_REPLAY`-style scripts, stabilized gauge replay, `scripts/run_switching_stabilized_gauge_figure_replay.m`, `run_switching_canonical_first_figure_anchor.m`, paper-figure scripts.
3. **Old / corrected-old reconstruction** — `scripts/run_switching_corrected_old_authoritative_builder.ps1`, `Switching/analysis/run_switching_corrected_old_builder_readiness_check.m`, `tables/switching_corrected_old_authoritative_*.csv`, `reports/switching_corrected_old_*.md`.
4. **Legacy quarantine** — `reports/switching_quarantine_index.md`, `tables/switching_quarantine_index.csv`, `tables/switching_misleading_or_dangerous_artifacts.csv` (cited in governance manifest), `LEGACY_OLD_TEMPLATE` namespace.
5. **X_eff / effective observables** — `scripts/run_switching_Xeff_width_validity_atlas.ps1`, `tables/switching_Xeff_*.csv`, `switching_center_width_*`, effective observable locks in corrected-old index.
6. **Collapse / collapse-failure** — Phase4B C01/C02/C02B runners and tables (`switching_phase4B_*`), collapse stress (`phase4C`), collapse specification (`phase4D`), `run_switching_collapse_subrange_analysis.m`, `run_switching_canonical_collapse_visualization.m`.
7. **Visualization / publication** — X-panel orientation/range lock scripts, gauge component summaries, `scripts/run_switching_canonical_paper_figures.ps1`, forensic replot scripts.
8. **Governance / naming / SoT** — `docs/switching_governance_persistence_manifest.md`, `docs/decisions/switching_main_narrative_namespace_decision.md`, `docs/switching_phi1_terminology_contract.md`, `tables/switching_analysis_claim_boundary_map.csv`, semantic/forbidden-term tables.
9. **Validation / status / manifest / fingerprint** — `switching_*_status.csv` pairs across phases, `switching_canonical_run_closure.csv`, maintenance identity-resolver tables, `tools/switching_canonical_run_closure.m`, infrastructure cross-refs in `docs/infrastructure_laws.md`.

---

## 4. Likely source-of-truth documents and tables

**Read-first chain**

1. `reports/switching_corrected_canonical_current_state.md`
2. `docs/switching_analysis_map.md`
3. `docs/switching_governance_persistence_manifest.md`
4. `docs/decisions/switching_main_narrative_namespace_decision.md`
5. `tables/switching_canonical_entrypoint.csv` + `tables/switching_corrected_old_authoritative_artifact_index.csv`

**Supporting locks**

- `docs/switching_canonical_reality.md` — factual flags from survey tables (S object on disk, multi-definition warnings).
- `docs/switching_phi1_terminology_contract.md` + `tables/switching_phi1_terminology_registry.csv` / `tables/switching_phi1_source_of_truth_pointer.csv`
- `reports/switching_quarantine_index.md` + `tables/switching_quarantine_index.csv`
- `reports/switching_stale_governance_supersession.md` (supersedes stale wording per manifest)

**Deprecated but still linked**

- `docs/switching_canonical_definition.md` — banner: **DEPRECATED**; points to `canonical/xy_switching/` (missing here).

---

## 5. Likely canonical entrypoints and orchestrators

| Kind | Path |
|------|------|
| **Registered canonical MATLAB entrypoint** | `Switching/analysis/run_switching_canonical.m` |
| **Minimal / non-canonical** (explicitly warned in deprecated definition doc) | `Switching/analysis/run_minimal_canonical.m` |
| **Corrected-old authoritative builder** | `scripts/run_switching_corrected_old_authoritative_builder.ps1` (orchestration; MATLAB helpers under `Switching/analysis/` / `scripts/`) |
| **High-traffic PS1 runners** | `scripts/run_switching_canonical_map_spine.ps1`, `scripts/run_switching_canonical_output_separation.ps1`, P0/P1/P2/P4 series, old replay audits |
| **Root-level Switching runner (untracked in snapshot)** | `run_switching_fixed_T_current_cuts_canonical_replay.m` |
| **Cross-module** | `scripts/run_cross_module_switching_relaxation_*.m` (out of strict Switching-only scope but uses Switching namespaces) |

---

## 6. Key status / classification artifacts

- `tables/switching_analysis_classification_status.csv` + `reports/switching_analysis_classification.md`
- `tables/switching_corrected_old_authoritative_builder_status.csv` (referenced from governance manifest)
- Phase gate tables: `tables/switching_phase4A_*`, `switching_phase4B_*`, `switching_phase4C_*`, `switching_phase4D_*`, `switching_phase5*_*.csv`
- `tables/switching_canonical_current_truth_status.csv` / `reports/switching_canonical_current_truth_freeze.md` (naming may vary; pattern `switching_canonical_current_truth*` exists in corpus)

---

## 7. Stale, draft, duplicate, quarantine, or confusing candidates

| Issue | Evidence |
|-------|----------|
| **Deprecated doc still in tree** | `docs/switching_canonical_definition.md` marks itself deprecated; links to missing `canonical/xy_switching/`. |
| **Stale status stubs** | `analysis/switching/xy/status.md` (deprecated banner + `canonical/xy_switching` pointer). |
| **Filename vs role mismatch** | `switching_canonical_phi1.csv` filename does not imply manuscript Phi1 authority — documented in `docs/switching_analysis_map.md` / phi1 contract. |
| **Mixed producer confusion** | `run_switching_canonical.m` header: multiple `NAMESPACE_ID` lines; mitigated by column-namespace tables and output separation design. |
| **Massive parallel doc/table surface** | Hundreds of `reports/switching*.md` and `tables/switching*.csv` — high **navigation** cost; risk of reading an outdated report without checking `switching_stale_governance_supersession` / `current_state`. |
| **Deleted figures in working tree** | Git status: `D figures/switching/phase4B_C01_*.png`, `phase4B_C02_*` — may confuse audits that expect committed figures. |
| **Untracked Switching scripts** | Snapshot showed `?? scripts/run_switching_*.m` and `?? Switching/diagnostics/...` for some files — **provenance gap** until tracked. |

---

## 8. Biggest organization gap

**Volume and versioning of narrative artifacts:** The authoritative *intent* is concentrated in a small **read-first** set (`current_state`, `analysis_map`, governance manifest), but the repository also contains **very large** historical report/table corpora without a single enforced “latest pointer” per topic beyond those hubs. New agents can land on **phase-N** or **superseded** markdown unless they follow the manifest’s pointer chain.

---

## 9. Survey outputs (this task)

| Output | Path |
|--------|------|
| Map (this file) | `reports/switching_canonical_system_survey_A_map.md` |
| Inventory CSV | `tables/switching_canonical_system_survey_A_inventory.csv` |
| Groups CSV | `tables/switching_canonical_system_survey_A_groups.csv` |
| Status CSV | `tables/switching_canonical_system_survey_A_status.csv` |

---

## 10. Staging guidance (survey outputs only)

If and only if you intend to record **these four paths** and nothing else from a dirty tree:

```text
git add -- reports/switching_canonical_system_survey_A_map.md tables/switching_canonical_system_survey_A_inventory.csv tables/switching_canonical_system_survey_A_groups.csv tables/switching_canonical_system_survey_A_status.csv
```

Do **not** stage unrelated untracked maintenance or Relaxation files. Commit safety is **content-safe** for these files; **process-safe** only when the commit is scoped to them (working tree otherwise unclean in the surveyed snapshot).
