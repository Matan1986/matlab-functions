# Switching Canonical Definition (v1.2)

## 0. Canonical execution system (locked)

### 0.1 Canonical entrypoint

- **`Switching/analysis/run_switching_canonical.m`** — sole registered Switching entrypoint for agents and automation.

Registry: `tables/switching_canonical_entrypoint.csv`. Backend: `docs/switching_backend_definition.md`. Aging path rules: `docs/switching_dependency_boundary.md`.

### 0.2 Guarantees (execution)

When this entrypoint is used as intended with the repository wrapper (`tools/run_matlab_safe.bat`) and run-context helpers:

- **Run-backed artifacts** — results are tied to a created `run_dir` and written per repository run rules; truth is established from those artifacts.
- **No precomputed inputs** — the canonical Switching pipeline does not treat pre-baked analysis tables as required inputs for the core Switching construction (contrast with weak candidates that read fixed repo tables; see `tables/switching_canonical_entrypoint_candidates.csv`).
- **Canonical pipeline execution** — Switching ver12 logic is reached only through the registered entrypoint wiring, not ad-hoc script selection.
- **Switching-only context** — experiment and outputs are Switching-scoped; cross-pipeline runners (e.g. Relaxation-mapped scripts) are out of scope for this definition.

### 0.3 Strict rules (agents)

- **DO NOT** use `run_minimal_canonical.m` as the canonical Switching entrypoint (minimal wiring only; see `tables/switching_noncanonical_scripts.csv`).
- **DO NOT** select Switching scripts heuristically or by filename pattern; use only `tables/switching_canonical_entrypoint.csv`.
- **DO NOT** run arbitrary `Switching/analysis/*.m` scripts as entrypoints unless this document and `docs/repo_execution_rules.md` explicitly allow them.
- **ONLY** use the registered canonical entrypoint **`Switching/analysis/run_switching_canonical.m`** for canonical Switching execution.

### 0.4 Execution contract

- **script → run_dir → artifacts → truth** — validity flows from the canonical script through run identity to persisted outputs; signaling follows `docs/repo_execution_rules.md` (Execution Signaling Contract).
- **No artifacts = no result** — if mandatory run artifacts and status files are not produced, the run must not be interpreted as delivering canonical Switching results.

---

## 1. Scope

This document defines the canonical Switching system as extracted strictly from:

* `run_switching_canonical.m` (path: `Switching/analysis/run_switching_canonical.m`)
* directly called code
* TRUSTED_CANONICAL runs (run_2026_04_03_*)

No assumptions, no legacy interpretation.

---

## 2. Canonical Observable

The canonical Switching observable is:

S(T, I) = change_pct

Where:

* S is taken directly from `metricTbl(:,4)`
* change_pct is defined upstream in `processFilesSwitching.m`

No additional normalization is applied at the observable level.

---

## 3. Canonical Model

S(T,I) = Scdf(T,I) + kappa1(T) * Phi1(I)

---

## 4. Components

### Scdf (Backbone)

* Constructed from CDF
* Uses internal normalization:

  * svalid / Speak(T)
  * normalized to [0,1]
* Then rescaled

IMPORTANT:
This normalization is internal to model construction and does NOT constitute coordinate collapse.

---

### Residual

DeltaS = Smap − Scdf

---

### Phi1

* First SVD mode:
  Phi1 = V(:,1)

* Normalized (max abs)

* Sign aligned via Spearman with Speak

---

### kappa1

kappa1 = U(:,1) * Sigma(1,1)

* Rescaled with Phi1 normalization
* Sign-aligned

---

## 5. Collapse Definition

### NOT USED:

* (I − I_peak)
* I / width
* I scaling
* shifting

### USED:

Low-dimensional functional decomposition:

S(T,I) = Scdf(T,I) + kappa1(T) * Phi1(I)

---

## 6. Interpretation

Collapse is implicit and occurs in function space.

COLLAPSE_DEFINED = YES
COLLAPSE_TYPE = IMPLICIT (WITH INTERNAL NORMALIZATION)

---

## 7. Normalization

Internal only (CDF construction).

INTERNAL_NORMALIZATION = YES
COORDINATE_COLLAPSE = NO

---

## 8. Dimensionality

Effective representation:

* backbone (Scdf)
* universal mode (Phi1)
* state coordinate (kappa1)

---

## 9. Exclusions

NOT canonical:

* width-based scaling
* I_peak alignment
* legacy collapse formulations

---

## 10. Scaling (Canonical Status)

A coordinate scaling collapse of the form:

S / S_peak  vs  (I − I_peak) / width

was tested using only TRUSTED_CANONICAL runs.

### Result

SCALING_COLLAPSE_EXISTS = PARTIAL
SCALING_REQUIRED_FOR_MODEL = NO

### Interpretation

* A partial collapse is observed across temperatures.
* However, the canonical decomposition model:

  S(T,I) = Scdf(T,I) + kappa1(T) * Phi1(I)

  provides a strictly superior representation across all tested metrics.

### Conclusion

Scaling should be treated as:

* an approximate projection of the system behavior
* NOT a canonical representation

---

## 11. Phi–Kappa Canonical Stability

The stability of the canonical decomposition was tested across canonical normalization variants.

### Result

PHI_STABLE_IN_CANONICAL_SPACE = YES
KAPPA_STABLE_IN_CANONICAL_SPACE = YES

Measured values:

* phi_shape_corr ≈ 0.9998
* abs_kappa_corr ≈ 0.9999

### Interpretation

* Phi1 is invariant under canonical normalization choices.
* kappa1 preserves its structure and ordering across variants.

### Conclusion

The pair (Phi1, kappa1) defines a stable canonical representation.

This confirms that:

* Phi1 is a universal mode
* kappa1 behaves as a stable state coordinate

---

## 12. Kappa1 Control (Canonical Analysis)

The dependence of kappa1 on observable quantities was tested using only TRUSTED_CANONICAL runs.

### Results

* kappa1 vs S_peak:

  * Pearson ≈ 0.92
  * Spearman ≈ 0.96
  * R² ≈ 0.85

* kappa1 vs I_peak:

  * Pearson ≈ 0.80
  * Spearman ≈ 0.88
  * R² ≈ 0.64

* Combined model:
  kappa1 ~ S_peak + I_peak:

  * R² ≈ 0.956

### Additional Observations

* kappa1 is not monotonic in temperature
* regime change detected near 22–24 K

---

### Verdict

KAPPA1_CONTROLLED_BY = MIXED
KAPPA1_IS_SIMPLE_OBSERVABLE = NO

---

### Interpretation

* kappa1 is not a simple amplitude parameter
* it is not reducible to a single observable
* it depends jointly on:

  * amplitude (S_peak)
  * structural location (I_peak)

---

### Conclusion

kappa1 defines a non-trivial state coordinate that couples:

* global response amplitude
* underlying structural configuration

---

## 13. Final Status

CANONICAL_STATE_VERSION = v1.2

CORE_MODEL_LOCKED = YES
COLLAPSE_LOCKED = YES
PHI1_LOCKED = YES
KAPPA1_LOCKED = YES

SCALING_LAYER_STATUS = RESOLVED
SCALING_NOT_REQUIRED = YES

PHI_STABLE = YES
KAPPA_STABLE = YES
STATE_SPACE_DEFINED = YES
