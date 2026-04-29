# Aging tau and R lineage naming policy (F6W)

**Version:** F6W-1.0  
**Scope:** Aging tau extraction, clock outputs, and scalar aging ratios.  
**Principle:** The goal is to prevent unsafe scientific claims, not to prevent diagnostic work.

This document does **not** change MATLAB analysis code or writers.

---

## 1. Separation of concerns

| Layer | What it answers |
|-------|------------------|
| **Observable definition** | Which dip scalar, FM scalar, and conventions (signed/abs, window, source) produced the inputs |
| **Tau extraction** | Which curve or clock construct yielded an effective timescale |
| **Ratio** | Whether numerator and denominator taus refer to the **same** definition families at matched conditions |

**Provenance labels** (`legacy_old`, `current_export`, `canonical_candidate`, …) describe artifact governance, not the measurement formula alone.

---

## 2. Naming patterns (lineage-dependent)

Use explicit placeholders until registry ids are assigned:

| Pattern | Meaning |
|---------|---------|
| `tau_Dip_<resolved_Dip_definition>` | Tau derived from a **resolved** dip scalar family (semantic id or registry id) |
| `tau_FM_<resolved_FM_definition>` | Tau derived from FM family with **convention explicit** (e.g. step magnitude vs abs envelope) |
| `R_tau_FM_over_Dip_<resolved_numerator>_over_<resolved_denominator>` | Scalar aging ratio at matched **T_p** (or declared pairing); **not** Relaxation **`R_relax`** |

**Rule:** Do not present **`R_tau_FM_over_Dip`** as interpretable unless **both** numerator and denominator **observable identities** are resolved (sidecar/registry), consistent with F6T ratio checks.

---

## 3. Known code anchors (documentation only)

- **`aging_timescale_extraction`** builds **`tau_vs_Tp`** from consolidated datasets whose **`Dip_depth`** column may be **`Dip_depth_unresolved`** until lineage is attached—tau labels must trace to the **dataset build**, not only the column name.
- **`stage4`** optional clock block: **`tau_dip_source = 'raw_deltam_window_metric_noncanonical'`**, **`tau_dip_is_canonical = false`** for that path—see **`tau_dip_canonical`** field-name caveat in `aging_unsafe_terms_and_alias_policy.md`.
- **`aging_clock_ratio_analysis`** / **`aging_clock_ratio_temperature_scaling`** merge tau tables by temperature; ratio validity requires **matched runs** and resolved identities.

---

## 4. Relaxation vs Aging **R**

Per repository execution rules: **scalar Aging ratio** must be distinguished from **Relaxation** **`R_relax(T,t)`**. Use **`R_age`** or fully qualified ratio names in new documentation.

---

## 5. Diagnostic vs canonical use

| Use case | Policy |
|----------|--------|
| Diagnostic plots / audits | Allowed with explicit warnings; ambiguous inputs must be labeled |
| Canonical or cross-run claims | Requires resolved **`Dip_depth`** branch, FM convention, and matched tau extraction metadata |
| Strict enforcement | Deferred until writers/helpers stabilize; **audit_only** remains valid |

---

## Related documents

- `docs/aging/aging_semantic_naming_taxonomy.md`
- `docs/aging/aging_unsafe_terms_and_alias_policy.md`
- `docs/aging/aging_lineage_sidecar_schema.md`
