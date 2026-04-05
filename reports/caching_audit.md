# Phase 3.2C — Caching Audit (Switching canonical execution)

**Scope:** Canonical path `Switching/analysis/run_switching_canonical.m`, legacy S1 helpers (`getFileListSwitching`, `processFilesSwitching`, `analyzeSwitchingStability`), and `Aging/utils/createRunContext.m` for identity/fingerprint. **Read-only.** No MATLAB, no new runs.  
**Builds on:** `reports/performance_audit.md` (S1 ~84% of marker span), `reports/parallelization_audit.md` (folder-level independence), `tables/artifact_lineage_map.csv`, `tables/source_of_truth_map.csv`, `tables/system_reality_risks.csv`.  
**Date:** 2026-04-04.

---

## 1. Stage-by-stage cacheability map

| Stage / artifact | Deterministic (same inputs)? | Raw-only? | Code / env deps | Cacheability |
|------------------|------------------------------|-----------|-----------------|--------------|
| **Wrapper / guard** | YES for path validation | N/A | Minor path resolution | **SAFE** but **LOW_VALUE** (negligible cost). |
| **`createRunContext` / manifest / fingerprint** | YES given repo + cfg | NO (git, MATLAB, host, user) | **Entry script hash** in manifest (`computeRunFingerprint`) | **CONDITIONAL** — each run still needs **new run identity**; skipping fingerprint rarely wins performance (`tables/runtime_stage_map.csv` S0 ~11%). |
| **Folder discovery** (`dir` + `Temp Dep*`) | Mostly | PARTIAL (listing order / presence) | FS | **CONDITIONAL** — keys **WEAK** if based only on parent path. |
| **S1 raw parsing** (`processFilesSwitching`) | YES if **all** code + args fixed | PARTIAL (call parameters) | **MATLAB**, **float** behavior, **legacy `.m` not hashed in manifest** | **CONDITIONALLY_CACHEABLE**, **HIGH_VALUE** — **dominant cost** (`reports/performance_audit.md`). |
| **S1 stability** (`analyzeSwitchingStability`) | YES given `stored_data` + opts | DERIVED | Same helper-hash gap | **CONDITIONALLY_CACHEABLE**, **HIGH_VALUE** — tied to C04 outputs. |
| **Aggregation** (`rawTbl`, `sortrows`) | YES given upstream rows | DERIVED | Low | **CONDITIONAL** — **MEDIUM_VALUE**; cheap vs S1. |
| **S2 algebra** (maps, SVD, Phi1/kappa1) | YES given grid | DERIVED | Canonical script / helpers | **CONDITIONAL**, **MEDIUM_VALUE** — S2 ~2–3% of span; **less leverage** than S1. |
| **Exports** (CSV/MD) | YES given tables | DERIVED | Templates | **CONDITIONAL**, **LOW_VALUE** — S3 tiny vs total. |
| **Optional helpers** (`resolve_preset`, `resolveNegP2P`) | **NO** if path-dependent | NO | **Path existence** (`system_reality_risks.csv` R5) | **NOT_CACHEABLE** without full path+version key. |
| **Execution signaling** (status, probes, markers) | N/A for physics | N/A | **Run truth** | **NOT_CACHEABLE** — must reflect **this** execution (`docs/repo_execution_rules.md` signaling contract). |

Full rows: `tables/caching_candidates.csv`.

---

## 2. Strongest cache candidates (value × structural feasibility)

1. **Whole S1 per-folder pipeline (C11 / C04+C05)** — **Highest** potential time savings (**~84%** of marker span is S1-shaped per `tables/performance_stage_breakdown.csv`). **Structurally** plausible: **folder-level independence** (`reports/parallelization_audit.md`).

2. **Per-folder intermediates** (parsed/stability outputs) — Same **ROI**, finer granularity, **harder invalidation** and **higher** partial-stale risk.

**Weakest / misleading targets:**

- **S2/S3-only caching (C07/C08/C12)** — **Low** benefit: S2+S3 are **~4–5%** combined (`reports/performance_audit.md`). Caching final exports without caching S1 **does not** address the bottleneck.
- **Fingerprint-only as cache key** — **Insufficient:** manifest stores **SHA256 of entry script** (`createRunContext.m` `computeRunFingerprint`) — **does not** include **`Switching ver12`** helper sources that dominate S1 numerics (`tables/source_of_truth_map.csv` notes legacy stack).

---

## 3. Why tempting targets are unsafe (under current contract)

- **Silent reuse of S1 results** while claiming a normal run would make **`run_manifest.json` / `script_hash`** **honest only for the canonical file**, not for **legacy processing code** actually executed — **provenance gap** (`tables/caching_identity_compatibility.csv`).
- **Optional presets / negP2P** can change outputs **without raw file changes** — any cache key that is **raw-only** is **unsafe** (R5).
- **Execution artifacts** (`execution_status.csv`, probes, markers) **must not** be served from cache as-if produced by this run — violates **execution truth** / **NO SIGNAL → NO RUN** spirit (`docs/repo_execution_rules.md`).

---

## 4. Key and provenance analysis

| Key ingredient | In current fingerprint/manifest? | Robustness |
|----------------|-----------------------------------|------------|
| Entry script hash | **YES** (`fingerprint.script_hash`) | **STRONG** for **that file** only |
| Legacy helper hashes (`processFilesSwitching`, etc.) | **NO** | **Gap** — **WEAK** if omitted from cache key |
| Raw `.dat` content hash | **NO** (not in manifest) | **STRONG** if added for cache policy |
| `git_commit` | **YES** | **PARTIAL** — repo state; **not** file-level helper drift if uncommitted |
| MATLAB version / host / user | **YES** | **PARTIAL** — environment sensitivity |

**Conclusion:** **Technically** cacheable intermediates can be keyed by **raw hashes + full code closure + MATLAB release + opts**. **Provenance-safe** reuse under **today’s** manifest contract is **not** demonstrated — **extended sub-fingerprint or cache-attestation fields** would be needed for **honest** reporting (conceptual only; no implementation here).

---

## 5. Does caching meaningfully help the dominant bottleneck?

**Yes, in principle** — if **repeat runs** hit the **same raw files** and **same code closure**, **S1**-level reuse avoids **~84%** of the measured script span (performance audit). **In practice**, worth depends on **how often** that repetition occurs — **UNKNOWN** from repository artifacts (no workload statistics).

**Fine-grained (per-file) caching** inside `processFilesSwitching` adds **complexity** and **invalidation** burden vs **folder-level** snapshot; parallelization audit already notes **U03** couples files within a folder.

---

## 6. Cross-run reuse model (structural)

| Scenario | Structural fit |
|----------|----------------|
| **Unchanged `.dat` + unchanged full code stack** | **Coarse-grained** (per-folder or S1 snapshot) **possible** with **strong keys**. |
| **Unchanged folder set only** | **Insufficient** — need **content** and **code** hashes. |
| **Unchanged canonical script only** | **Insufficient** — legacy helpers not in entry hash. |
| **Export-only cache** | **Low** value; does not target S1. |

**Verdict:** System is **not** structurally aligned with **no caching** (repeat raw data is plausible in research workflows), but **not** with **naive** fingerprint-only **safe** caching. **Coarse-grained** is the **best fit** for **ROI vs complexity**; **fine-grained** only if invalidation discipline is acceptable (**HIGH** risk).

---

## 7. Identity compatibility (conceptual)

- **Manifest/fingerprint today:** Represent **this run’s** resolved entry script and **environment snapshot** — **not** a **full dependency closure** for S1.
- **If cached S1 outputs were reused:** Current artifacts could **misrepresent** what code ran unless **cache hits** are **explicitly recorded** — **requires new contract layer** for **honest** provenance (`tables/caching_identity_compatibility.csv`).
- **Provenance-safe caching under current system alone:** **Does not exist** for **high-value S1** targets without **additional attestation**.

---

## 8. Final caching verdict (policy, not implementation)

| Question | Answer |
|----------|--------|
| **Worth pursuing later?** | **Conditionally yes** — **only** if workloads repeat raw inputs and **provenance policy** accepts **extended** cache accounting. |
| **Target S1 only?** | **Yes** for **meaningful** speedup; S2/S3 caching is **secondary**. |
| **Main blocker?** | **Provenance / identity**, not raw **technical** impossibility of hashing inputs. |

**No implementation suggestions** — this audit stops at classification and contract boundaries.

---

## Deliverables

| File | Role |
|------|------|
| `tables/caching_candidates.csv` | Candidate stages and classifications |
| `tables/caching_risks.csv` | Risks by candidate |
| `tables/caching_identity_compatibility.csv` | Manifest/fingerprint compatibility |
| `tables/caching_summary.csv` | One-row summary |
| `tables/caching_status.csv` | Readiness flags |
| `reports/caching_audit.md` | This report |

---

## References (read-only)

- `Aging/utils/createRunContext.m` (`computeRunFingerprint`, `writeManifest`)
- `tables/artifact_lineage_map.csv`, `tables/source_of_truth_map.csv`
- `reports/performance_audit.md`, `reports/parallelization_audit.md`, `reports/system_reality_audit.md`
