# AGING-TAU-METADATA-GATE-01 — Baseline Dip/FM tau metadata gate audit

**Agent:** Narrow Aging tau metadata audit (read-only).  
**Rules:** [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Execution:** No MATLAB, Python, replay, tau computation, ratio computation, or code edits. No physics claims.

**Preflight:** `git diff --cached --name-only` was **empty** at audit time.

---

## Executive summary

Baseline Dip and FM tau **producers** are **`Aging/analysis/aging_timescale_extraction.m`** (`tau_vs_Tp.csv`, Dip_depth vs `tw`) and **`Aging/analysis/aging_fm_timescale_analysis.m`** (`tau_FM_vs_Tp.csv`, FM_abs vs `tw`). Both write a shared column name **`tau_effective_seconds`** with **different builder semantics** (dip: consensus `10^median(log10)` of trusted methods; FM: **`half_range` primary** when half-range status is ok, else same log-median consensus). **`tau_effective_seconds` is domain-ambiguous without metadata** — see `tables/aging/aging_F7X4_tau_effective_seconds_resolution.csv` and companion policy CSV from this gate.

**Ratio** object **`R_tau_FM_over_tau_dip`** (clock-ratio table; lineage text references FM/dip tau ratio; user-facing name **`R_age`** appears in governance as the aging scalar ratio concept) is produced by **`Aging/analysis/aging_clock_ratio_analysis.m`**, which loads **`tau_effective_seconds`** from each tau CSV into **`tau_dip_seconds`** / **`tau_FM_seconds`** and merges on **`Tp`**.

**Mandatory metadata before treating tau outputs as authoritative:** F7X5 tau bundle — at minimum **`tau_domain`**, **`tau_method`** (or explicit half-range primary / method list), **`tau_input_object`**, **`producer_script`**, **`source_artifact`**, **`grain`**, **`units`**, **`tau_consensus_methods`** (or equivalent), **`lineage_status`** (`reports/aging/aging_F7X5_definition_contract_draft.md` §16).

**Mandatory before ratio / `R_age`-style use:** paired dip + FM tau artifacts with **aligned provenance** (same consolidation dataset identity where required), **`Tp`** as pairing key, **`ratio_inputs`** and **`pairing_keys`** documented; bridge lineage **B-004** and **B-003** still gate “closed” ratio re-entry per **`tables/aging/aging_multipath_status_01_blockers.csv`**.

**Readiness:** Baseline tau extraction is **PARTIAL** (implementations + tables exist; metadata disclosure bundle still governance spine). Baseline ratio is **PARTIAL** (narrow bookkeeping lane; not “closed” for authoritative multipath claims). Multipath tau/ratio **NO** per existing status tables.

---

## Primary questions (answers)

1. **Which tau scripts/tables exist for Dip and FM?**  
   - **Dip:** `aging_timescale_extraction.m` → **`tau_vs_Tp.csv`**.  
   - **FM:** `aging_fm_timescale_analysis.m` → **`tau_FM_vs_Tp.csv`**.  
   Repo **`tables/aging/`** does not ship static copies of these outputs; they are **run-scoped** under `results/aging/runs/.../tables/` when produced.

2. **What input object does each tau table use?**  
   - Both load the **Track B five-column consolidation** schema: **`Tp`**, **`tw`**, **`Dip_depth`**, **`FM_abs`**, **`source_run`** (`aging_observable_dataset` / `AGING_OBSERVABLE_DATASET_PATH`).  
   - Dip fits **`Dip_depth` vs `tw`** per **`Tp`**.  
   - FM fits **`FM_abs` vs `tw`** per **`Tp`**.  
   - FM script additionally requires **`tau_vs_Tp.csv`** (dip tau) and a **failed dip-clock metrics** file per its `cfg` defaults.

3. **What tau method is encoded?**  
   Per-curve methods include **logistic half-time**, **stretched exponential half-time**, and **half-range crossing** on the selected observable vs `tw`; **`tau_effective_seconds`** aggregates via **`buildConsensusTau`** (dip) or **`buildEffectiveFmTau`** (FM — half-range primary when valid). Method names are reflected in **`tau_consensus_methods`** and per-method columns in the output tables.

4. **Is `tau_effective_seconds` domain-specific or ambiguous?**  
   **Ambiguous by column name alone.** Same column name is written by **two builders** (dip vs FM); meaning requires **`tau_domain`** / **`writer_family_id`** / **`source_artifact_path`** (F7X4 + F7X5).

5. **Mandatory metadata before tau extraction is allowed (interpretation/display)?**  
   **Tau bundle** fields in §16 F7X5 and schema CSV — see **`tables/aging/aging_tau_metadata_gate_01_required_metadata.csv`**.

6. **Mandatory metadata before ratio / `R_age` is allowed?**  
   **Tau bundle for both inputs**, **`ratio_inputs`**, **`pairing_keys`** (`Tp`, plus run/dataset identity), **`lineage_status`** for clock-ratio writer; bridge blockers where applicable.

7. **Baseline tau extraction readiness?**  
   **Ready with metadata / PARTIAL — not fully “closed.”** Scripts exist; **B-003** (dual-builder disclosure) and lineage rows still imply **PARTIAL** until writers/consumers consistently emit and check the bundle.

---

**`R_age` (aging scalar ratio narrative)** aligns with **`R_tau_FM_over_tau_dip`** from **`aging_clock_ratio_analysis.m`** (`tau_FM_seconds / tau_dip_seconds` after loading paired tau CSVs); not inventoried as a third tau row in `*_tau_sources.csv` — see **`*_ratio_gate.csv`**.

---

## Machine-readable outputs (this task)

| File | Role |
|------|------|
| `tables/aging/aging_tau_metadata_gate_01_tau_sources.csv` | Inventoried tau sources |
| `tables/aging/aging_tau_metadata_gate_01_required_metadata.csv` | Mandatory fields by use |
| `tables/aging/aging_tau_metadata_gate_01_tau_effective_seconds_policy.csv` | Legacy alias policy |
| `tables/aging/aging_tau_metadata_gate_01_ratio_gate.csv` | Ratio pairing and gates |
| `tables/aging/aging_tau_metadata_gate_01_status.csv` | Verdict keys |

---

## Cross-module

No Switching, Relaxation, Maintenance/INFRA, or MT scope in this audit.
