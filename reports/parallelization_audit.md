# Phase 3.2B — Parallelization Audit (Switching canonical, S1 focus)

**Scope:** Canonical script `Switching/analysis/run_switching_canonical.m` and legacy helpers on the **S1** path: `getFileListSwitching`, `processFilesSwitching`, `analyzeSwitchingStability`. **Read-only.** No MATLAB, no new runs.  
**Builds on:** `reports/performance_audit.md` (S1 ~84% of marker span, hybrid IO+compute), `tables/performance_stage_breakdown.csv`, `tables/parallelization_map.csv`, `tables/io_behavior_map.csv`, `tables/performance_recomputation.csv`, `tables/system_reality_risks.csv`, `reports/system_reality_audit.md`.  
**Date:** 2026-04-04.

---

## 1. S1 decomposition (critical)

**S1 timing segment** (`tables/runtime_stage_map.csv`): from `STAGE_START_PIPELINE` through end of the **Temp Dep\*** `for` loop (immediately before `STAGE_AFTER_PROCESSING`). **Temp Dep enumeration** (`dir` + filter) runs **before** `STAGE_START_PIPELINE` and is attributed to **S0** in the performance breakdown; it is listed as **S0-U01** for logical completeness.

| Unit | What it does | Depends on | Produces |
|------|----------------|------------|----------|
| **S0-U01** | `dir(parentDir)` + `Temp Dep*` filter | `parentDir` | `subDirs` list |
| **S1-U01** | `getFileListSwitching(thisDir, dep_type)` | Folder path | `fileList`, `sortedValues`, `meta` |
| **S1-U02** | `processFilesSwitching(...)` | `fileList`, `sortedValues`, folder-local params | `stored_data`, `tableData` (per folder) |
| **S1-U03** | `analyzeSwitchingStability(...)` | **Full** `stored_data` + `sortedValues` for that folder | `stability` (channel choice, metrics) |
| **S1-U04** | Extract `metricTbl`, `Tvec`, `Svec`, `accumarray`, append `rows*` | Outputs of U03 + `tableData` | In-memory row blocks |
| **S1-U05** | `rawTbl`, `sortrows`, grid prep | **All** folder rows | Tables for S2 (after S1 marker) |

**Ordering constraints (structural):**

- **U01 → U02 → U03 → U04** must stay **in that order per folder**: stability analysis is written to consume **all files’** `stored_data` together (`analyzeSwitchingStability.m` documentation and `runOneSkip` pattern).
- **Across folders:** No **shared input files** between `thisDir` instances; **accumulators** (`rowsCurrent`, …) are **mergeable**; `rawTbl = sortrows(...)` makes **final physics order** independent of **folder iteration order** (commutative merge for the aggregated table, modulo provenance fields like `inputPaths` ordering).

Evidence: `run_switching_canonical.m` L156–247; `processFilesSwitching.m` file loop L43–578 with per-`i` `stored_data` and ordered `tableData` append; `analyzeSwitchingStability.m` L101–120 cross-file `runOneSkip`.

---

## 2. Independence analysis (summary)

| Unit | Independent across folders? | Independent across files? | Shared state? | Ordered execution? |
|------|----------------------------|----------------------------|---------------|---------------------|
| S1-U01 | **YES** (disjoint paths) | **PARTIAL** (sorted order defines sweep) | Per call | Sort order fixed by `getFileListSwitching` |
| S1-U02 | **YES** (disjoint `.dat` sets) | **PARTIAL** | **YES** (`tableData`, `stored_data` built in loop order) | **YES** (index `i` aligned with `sortedValues(i)`) |
| S1-U03 | **YES** (per-folder inputs) | **NO** (needs all files in folder) | Per-folder output struct | **After** U02 for that folder |
| S1-U04 | **YES** (row blocks) | N/A | **YES** (global row vectors in script) | **PARTIAL** (`sortrows` later) |

**No `global` / `persistent`** was found in `getFileListSwitching.m` or `processFilesSwitching.m` (grep). `analyzeSwitchingStability.m` matches referred to **field names** (e.g. `globalChannel`), not MATLAB `global`.

---

## 3. Parallelization classification

| Unit | Classification | Granularity | Rationale |
|------|----------------|-------------|-----------|
| S1-U01 | **PARALLEL_SAFE** (read-only listing) | per-folder | Disjoint `*.dat` listings |
| S1-U02 | **SEMI_PARALLEL** | per-file *or* per-folder | Per-file work is mostly independent; **`tableData` / `stored_data` require index-consistent merge** |
| S1-U03 | **SERIAL** (as written) | per-folder stage | **Cross-file** batch; cannot split without changing the analysis contract |
| S1-U04 | **SEMI_PARALLEL** | per-folder | Row appends commutable; **concat barrier** before S1-U05 |

Conservative rule applied: **PARALLEL_SAFE** only where independence is **clear** (folder-scoped listing reads). Anything requiring **ordered merge** or **full-batch stability** is **SEMI_PARALLEL** or **SERIAL**.

---

## 4. IO constraints (`tables/io_behavior_map.csv`)

| Candidate | Shared reads? | Shared writes? | Collision? | Contention? |
|-----------|---------------|----------------|------------|-------------|
| Per-folder `.dat` reads | **No** across folders | **No** legacy disk outputs in loop | **No** write collision | **Yes** possible **bandwidth** contention on one disk |
| Workspace only | N/A | N/A | N/A | N/A |

**Classification:** **IO_SAFE** for correctness (disjoint paths); **IO_CONTENTION_RISK** under parallel readers on the **same volume** (not **IO_COLLISION_RISK** for output paths—no concurrent writers to the same file in the legacy loop).

---

## 5. State / coupling

| Mechanism | Finding | Risk |
|-----------|---------|------|
| MATLAB `global` / `persistent` in three legacy files | Not used (grep) | **NONE** |
| Growing `rows*` in canonical script | Merge point at loop end | **LOW** |
| `tableData` build order in `processFilesSwitching` | File index order | **MEDIUM** if parallelizing file loop without ordered merge |
| `analyzeSwitchingStability` cross-file use | **HIGH** coupling **within** folder | **MEDIUM** |
| Optional `resolve_preset` / `resolveNegP2P` | Path-dependent numerics (`system_reality_risks.csv` R5) | **LOW** |

**Overall state/coupling:** **LOW** at **folder** boundary; **MEDIUM** **inside** `processFilesSwitching` / `analyzeSwitchingStability` **pair**.

---

## 6. Conceptual parallelization models (no implementation)

| Model | Applies to | Scalability (structural) | Risk |
|-------|--------------|----------------------------|------|
| **Per-folder parallel** | Run **U01–U04** per `thisDir` in isolation, then merge rows | **Good** if many `Temp Dep*` folders | **Medium** — merge + disk contention |
| **Per-file parallel inside U02** | Split `processFilesSwitching` file loop | **Limited** until merge; **U03 still serial** on full batch | **High** ordering / merge |
| **Batched folders** | Chunks of folders | **Moderate** | **Medium** — reduces contention |
| **Staged pipeline overlap** | Overlap U02 and U03 | **Low** without API change — **U03 needs complete `stored_data`** | **High** |
| **Outer parallel** (multiple `matlab -batch` runs) | Whole script instances | **Semi** (`tables/parallelization_map.csv`) | **Low** if distinct `run_id`; repo/git read-only |

---

## 7. Theoretical speedup (qualitative)

- **Dominant serial component in the loop:** **U02+U03** chain per folder; **U03** prevents trivial file-level pipeline parallelism for the **whole** per-folder pipeline.
- **Parallelizable fraction (rough):** On the order of the **S1 share of total time** (~**84%** of marker span per `tables/performance_stage_map.csv`), **reduced** by:
  - merge / serial sections,
  - **Amdahl** limits (S0, S2–S4 remain serial in one MATLAB process),
  - **small folder count** (common case — low **P**).

**Expected speedup class:** **MEDIUM (1.5×–3×)** **if** enough independent folders and **IO does not saturate**; **LOW (<1.5×)** if **one folder** dominates or disk-bound. **HIGH (>3×)** is **not** justified structurally without **many** balanced folders **and** favorable IO—mark **UNKNOWN** for this repo’s real folder counts (no measured distribution in artifacts).

---

## What limits scaling

1. **`analyzeSwitchingStability` cross-file dependency** — **primary** barrier to **within-folder** parallelism.
2. **Ordered `tableData` / `stored_data` assembly in `processFilesSwitching`** — barrier to naive **per-file** parallelism.
3. **Shared filesystem bandwidth** — many parallel readers on one drive.
4. **Single MATLAB process** — S2–S4 and merge remain serial; **outer** parallelization is a different model (`parallelization_map.csv`).

---

## Optimization vs parallelization vs caching

This audit **does not** conflate **caching** or **algorithmic optimization** with **parallelism**. **Caching audit** remains a separate concern (`parallelization_status.csv`).

---

## Deliverables

| File | Role |
|------|------|
| `tables/parallelization_units.csv` | Units, independence, classification |
| `tables/parallelization_io.csv` | IO risk by unit |
| `tables/parallelization_risks.csv` | Risk register |
| `tables/parallelization_models.csv` | Conceptual models |
| `tables/parallelization_summary.csv` | One-row summary |
| `tables/parallelization_status.csv` | Readiness flags |
| `reports/parallelization_audit.md` | This report |

---

## References (read-only)

- `Switching/analysis/run_switching_canonical.m`
- `Switching ver12/getFileListSwitching.m`
- `Switching ver12/main/processFilesSwitching.m`
- `Switching ver12/main/analyzeSwitchingStability.m`
- `tables/io_behavior_map.csv`, `tables/performance_stage_breakdown.csv`, `tables/parallelization_map.csv`
