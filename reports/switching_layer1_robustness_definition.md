# Canonical Layer 1 robustness definition (Switching)

**Scope:** Switching only. **Purpose:** Align future audits with **physics-based** robustness and avoid conflating it with **implementation-level** sweep requirements.

**Related evidence (no new experiments):** Prior repository conclusions in `reports/switching_layer1_robustness_reconciliation.md`, `tables_old/map_pair_metrics.csv`, `reports/parameter_robustness_*.md`, `reports/switching_measurement_robustness_report.md`, `reports/phi_kappa_canonical_verdict.md`, and `reports/ver12_canonical_audit.md`.

---

## Definition

**Layer 1 robustness (canonical):** **Physical invariance** of the switching surface **S(I,T)** (equivalently **`Smap`** after gridding) under **admissible changes** to **how observables are defined, extracted, or summarized** from a **fixed underlying measurement family**, together with **stability of derived canonical objects** (maps, **Φ₁**, reconstruction) **as already documented** in existing Switching analysis artifacts.

Robustness is **not** defined as mandatory re-ingestion of raw **`.dat`** through **Switching ver12** under a full matrix of **implementation-only** parameter toggles **unless** a separate science or engineering requirement explicitly demands it.

---

## Distinction: observable-level vs implementation-level

| Kind | Meaning (Switching) |
|------|---------------------|
| **Observable-level (physical)** | Stability of **S(I,T)** and downstream summaries when **measurement definitions** change (e.g. peak rules, width rules, normalization, variant labels such as **raw_xy_delta** vs **baseline_aware**) while staying on a **comparable** sample grid. Evidence includes **correlation / NRMSE / map_corr** between variants and **intra-definition** tests in existing reports and **`tables_old/`** tables. |
| **Implementation-level (engineering)** | Pairwise comparison of **`Smap`** produced by **two independent** runs of **ver12** **`processFilesSwitching`** (or channel/metric choices) with **swept internal filter constants** — a **stress test of the legacy engine**, distinct from the **physics question** “does the **interpreted** map survive definition changes?” |

Prior audits that required **paired `Smap` RMSE/corr from two formation runs** were **implementation-level** expectations **not** stated as a **canonical physics** requirement in repository policy documents.

---

## Tested dimensions (already represented in-repo)

The following **dimensions** have **explicit Switching** documentation or **tables** (see reconciliation report for paths and linkage caveats):

1. **Measurement definition** — e.g. intra-measurement and measurement robustness reports; variant observables.
2. **Parameter robustness** — canonical-class extraction variants (**I_peak**, **width**, **S_peak**, **kappa1** methods) on locked samples; stage-1/stage-1b reports and **`tables_old/parameter_robustness_*.csv`**.
3. **Map-level stability** — **`map_corr`**, **normalized_rmse** between **named variant pairs** in **`tables_old/map_pair_metrics.csv`** (map-level metrics, not necessarily two ver12 ingests).
4. **Φ₁ stability** — stability statements in **`reports/phi_kappa_canonical_verdict.md`** and pipeline stability reports **in canonical space** (downstream of **`Smap`** formation in the canonical script).
5. **Reconstruction stability** — reconstruction / pipeline stability reports (with **known** cross-report tensions **already noted** in `reports/switching_pipeline_stability.md`).

**Caveat:** Some cited **run directories** are **absent** from the current **`results/switching/runs`** tree; **report- and table-backed** conclusions remain **formal evidence** where files exist.

---

## Explicit criterion (normative for future audits)

**`IMPLEMENTATION_SWEEP_REQUIRED` = NO**

A Switching Layer 1 robustness audit **passes** on **physics-based** grounds when:

- **S(I,T)** invariance (or controlled, documented deviation) is assessed under **measurement-definition** and **parameter-extraction** variation **as recorded** in existing artifacts, **and**
- **Map-level** and **Φ₁** / **reconstruction** stability are interpreted **in that context**,

without requiring a **repository-default** **implementation sweep** of **ver12** internal knobs **unless** a **separate** task explicitly mandates it.

---

*Documentation only; no code or pipeline changes.*
