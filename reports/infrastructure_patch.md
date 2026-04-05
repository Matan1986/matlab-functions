# Infrastructure patch report (Switching-focused)

**Date:** 2026-04-03  
**Scope:** Minimal infrastructure consistency fixes only; no scientific logic changes.

## Resolved (audit critical items)

1. **Wrapper truth:** `docs/AGENT_RULES.md`, `docs/repo_execution_rules.md`, and `tools/run_matlab_safe.bat` header now describe `matlab -batch` with `run('<script>')`. Legacy `eval(fileread(...))` wording removed for execution. Preflight validation described as optional / non-blocking.
2. **execution_status schema:** Single schema per `docs/run_system.md` section 3, summarized in `docs/execution_status_schema.md`. `Switching/analysis/run_switching_canonical.m` writes `EXECUTION_STATUS`, `INPUT_FOUND`, `ERROR_MESSAGE`, `N_T`, `MAIN_RESULT_SUMMARY` (including PARTIAL phases).
3. **Shared pointer:** Removed `run_dir_pointer.txt` writes from `Switching/analysis/run_minimal_canonical.m` and `docs/templates/matlab_run_template.m`. `docs/run_system.md` section 6 deprecates repo-root pointer; discovery via `run_dir/run_manifest.json`.
4. **run_dir-only outputs:** `run_switching_canonical.m` catch path allocates a failure `run_dir` via `createRunContext` or a `results/Switching/runs/run_failure_*` folder — no `execution_status` under repo root.
5. **Hardcoded paths:** Removed `C:/Dev/...` probe from `run_switching_canonical.m`; `repoRootBootstrap` from `mfilename`. Template uses dynamic `repoRoot` from script location.
6. **Documentation pruning:** `docs/agent_prompt_exclude.md` lists 15 non-essential paths; `docs/repo_context_minimal.md` and `docs/AGENT_RULES.md` reference it so default prompts do not bulk-load them.
7. **repo_context_infra:** Rewritten to match the minimal batch wrapper (no fictional fingerprint/pointer/post-check stages).

## Follow-up (out of scope)

Other non-Switching scripts (e.g. root-level `run_parameter_robustness_*.m`, `Relaxation ver3/`, experimental Switching) may still reference `run_dir_pointer.txt`. Remove when those modules are touched under the same policy.

## Machine-readable log

`tables/infrastructure_patch.csv`

---

## FINAL METRICS (see user query)

| Metric | Value |
| --- | --- |
| CRITICAL_ISSUES_RESOLVED | 7 |
| PARALLEL_READY_AFTER_PATCH | YES (Switching canonical paths: no shared repo-root pointer from patched scripts; outputs under unique `run_dir`) |
| DOCS_CLEANED | YES |
| SYSTEM_CONSISTENT | YES |
