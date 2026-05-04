# SW-STATE-U — `run_switching_canonical_state_audit.m` inspection

**Date:** 2026-05-04  
**Mode:** Audit-only — text inspection only; MATLAB not executed; script not modified.  
**Git preamble:** `git diff --cached --name-only` **empty** at audit time.  
**HEAD reference:** `bfa34b2` (`docs(switching): audit remaining leftover paths`) pushed per prior step.

---

## 1. Existence and tracking

| Check | Result |
|-------|--------|
| File exists on disk | **YES** — `Switching/analysis/run_switching_canonical_state_audit.m` |
| Git tracking | **Untracked** (`??` in `git status --short -- <path>`) |

---

## 2. Purpose (from header and body)

- **One-line:** Repository-level **Switching canonical state** audit: emits **governance tables** under `tables/switching/` and a **markdown report** under `reports/switching/`, plus run-scoped execution metadata under a Switching run directory from `createSwitchingRunContext`.
- **Explicit non-goals (header):** Does not run physics fits; does not read Relaxation inputs.
- **Nature:** **Governance / audit synthesis** — aggregates pointers, file-presence checks, and policy-shaped narrative; **not** a scientific analysis pipeline (no fits, no new quantitative inference).

---

## 3. Behavior summary

| Topic | Assessment |
|-------|------------|
| **Inputs read** | Mostly **existence probes** via `exist(fullfile(repoRoot, relPath), 'file')` in `buildCompletedTests`. Tabular **content** is not deeply parsed; several matrices (`buildClaimSafetyMatrix`, `buildOpenTasks`, `buildCrossModuleBlockers`, `buildStatusVerdicts`) are **largely static cell literals** (policy text), not recomputed from CSV rows. |
| **Outputs written (durable, repo-root)** | `tables/switching/switching_canonical_state_*.csv` (family inventory, claim safety matrix, completed tests, open tasks, cross-module blockers, status) and `reports/switching/switching_canonical_state_audit.md`. |
| **Outputs written (run directory)** | Via `createSwitchingRunContext` / `writeSwitchingExecutionStatus`: execution status, copies of status CSV + report into `runDir`, and `execution_probe_top.txt` (probe line `SCRIPT_ENTERED`). |
| **Report/table/status pattern** | **Yes** — matches expected Switching governance pattern: durable CSVs + paired markdown + machine-readable status keys. |
| **Canonical Switching artifacts** | **Primary scope yes** — reads and cites `tables/switching_*`, `docs/switching_*`, `scripts/run_switching_*`, `Switching/analysis/*` paths in strings and probes. |
| **Relaxation / Aging / cross-module** | **Does not read Relaxation or Aging data files.** Adds **`Aging/utils` to the MATLAB path** because **`createSwitchingRunContext` → `createRunContext`** lives there (shared repo infrastructure; same pattern as other Switching runners). **Content** references cross-module *policy* (e.g. `SAFE_TO_COMPARE_TO_RELAXATION`, maintenance gauge CSV paths) in **tables and narrative** — documentation of blockers, not execution of Relaxation code. |
| **Hardcoded absolute paths** | **No** — `repoRoot` from `mfilename`-relative ascent; all file ops use `fullfile(repoRoot, ...)`. |
| **Debug / tmp** | **Minor:** `execution_probe_top.txt` with a single marker line; run-dir sidecar pattern shared with other audits. |
| **Forbidden patterns (search-based)** | No `input`, no broad `delete`/`rmdir`, no figure generation calls, no interactive prompts. **`try`/`catch`:** on failure, writes `FAILED` execution status and **`rethrow(ME)`** — **not** a silent swallow. **`clear; clc`** at top — session hygiene, not a silent failure mask. No obvious “fallback” data fabrication beyond **static** synthesized rows (which is a **governance risk** if mistaken for live gates — see §5). |

---

## 4. Conceptual comparison to committed artifacts

| Artifact | Relationship to this runner |
|----------|----------------------------|
| `docs/switching_canonical_reader_hub.md` | **Hub = navigation and vocabulary** for humans. Runner = **generated bundle** of inventory + verdict-shaped tables. **Complementary** — aligns with SW-LEFTOVER-R: not a replacement for the hub. |
| `reports/switching_leftover_R_untracked_dirty_audit.md` | Classified this file as **`CURRENT_SWITCHING_WORK_CANDIDATE`**; stated runners emitting `tables/switching/` + `reports/switching/` are **complementary** to the hub. |
| `reports/switching_phase4B_figure_hygiene_K_audit.md` | **Explicitly references** this script as registry visibility for Phase4B/collapse machinery — committed docs already **expect** this runner name to exist in the narrative ecosystem. |
| `reports/switching_phase4B_figure_hygiene_N2_latest_export_interaction.md` | Orthogonal (paper export vs QA figures); no duplication of this runner’s role. |
| Synthesis / survey reports (`reports/switching_canonical_system_synthesis_E_state_and_plan.md`, etc.) | Runner output would **overlap in theme** (state-of-system) but is **machine-emitted** from a fixed template; **not** a byte-duplicate of synthesis markdown. **Risk:** static verdict cells could **diverge** from authoritative CSV gates unless regenerated under discipline. |

---

## 5. Governance risks before promotion

1. **`buildStatusVerdicts` / several builders** embed **fixed YES/NO/PARTIAL** strings — not all derived from reading current gate columns in source CSVs. Promoting **generated** outputs without a human diff against authoritative tables could **overstate** “machine-readable truth.”
2. **`writeMarkdownReport`** hardcodes **“missing expected paths”** bullet list — can become **stale** relative to disk without code edits.
3. **`addpath(..., 'Aging', 'utils')`** is **infrastructure**, not Aging science — should be **documented in the script header** so reviewers do not misread it as an Aging dataset dependency.

---

## 6. Classification

**`NEEDS_REPAIR_BEFORE_PROMOTION`**

Rationale: Runner is **coherent and valuable** as a governance synthesizer and is **already referenced** by committed Phase4B hygiene docs; however **header documentation** (Aging/utils path) and **truthiness** of static vs live-derived verdicts should be tightened **before** treating tracked outputs as authoritative. Not duplicate of existing committed prose artifacts; not obsolete by synthesis alone.

**Staging:** **`DO_NOT_STAGE_YET`** — classification is not `PROMOTE_AFTER_REVIEW` under the task rule (repair expected first).

---

## 7. Recommended next step

1. Author a **small header patch** (when edits are allowed): state that **`Aging/utils` is required for `createRunContext` only**.  
2. Decide policy: either **derive more verdict keys from live CSV reads** or **label static rows explicitly as editorial synthesis** in output CSV/report.  
3. Run MATLAB **once** in a controlled session to validate outputs, then **diff** against governance expectations before any commit.

---

*End of report.*
