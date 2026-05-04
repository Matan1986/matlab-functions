# AGING-TAU-FIX-03-FM-BRANCH-CLOSURE

## 1. Scope and exclusions

- **Scope:** Governance closure for **baseline FM component branch lineage only** (`AGN_WF_CONSOL_DS_FM_ABS_CURVEFIT_V1`): consolidated source object, `FM_abs` branch definition and ABS_ONLY semantics, component-vs-wait construction, curve-fit tau extraction, artifact/sidecar linkage, disclosures, independence from collapse-optimizer tau and forensic old-fit tau.
- **Exclusions:** No MATLAB, Python, Node, or replay; no tau computation, refit, ratios, figures; no pipeline or tau value edits; no Dip branch edits (FIX-02 remains authoritative for Dip); no broad sidecar hardening (record FM gaps only); no row-identity/co-registration closure; no Switching, Relaxation, Maintenance-INFRA, or MT changes; no Dip-vs-FM tau comparison or ratio claims.

## 2. Executive summary

Committed artifacts identify the FM pathway token, the shared five-column consolidation as the source signal object, **direct** use of the `FM_abs` column as the observable on `tw`, **ABS_ONLY** magnitude semantics per registry and PRB03 disclosures (not signed FM dynamics in the tau lane), consolidation via `run_aging_observable_dataset_consolidation.m`, FM tau runner `Aging/analysis/aging_fm_timescale_analysis.m` with optional **dipTauPath** coupling (auxiliary Dip tau clock wiring per PRB01, distinct from collapse optimizer), curve-fit tau via `buildEffectiveFmTau`, outputs `tau_FM_vs_Tp.csv` with `tau_FM_vs_Tp_sidecar.csv`. Baseline FM tau is **not** produced by `aging_time_rescaling_collapse.m` and **not** the forensic `AGN_WF_FORENSIC_OLD_FIT_REPLAY_F6_V0` lane. FIX-03 records this chain and closes the **FM branch definition / lineage-documentation** gap; PRB03 still shows `WARN_LINEAGE_PARTIAL` and F7S/FM policy tokens until FIX-04–FIX-06. Tau remains **non-canonical** for evidence use.

## 3. FIX-01C and FIX-02 context

- **FIX-01C** closed the **shared** committed dataset-lineage package (`source_dataset_id`, `source_run`, required columns) for the consolidation inputs used by both baseline lanes.
- **FIX-02** closed the **Dip** branch documentation layer for `AGN_WF_CONSOL_DS_DIP_DEPTH_CURVEFIT_V1`; FM work references that upstream closure but does not reopen Dip tables.

## 4. FM pathway identity

- **Registry pathway_id:** `AGN_WF_CONSOL_DS_FM_ABS_CURVEFIT_V1`
- **PRB01 semantic name:** Consolidation FM_abs tw-curve tau
- **Proposed long semantic label:** `CONSOLIDATED_MEMORY_DATASET__DIRECT_FM_ABS_FROM_FIVE_COLUMN_CONSOLIDATION__FM_ABS_VS_WAIT__CURVEFIT_HALF_RANGE_PRIMARY_TAU` (`tables/aging/aging_tau_decomposition_lineage_01_semantic_names.csv`)

## 5. FM component definition

- **Source signal object:** Five-column consolidated Aging observable dataset (`Tp`, `tw`, `Dip_depth`, `FM_abs`, `source_run`) from Stage4 or structured-export lineage then `run_aging_observable_dataset_consolidation.m`.
- **Component observable:** `FM_abs` read **directly** from the consolidation table for per-Tp curves over `tw` (PRB01: FM_abs magnitude surface; ABS_ONLY policy for the tau lane).

## 6. FM extraction / decomposition method

- **Class:** Direct column extraction from consolidation + **CURVEFIT_ZOO** tau stage using `buildEffectiveFmTau` (half-range primary with consensus-pool fallback per decomposition lineage), **not** collapse optimization and **not** forensic replay.
- **Runner coupling:** PRB01 notes explicit **dipTauPath** to paired Dip tau in FM runner configuration (policy/auxiliary wiring; not interchange with baseline Dip pathway identity).

## 7. Meaning of `FM_abs`

- Registry and PRB03: **ABS_ONLY** — magnitude collapsed from consolidation for this tau lane; PRB03 disclosure states interpretation as **not signed FM dynamics** for this pathway row context.
- Signal chain step 2 notes **absolute value origin policy** remains sensitive (F7Q/F7S context); full signed-source lineage is a **policy closure** item (FIX-04/FM convention tasks), not re-derived here.

## 8. FM_abs vs wait-time source

- Consolidation rows supply `FM_abs` and `tw` (and `Tp`, `source_run`); `Aging/analysis/aging_fm_timescale_analysis.m` builds per-Tp **FM_abs** vs **tw** curve families for tau extraction. Partial-grid caveats match PRB03 `GRID_DISCLOSURE_REF` notes (policy closure FIX-05 scope).

## 9. FM tau artifact and sidecar linkage

- **Tau table (metadata path in PRB03/PRB02B):** `.../run_2026_05_04_135134_aging_fm_timescale_analysis/tables/tau_FM_vs_Tp.csv`
- **Sidecar:** `.../tau_FM_vs_Tp_sidecar.csv` adjacent to the tau table (PRB01 sidecar requirement).
- **Producer script:** `Aging/analysis/aging_fm_timescale_analysis.m`
- **PRB03** binds `pathway_id`, `source_observable`, `tau_method`, `tau_input_object` / `tau_input_axis`, `lineage_status`, and output artifact name for baseline FM rows.

## 10. Sign, magnitude, baseline, and normalization disclosure

- PRB03 FM rows: **ABS_ONLY** magnitude disclosure and grid disclosure reference.
- Signal chain: FM signed-origin disclosure **policy-sensitive**; consolidation emits magnitude column for downstream route.
- Baseline FM lane is **not** the amplitude-normalized collapse objective lane (`aging_time_rescaling_collapse.m` covers **Dip_depth** collapse tau, different pathway_id).

## 11. Independence from collapse optimizer and old-fit forensic tau

- **Collapse optimizer:** Pathway `AGN_WF_CONSOL_DS_DIP_DEPTH_COLLAPSE_OPTIMIZER_V0` uses `aging_time_rescaling_collapse.m` on **Dip_depth** — distinct from baseline FM curve-fit lane.
- **Forensic old-fit:** Pathway `AGN_WF_FORENSIC_OLD_FIT_REPLAY_F6_V0` is blocked/placeholder in PRB03 (`TB_INV_FORENSIC_F6_NO_ROW_LEDGER`) — not the FM baseline bundle row family.

## 12. FM branch blocker resolution

- **FM branch/component-definition documentation:** Closed in FIX-03 by consolidating committed references (PRB01, decomposition signal chain, semantic names, PRB03/PRB02B rows).
- **PRB03 pathway summary** dominant blocker (`LINEAGE_METADATA_HARDENED_PENDING_F7S`) and **sidecar lineage_status** on disk remain **unchanged** here; F7S/policy hardening is **FIX-04+** scope.

## 13. Remaining blockers after FIX-03

- **FIX-04:** FM sidecar lineage token hardening, F7S policy closure, naming guards.
- **FIX-05:** Row identity / co-registration / partial-grid policy.
- **FIX-06:** Canonical readiness gate and PRB03 policy status (`WARN_LINEAGE_PARTIAL` to PASS).
- **FM convention depth:** `FM_B02` (decomposition blockers) — finalize signed-source and ABS convention contracts beyond lineage documentation.
- **Local run artifacts:** `tau_FM_vs_Tp.csv` / sidecars under `results/aging/runs/...` remain **not** bulk-committed.

## 14. What remains forbidden

Canonical tau-as-evidence, ratios, comparison-runner execution, replay, tau refit/recompute, Dip branch mutation, collapse/forensic tau as baseline substitutes — unchanged.

## 15. Final verdicts

- **FM branch definition lineage (documentation layer):** **CLOSED** per FIX-03 tables.
- **FM tau canonical-ready:** **PARTIAL** — blocked by policy/sidecar/identity gates.
- **Safe ratios/comparison/canon tau use:** **NO.**

See `tables/aging/aging_tau_fix03_fm_status.csv` for machine-readable fields.
