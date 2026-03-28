# 22 K peak-switch artifact (switching pipeline)

Central project note documenting the **upstream representation** issue behind the **22 K** residual-decomposition anomaly. This is **not** a claim of new physics at 22 K; it records verified audit conclusions.

---

## Problem summary

Residual decomposition (`switching_residual_decomposition_analysis`) showed a **degraded rank-1 reconstruction at 22 K**: per-curve correlation **δS vs κ·Φ ≈ 0.7469** (vs >0.89 at many neighbors) and a **shallow κ(22 K) ≈ 0.038** (vs ~0.07–0.09 nearby). Follow-up tracing showed the driver is **not** the PT matrix, **not** CDF fallback, and **not** a sparse x-grid in the decomposition step.

The root cause is a **discrete change in upstream collapse parameters** between **20 K and 22 K** produced by **`switching_full_scaling_collapse.m`**:

| Quantity | 20 K | 22 K |
|----------|------|------|
| `I_peak` | 35 mA | 30 mA |
| `peak_index` (valid-grid index) | 5 | 4 |
| `width_chosen_mA` (FWHM, typical) | ~15.07 | ~17.21 |
| `S_peak` (P2P %) | ~0.118 | ~0.085 |

Because the decomposition uses **`x = (I − I_peak) / w`**, a **step in `I_peak` and `w`** **misaligns** the 22 K row on the **shared** Φ(x) grid and **suppresses κ** via projection—**artifactually**.

---

## Evidence (numbers)

- **Residual row (22 K):** corr ≈ **0.7469**, κ ≈ **0.038** (`run_2026_03_25_000845_22k_residual_failure_audit`, `tables/22k_residual_audit_per_temperature.csv`).
- **Upstream scaling table:** discontinuity as in the table above (`run_2026_03_12_234016_switching_full_scaling_collapse`, `tables/switching_full_scaling_parameters.csv`).
- **Raw grid competition (22 K):** on **seven** finite current points, **S(30 mA) > S(35 mA)** but **(S_max − S_second)/S_max ≈ 0.019 (~1.9%)** (`run_2026_03_25_003337_peak_jump_audit`, `tables/peak_trace_20_22_24K.csv`).
- **PT / CDF:** reference residual run used **PT on all rows**, **zero** fallback rows—**not** a PT failure mode at 22 K.

---

## Mechanism (discrete argmax on a coarse grid)

1. **Map:** `buildSwitchingMapRounded` averages samples onto a **fixed** current list.
2. **Per temperature:** `buildScalingParametersTable` takes **`[S_peak, idxPeak] = max(rowValid)`** and **`I_peak = currValid(idxPeak)`** — **pure discrete argmax**, **no** sub-grid peak, **no** smoothing of `I_peak` across T.
3. **Width:** **`width_chosen_mA`** prefers **FWHM** from **`0.5 * S_peak`**, with bracket search **anchored at `idxPeak`** (`estimateFwhmWidth`). When the winning bin changes, **width updates with it**.

At **22 K**, **30 mA** and **35 mA** are **nearly tied** in **S**; the pipeline **must** pick one bin. That choice **steps** **`x`**, which is exactly what stresses **residual collapse** built from a **single** Φ(x).

---

## Why this is **not** …

| Misinterpretation | Why it does not hold |
|-------------------|----------------------|
| **PT failure** | CDF used **PT matrix for every temperature** in the audited residual run; 22 K was not a fallback row. |
| **Second physical mode** | A **large** correlation of the rank-1 **leftover** with the **second SVD direction** is **expected** when one row is **misregistered in x**; it is **not** sufficient to claim an independent second **physical** channel without fixing alignment. |
| **Residual model “breakdown”** | The **ansatz** assumes a **consistent** normalized coordinate; a **representation jump** in **`I_peak`/`w`** violates that **locally**. The formalism is fine; the **inputs** are **grid-sensitive** at this T. |

---

## Implications

- **`x = (I − I_peak)/w`** is **discontinuous in T** at 22 K **given the current pipeline**, so any analysis that stacks curves in **x** (residual SVD, geometry, etc.) can show **local** stress **without** implying a failure of the underlying **physics** story.
- **Downstream observables** that consume **`I_peak`** and **`w`** should treat **22 K** as **conditionally sensitive** to the **tabulated current mesh**.

---

## Recommended handling

1. **Treat 22 K as a grid-sensitive point** in cross-experiment or collapse summaries—**document**, do not over-interpret dips in corr or κ **in isolation**.
2. **Optional exclusion or down-weighting** in strict master-curve tests (policy choice; document when applied).
3. **Do not** relabel this as a “physics anomaly” or “second mode discovery” **without** separate evidence **after** alignment is stabilized.

---

## Standard phrasing (reuse in future reports)

The anomalous behavior at 22 K originates from a discrete peak-bin switch in the full-scaling collapse pipeline. Due to near-degeneracy between neighboring current bins, the argmax-based peak extraction shifts from 35 mA to 30 mA, inducing a discontinuity in the alignment coordinate. This effect is a representation artifact of the coarse current grid and does not indicate a breakdown of the underlying physical model.

---

## Flagging recommendation (documentation only — no implementation here)

**Near-degenerate peak condition (suggested):** on the **same finite current grid** used for `max(S)`, flag when

**(S_max − S_second) / S_max < ~0.05** (5%).

**Future pipeline design (not implemented in this note):**

- Emit a **diagnostic flag** in scaling-parameter exports when the condition holds.
- Consider an optional **sub-grid peak estimator** (e.g. local quadratic fit or denser current sampling) **only** after requirements and validation are defined.

---

## Related artifacts

| Artifact | Run / path |
|----------|------------|
| Residual decomposition (original) | `results/switching/runs/run_2026_03_24_220314_residual_decomposition/` |
| 22 K residual audit | `results/switching/runs/run_2026_03_25_000845_22k_residual_failure_audit/` |
| Peak jump trace (20 / 22 / 24 K) | `results/switching/runs/run_2026_03_25_003337_peak_jump_audit/tables/peak_trace_20_22_24K.csv` |
| Scaling parameters source | `results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_parameters.csv` |

Run-level reports under the residual and audit folders include an appended section **“22 K Anomaly — Root Cause”** with the same standard paragraph and table for readers who open those bundles first.
