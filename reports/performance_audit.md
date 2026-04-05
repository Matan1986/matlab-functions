# Phase 3.2 — Performance Audit (Switching canonical execution)

**Scope:** Canonical Switching path only: `tools/run_matlab_safe.bat` → `Switching/analysis/run_switching_canonical.m` with `Aging/utils/createRunContext.m` on the direct chain.  
**Method:** Read-only. **No MATLAB runs.** **No new runs.** Uses repository tables (`tables/runtime_stage_map.csv`, `tables/io_behavior_map.csv`, `tables/system_execution_map.csv`, `tables/artifact_lineage_map.csv`, `tables/system_reality_status.csv`, `reports/system_reality_audit.md`) and script structure. **Measured durations** come from **`tables/runtime_stage_map.csv`** (sample run `run_2026_04_04_143749_switching_canonical`). **This workspace checkout contains no `results/.../run_*` artifacts** (no `runtime_execution_markers.txt` on disk to re-verify or measure file sizes); where replication is impossible, entries are marked **UNKNOWN**.  
**Date:** 2026-04-04.

---

## 1. Runtime decomposition

### 1.1 Measured script segments (marker-derived)

Intervals are defined in `tables/runtime_stage_map.csv` and summarized in `reports/system_reality_audit.md` §6. Sum of script segments (excluding unknown pre-marker time) ≈ **20.37 s**.

| Segment | ~Duration | ~% of marker span | Classification |
|---------|-----------|-------------------|----------------|
| S0: `ENTRY` → `STAGE_START_PIPELINE` | 2.3 s | ~11% | **MODERATE** |
| S1: `STAGE_START_PIPELINE` → `STAGE_AFTER_PROCESSING` | 17.2 s | ~84% | **HEAVY** |
| S2: after processing → `STAGE_BEFORE_OUTPUTS` | 0.48 s | ~2.4% | **NEGLIGIBLE** (vs total) |
| S3: `STAGE_BEFORE_OUTPUTS` → `STAGE_AFTER_OUTPUTS` | 0.29 s | ~1.4% | **NEGLIGIBLE** |
| S4: after outputs → `COMPLETED` | &lt;0.1 s | ~0.5% | **NEGLIGIBLE** |

**Variability:** **UNKNOWN** — only **one** sample row exists in `runtime_stage_map.csv`; no second run in-repo to compare.

### 1.2 Stages requested vs observable

| Requested stage | Evidence |
|-----------------|----------|
| Wrapper / guard overhead | **UNKNOWN** duration — not timed in marker file; expected **negligible** vs 20 s script work. |
| MATLAB startup (JVM, `-batch`) | **UNKNOWN** — occurs **before** first `ENTRY` marker; not separated in artifacts. |
| `createRunContext` + manifest / fingerprint writes | **Embedded in S0** (~2.3 s total with path setup, probes, partial status); **cannot** split from markers without extra instrumentation. |
| Pipeline (parse, stability, aggregation) | **S1 (~17.2 s)** — dominant. |
| Analysis (Phi1, kappa1, observables, validation flags) | **S2 (~0.48 s)**. |
| Export (CSV, MD) | **S3 (~0.29 s)**. |
| Finalize status / markers | **S4 (&lt;0.1 s)**. |

Detail: `tables/performance_stage_breakdown.csv`.

---

## 2. Bottleneck identification

- **Dominant stage:** **S1 — legacy pipeline** (`getFileListSwitching` → `processFilesSwitching` → `analyzeSwitchingStability` loop over `Temp Dep*` folders). ~**84%** of the **marker-derived** span (`tables/runtime_stage_map.csv`).
- **Second-order:** **S0** (~11%) — context creation, manifest/fingerprint, probes, early CSV writes (not the rank-1 algebra).
- **Negligible vs total:** **S2–S4** combined ≈ **4–5%** — analysis + export + finalize.

**Single vs distributed:** **Single dominant bottleneck** (S1). Remaining time is **distributed** but **small**.

**CPU vs IO:** **HYBRID** for S1 — `tables/io_behavior_map.csv` classifies **many `.dat` reads via legacy** as heavy per folder; stability work is compute. No profiling data in-repo to split CPU vs disk precisely.

---

## 3. IO cost audit

Sources: `tables/io_behavior_map.csv`, `tables/artifact_lineage_map.csv`.

- **Writes:** Multiple **small** run artifacts (CSV, MD, probes); `execution_status.csv` **overwritten three times** — **ESSENTIAL** for signaling (`artifact_lineage_map`), not redundant physics.
- **Append:** `runtime_execution_markers.txt` — many appends, **ordered observability**; **ESSENTIAL** for stage tracing.
- **Fallback:** `tables/runtime_execution_markers_fallback.txt` — **cross-run append**; **REDUNDANT** for performance (noise), not on hot path of S1.
- **Large IO:** Dominated by **reads inside legacy pipeline** (many `.dat` per folder), not by final CSV export.

**File sizes:** **UNKNOWN** in this workspace (no run output files present).

Classification table: `tables/performance_io_audit.csv`.

---

## 4. Re-computation / duplication

From script structure (`Switching/analysis/run_switching_canonical.m`) and `reports/system_reality_audit.md`:

- **Per-folder loop:** Distinct inputs per folder — **NECESSARY**, not duplicate work on the same data.
- **`Smap` vs `S_long`:** Two representations of the same surface — **NECESSARY** by design (`tables/source_of_truth_map.csv` / audit).
- **Single SVD** on `Rfill` — **NECESSARY**; no repeated SVD in-script.
- **Legacy internals:** Possible internal re-reads — **UNKNOWN** without profiling.

Table: `tables/performance_recomputation.csv`. **No major wasted recomputation** identified from structure alone.

---

## 5. Stage efficiency (verdict)

| Stage | Cost | Necessity | Verdict |
|-------|------|-----------|---------|
| S0 | MODERATE | High (identity, probes, manifest) | **ACCEPTABLE** |
| S1 | HEAVY | High (canonical raw→aggregated path) | **CRITICAL BOTTLENECK** (wall time) |
| S2 | Low | High (defined analysis) | **OPTIMAL** (relative to total; not profiled) |
| S3 | Low | High (contracted outputs) | **OPTIMAL** (relative to total) |
| S4 | Tiny | High (signaling) | **OPTIMAL** |

---

## 6. Sensitivity (qualitative, no new runs)

- **Improve S1 (legacy processing + stability):** **Largest** expected impact on total time — S1 is ~**84%** of marker span.
- **Reduce final CSV/MD writes:** **Small** expected gain — S3 is ~**1.4%** of marker span.
- **Reduce analysis (SVD, maps):** **Small** expected gain — S2 ~**2.4%**.
- **Reduce S0 (context + fingerprint):** **Moderate second-order** — ~**11%**; manifest/git/hash are **once per run**.

---

## 7. Simplified performance model

Using **marker-derived** totals only (pre-MATLAB time excluded):

\[
T_{\mathrm{visible}} \approx T_{\mathrm{S0}} + T_{\mathrm{S1}} + T_{\mathrm{S2}} + T_{\mathrm{S3}} + T_{\mathrm{S4}}
\approx 2.3 + 17.2 + 0.48 + 0.29 + 0.1 \approx 20.4\ \mathrm{s}
\]

Full wall clock:

\[
T_{\mathrm{wall}} \approx T_{\mathrm{pre\mbox{-}MATLAB}} + T_{\mathrm{visible}}
\]

with \(T_{\mathrm{pre\mbox{-}MATLAB}}\) **UNKNOWN** from repository artifacts.

**Approximate contribution of terms (within \(T_{\mathrm{visible}}\)):**

| Term | ~Share |
|------|--------|
| \(T_{\mathrm{S1}}\) pipeline | ~**84%** |
| \(T_{\mathrm{S0}}\) setup / context / probes | ~**11%** |
| \(T_{\mathrm{S2}}+T_{\mathrm{S3}}+T_{\mathrm{S4}}\) analysis + export + finalize | ~**4–5%** |

Model is **SIMPLE**: one term dominates.

---

## What matters vs what does not

| Matters for wall time | Does not matter much (in measured span) |
|------------------------|----------------------------------------|
| Legacy **S1** loop: raw reads + stability + aggregation | Rank-1 **SVD** and maps (**S2**) |
| Per-folder **IO** and compute in **Switching ver12** helpers | Final **CSV/MD** export volume (**S3**) |
| | Wrapper/guard (expected tiny vs S1) |

---

## Optimization focus (informational only — no fixes)

**If** future work targets runtime: **focus on S1** (legacy pipeline and stability path), because it accounts for the vast majority of **measured** script time. **Export and post-processing algebra are not the bottleneck** in the available sample. **Confirmation across runs and environments** would require additional timed runs or profiling — **not done here**.

---

## Deliverables index

| File | Purpose |
|------|---------|
| `tables/performance_stage_breakdown.csv` | Stage durations, %, classification |
| `tables/performance_io_audit.csv` | Artifact write/read classification |
| `tables/performance_recomputation.csv` | Recomputation vs necessary |
| `tables/performance_summary.csv` | Single-row roll-up |
| `tables/performance_status.csv` | Audit readiness flags |
| `reports/performance_audit.md` | This report |

---

## References (read-only)

- `docs/repo_execution_rules.md` (wrapper policy; not timing)
- `tables/runtime_stage_map.csv`, `tables/io_behavior_map.csv`, `tables/artifact_lineage_map.csv`, `tables/system_execution_map.csv`
- `reports/system_reality_audit.md`
