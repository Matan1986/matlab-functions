# Aging F7Y1 -- Docs promotion draft (record)

**Task:** Controlled promotion of the Aging user observable guide into `docs/` as **draft documentation** only.  
**Anchor (read-only):** `097088c` -- `Polish Aging F7X user observable guide`.  
**Hygiene:** No MATLAB, Python, replay, tau, ratio; see [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

**Explicit:**

- Docs promotion is **draft-only** -- not a **final naming contract**, not a physics certification.
- **No** final naming contract was written by this step.
- **No** annex CSV tables were duplicated into `docs/` -- canonical annex paths remain **`tables/aging/`**.
- **No** new physics claims were added beyond fidelity copy from the source guide.
- **F7X5 blockers** remain **inherited** and disclosed in the guide body (**Open caveats before final naming contract**).
- **No** Switching, Relaxation, Maintenance/INFRA, MT, or unrelated repo paths were touched.

---

## Scope

- **Created:** `docs/aging_observable_user_guide_draft.md` from **`reports/aging/aging_F7X7_user_observable_guide_draft.md`** (adapt header only).
- **Not edited:** `reports/aging/aging_F7X7_user_observable_guide_draft.md`, all F7X2--F7X6, F7X8, F7X9, F7Y0 artifacts, router docs, F7X7 `tables/aging/*.csv` annex files.

---

## Source basis

- `reports/aging/aging_F7X7_user_observable_guide_draft.md` (content at repo state including `097088c` polished guide and at-a-glance table).
- `tables/aging/aging_F7X7_*.csv` -- referenced from the doc but **not** copied into `docs/`.

---

## Docs file created

- **Output:** `docs/aging_observable_user_guide_draft.md`
- **Top matter:** Main H1 `Aging observable user guide (draft)` plus blockquote banner identifying source and caveats.
- **Link fix:** `repo_execution_rules.md` (sibling under `docs/`) replaces `../../docs/repo_execution_rules.md` from the `reports/aging/` path.
- **Body:** Content aligned with source at promotion time; first-screen sections (At a glance, Quick start, Short glossary, How to read the safe-use matrix) and all warning lists preserved.

---

## What was preserved

- **At a glance: what not to misread** table and follow-up sentences.
- **Quick start**, **glossary**, **safe-use matrix** legend and **NOT_CLAIMED** / false distinction.
- **What this guide is / is not** and **Explicit** bullets: not final naming contract, no renames, no physical validity claim, Track A/B, bridge, `tau_effective_seconds`, `FM_abs`, background/baseline/residual.
- **Open caveats** / F7X5 blocker inheritance.
- **Annex** references as repository paths under `tables/aging/`.

---

## What was not promoted

- **No** copy of `tables/aging/*.csv` into `docs/`.
- **No** change to governance router documents in `docs/` beyond this new file (router docs explicitly out of scope).

---

## Remaining caveats

- F7X5 open blockers (B-001--B-006 class) stay open until resolved elsewhere; the guide text still says so.
- Draft status and **not** final naming contract remain the governing frame.

---

## Verification

- [x] Single new file under `docs/`.
- [x] Source `reports/aging/aging_F7X7_user_observable_guide_draft.md` unmodified.
- [x] No `git add` / commit in this task.

---

## Next safe step

**Optional:** Archive commit including `docs/aging_observable_user_guide_draft.md` and this F7Y1 record when ready (`F7Y1_READY_FOR_ARCHIVE_COMMIT` in status CSV). Link the draft from a docs index in a **separate** small task if desired.

---

## Cross-module

No maintenance, INFRA, Switching, Relaxation, or MT file changes.
