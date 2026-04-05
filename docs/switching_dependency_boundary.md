# Switching dependency boundary: Aging/utils

This document defines **allowed** and **forbidden** use of `Aging/utils` and related path setup for Switching execution. It aligns with `tables/switching_canonical_entrypoint_candidates.csv` (canonical candidate uses `addpath` limited to `Aging/utils`, not `genpath(Aging)`).

## 1. Allowed usage

- `addpath(<repoRoot>/Aging/utils)` (or equivalent resolution to the repository `Aging/utils` directory).
- `createRunContext(...)` from that utils path, as used by the canonical Switching entrypoint wiring.

## 2. Classification

- **`createRunContext`** — **SAFE_INFRASTRUCTURE (CONDITIONAL)**  
  It is infrastructure for run identity and output placement, not Switching science code.

## 3. Conditions (must all hold)

When using `createRunContext` for Switching:

- **Must not** load Aging datasets or Aging experiment data as part of defining the Switching run (no implicit Aging pipeline activation via path or calls).
- **Must not** use Aging pipeline logic (non-utils Aging code) for Switching execution.
- **Must not** introduce **cross-run state leakage** (run identity and outputs must remain tied to the current `run_dir` and repository run rules).

## 4. Explicit prohibitions

- `addpath(genpath(Aging))` — **not allowed** for Switching canonical execution.
- Importing or calling **non-utils** Aging modules as if they were part of the Switching canonical path — **not allowed**.

## 5. Risk explanation

- `genpath(Aging)` causes **path pollution**: a large subtree on the MATLAB path increases the chance of wrong-function resolution.
- **Function shadowing**: unrelated Aging `.m` files can override intended helpers.
- **Unintended coupling**: Switching runs may accidentally depend on Aging behavior not reviewed for Switching audits.

## 6. Final verdict

- **AGING_UTILS_ALLOWED = RESTRICTED**  
  Only `Aging/utils` + conditional `createRunContext` as documented here; no broad Aging pathing.

## 7. Source of truth (Switching infra; read-only)

Authoritative definitions for **RUN_ID**, **PARENT_RUN_ID**, **INPUT_SOURCE**, **FINGERPRINT**, **EXECUTION_STATUS**, and **IS_CANONICAL** for Switching are locked in **`docs/switching_backend_definition.md`** (Sections 7–9) and in **`tables/infra_source_of_truth_definition.csv`**. This document adds only the **boundary** rule: do not infer cross-experiment or cross-run identity from Aging paths, `genpath`, or non-canonical tables — use the same allowed vs forbidden derivations as in that section.

### Allowed vs forbidden derivations (boundary slice)

- **Allowed:** `addpath` to `Aging/utils` only; `createRunContext` for run directory placement consistent with `docs/switching_backend_definition.md`.
- **Forbidden:** Using Aging modules or path layout to infer **PARENT_RUN_ID**, **INPUT_SOURCE**, or **IS_CANONICAL** (those come only from the SSOT files listed in the backend doc).

### Undefined fields policy (boundary slice)

If a Switching run manifest does not define a field governed by SSOT rules, treat it as **undefined**; do not substitute Aging-side state or path heuristics.
