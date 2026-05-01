# Canonical AX organization plan — pre-commit review

**Review mode:** Read-only verification of the seven listed artifacts; **no edits** to those artifacts in this step. **Review outputs:** this file + `tables/cross_module_switching_relaxation_AX_organization_review_status.csv`.

**Opening checks:** `git diff --cached --name-only` was **empty** (safe to proceed). `git log --oneline -8` and `git status --short` noted unrelated backlog as expected.

---

## Checklist results

| # | Requirement | Result |
|---|-------------|--------|
| 1 | Relaxation-folder AX using `X_eff` / `X_eff_nonunique` is **cross-module**, not Relaxation-only | **PASS** — `reports/cross_module_switching_relaxation_AX_organization_plan.md` §A (lines 13–13, 78–80); `docs/cross_module_switching_relaxation_AX_index_draft.md` opening rule. |
| 2 | No physical file moves now | **PASS** — Plan §B: **Moves: None now**; status `PHYSICAL_FILE_MOVE_RECOMMENDED_NOW=NO`. |
| 3 | Recommend flat cross-module index | **PASS** — Option 1: `docs/cross_module_switching_relaxation_AX_index.md` + `tables/..._artifact_index.csv`; draft exists. |
| 4 | Rules distinguish RELAXATION_ONLY / SWITCHING_ONLY / CROSS_MODULE / GOVERNANCE_ONLY | **PASS with minor note** — `classification_rules.csv` defines **CROSS_MODULE** (CM1), folder trap (CM2), and legacy-X wording (CM3–CM5). **`SWITCHING_ONLY` and `GOVERNANCE_ONLY` are not separate rule rows**; `inventory_plan.csv` uses `RELAXATION_ONLY`, `SUPPORTING_CROSS_MODULE_TOOLING`, etc. Acceptable for commit; optional follow-up: add two explicit rule rows for symmetry. |
| 5 | Conservative claim boundary | **PASS** — `claim_boundary_plan.csv`: bridge **PARTIAL**, power-law main **NO**, supplement **PARTIAL**, universal exponent **NO**. Matches report §D. |
| 6 | Completion order | **PASS** — `completion_order.csv`: ORG_INDEX → ARCH_CANON_X → CANON_AX_SUMMARY → SCIENCE_GAPS → CLAIM_SAFETY_PASS. Matches report §E. |
| 7 | No final physics beyond evidence | **PASS** — Plan is survey + governance + conservative defaults; no new fitted claims. |
| 8 | No `X_canon` allowed | **PASS** — CM3: do not use **unless** explicit Switching contract allows (not wholesale allowance). |
| 9 | `get_canonical_X` / `canonical_X` not treated as safe | **PASS** — CM4: **legacy/misleading until audit**. |
| 10 | Status CSV required keys | **PASS** — All keys listed in the review prompt are present in `cross_module_switching_relaxation_AX_organization_status.csv`. |

---

## Verdict

- **Blocking issues:** **NO**
- **Safe to commit** these seven artifacts: **YES**
- **Recommended edits before commit:** **Optional only** — consider adding explicit **`SWITCHING_ONLY`** and **`GOVERNANCE_ONLY`** rows to `classification_rules.csv` for parity with the four-way taxonomy (non-blocking).

---

## Git state (review session)

- **Staged:** **No** (review agent did not stage).
- **Committed / pushed:** **No** (review agent did not commit or push).
