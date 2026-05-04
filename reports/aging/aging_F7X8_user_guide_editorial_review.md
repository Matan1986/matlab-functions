# Aging F7X8 -- User observable guide editorial review (draft)

**Review type:** Editorial and readability assessment only -- **not** a new contract, **not** a scientific revalidation, **not** docs promotion.  
**Anchors (read-only):** `36d817e`, `e59244c`, `4fe11ad`.  
**Artifacts reviewed:** `reports/aging/aging_F7X7_user_observable_guide_draft.md` and `tables/aging/aging_F7X7_*.csv`.  
**Supporting context (read-only):** F7X5 open blockers table; F7X6 end-user checklist cited where relevant.  
**Hygiene:** No MATLAB/Python/replay/tau/ratio; see [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

**Explicit:**

- This is an **editorial review**, not a new definition or naming contract.
- **No final naming contract** is written here.
- **No files are promoted** to `docs/` by this task.
- **No new physics claims** are introduced.
- **F7X5 blockers B-001 through B-006 remain** unless resolved in separate work; this review does not close them.

---

## Scope

Assess whether a **future user** who did **not** follow the F7X2--F7X6 process can:

- Orient to the main Aging observable families,
- Understand warnings and layering (decomposition vs tau vs ratio vs bridge),
- Know when **not** to compare or substitute quantities,
- Use annex CSVs without drowning in governance jargon.

---

## Non-goals

- Rewriting F7X7 in this report (recommendations only).
- Resolving contract disputes or re-auditing code paths.
- Editing F7X2--F7X7 artifacts, router docs, or cross-module trees.

---

## Review basis

Primary: full text of `aging_F7X7_user_observable_guide_draft.md` and annex tables:

- `aging_F7X7_user_observable_cheatsheet.csv`
- `aging_F7X7_common_misreadings.csv`
- `aging_F7X7_minimal_metadata_checklist.csv`
- `aging_F7X7_safe_use_matrix.csv`
- `aging_F7X7_status.csv`

Secondary: `tables/aging/aging_F7X5_open_blockers_before_naming_contract.csv` for inherited caveats disclosure.

---

## Executive verdict

The F7X7 guide is a **strong draft**: concise prose (~under 200 lines for the main markdown), a **numbered quick map** of nine families, and **sharp warnings** on Track A/B, `FM_abs`, `tau_effective_seconds`, bridge IDs, and ambiguous vocabulary. The **cheatsheet** and **misreadings** tables are usable without reading prior F7X volumes.

**Gap:** A **dedicated quick-start** (first-screen checklist) and a **plain-language decode** of matrix tokens (`WITH_QUALIFIER`, `WITH_METADATA`, `NOT_CLAIMED`) are **not** yet in the main guide body; new readers may bounce to CSVs or feel that repo jargon (`pauseRuns`, `cfg.agingMetricMode`) appeared without a one-line gloss.

**Promotion stance:** **Ready for docs promotion only after light structural edits** (see Final recommendation). Inherited F7X5 blockers remain disclosure obligations, not reasons to block a **user guide** if caveats stay visible.

---

## Readability assessment

**Strengths:** Short sections; repeated “do not assume” pattern; explicit bullets on what the guide is not.

**Friction:** Several sentences assume familiarity with MATLAB naming (`pauseRuns`, `stage4`, script basenames). A newcomer can still follow **if** they read the Quick map and Track A/B sections; **without** those, column names alone remain opaque (which is honest but steep).

**Score (holistic):** Clear for a motivated technical reader; **partial** for a casual reader until quick-start and gloss are added.

---

## User onboarding assessment

**Works:** Numbered family list + “three layers” framing (headline / stage / metadata).

**Missing:** A **first-page** “Start here” box (5 bullets) that tells the user exactly what to read in order and when to open which CSV.

---

## Quick-start assessment

The guide contains a **Quick map** section but **not** a procedural quick-start (“Step 1: identify family from cheatsheet row...”). The F7X7 next-safe-step already pointed at editorial review -- this review confirms **quick-start prose is the highest-impact add**.

---

## Terminology clarity assessment

**Clear:** Track A/B as lane labels; bridge/export; tau downstream; ratio downstream.

**Needs gloss once:** `pauseRuns` (MATLAB structure holding run outputs), `cfg.agingMetricMode` (configuration switch -- including why `fit` here is **not** stage 5 Gaussian fit).

---

## Warning clarity assessment

Warnings are **specific** and **not** paralyzing: they say what to pair with labels and what **not** to infer. The tone is appropriately cautious without forbidding all use.

---

## Examples assessment

**Strong examples** live in the **cheatsheet** (`example_good_label` / `example_bad_label`). The **main markdown** could mirror **one** compact row (for example FM_abs vs FM_signed) so readers do not need to open CSV for the core FM lesson.

---

## Metadata burden assessment

The checklist CSV is thorough; for end users it may feel heavy. **Mitigation already present:** guide points to checklist rather than pasting every row. **Recommendation:** In a future edit, add **one** “minimum panel” example (three lines of fake metadata) showing “good enough for tau row.”

---

## Safe-use / physical-claim separation assessment

`aging_F7X7_safe_use_matrix.csv` correctly uses **`NOT_CLAIMED`** for `allowed_for_physical_interpretation`, separating contract honesty from display/tau-input gates. **Issue:** casual readers may not open the CSV; **decode table** in prose recommended.

---

## Missing or confusing sections

| Gap | Severity |
|-----|----------|
| No explicit quick-start procedure | Medium |
| Matrix token legend not in main guide | Medium |
| No inline mini-example table for FM_abs / tau | Low |
| Glossary for pauseRuns / cfg flags | Low |

---

## Recommended edits before docs promotion

1. Add **“Quick start (first 5 minutes)”** subsection immediately after Purpose: ordered bullets + “open cheatsheet row for your family.”
2. Add **“How to read the safe-use matrix”** paragraph: define WITH_QUALIFIER, WITH_METADATA, NOT_CLAIMED, NA in plain English.
3. Add **mini glossary** (5--8 lines): pauseRuns, stage4/stage5/stage6, consolidation CSV role.
4. Optionally embed **one** cheatsheet-style good/bad pair for **`FM_abs`** in the Sign section.

All are **editorial**; **no** contract table changes required for usefulness.

---

## Minimal docs-promotion candidate structure

When promoting (future task, not performed here), suggested `docs/` shape:

1. **Single landing page:** user guide markdown body + link to `tables/aging/` annex CSVs.
2. **Sidebar or appendix:** misreadings FAQ + minimal metadata checklist.
3. **Explicit banner:** “Inherited caveats: F7X5 blockers B-001--B-006 remain open for full naming closure.”

---

## Final recommendation

**Do not** promote verbatim to `docs/` without adding quick-start + matrix decode + short glossary. After those **small** edits, the package is **suitable** for docs promotion as a **draft user guide** with inherited blocker disclosure. **Honest rating:** **YES_WITH_EDITS** for docs readiness (see `tables/aging/aging_F7X8_status.csv`).

---

## Cross-module

No Switching, Relaxation, or MT scope in this review artifact.
