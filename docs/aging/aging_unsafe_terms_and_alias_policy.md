# Aging unsafe terms and alias policy (F6W)

**Version:** F6W-1.0  
**Scope:** Aging documentation and agent guidance.  
**Principle:** The goal is to prevent unsafe scientific claims, not to prevent diagnostic work.

This policy complements `tables/aging/aging_unsafe_term_inventory.csv` (F6V) and **does not rename code**.

---

## 1. Terms that must not stand alone (unsafe without qualification)

| Term | Why unsafe | Allowed use | Forbidden use |
|------|------------|-------------|----------------|
| Plain **`Dip_depth`** | Names multiple incompatible scalarizations | Diagnostic tables with warnings; reads paired with **`Dip_depth_source`** or sidecar | Canonical/tau/R claims without resolved identity |
| Plain **`old`** | No protocol or artifact binding | Cite specific **run id**, commit, or artifact path | Implying equivalence to “pre-contract” without evidence |
| Plain **`canonical`** | Overloaded (governance vs colloquial vs comment-only) | When tied to **registry_id**, governance record, or explicit contract sentence | Shorthand for “current pipeline output” |
| Plain **`R`** | Conflicts with Relaxation **`R_relax`**, hides ratio legs | Explicit **`R_age`** or full **`R_tau_FM_over_Dip_...`** style label with identities | New prose or tables using bare `R` for aging ratio |
| Plain **`tau_Dip`** / **`tau_FM`** | Hides which dip/FM definition was used | Diagnostic runs with manifest | Cross-run compare without matching extraction inputs |
| **`stage4_S4A`** / **`stage4_S4B`** as primary names | Stage labels, not measurement recipes | **Historical alias** in namespaces after **`Dip_depth_source`** verification | Human-facing primary naming without semantic names |

---

## 2. Historical aliases: `stage4_S4A` and `stage4_S4B`

- **Not primary terminology** in new docs, tables, or claims.
- **May remain** as machine namespaces in F6S when mapped:
  - **`stage4_S4A`** ↔ semantic **`Dip_depth_afm_amp_residual_height`** when `Dip_depth_source = 'afm_amp_residual'`.
  - **`stage4_S4B`** ↔ semantic **`Dip_depth_raw_deltam_window_max_noncanonical`** when `Dip_depth_source = 'raw_deltam_window_metric_noncanonical'`.
- Mixing S4A and S4B under one **`Dip_depth`** column without a bridge remains **forbidden** for comparable science claims (F6Q / contract).

---

## 3. Field-name hazard: `tau_dip_canonical`

Stage4 may populate **`tau_dip_canonical`** while also setting **`tau_dip_is_canonical = false`** for the dip-window metric clock path.

**Policy:** Treat **`tau_dip_is_canonical`** (and sidecar/registry lineage) as **authoritative**. Do not infer “canonical dip tau” from the substring “canonical” in the field name alone. Prefer documenting **which observable stream** fed the clock (`tau_dip_source`, structs, reports).

---

## 4. Legacy and diagnostic artifacts

- **Legacy** outputs without sidecars remain **readable as evidence** (`legacy_quarantine` routing per assistive enforcement).
- **Diagnostic** pipelines may emit ambiguous labels; downstream must label **diagnostic** and avoid canonical promotion language.

---

## 5. Strict enforcement

Registry validators and strict writers may enforce these rules later. Until helpers/templates are ubiquitous, **audit_only** warnings and documentation clarity are the default—**diagnostic work is not blocked**.

---

## Related documents

- `docs/aging/aging_semantic_naming_taxonomy.md`
- `docs/aging/aging_tau_R_lineage_naming_policy.md`
- `docs/aging/aging_contract_validation_rules.md`
