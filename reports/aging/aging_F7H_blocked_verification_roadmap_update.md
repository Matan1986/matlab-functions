# F7H-plan-update — Blocked real-output tau/R verification (roadmap note)

**Date:** 2026-04-30  
**Scope:** Aging planning documentation only.

## Facts

| Item | Status |
|------|--------|
| **F7G** | **Committed** at **`ced4798`** (*Add Aging tau R semantic metadata columns*). |
| **F7H** | Real-output validation **blocked** --- **zero** tau/R CSVs generated or inspected on disk in the audited checkout. |

## Blocker (not metadata regression)

Missing input at writer default:

`results/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv`

F7H did **not** prove the append-only helper wrong; absence of **`results/**`** datasets is a **dataset availability / lineage** issue.

## What future agents must not do

Repeat tau/R **real-output** verification or treat sidecar/metadata work as unblockers **before** consolidating where the canonical **`aging_observable_dataset.csv`** lives, how it is built, and that it is reproducible.

Do **not** perform tau/R **physics synthesis** from **legacy or unresolved** exports when consolidation identity is unclear.

Defer **replay/proxy/pipeline-clock** writer metadata parity until lineage for the consolidated dataset layer is audited.

## Next step

**`F7I --- Aging dataset availability + lineage audit`**

Produce a single audited answer: authoritative path(s), build script/run id, `source_run`, `Dip_depth` branch resolution posture, and gating checklist before any new F7*-style CSV verification burn.

## Source artifacts

- F7H log: `reports/aging/aging_F7H_real_output_metadata_verification.md`
- Roadmap linkage: `docs/aging_canonicalization_roadmap.md` (**F-series branch**)
