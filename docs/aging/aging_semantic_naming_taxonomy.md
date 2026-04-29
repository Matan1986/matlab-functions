# Aging semantic naming taxonomy (F6W)

**Version:** F6W-1.0  
**Status:** Stable terminology documentation for agents and contract writers.  
**Scope:** Aging module only.  
**Binding contracts:** `aging_namespace_contract.md`, `aging_observable_registry_contract.md`, `aging_writer_output_contract.md` remain normative for registry rows; this document clarifies **human-facing vocabulary** and separates **provenance** from **observable definition**.

**Principle:** The goal is to prevent unsafe scientific claims, not to prevent diagnostic work.

---

## 1. Locked semantic decisions (F6V / F6W)

1. **`Dip_depth` is not one resolved observable.** The same column name can denote incompatible scalarizations unless lineage resolves which branch produced it.

2. **AFM-amplitude branch (STRONG evidence)**  
   - **Semantic observable name:** `Dip_depth_afm_amp_residual_height`  
   - **Code anchor:** `Dip_depth = AFM_amp` when populated from the analyzer path (`Aging/pipeline/stage4_analyzeAFM_FM.m`).  
   - **Source marker:** `Dip_depth_source = 'afm_amp_residual'`  
   - **Confidence:** STRONG  

3. **Raw-window branch (STRONG evidence; noncanonical dip metric)**  
   - **Semantic observable name:** `Dip_depth_raw_deltam_window_max_noncanonical`  
   - **Code anchor:** maximum of the active `DeltaM` observable within the dip temperature window.  
   - **Source marker:** `Dip_depth_source = 'raw_deltam_window_metric_noncanonical'`  
   - **Canonical status:** noncanonical (explicit in stage4 comments: not the canonical physical residual dip).  
   - **Confidence:** STRONG  

4. **Export-time plain `Dip_depth`** in consolidated CSVs remains **`Dip_depth_unresolved`** unless a sidecar, `Dip_depth_source`, or split columns (`Dip_depth_S4A` / `Dip_depth_S4B`) resolve it.

5. **`stage4_S4A` and `stage4_S4B` must not be primary human-facing names.** They are **historical namespace aliases** in F6S, mapped to semantic names when evidence matches `Dip_depth_source`.

6. Aliases may remain in machine-readable namespaces; documentation and new prose should prefer **semantic names** above.

7. **`tau_dip_canonical` is semantically unsafe** as a label because stage4 also sets `tau_dip_is_canonical = false` for the dip-window clock path. **Trust lineage metadata and flags over misleading field names.**

8. **Canonical flag / sidecar / registry lineage is authoritative** over informal or legacy column titles.

9. **`R_tau_FM_over_Dip` (and similar ratios)** is interpretable only when **numerator and denominator observable identities** are both resolved (registry/sidecar), not from the symbol string alone.

10. **Provenance/status labels** (governance) must never be confused with **observable-definition labels** (measurement recipe).

---

## 2. Provenance / status labels (non-measurement)

These describe **where an artifact sits in governance**, not what physical quantity was measured.

| Label | Role |
|-------|------|
| `legacy_old` | Pre-contract runs; formulas may be implicit; bridges required for promotion |
| `current_export` | Present writer outputs; identity completed via sidecar when implemented |
| `canonical_candidate` | Passed parity/review; not yet ratified as policy canonical |
| `canonical` | Ratified registry row **only** with governance metadata |
| `diagnostic` | Audits, smoke tests; unstable definitions |
| `deprecated` | Superseded; migration/history only |
| `unknown` | Explicit unresolved namespace |
| `legacy_quarantine` | Session routing for artifacts without sidecars; remain readable as evidence |

Also referenced in contracts: `canonical_promotion_status`, `legacy_quarantine_status` (see lineage sidecar schema).

---

## 3. Observable-definition labels (measurement-scoped)

### Required dip-family entries

| Semantic name | Meaning |
|----------------|---------|
| `Dip_depth_afm_amp_residual_height` | Scalar tied to `Dip_depth_source = 'afm_amp_residual'` / AFM_amp fill-in path |
| `Dip_depth_raw_deltam_window_max_noncanonical` | Scalar tied to `Dip_depth_source = 'raw_deltam_window_metric_noncanonical'` (max active DeltaM in window) |
| `Dip_depth_unresolved` | Plain export column or missing lineage; **do not** treat as one physical definition |

Do not invent physics-flavored names for unknown exports; keep **`Dip_depth_unresolved`** until sidecar/registry resolves.

### Related decomposition concepts (not interchangeable with plain export `Dip_depth`)

Residual / decomposition paths (e.g. `dip_signed`, `DeltaM_signed`, `DeltaM_smooth`) are documented in pipeline and model code; they require explicit bridging to any exported scalar column.

---

## 4. Lineage-dependent derived labels (pattern)

Use explicit templates so tau and ratios cite **which definition** was used:

| Pattern | Use |
|---------|-----|
| `tau_Dip_<resolved_Dip_definition>` | Effective timescale from a **resolved** dip scalar family (replace placeholder with registry id or semantic id) |
| `tau_FM_<resolved_FM_definition>` | FM timescale with **FM_abs vs signed step** convention explicit in id |
| `R_tau_FM_over_Dip_<resolved_numerator>_over_<resolved_denominator>` | Aging scalar ratio; **not** Relaxation `R_relax(T,t)` |

Do not shorten to plain `tau_Dip`, `tau_FM`, or `R` in new documentation when claiming cross-run or canonical agreement.

---

## 5. Enforcement posture

- **Plain `Dip_depth`** is **forbidden** as canonical / tau/R **input identity** unless resolved via sidecar, `Dip_depth_source`, or namespaced columns (see F6S/F6T).
- **Strict blocking enforcement** in tooling is **deferred** until helpers/templates exist; **audit_only** and warnings remain the default (see `aging_agent_assistive_enforcement.md`).
- **Diagnostic work** continues with explicit warnings; legacy files remain **readable as evidence**.

---

## Cross-references

- `docs/aging/aging_unsafe_terms_and_alias_policy.md`
- `docs/aging/aging_tau_R_lineage_naming_policy.md`
- `docs/aging/aging_namespace_contract.md`
- `docs/aging/aging_observable_registry_contract.md`
