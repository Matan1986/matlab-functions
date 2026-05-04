# AGING-DECOMPOSITION-TAU-GAP-SURVEY-01

**Rules:** [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Agent:** Narrow Aging read-only gap survey (decomposition + tau-method clarity **before** comparison-runner work, visuals, ratio re-entry, paper figures).

**Preflight:** `git diff --cached --name-only` was **empty** at task start.

**Scope:** Synthesize **what is still unclear** for canonical **multi-route** decomposition × tau comparison, **without** rerunning prior inventories from scratch. Prior work (**F7U**, **F7V**, **F7X2**, **F7T**, **F7S**, baseline emission **`c7e5d41`**, output sanity **OUTPUT-SANITY-01**) already constrains the answer.

---

## Executive answer

**Canonical comparison of multiple decomposition routes and tau-computation routes is not fully specified yet.** The repo has:

- A **clear, validated** *narrow* lane: **Track B–style** consolidation inputs → **curve-fit** \(\tau\) on **`Dip_depth`** / **`FM_abs`** with **sidecars** (`DIP_DEPTH_CURVEFIT`, `FM_ABS_CURVEFIT`, **`ABS_ONLY`** on FM), evidenced by **`aging_baseline_tau_sidecar_emission_validation_01`** and **`aging_baseline_tau_output_sanity_01`**.
- **Documented non-equivalence** between **Track A** summaries (`AFM_like`, `FM_like`, …) and **Track B** consolidation columns — **forbidden naive substitution** per measurement freeze and **F7V** (`COMPARABLE_AFTER_BRIDGE` only).
- **Persistent naming/metadata gaps**: **`Track A` / `Track B`** are routing shorthand, not method identities (**F7X2**). **`tau_effective_seconds`** is a **shared legacy column name** across Dip and FM writers; comparability requires **`tau_domain`**, consensus method strings, and lineage (**`aging_tau_metadata_gate_01_tau_effective_seconds_policy.csv`**, **F7X4/F7X5** blockers cited in **re-entry map**).

Therefore: **method taxonomy is partially clear**, **baseline direct path is validated for bookkeeping-level tau+sides**, but **multipath / cross-family comparison** remains **blocked** until **bridges**, **paired artifact registries**, and **explicit per-path semantic IDs** are implemented or chartered — consistent with **F7U** / **F7V** verdicts.

---

## What prior artifacts already resolved (do not reopen)

| Topic | Resolution (citation) |
|------|-------------------------|
| Fit vs direct **cannot** be treated as same observable without bridge | **F7V** forbidden substitutions + `FIT_DIRECT_DIRECTLY_COMPARABLE = NO` |
| Multipath ratio robustness **not** ready | **F7U** `F7U_READY_FOR_MULTIPATH_ROBUSTNESS_EXECUTION = NO` |
| **`tau_effective_seconds`** unsafe solo | Metadata gate policy rows + **re-entry** B-003 |
| Baseline Dip/FM tau **emission + fields** for consolidation run | **`c7e5d41`** validation report + tables |
| FM **ABS_ONLY** and Dip depth curvefit **domains** on validated sidecars | Emission validation + OUTPUT-SANITY-01 |
| **`Track A`/`Track B` insufficient as primary names** | **F7X2** § “Why Track A / Track B are insufficient” |
| Scoped ratio **charter** mechanics (CEL, branch modes) | **F7T** (execution still future) |
| FM convention / failed-clock **policy** still partial | **F7S**, **F7T** remaining blockers |

---

## What remains unclear for canonical multi-route comparison

1. **Cross-family bridges** — **F7V** requires explicit bridge implementation (`F7V_BRIDGE_IMPLEMENTED = NO`). Until then, **Track A**↔**Track B** rows are **AMBIGUOUS_SOURCE** / **BLOCKED_BY_MISSING_METADATA** for side-by-side “same component” claims.
2. **Opaque pathway identity in automation** — **F7X2** recommends **`decomposition_path_id`**-style ids; without a **central registry** keyed to producer cfg + dataset hash, two runs labeled “direct” may differ (**AMBIGUOUS_METHOD** at automation layer).
3. **Tau column headline without bundle** — Joining or sorting on **`tau_effective_seconds`** alone remains **unsafe** for cross-writer science (**TAU_EFFECTIVE_SECONDS_STILL_AMBIGUOUS = YES** for naive use; **YES** with sidecar+bundle per validated baseline).
4. **Old-fit / replay lanes** — **F6**–series and **R1–R4** documents describe **legacy** and **diagnostic** paths; they are **CLEAR_BUT_NOT_VALIDATED_FOR_COMPARISON** as a unified “method” for baseline parity (**OLD_FIT_PATH_CLEAR = PARTIAL** at catalog level).
5. **Comparison-runner implementation** — **NOT READY** until pathway rows carry **producer_script**, **output_artifacts**, **sidecar_status**, and **bridge class** for **each** route to be compared (**COMPARISON_RUNNER_READY_TO_IMPLEMENT = NO**).

---

## Machine-readable deliverables

| File | Role |
|------|------|
| `tables/aging/aging_decomposition_tau_gap_survey_01_prior_artifacts.csv` | Prior reports/tables consulted |
| `tables/aging/aging_decomposition_tau_gap_survey_01_pathway_status.csv` | Pathway classifications |
| `tables/aging/aging_decomposition_tau_gap_survey_01_remaining_gaps.csv` | Open gaps |
| `tables/aging/aging_decomposition_tau_gap_survey_01_next_tasks.csv` | Suggested follow-on tasks |
| `tables/aging/aging_decomposition_tau_gap_survey_01_status.csv` | Status keys |

---

## Cross-module

No edits to Switching, Relaxation, Maintenance-INFRA, MT, or Aging code. No MATLAB, Python, replay, tau, ratio, or visualization execution in this task.
