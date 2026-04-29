# F7B0 Aging old-analysis canonical reconstruction plan (summary)

**Task:** Planning documentation only. No reconstruction implemented; no writers patched.

**Source of truth (committed):** `docs/aging/aging_old_analysis_canonical_reconstruction_plan.md` on `main` (sections **1 through 11**).

## Purpose

Define an **Aging-specific** path from legacy outputs to lineage-safe replay and optional canonical reconstruction, without treating old CSVs or plots as canonical evidence.

## Full plan structure (matches committed doc)

1. Old-analysis inventory scope  
2. Reconstruction targets  
3. Observable identity gates  
4. Lineage sidecar prerequisites  
5. Canonical promotion criteria  
6. Replay vs reconstruction rule  
7. Tau/R reconstruction plan  
8. Forbidden shortcuts  
9. Execution order (proposed)  
10. **Review-stage visualization and figure exports**  
11. Stop conditions  

## Section 10 — Review-stage visualization (summary)

During Aging reconstruction **review** stages (replay diagnostics, parity checks, human review of lineage replay and canonical reconstruction candidates), figures must follow:

- `docs/visualization_rules.md`
- `docs/figure_style_guide.md`
- `docs/figure_export_infrastructure.md`

**Exports:** Where export rules apply, deliver **PNG** and **MATLAB FIG** (`.fig`) for review-stage figures so reviewers can compare raster outputs and reopen editable layouts.

**Evidence role:** Figures are **diagnostic and review artifacts** only. They are **not** standalone canonical evidence and do not replace tables, sidecars, or registry-backed identities.

**Prohibited:** Changing **data paths**, **scientific calculations**, or **analysis logic** solely to improve figure appearance. Layout/style changes must stay within visualization and export rules without altering numerical pipelines.

## Authoritative document

Full normative text: `docs/aging/aging_old_analysis_canonical_reconstruction_plan.md`

## Machine-readable tables

| File | Role |
|------|------|
| `tables/aging/aging_F7B0_old_analysis_reconstruction_scope.csv` | Analysis family inventory scope |
| `tables/aging/aging_F7B0_reconstruction_target_classes.csv` | Target classes and promotion evidence |
| `tables/aging/aging_F7B0_reconstruction_execution_order.csv` | Proposed execution order (includes review-stage visualization checkpoint) |
| `tables/aging/aging_F7B0_stop_conditions.csv` | Stop conditions (includes visualization shortcuts) |
| `tables/aging/aging_F7B0_status.csv` | F7B0 verdict rows |

## Four modes (summary)

1. **`legacy_old_analysis`** — evidence only; not canonical.  
2. **`lineage_replay`** — rerun with sidecars; not automatically canonical.  
3. **`canonical_reconstruction`** — rebuild on resolved observables; candidate only after gates.  
4. **`canonical_claim`** — only after promotion and validator/readiness criteria.

## Global playbook cross-reference

`docs/analysis_module_reconstruction_and_canonicalization.md` — non-linear; verify repo state before repeating steps.

## F6Z tables

If `tables/aging/aging_F6Z_*.csv` are absent locally, inventory completeness remains **not verified** until materialized and cross-checked.
