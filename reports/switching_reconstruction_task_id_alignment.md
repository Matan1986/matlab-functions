# Switching reconstruction task ID alignment

This note **resolves vocabulary collision** without renaming historical CSV rows.

**Machine-readable:** `tables/switching_reconstruction_task_id_alignment.csv`

---

## Problem

The string **`TASK_002`** was used for **two different** workstreams:

1. **Quality metrics closure + diagnostic QA figures (+ refined visual QA)** — scripts `run_switching_corrected_old_task002_*.m`, status `tables/switching_corrected_old_quality_metrics_closure_status.csv`.
2. **Authoritative old-vs-corrected backbone parity bridge** — program row in **`tables/switching_missing_reconstruction_tasks.csv`** (historically **`task_id=TASK_002`**).

---

## Aligned identifiers (use these in new prose)

| Aligned ID | Meaning |
|------------|---------|
| **`TASK_002A_quality_metrics_closure`** | Closure checks + QA PNG folders under **`figures/switching/diagnostics/corrected_old_task002_quality_QA/`**. |
| **`TASK_002A_visual_QA_refinement`** | Refined QA PNG folder **`corrected_old_task002_quality_QA_refined/`** when run. |
| **`TASK_002B_backbone_parity_bridge`** | Backbone parity comparison task — corresponds to **historical program `TASK_002`** row. |

---

## Historical preservation

- **`tables/switching_missing_reconstruction_tasks.csv`** remains **unchanged** as an archival program table.
- **`tables/switching_missing_reconstruction_tasks_aligned.csv`** duplicates program intent with **TASK_002B** spelling for dependencies.

---

## Dependency interpretation

When a row lists **`dependencies=TASK_002`**, interpret as **`TASK_002B_backbone_parity_bridge`** **unless** the row explicitly refers to QA closure artifacts.

---

## Related

- **`reports/switching_corrected_canonical_current_state.md`**
- **`tables/switching_corrected_old_authoritative_artifact_index.csv`** (TASK_002A outputs enumerated)
