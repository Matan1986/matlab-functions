# Switching historical / diagnostic artifact inventory (lightweight)

**Purpose:** Group **classes** of artifacts that are often **non-authoritative** or **mixed-namespace**, so agents do not rely on filename alone.

**Machine-readable:** `tables/switching_historical_diagnostic_artifact_inventory.csv`

**Does not replace:** `tables/switching_corrected_old_authoritative_artifact_index.csv`, `reports/switching_quarantine_index.md`, or `reports/switching_corrected_canonical_current_state.md`.

---

## Categories (summary)

| Category | Rule of thumb |
|----------|----------------|
| **Legacy alignment / full scaling** | **`OLD_*`** families — cite `docs/switching_analysis_map.md` row for each script. |
| **Mixed `switching_canonical_S_long.csv`** | **`S_percent`** ≠ **`S_model_pt_percent`** — see **`reports/switching_canonical_S_long_column_namespace.md`**. |
| **Geocanon descriptors** | **Diagnostic / interpretation-blocked** unless explicitly promoted (boundary **B08**). |
| **Phi/kappa test scripts** | Large family under **`Switching/analysis/run_phi*.m`** — not automatically **`CORRECTED_CANONICAL_OLD_ANALYSIS`**. |
| **Phase-gated design CSVs** | Inventory / design — not standalone manuscript proof. |
| **Quarantined `switching_corrected_old_*.png`** | **`QUARANTINED_MISLEADING`** — see quarantine index. |
| **Backbone / collapse audit scripts** | **`run_switching_backbone_*.m`**, **`run_switching_collapse_*.m`** — **diagnostic**; see final micro-pass report for header coverage. |
| **Maintenance reports** | Under **`reports/maintenance/`** — may predate the authoritative index; **start from** **`reports/switching_corrected_canonical_current_state.md`**. |

---

## Sufficiency (final micro-pass, 2026-04-29)

The category list above is **sufficient** for agent navigation: it groups the main **mixed-namespace** and **misleading-name** classes without duplicating the authoritative index line-by-line. Residual **uncatalogued** `Switching/analysis/*.m` files are covered by the **broad sweep** table, **script headers** where added, and the quarantine **category** row for uncatalogued scripts.

---

## Relation to broad ambiguity sweep

Created by **`reports/switching_broad_artifact_ambiguity_sweep.md`** to satisfy **`HISTORICAL_DIAGNOSTIC_INVENTORY_NEEDED`** without editing scientific CSV bodies. Updated in the **final governance micro-pass** to close **`HISTORICAL_DIAGNOSTIC_INVENTORY_NEEDED=PARTIAL`**.
