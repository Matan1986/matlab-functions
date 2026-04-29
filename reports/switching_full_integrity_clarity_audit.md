# Switching — full integrity, clarity, and quarantine audit

**Audit date:** 2026-04-29 (workspace inspect + git inspect + read-only artifact cross-check).  
**HEAD:** `72215df` (*Close Switching governance and TASK002A visual QA*).  
**Constraints respected:** Switching-only analytical scope; no reconstruction; no builder rerun; no figure regeneration; no edits to authoritative numerical CSV outputs; read-only except new audit tables/reports listed below.

---

## Executive summary

Corrected-old **formula identities** and **quality-metric replays** recorded in `tables/switching_corrected_old_quality_metrics_consistency_check.csv` **pass** with documented limits (CHK007 not recomputed). **Policy and builder gates** assert **no** experimental PTCDF / mixed-canonical-diagnostic inputs to the authoritative builder (`CHK009`). The **canonical module** remains a **mixed producer**; isolation relies on **column namespace documentation**, **post-run `switching_canonical_source_view.csv`**, and **discipline** — not a mechanical lock on `switching_canonical_S_long.csv`.

**Blocking governance risks:** (1) **`run_switching_corrected_old_authoritative_builder.m` and related PS1 wrappers are untracked** (`??`). (2) **Authoritative numerical tables** (`switching_corrected_old_authoritative_*` maps/metrics) are **not** in `git ls-files` at audit time — they live under `.gitignore` rules (`tables/**`, `tables/*_map*`, `tables/*metrics*`, etc.). Commit `72215df` captured TASK_001/TASK_002/TASK_002A **process artifacts** and diagnostic drivers/PNGs, **not** the full authoritative numerical bundle.

**Experimental PTCDF quarantine verdict:** **PARTIAL** — registry + builder forbids + docs are strong; **mixed files**, **legacy filenames**, and **human load patterns** remain residual hazards.

**Safe to proceed to TASK_002B / scientific interpretation:** **PARTIAL** — interpret only under explicit namespace rules; **do not** treat TASK_002B as started; resolve **P0** provenance items before collaborative handoff.

---

## Deliverables (this audit)

| Deliverable | Path |
|-------------|------|
| Git state classification | `tables/switching_full_integrity_clarity_audit_git_state.csv` |
| Current-state / Test A | `tables/switching_full_integrity_clarity_audit_current_state.csv` |
| Canonical isolation / Test B | `tables/switching_full_integrity_clarity_audit_canonical_isolation.csv` |
| PTCDF quarantine / Test C | `tables/switching_full_integrity_clarity_audit_ptcdf_quarantine.csv` |
| Corrected-old inputs / Test D | `tables/switching_full_integrity_clarity_audit_corrected_old_inputs.csv` |
| Formula/numeric / Test E | `tables/switching_full_integrity_clarity_audit_formula_numeric.csv` |
| Lineage & commit visibility / Test F | `tables/switching_full_integrity_clarity_audit_artifact_lineage_commit_visibility.csv` |
| Status contradictions / Test G | `tables/switching_full_integrity_clarity_audit_status_contradictions.csv` |
| Risk register / Test H | `tables/switching_full_integrity_clarity_audit_risk_register.csv` |
| Verdict row | `tables/switching_full_integrity_clarity_audit_status.csv` |
| Recommended fixes (optional) | `tables/switching_full_integrity_clarity_audit_recommended_fixes.csv` |

**Git hygiene note:** Under `.gitignore`, most `tables/*audit*` and `reports/**` paths are **ignored** unless force-added (same pattern as checkpoint `72215df`). This audit’s outputs are **not** automatically committed.

---

## Git commands recorded

Executed and summarized in `tables/switching_full_integrity_clarity_audit_git_state.csv` header section and rows:

- **35 modified** (`M`): canonical namespace scripts, gauge atlas assets, docs manifest, maintenance/governor reports, classification CSVs.
- **58 untracked** (`??`): full Relaxation `Relaxation ver3/` bundle; Aging root scripts; untracked **corrected-old authoritative builder** + PS1 helpers; mixed Switching scripts (gauge, replay, tmp paper figures); `docs/decisions/` entry.

**Recent log (`git log --oneline -8`):** `72215df`, `5aa4538`, `76f6445`, `3663b8d`, `948f30a`, `b9f9b42`, `f7137a0`, `147856f`.

---

## Tests A–H (short)

| Test | Result |
|------|--------|
| **A** Current-state entrypoint | **PASS** — `reports/switching_corrected_canonical_current_state.md` is explicitly “start here”; minor TASK_002A pointer inconsistency (see contradictions). |
| **B** Canonical isolation | **PARTIAL** — `run_switching_canonical.m` carries a **visible header** (`NAMESPACE_ID` / `EVIDENCE_STATUS` / splitter pointer); `S_long` remains mixed; safe path is **source view** + column map. |
| **C** PTCDF quarantine | **PARTIAL** — index lists PT/CDF-related hazards; builder blocks CANON_GEN diagnostics; **not** a filesystem quarantine of `run_switching_canonical.m`. |
| **D** Corrected-old inputs | **PASS on contamination** per stored CHK009; **PARTIAL on git provenance** for `results/` source view and authoritative CSVs (ignored / untracked patterns). |
| **E** Formula/numeric | **PASS** CHK001–006; CHK007 N/A; CHK008–009 pass. |
| **F** Lineage / commits | **PARTIAL** — TASK_001/002 artifacts and drivers exist in `72215df`; authoritative numerical maps **not** tracked. |
| **G** Status contradictions | **PARTIAL** — artifact index refined QA rows stale vs refined_status; micro-pass resume flag stale; quarantine row vs canonical header; see CSV. |
| **H** Risk register | See `tables/switching_full_integrity_clarity_audit_risk_register.csv` — **BLOCKING** items R01–R02. |

---

## Canonical driver evidence (spot-check)

`Switching/analysis/run_switching_canonical.m` begins with an explicit mixed-producer banner:

```4:10:c:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m
% SWITCHING NAMESPACE / EVIDENCE WARNING (mixed producer — read column map before any claims)
% NAMESPACE_ID: CANON_GEN_SOURCE (S_percent) + EXPERIMENTAL_PTCDF_DIAGNOSTIC (S_model_pt_percent,CDF_pt,PT_pdf) + DIAGNOSTIC_MODE_ANALYSIS (residual_percent, phi outputs)
% EVIDENCE_STATUS: MIXED_OUTPUT_RUN — post-run splitter recommended; see tables/switching_canonical_output_view_contracts.csv
% BACKBONE_FORMULA: producer emits multiple backbone semantics by column; cite switching_canonical_S_long_column_namespace.md
% SVD_INPUT: diagnostic-mode phi path uses svd on residual fill — not authoritative corrected-old phi1
%
% SAFE_USE: canonical S_percent evidence + splitter source views; EXPERIMENTAL columns labeled diagnostic-only for CORRECTED manuscript path
```

---

## TASK_001 / TASK_002 / TASK_002A / TASK_002B

- **TASK_001:** Finite-grid / interpolation closure — tables under `tables/switching_corrected_old_finite_grid_*` referenced in current_state; report committed in `72215df`.
- **TASK_002 / TASK_002A:** Quality closure + diagnostic QA + **refined** visual QA — `tables/switching_corrected_old_quality_metrics_visual_QA_refined_status.csv` shows **TASK_002A_VISUAL_QA_REFINEMENT_ALREADY_COMPLETE=YES**; PNGs under `figures/switching/diagnostics/corrected_old_task002_quality_QA_refined/` included in `72215df`.
- **TASK_002B:** Backbone parity bridge — **not completed** per `tables/switching_missing_reconstruction_tasks_aligned.csv`; vocabulary distinguishes **TASK_002B_backbone_parity_bridge** from TASK_002A closure row.

---

## Required answers (15)

1. **Is corrected-old authoritative analysis numerically/logically valid (so far)?** **Yes**, within limits of exported artifacts: stored consistency checks **pass**; CHK007 remains not_applicable without aligned residual matrix export.

2. **Are all corrected-old inputs approved and uncontaminated?** **Policy-approved** per artifact index + CHK009; **git provenance** for `results/` source view and authoritative CSVs is **not** fully visible in git history without force-add — **PARTIAL** as “committed archive.”

3. **Is the canonical module clear enough?** **PARTIAL** — docs + script header + separation workflow are clear; **mixed output** still demands discipline.

4. **Is canonical `S_percent` safe as source input?** **Yes** when taken from **`switching_canonical_source_view.csv`** (or explicit CANON_GEN_SOURCE columns + run id), **not** by blind use of full `S_long`.

5. **Are canonical diagnostic / PTCDF products isolated?** **PARTIAL** — **post-run views** and namespace docs isolate; **`S_long`** file itself is mixed.

6. **Is experimental PTCDF fully quarantined?** **PARTIAL** — governance quarantine is **policy/index** level, not deletion or hard separation of columns inside the producer file.

7. **Anything still misleading enough to block continuation?** **Yes for careless agents** — untracked builder + untracked authoritative CSVs + mixed filenames; **no** automatic hard stop in tooling.

8. **Are all major artifacts indexed and visible?** **Indexed** in `tables/switching_corrected_old_authoritative_artifact_index.csv` with **known stale rows** for refined QA; **visibility in git** incomplete for authoritative numerical CSVs.

9. **Committed/tracked vs git hygiene risks?** **High risk** — many governance outputs and authoritative tables **ignored**; builder **untracked**; 35 modified canonical scripts **uncommitted**.

10. **Status gates mutually consistent?** **PARTIAL** — see contradictions CSV (artifact index vs refined completion; micro-pass resume flag).

11. **TASK_002A complete and not conflated with TASK_002B?** **Complete** per refined status; **alignment docs** still use legacy “TASK_002” vocabulary in places — **indexed**, not a numerical conflation.

12. **Publication figures still blocked?** **Yes** — `SAFE_TO_CREATE_PUBLICATION_FIGURES=PARTIAL` in builder status; program gates TASK_009–012.

13. **Remaining risks by severity?** See **`tables/switching_full_integrity_clarity_audit_risk_register.csv`** — **BLOCKING:** untracked builder; authoritative CSVs not in git.

14. **Safe to proceed to TASK_002B?** **PARTIAL** — do **not** conflate with TASK_002A; resolve **P0** provenance items for shared workflows; TASK_002B **not started** in missing-task table sense.

15. **Safe to write scientific interpretation?** **PARTIAL** — safe **only** under **CORRECTED_CANONICAL_OLD_ANALYSIS** namespace and cited CSVs; **not** safe to cite experimental PTCDF or mixed canonical diagnostics as primary evidence.

---

## Machine-readable verdict row

See **`tables/switching_full_integrity_clarity_audit_status.csv`** for all required keys (`FULL_INTEGRITY_CLARITY_AUDIT_COMPLETE=YES`, etc.).
