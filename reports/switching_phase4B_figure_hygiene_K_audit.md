# SW-FIG-HYGIENE-K — Phase 4B Switching figure hygiene audit

**Audit ID:** `switching_phase4B_figure_hygiene_K`  
**Date:** 2026-05-03  
**Scope:** Switching only — deleted tracked files matching `figures/switching/phase4B_*` as reported by `git status`.  
**Mode:** Audit only — no restore, regenerate, delete, stage, commit, or push; no MATLAB/Python/Node.

**Preflight:** `git diff --cached --name-only` was **empty**. Working tree issues outside this scope (Relaxation, Aging, CV07 maintenance bundles, paper figure scripts) are **not** analyzed except where they reference these paths.

---

## 1. Deleted paths found (from `git status`)

| Path | Extension | Role (from linked reports) |
|------|-----------|----------------------------|
| `figures/switching/phase4B_C01_X_like_panel_orientation_lock.png` | PNG | Phase 4B **C01** QA/inspection figure — orientation/range lock for corrected-old X-like panel slice (`reports/switching_phase4B_C01_X_like_panel_orientation_lock.md`). Report states **manuscript claims not allowed in this slice**; figure is **inspection/QA only**. |
| `figures/switching/phase4B_C02_collapse_like_panel_range_lock.png` | PNG | Phase 4B **C02** QA figure — collapse-like panel range lock (`reports/switching_phase4B_C02_collapse_like_panel_range_lock.md`). **QA only**; not broad replay. |
| `figures/switching/phase4B_C02_collapse_like_panel_range_lock.fig` | FIG | Same C02 run — **interactive inspection only** per report. |

**Count:** **3** deleted tracked figures (2 PNG, 1 FIG).

---

## 2. Disk and git posture

| Path | exists_on_disk | tracked_in_index_history | deleted_in_worktree |
|------|----------------|---------------------------|---------------------|
| `phase4B_C01_...png` | NO | YES (was committed) | YES (`D` in status) |
| `phase4B_C02_...png` | NO | YES | YES |
| `phase4B_C02_...fig` | NO | YES | YES |

---

## 3. Likely producers and related artifacts

| Figure | Producer script | Related report | Related tables (non-exhaustive) |
|--------|-----------------|---------------|-----------------------------------|
| C01 PNG | `Switching/analysis/run_switching_phase4B_C01_X_like_panel_orientation_lock.m` | `reports/switching_phase4B_C01_X_like_panel_orientation_lock.md` | `tables/switching_phase4B_C01_*` |
| C02 PNG/FIG | `Switching/analysis/run_switching_phase4B_C02_collapse_like_panel_range_lock.m` | `reports/switching_phase4B_C02_collapse_like_panel_range_lock.md` | `tables/switching_phase4B_C02_*` |

**Phase 4B C02B:** `Switching/analysis/run_switching_phase4B_C02B_primary_collapse_variant_audit.m` writes under **`figures/switching/canonical/phase4B_C02B_*`** — **different basename/prefix** than the deleted C02 collapse-like panel files. C02B evidence chain is **not** the same filesystem trio as this audit.

**Registry:** `Switching/analysis/run_switching_canonical_state_audit.m` lists the C01/C02/C02B runners together as part of collapse/QA machinery visibility.

---

## 4. Classification (stale vs canonical vs publication)

| Asset class | Assessment |
|-------------|------------|
| **Manuscript / CORRECTED_CANONICAL_OLD_ANALYSIS backbone** | These three files are **not** authoritative manuscript numeric tables; linked reports label outputs **QA / inspection only** and disallow manuscript claims from these slices. |
| **Publication candidate (paper)** | **No** — reports explicitly constrain manuscript posture (C01: manuscript claim status not allowed in slice; C02: narrow QA). They are **not** interchangeable with `results/switching/figures/canonical_paper/` or TASK_009–012 publication authorization targets. |
| **Governance / Phase 4B audit artifact** | **Yes** — committed binaries expected for **clone-only reproduction** of Phase 4B QA visuals and for audits that assume figures exist alongside reports. |
| **Legacy noise** | **No** — paths are tied to named Phase 4B runners and reports; not orphan filenames. |

---

## 5. Reader hub and synthesis alignment

- **`docs/switching_canonical_reader_hub.md`** does **not** list these PNG/FIG paths in the **read-first** chain. It **does** recommend (next-work item) **restore or regenerate** deleted tracked `figures/switching/phase4B_*` for **clone-only visual fidelity** — category-level hygiene, not a claim that these are manuscript source-of-truth files.
- **`reports/switching_canonical_system_synthesis_E_state_and_plan.md`** / **`tables/switching_canonical_system_synthesis_E_confusions_and_gaps.csv`**: deleted trio is **HIGH** severity for **health/lineage** — breaks **clone-only visual reproduction** and workflows expecting committed binaries; resolution = restore from last good commit or regenerate via locked scripts.
- **`tables/switching_canonical_system_synthesis_E_action_plan.csv`**: P0 housekeeping row **Restore_or_regenerate_deleted_tracked_phase4B_figures_under_figures_switching** — consistent with this audit.

---

## 6. Blocker verdicts (narrow definitions)

| Question | Verdict | Rationale |
|----------|---------|-----------|
| **Blocks manuscript narrative authority from CSV/index alone?** | **NO** | Corrected-old authoritative tables and builder status do not require these PNGs to exist for **numeric** manuscript routing. |
| **Blocks Phase 4B C02B numeric/report chain by absence of these three files?** | **NO** | C02B outputs use **other** paths under `figures/switching/canonical/phase4B_C02B_*`. |
| **Impairs repo/git fidelity and Phase 4B QA visual reproduction?** | **YES** | Matches synthesis and Phase 4B reports that reference these paths as written outputs. |
| **Same as “publication gate PARTIAL” / paper figure hazards?** | **Not equivalent** | Publication authorization issues (quarantine, TASK_009–012) are a **separate** risk class; these deletions are **operational git/visual fidelity** for Phase 4B QA figures. |

---

## 7. Recommendations (no execution in this task)

| Action | Recommended |
|--------|-------------|
| **Treat as safe dirty-tree noise forever** | **NO** — tracked deletions should be resolved intentionally (restore or regenerate + commit, or explicit repo decision to remove from tracking with doc updates). |
| **Restore from git history** | **YES** as lowest-friction recovery if binaries must match last committed versions. |
| **Regenerate via locked scripts** | **YES** — preferred when inputs/tables still validate and regeneration is the governance-approved path (per synthesis action plan). |
| **Separate human review** | **YES** — maintenance figure-governance docs already flag these paths as **manual review** / exclude from blind bundles (`reports/maintenance/repo_figure_governance_prestage_01.md`, related CSVs). |

---

## 8. Deliverables

| File | Purpose |
|------|---------|
| `tables/switching_phase4B_figure_hygiene_K_deleted_figures.csv` | Per-path classification |
| `tables/switching_phase4B_figure_hygiene_K_reference_hits.csv` | Repo references to these paths |
| `tables/switching_phase4B_figure_hygiene_K_status.csv` | Task status flags |

---

END
