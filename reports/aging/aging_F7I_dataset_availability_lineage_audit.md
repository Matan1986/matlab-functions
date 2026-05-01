# F7I — Aging dataset availability and lineage audit

Generated as a **read-only governance audit**. No MATLAB runs, dataset rebuilds, writer executions, staging, commits, or pushes occurred for this memo.

Canonical execution reminders for downstream work remain in [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

---

## HEAD and git hygiene summary

| Item | Observation |
|------|-------------|
| `git diff --cached --name-only` | **Empty** at audit time (safe to proceed with read-only edits to generated audit artifacts locally). |
| `git status` | Dirty tree dominated by unrelated untracked backlog; **no Aging audit artifacts were staged.** |
| `HEAD` snapshot | **`df90052`** observed in workspace log; roadmap anchors **`84431dc`** (F7H blocked roadmap) and **`ced4798`** (F7G metadata columns) remain cited as lineage commits in governance docs. |

---

## Answers to posed audit questions

1. **Who creates `aging_observable_dataset.csv`?**  
   The **Stage E consolidation script** [`Aging/analysis/run_aging_observable_dataset_consolidation.m`](../../Aging/analysis/run_aging_observable_dataset_consolidation.m) is the authoritative **thin writer**: it consumes structured `tables/observable_matrix.csv` or `observables.csv` beneath a structured-export run referenced by [`tables/aging/consolidation_structured_run_dir.txt`](../../tables/aging/consolidation_structured_run_dir.txt), then emits the five-column consolidated CSV plus a sidecar. The orchestrating entry [`Aging/analysis/run_aging_Tp_tw_structured_export_and_consolidation.m`](../../Aging/analysis/run_aging_Tp_tw_structured_export_and_consolidation.m) terminates on the **same landing filename** under `tables/aging/`. A **historical `aging_dataset_build` run** (registry id `run_2026_03_12_211204_aging_dataset_build`) is documented as producing a **`results/` snapshot copy** mirrored today under **`results_old/`** for archival replays—not a substitute for rerunning consolidation unless policy accepts that snapshot.

2. **Known candidate path patterns** — see **`tables/aging/aging_F7I_dataset_candidate_paths.csv`**.

3. **Which paths exist here?**
   | Path | Exists this checkout |
   |------|----------------------|
   | `results/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv` (**F7H writer default**) | **NO** (`Test-Path` false) |
   | `tables/aging/aging_observable_dataset.csv` (consolidation landing) | **YES** (**22 Import-Csv rows** data) |
   | `results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv` | **YES** (**30 rows**) |
   | Runtime `AGING_OBSERVABLE_DATASET_PATH` | Exists only when operator exports it |

4. **Which path is “authoritative” for patched Dip/FM tau writers in code today?**
   **`aging_timescale_extraction`** and **`aging_fm_timescale_analysis`** **default `datasetPath`** to the **historical **`results/`** subtree** referencing **`run_2026_03_12_211204_aging_dataset_build`**, not to `tables/aging/`. The **canonical consolidation contract emitter** nonetheless lands under **`tables/aging/aging_observable_dataset.csv`**. Operational authority therefore **splits**:

   | Layer | Interpretation |
   |-------|----------------|
   | **Contract producer output** | `tables/aging/aging_observable_dataset.csv` (+ sidecar + status markdown/CSV emitted beside it) |
   | **Code-default reader for Dip tau** (`aging_timescale_extraction`) | Missing `results/.../211204/...` unless restored or bridged via **`AGING_OBSERVABLE_DATASET_PATH`** |
   | **Code-default reader inputs for FM tau** (`aging_fm_timescale_analysis` `applyDefaults`) | Same **hard-coded `results/` fragment** |

5. **Is the tau writer default stale, artifacts untracked, or broken logic?**
   Combination classification (not mutually exclusive):

   | Mechanism | Verdict |
   |-----------|---------|
   | **Specific historic run folder absent under `results/aging/runs/`** despite many other contemporaneous aging runs existing | **`MISSING_SPECIFIC_RUN_SNAPSHOT`** — not merely “repo has zero results”; the **exact default id folder is absent**. |
   | **`.gitignore` masks `tables/**`** (exceptions only for README and `tables/maintenance_*.csv`) | Local **consolidated datasets are normally absent from clones** unless reproduced or selectively force-tracked |
   | **Writer code still points at archived id** without auto-discover | **`STALE_HARD_CODED_DEFAULT` relative to current consolidation-first workflow** |

   Net: **`NOT_MALFORMED_F7G_LOGIC`** aligns with roadmap; root cause remains **availability + pointer drift**.

6. **Lineage fields before resuming tau/R **real-output** verification (beyond simply “file exists”)**
   Minimal science-safe parcel:

   | Field bundle | Requirement |
   |--------------|-------------|
   | **`run_manifest.json` + structured `observable_matrix.csv` (or observables)** | Identifiable **producer run** feeding consolidation pointer |
   | **`source_run` column** populated per Stage D `sprintf('%s|%s|%s', run_id,sample,dataset)` | Row-level trace into consolidation |
   | **Sidecar** (`aging_observable_dataset_sidecar.csv`) | Join keys (`manifest_run_id`, `input_table`, `orig_row_index`) for manifest ↔ matrix lineage |
   | **`Dip_depth` numeric fidelity** | Must match consolidation contract semantics (Freeze doc) |
   | **`Dip_depth_source`** | **Optional** enricher for branch-level lineage; **not emitted** in consolidation sidecar schema audited here—**writers still flag `pending_lineage`** until Dip branch policy resolved |

   Patched writer metadata intentionally marks **`canonical_status`** / **`lineage_status`** non-final until datasets are reconciled (`aging_timescale_extraction.m`, `appendF7GTauRMetadataColumns`).

7. **Roadmap clause on `tables/aging/aging_observable_dataset.csv` accuracy**
   Supported by **physical files present** **in this workspace** (`Import-Csv` succeeded; sidecar/status siblings exist locally). Presence is **still clone-dependent** owing to **`tables/**` ignore policy**, so roadmap language remains partially accurate: **documentation + local policy**, not purely documentation-only.

---

## Gate to reopen F7H

All must be affirmative before restarting **F7H real-output CSV inspections**:

| # | Gate |
|---|------|
| G1 | A **specific absolute or repo-relative** path to **`aging_observable_dataset.csv`** is selected and documented (not silent defaults). |
| G2 | The chosen file **matches the five-column contract** (`tables/aging/aging_observable_dataset_contract.csv`). |
| G3 | `consolidation_structured_run_dir.txt` (or archival manifest for `results_old` snapshot) proves **upstream structured export lineage** aligns with verification intent (Tp/tw coverage, sample ids). |
| G4 | If using **`results_old/...`** mirror or partial coverage tables artifact, analysts record **explicit science scope limits** versus full multi-Tp atlas. |
| G5 | If bypassing consolidation outputs, **`AGING_OBSERVABLE_DATASET_PATH`** exported **before MATLAB** wherever defaults still target missing `results/...211204...`. |

---

## Recommended controlled next action (no code edits in-scope)

Prefer **bridge then verify**:

1. **Option A — Fastest unblock:** Export **`AGING_OBSERVABLE_DATASET_PATH`** pointing at **`tables/aging/aging_observable_dataset.csv`** (after manual contract header/row skim) OR at **`results_old/...`** if verifying archived parity—not both without narrative.
2. **Option B — Re-materialize authoritative consolidation:** Populate pointer file + rerun **`run_aging_observable_dataset_consolidation`** under wrapper (explicitly **outside** this static audit execution scope) to refresh deterministic outputs.
3. **Option C — Restore missing `results/...211204/` tree** only if archival tarball exists; redundant if `tables/aging`/`results_old` already satisfy reproducibility proofs.

Defer **changing hard-coded MATLAB defaults** to a deliberate follow-on change bundle after verifying which pointer should become canonical repo policy.

---

## Machine-readable artifacts

| File | Purpose |
|------|---------|
| `tables/aging/aging_F7I_dataset_reference_inventory.csv` | Exhaustive MATLAB + ancillary asset references enumerated |
| `tables/aging/aging_F7I_dataset_candidate_paths.csv` | Path existence classification matrix |
| `tables/aging/aging_F7I_dataset_lineage_audit.csv` | Column-level lineage sufficiency ledger |
| `tables/aging/aging_F7I_dataset_availability_status.csv` | Verdict booleans aligned to sprint checklist |

Both `tables/**` (except enumerated maintenance carve-outs) and `reports/**` (except whitelist) remain **ignored for fresh files** unless force-added under separate governance—the content here still satisfies “write audit tables/report” mandate as **workspace artifacts**.

---

## Verdict block — required keys

```
F7I_DATASET_AUDIT_COMPLETE = YES
F7I_MISSING_F7H_DATASET_PATH_CLASSIFIED = YES (missing_specific_results_run_snapshot + stale_hard_default + artifact_ignore_policy_not_code_bug)
F7I_AUTHORITATIVE_DATASET_CREATOR_IDENTIFIED = YES (run_aging_observable_dataset_consolidation.m primary; structured export upstream)
F7I_AUTHORITATIVE_DATASET_PATH_IDENTIFIED = YES (dual: consolidation_output tables/aging vs code_default_results_legacy_id_missing_here)
F7I_EXISTING_CANDIDATE_DATASETS_INVENTORIED = YES
F7I_DIP_DEPTH_LINEAGE_ASSESSED = PARTIAL (numeric OK branch metadata_optional_missing)
F7I_SOURCE_RUN_LINEAGE_ASSESSED = ADECUATE_UNDER_CONTRACT_PLUS_SIDECAR
F7I_SAFE_RETURN_TO_F7H = CONDITIONAL_YES_AFTER_BRIDGE_AND_LINEAGE_GATE
F7I_NEXT_ACTION_RECOMMENDED = CONTROLLED_BRIDGE_ENV_OR_RESTORE_THEN_RESUME_F7H
NO_CODE_EDITED = YES
NO_MATLAB_RUN = YES
NO_DATASET_REBUILD = YES (this audit session)
NO_TAU_R_WRITER_RUN = YES
NO_TAU_R_PHYSICS_ANALYSIS = YES
NO_OLD_ANALYSIS_REPLAY = YES
NO_MODEL_ANALYSIS = YES
NO_SWITCHING_TOUCHED = YES (only read cross-link files)
NO_RELAXATION_TOUCHED = YES
NO_MT_TOUCHED = YES
NO_FILES_STAGED = YES (per empty index diff)
NO_COMMITS_CREATED = YES
NO_PUSH_PERFORMED = YES
```

---

## Explicit confirmation

This audit performed **static inspection and optional existence checks only**. It **did not** edit production MATLAB defaults, execute MATLAB, rebuild datasets, run tau/R writers, replay old analyses, perform model analysis, modify Switching/Relaxation/MT trees, stage files, commit, or push.
