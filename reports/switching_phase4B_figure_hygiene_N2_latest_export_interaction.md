# SW-FIG-HYGIENE-N2 — Commit `3295c26` vs deleted Phase 4B QA figures

**Audit ID:** `switching_phase4B_figure_hygiene_N2`  
**Date:** 2026-05-04  
**Scope:** Switching only — inspect commit `3295c26` (`Add canonical paper figure export outputs`) vs three deleted tracked `figures/switching/phase4B_*` QA figures.  
**Mode:** Audit only — no stage, commit, push, restore, regenerate, or toolchain runs (see status CSV).

---

## Preflight

| Check | Result |
|-------|--------|
| `git diff --cached --name-only` | **Empty** — proceed |
| `HEAD` | `3295c26` |

---

## 1. What `3295c26` changed (Switching-relevant)

All paths from `git show --name-status 3295c26`:

| Path | Change |
|------|--------|
| `reports/switching_canonical_paper_figures.md` | Modified |
| `results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.pdf` | Modified |
| `results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.png` | Modified |
| `results/switching/figures/canonical_paper/switching_supp_Xeff_components.pdf` | Modified |
| `results/switching/figures/canonical_paper/switching_supp_Xeff_components.png` | Modified |
| `scripts/run_switching_canonical_paper_figures.ps1` | Modified |
| `tables/switching_canonical_paper_figures_manifest.csv` | Modified |

**Note:** This commit’s `--name-status` lists **no** files under `figures/switching/phase4B_*` and **no** additions under `figures/switching/` for Phase 4B.

---

## 2. Canonical paper export outputs (exact paths)

Binary exports updated in `3295c26` (repository-relative):

- `results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.png`
- `results/switching/figures/canonical_paper/switching_main_candidate_map_cuts_collapse.pdf`
- `results/switching/figures/canonical_paper/switching_supp_Xeff_components.png`
- `results/switching/figures/canonical_paper/switching_supp_Xeff_components.pdf`

Related documentation and registers modified in the same commit:

- `reports/switching_canonical_paper_figures.md`
- `tables/switching_canonical_paper_figures_manifest.csv`
- `scripts/run_switching_canonical_paper_figures.ps1`

The reader-facing report `reports/switching_canonical_paper_figures.md` also lists paired `.fig` paths under `results/switching/figures/canonical_paper/`; those `.fig` paths are **not** present in `3295c26`’s name-status (only PNG/PDF binaries were modified in that commit’s file list).

---

## 3. Deleted Phase 4B QA figures (unchanged by `3295c26`)

| Path |
|------|
| `figures/switching/phase4B_C01_X_like_panel_orientation_lock.png` |
| `figures/switching/phase4B_C02_collapse_like_panel_range_lock.png` |
| `figures/switching/phase4B_C02_collapse_like_panel_range_lock.fig` |

---

## 4. Relationship classification (single label)

**`DOES_NOT_AFFECT_DELETED_QA_FIGURES`**

**Rationale:** `3295c26` only touches **canonical paper candidate** outputs under `results/switching/figures/canonical_paper/` plus the paper manifest and PS1. It does **not** modify, restore, delete, or rename the Phase 4B QA paths under `figures/switching/phase4B_*`. It therefore **does not supersede** those QA artifacts as outputs (different directories, different artifact class per SW-FIG-HYGIENE-K: publication-style candidates vs Phase 4B governance/QA inspection figures).

**Not** `SUPERSEDES_DELETED_QA_FIGURES`: K audit and reader hub distinguish publication-candidate / `canonical_paper` routing from Phase 4B QA inspection figures — they are not treated as interchangeable replacements.

**Not** `BYPASSES_DELETED_QA_FIGURES` as the primary label: “bypass” suggests the new commit resolves or reroutes the QA debt; operationally the paper pipeline is orthogonal, but the git debt for the three deleted tracked files **remains**.

**Not** `UNCLEAR_REQUIRES_SEPARATE_REVIEW` for the narrow commit-vs-path comparison; separate review for **figure governance** remains appropriate per K audit (see below).

---

## 5. Alignment with `docs/switching_canonical_reader_hub.md`

The hub’s recommended hygiene item is **restore or regenerate** deleted tracked `figures/switching/phase4B_*` for **clone-only visual fidelity**. Commit `3295c26` advances **canonical paper figure exports** — a **different** workstream from Phase 4B QA PNG/FIG under `figures/switching/`. It does **not** satisfy the Phase 4B deletion gap by itself.

---

## 6. K audit (SW-FIG-HYGIENE-K) — does recommendation change?

**No material change to K audit’s substance.**

- K audit: trio is **governance/QA inspection**, **not** manuscript backbone, **not** interchangeable with `results/switching/figures/canonical_paper/` publication routing.
- `3295c26` **confirms** that parallel track (canonical paper exports) without addressing the Phase 4B paths.

**Updated stance for the three deleted figures:** Still **not** `SUPERSEDED_BY_CANONICAL_PAPER_EXPORTS`. Preferred resolution remains **intentional** `RESTORE_FROM_GIT` or `REGENERATE_FROM_LOCKED_SCRIPT` (or a deliberate `DELETE_TRACKED_FIGURES_IN_DELIBERATE_COMMIT` with documentation if governance chooses removal), not implicit abandonment.

---

## 7. Next safe step (audit-only)

Record N2 deliverables; plan a **deliberate** maintenance action for the three paths (restore/regenerate/delete-with-docs) **without** conflating it with canonical paper export work.

---

END
