# Switching canonical entrypoint audit

**Rules:** Inspection only; no MATLAB execution; no code changes.

## 1. Search method

- Grep `createRunContext` under `Switching/analysis/**/*.m` (excluding `experimental/**` from primary recommendations where noted).
- Grep `execution_status`, `addpath.*Aging`, `Relaxation`.
- Read file headers for: pure script vs `function`, hardcoded outputs, cross-experiment keys.

## 2. Ranked candidates (summary)

| Rank | File | Class |
| --- | --- | --- |
| 1 | `Switching/analysis/run_switching_canonical.m` | STRONG_CANDIDATE |
| 2 | `Switching/analysis/run_minimal_canonical.m` | STRONG_CANDIDATE |
| 3 | `Switching/analysis/run_parameter_robustness_switching_canonical.m` | WEAK_CANDIDATE |
| 4+ | See `tables/switching_canonical_entrypoint_candidates.csv` | WEAK / NOT_VALID |

## 3. Reasoning

- **Primary canonical definition:** `docs/switching_canonical_definition.md` explicitly extracts from `run_switching_canonical.m` (lines 7–8). That file is a **pure script** (no top-level `function`), uses `createRunContext('Switching', ...)`, writes `execution_status.csv` under `run_dir`, and produces `tables/` and `reports/` there.
- **Minimal wiring:** `run_minimal_canonical.m` is the smallest **pure script** that exercises `createRunContext` + CSV + MD + manifest under `run_dir`; suitable as an infrastructure smoke entry, not the full physics canonical generator.
- **Robustness runner:** `run_parameter_robustness_switching_canonical.m` is named “canonical” in the robustness sense but **does not** call `createRunContext`; it writes status via `writeExecutionStatus` to paths derived from `baseFolder` (see L22–47); it contains **local `function` blocks** (e.g. L373+), so it does not match the repo’s “pure script” runnable contract. It **depends on precomputed** trust and canonical CSV inputs (L56–64).
- **Relaxation / cross-pipeline `run_*.m` files** (e.g. `run_PT_to_relaxation_mapping.m`, `run_relaxation_deep_search.m`) are **NOT_VALID** as Switching-only canonical entrypoints per scope (Relaxation data paths in headers).

## 4. Recommendation

- **Single “canonical Switching definition” entrypoint (science + pipeline):** **`Switching/analysis/run_switching_canonical.m`** — documentation-backed.
- **Secondary entry for minimal execution proof:** **`Switching/analysis/run_minimal_canonical.m`**.
- **Verdict:** **MULTIPLE_PLAUSIBLE_ENTRYPOINTS** with **clear roles** (full canonical vs minimal vs robustness audit), not a single ambiguous file.

Evidence table: `tables/switching_canonical_entrypoint_candidates.csv`.
