# Switching quarantine visibility index

> **Switching namespace / evidence warning**
>
> - **NAMESPACE_ID:** QUARANTINED_MISLEADING / EXPERIMENTAL_PTCDF_DIAGNOSTIC (per-row in `tables/switching_quarantine_index.csv`)
> - **EVIDENCE_STATUS:** REGISTRY_AND_POLICY — this document makes quarantine **visible** because PNG filenames alone do not
> - **BACKBONE_FORMULA:** quarantined flows often used **S_model_pt_percent** — **not** CORRECTED_CANONICAL_OLD_ANALYSIS backbone
> - **SVD_INPUT:** varies — see per-artifact rows
> - **COORDINATE_GRID:** varies
> - **SAFE_USE:** hazard-aware reading; governance maintenance; never cite quarantined figures as authoritative corrected-old evidence
> - **UNSAFE_USE:** manuscript figures from `figures/switching/canonical/switching_corrected_old_*.png` flagged QUARANTINED_MISLEADING without regeneration from authoritative tables
> - **NOT_MAIN_MANUSCRIPT_EVIDENCE_IF_APPLICABLE:** YES for listed quarantine rows
> - **Current state entrypoint:** `reports/switching_corrected_canonical_current_state.md`

**Machine-readable:** `tables/switching_quarantine_index.csv`  
**Source registry (detail):** `tables/switching_misleading_or_dangerous_artifacts.csv`

This index exists because **quarantine status** often lives **only in tables**, while **filenames** (`switching_corrected_old_*.png`) still **look authoritative**.

---

## Policy

1. **Do not delete** quarantined artifacts (repository rule).
2. **Do not** cite quarantined figures as **`CORRECTED_CANONICAL_OLD_ANALYSIS`** evidence.
3. **First read** for operators: **`reports/switching_corrected_canonical_current_state.md`**.

---

## High-confusion figure family

**`figures/switching/canonical/switching_corrected_old_*.png`** — Many rows in the CSV are **`QUARANTINED_MISLEADING`** because flows used **`S_model_pt_percent`** or ad hoc decomposition — **not** `tables/switching_corrected_old_authoritative_*.csv`.

**`warning_visible_in_artifact`:** generally **NO** — filenames are **not** safe warnings. Mitigation is **this index** + **artifact index** + optional captions in future publication pipelines.

---

## Scripts with name/behavior mismatch

| Script | Risk |
|--------|------|
| `scripts/run_sw_old_inv_phi1_viz.m` | Name vs diagnostic/quarantine role |
| `scripts/run_switching_corrected_old_replay_inventory_and_phi1_visual_sanity.m` | Mixed corrected-old naming with PT/CDF backbone |
| `scripts/run_sw_corr_old_replay_auth.m` | Authority implication — verify against **`tables/switching_corrected_old_authoritative_builder_status.csv`** |

---

## Safe vs unsafe (summary)

**Safe:** Governance consumption; hazard-aware reading; rebuilding publication figures **only** after **`SAFE_TO_CREATE_PUBLICATION_FIGURES`** gate.

**Unsafe:** Manuscript evidence from quarantined PNGs; treating **`run_switching_canonical`** PT/CDF columns as corrected-old authority.

---

## Related

- **`reports/switching_stale_governance_supersession.md`** — existence of authoritative tables does **not** un-quarantine diagnostic flows.
- **`tables/switching_corrected_old_authoritative_artifact_index.csv`** — **positive** list of authoritative paths.

### Micro-pass additions (quarantine PARTIAL closure)

- **`reports/switching_corrected_old_replay_inventory_and_phi1_visual_sanity.md`** — often **absent** until a generator run; when present, treat per **`tables/switching_misleading_or_dangerous_artifacts.csv`** row — **prepend** the standard namespace warning block.
- **`scripts/run_switching_phase5B_residual_absorption_test.ps1`** — diagnostic overlap / PCA-on-**`CDF_pt`** studies; **not** standalone manuscript backbone proof (see **`docs/switching_analysis_map.md`** Phase 5B discussion).
- **Uncatalogued `run_switching_canonical_*` / backbone audit scripts** — use **`reports/switching_broad_artifact_ambiguity_sweep.md`** + per-script **`SWITCHING NAMESPACE`** headers; category-level quarantine does not replace script-level captions.
