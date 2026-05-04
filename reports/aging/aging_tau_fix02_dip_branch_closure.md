# AGING-TAU-FIX-02-DIP-BRANCH-CLOSURE

## 1. Scope and exclusions

- **Scope:** Governance closure for **baseline Dip component branch lineage only** (`AGN_WF_CONSOL_DS_DIP_DEPTH_CURVEFIT_V1`): consolidated source object, `Dip_depth` branch definition, component-vs-wait construction, curve-fit tau extraction, artifact/sidecar linkage, disclosures, and independence from collapse-optimizer tau.
- **Exclusions:** No MATLAB, Python, Node, or replay; no tau computation, refit, ratios, figures; no pipeline or tau value edits; no FM branch work; no broad sidecar hardening (record Dip gaps only); no row-identity/co-registration closure; no Switching, Relaxation, Maintenance-INFRA, or MT changes; no use of collapse-optimizer tau or forensic old-fit tau as canonical substitutes.

## 2. Executive summary

Committed artifacts (PRB01 pathway registry, PRB03 bundle inventory, PRB02B ledger, decomposition-lineage signal chain, fixplan blocker matrix) jointly identify the Dip pathway token, the shared five-column consolidation dataset as the source signal object, **direct** use of the `Dip_depth` column as the component observable on `tw`, production via `run_aging_observable_dataset_consolidation.m` then `Aging/analysis/aging_timescale_extraction.m`, curve-fit tau via `buildConsensusTau`, outputs `tau_vs_Tp.csv` with `tau_vs_Tp_sidecar.csv`, and explicit sign/magnitude disclosure for signed `Dip_depth`. The Dip lane is **distinct** from `AGN_WF_CONSOL_DS_DIP_DEPTH_COLLAPSE_OPTIMIZER_V0` (optimizer tau). FIX-02 records this chain in new tables and closes the **Dip branch definition / lineage documentation** gap; PRB03 pathway summaries still show `WARN_LINEAGE_PARTIAL` until FIX-04–FIX-06 refresh tokens and policy. Tau remains **non-canonical** for evidence use.

## 3. FIX-01C context

FIX-01C closed the **shared committed compact bundle** for upstream dataset identity (`source_dataset_id`, `source_run`, required columns). That satisfies shared upstream lineage for Dip and FM inputs but does not, by itself, freeze Dip component-branch semantics or sidecar lineage tokens.

## 4. Dip pathway identity

- **Registry pathway_id:** `AGN_WF_CONSOL_DS_DIP_DEPTH_CURVEFIT_V1`
- **PRB01 semantic name:** Consolidation Dip_depth tw-curve tau
- **Proposed long semantic label (lineage survey):** `CONSOLIDATED_MEMORY_DATASET__DIRECT_DIP_DEPTH_FROM_FIVE_COLUMN_CONSOLIDATION__DIP_DEPTH_VS_WAIT__CURVEFIT_CONSENSUS_TAU` (`tables/aging/aging_tau_decomposition_lineage_01_semantic_names.csv`)

## 5. Dip component definition

- **Source signal object:** Five-column consolidated Aging observable dataset (`tables/aging/aging_observable_dataset.csv` contract: `Tp`, `tw`, `Dip_depth`, `FM_abs`, `source_run`) built by Stage4 or structured-export lineage then `run_aging_observable_dataset_consolidation.m` (signal chain step 2).
- **Component observable:** `Dip_depth` read **directly** from the consolidation table (not reconstructed via a separate decomposition fit of `Dip_depth` identity).
- **Per-pathway definition (PRB01):** Dip_depth scalar on `TW_CURVE_PER_TP` grid (per-Tp summaries over `tw` curves for tau extraction).

## 6. Dip extraction / decomposition method

- **Class:** Direct column extraction from consolidated dataset + curve-fit tau extraction stage (not collapse optimization, not forensic replay).
- **Decomposition text (PRB01):** Stage4 to structured export to five-column consolidation reader; provenance in `source_run`.
- **Signal chain step 3:** Per-Tp `Dip_depth` vs `tw` curves produced in `Aging/analysis/aging_timescale_extraction.m` as direct component-vs-wait input (`tables/aging/aging_tau_decomposition_lineage_01_signal_chain.csv`).

## 7. Dip_depth vs wait-time source

- Rows carrying `Dip_depth` and `tw` (and `Tp`, `source_run`) live in the consolidation CSV; the tau runner consumes **per-Tp** `Dip_depth` vs `tw` curve families. Partial-grid caveats for certain `Tp` remain documented in PRB03 notes (grid policy closure is FIX-05 scope).

## 8. Dip tau artifact and sidecar linkage

- **Tau table (metadata path in PRB03/PRB02B):** `.../run_2026_05_04_134220_aging_timescale_extraction/tables/tau_vs_Tp.csv`
- **Sidecar:** `.../tau_vs_Tp_sidecar.csv` adjacent to the tau table (`PRB01` sidecar requirement).
- **Producer script:** `Aging/analysis/aging_timescale_extraction.m`
- **PRB03 inventory** binds `pathway_id`, `source_observable`, `tau_method`, `tau_input_object`/`tau_input_axis`, and output artifact filename for baseline Dip rows.

## 9. Sign, magnitude, baseline, and normalization disclosure

- PRB03 baseline Dip rows include **sign disclosure:** `Dip_depth` is a signed consolidation column; negative cells possible; sign context required for interpretation.
- Signal chain notes **no explicit baseline-subtraction declaration** in the sidecar contract (gap flagged for FIX-04 sidecar hardening, not re-derived here).
- Baseline Dip tau path is **not** the amplitude-normalized collapse objective lane (`aging_time_rescaling_collapse.m` is a different pathway).

## 10. Independence from collapse optimizer tau

- **Baseline Dip curve-fit:** `AGN_WF_CONSOL_DS_DIP_DEPTH_CURVEFIT_V1`
- **Collapse optimizer lane:** `AGN_WF_CONSOL_DS_DIP_DEPTH_COLLAPSE_OPTIMIZER_V0` — optimizer-derived shifts in log10 `tw`, distinct pathway_id, non-canonical per decomposition lineage and fixplan exclusions.
- No evidence in inspected artifacts that baseline Dip `tau_effective_seconds` is produced by the collapse optimizer script.

## 11. Dip branch blocker resolution

- **Branch/component-definition documentation:** Closed in FIX-02 by consolidating committed references (PRB01, decomposition signal chain, PRB03 row metadata).
- **PRB03 dominant blocker token on pathway summary** (`LINEAGE_NOT_COMPLETE_SIDEcar_REQUIRES_DATASET_PATH`) and **sidecar lineage_status** strings on disk remain **unchanged** in this task; token promotion and bundle WARN clearance are **FIX-04 / FIX-06** scope.

## 12. Remaining blockers after FIX-02

- **FIX-03:** FM branch (untouched here).
- **FIX-04:** Dip sidecar lineage token hardening and naming guards; refresh sidecar `lineage_status` class when chartered.
- **FIX-05:** Row identity / co-registration / partial-grid policy.
- **FIX-06:** Canonical readiness gate and PRB03 policy status (`WARN_LINEAGE_PARTIAL` to PASS).
- **Local run artifacts:** `tau_vs_Tp.csv` / sidecar files under `results/aging/runs/...` remain **not** bulk-committed; numeric reproducibility still depends on local runs or future canonical regeneration.

## 13. What remains forbidden

Tau as canonical evidence, ratios, comparison-runner execution, replay, tau refit/recompute, FM closure tasks, and treating collapse or forensic tau as baseline substitutes — unchanged.

## 14. Final verdicts

- **Dip branch definition lineage (documentation layer):** **CLOSED** from committed evidence per FIX-02 tables.
- **Dip tau canonical-ready:** **PARTIAL** — blocked by sidecar/identity/policy gates above.
- **Safe ratios/comparison/canon tau use:** **NO.**

See `tables/aging/aging_tau_fix02_dip_status.csv` for machine-readable fields.
