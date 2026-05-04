# Aging F7Y0 -- At-a-glance table polish (record)

**Task:** UX/readability polish **only** -- one-screen **At a glance: what not to misread** table added to the F7X7 user observable guide draft.  
**Anchor (read-only):** `d44f6ce` -- `Refine Aging F7X user observable guide`.  
**Hygiene:** No MATLAB, Python, replay, tau, or ratio runs; see [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

**Explicit:**

- This is a **readability** pass, not a new **naming contract** and not a **science** revalidation.
- **No** final naming contract was written.
- **No** `docs/` promotion was performed.
- **No** new physics claims were added.
- **No** F7X7 CSV annex tables were edited.

---

## Scope

- **Edited file:** `reports/aging/aging_F7X7_user_observable_guide_draft.md` (insert one section after **Purpose**, before **Quick start**).
- **Unchanged:** F7X2--F7X6 artifacts, F7X8 review pack, F7X9 edit log, router docs, all F7X7 `tables/aging/*.csv` files.
- **Not in scope:** Switching, Relaxation, Maintenance, INFRA, MT, or code.

---

## Source basis

- `reports/aging/aging_F7X7_user_observable_guide_draft.md` (pre-edit structure)
- `tables/aging/aging_F7X7_common_misreadings.csv` and `tables/aging/aging_F7X7_safe_use_matrix.csv` (consistency with existing warnings; no new claims)
- `reports/aging/aging_F7X9_editorial_edits_applied.md` and `tables/aging/aging_F7X9_status.csv` (context: F7X9 editorial pass already applied)

---

## Edit applied

Inserted **## At a glance: what not to misread** with an eight-row orientation table (Track A/B, FM fields, `tau_effective_seconds`, bridge IDs, ratios, vague residual vocabulary) plus two short sentences directing readers to treat "do not assume" rows as **still usable with context**.

---

## What was not changed

- All sections below the insertion (Quick start, glossary, safe-use legend, explicit disclaimers, warnings, annex pointers).
- **`NOT_CLAIMED`** semantics and safe-use matrix wording elsewhere.
- Draft status / not-final-naming-contract messaging.

---

## Verification

- One markdown file modified; no CSV edits.
- Table rows align with `aging_F7X7_common_misreadings.csv` themes (MR-001--MR-008 class topics) without expanding claims.
- No maintenance or cross-module paths touched.

---

## Docs promotion implication

When a future task copies the guide to `docs/`, the at-a-glance table should remain **on the first screen** for new readers. **Human review** still recommended before publication (`F7Y0_READY_FOR_DOCS_PROMOTION` in status CSV).

---

## Cross-module

No Switching, Relaxation, Maintenance/INFRA, or MT changes.
