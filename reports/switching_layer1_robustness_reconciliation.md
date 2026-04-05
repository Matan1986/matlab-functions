# Switching Layer 1 robustness — reconciliation (read-only)

**Purpose:** Explain why `reports/switching_layer1_robustness_audit.md` returned **`LAYER1_ROBUSTNESS_AUDITED=NO`**, **`MAP_LEVEL_STABILITY_PROVEN=NO`**, **`EVIDENCE_IS_RUN_BACKED=NO`**, and whether that outcome is **missing science**, **path/linkage**, or **strict criterion**.

**Scope:** Switching only. No code changes. No MATLAB runs.

---

## A. Why the first audit returned NO

1. **Strict definition of Layer 1 audit:** Raw **`.dat` → `Smap` via Switching ver12** with **systematic variation of ver12 controls** and **paired `Smap` RMSE/corr** between formation runs.

2. **Run directory gap:** Reports cite **`run_2026_03_10_112659_alignment_audit`**, **`run_2026_03_28_214509_*`**, **`run_2026_03_29_014323_*`**, **`run_2026_03_29_014529_*`**, etc. **None** of these paths exist under **`C:\Dev\matlab-functions\results\switching\runs\`** (verified via glob). So **`EVIDENCE_IS_RUN_BACKED=NO`** was **correct** for *co-located run folders*.

3. **Path casing:** On Windows, **`results/Switching/runs`** and **`results/switching/runs`** resolve to the **same** directory. The negative verdict was **not** caused by looking at the wrong case — the **March 2026** run IDs are simply **absent** from the tree.

4. **Substance vs format:** **`tables_old/parameter_robustness_*.csv`**, **`tables_old/map_pair_metrics.csv`**, and multiple **`reports/*.md`** still document **historical** measurement and parameter robustness work, including **map_corr** between **named variant pairs** — but those pairs are **observable-definition / processing variants**, **not** two independent **ver12 raw ingestions** with different **`processFilesSwitching`** knobs.

5. **Tables location drift:** **`reports/map_rmse_closure_summary.md`** references **`tables/map_pair_metrics.csv`**; the metrics file is present as **`tables_old/map_pair_metrics.csv`** — **evidence exists** but **link broke** by path move.

---

## B. Classification of the negative verdict

| Hypothesis | Verdict |
|------------|---------|
| (1) Truly missing evidence | **PARTIAL** — empirical **run outputs** for cited IDs are **missing**; **written evidence** (reports + **`tables_old`**) **exists**. |
| (2) Different paths/names | **YES for tables** — **`tables_old/`** vs **`tables/`**; **NO for runs** — no alternate folder found for March runs. |
| (3) Evidence not linked to present run dirs | **YES** — chain **report → run_id → run_dir** **breaks** at **run_dir**. |
| (4) Robustness exists but not strict paired-Smap form | **YES** — parameter/measurement work **substantively** tests **stability of observables and map_corr between variants** on **fixed** or **locked** samples, **not** the **strict Layer 1** experiment design. |

---

## C. Artifact trail (summary)

See **`tables/switching_layer1_robustness_reconciliation.csv`** for **artifact → cited `run_id` → expected path → found/missing → dimensions**.

**Run-backed in workspace today:** e.g. **`results/switching/runs/run_2026_04_03_*_switching_canonical`** (canonical pipeline repeats; **not** historical robustness matrix).

---

## D. Does any existing work “cover Layer 1 in substance”?

- **`reports/ver12_canonical_audit.md`:** **Defines** Layer 1 behavior (filters, thresholds) — **does not** substitute for **multi-run empirical** robustness.
- **Parameter robustness suite:** Demonstrates **sensitivity of derived observables** to **extraction / width / I_peak** definitions on a **locked sample table** — **downstream** of a **single** formed **`S_percent`** field; **does not** re-sweep **ver12** preprocessing **inputs** from raw.
- **`tables_old/map_pair_metrics.csv`:** **Explicit map_corr / normalized_rmse** between **variant pairs** — **map-level** evidence, but **not** the **audit’s required** “two formation **`Smap`s from two ver12 configs.”

**Conclusion:** **Partial overlap** with **measurement/parameter/map stability** in a **broader sense**; **does not** equal **documented Layer 1 (ver12) systematic robustness** under the **first audit’s** definition.

---

## E. Final forced verdict (single)

**`EVIDENCE_EXISTS_BUT_NOT_CANONICALLY_LINKED`**

- **Evidence** for historical Switching robustness work **exists** in **reports** and **`tables_old/`**.
- **Run directories** referenced by those reports are **not** present to **re-verify** or **extend** the chain **in-repo**.
- The **first audit** was **correctly strict** on **paired ver12 `Smap`** and **run co-location**; it should be **upgraded** to **explicitly record** (i) **tables_old** quantitative artifacts, (ii) **broken report→run links**, (iii) **path drift** for **`map_pair_metrics`**, without conflating **missing folders** with **zero historical work**.

---

## F. Machine-readable outputs

- `tables/switching_layer1_robustness_reconciliation.csv`
- `tables/switching_layer1_robustness_reconciliation_status.csv`

---

*Inspect-only.*
