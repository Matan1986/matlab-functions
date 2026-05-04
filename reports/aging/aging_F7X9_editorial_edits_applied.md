# Aging F7X9 -- F7X8 editorial edits applied to F7X7 user guide (record)

**Task type:** Apply F7X8 **E-001**, **E-002**, and **E-004** to the F7X7 user-facing guide draft. **Not** a new contract, **not** analysis, **not** `docs/` promotion.  
**Hygiene:** No MATLAB/Python/replay; see [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

---

## Scope

- **Single file edited:** `reports/aging/aging_F7X7_user_observable_guide_draft.md`
- **F7X8 review artifacts** were **not** modified (this report is additive only).
- **F7X7 CSV annexes** were **not** modified (legend lives in prose per F7X8 E-004 intent).

---

## Source review basis

- `tables/aging/aging_F7X8_recommended_edits.csv` (E-001, E-002, E-004)
- `reports/aging/aging_F7X8_user_guide_editorial_review.md` and `tables/aging/aging_F7X8_status.csv` (readiness **YES_WITH_EDITS**)

---

## Edits applied

1. **E-001 -- Quick start (first ~5 minutes)** -- Inserted after **Purpose**: ordered steps covering cheatsheet, object kind, source/stage/branch, sign/magnitude, tau/ratio metadata, safe-use matrix, common misreadings.
2. **E-002 -- Short glossary** -- Inserted **Short glossary** with plain-language entries for: `pauseRuns`, `DeltaM`, `dM`, `DeltaM_signed`, `stage4`, `stage5`, `stage6`, `cfg.agingMetricMode`, `Track A`, `Track B`, `bridge/export`, `tau output`, `ratio output`, and matrix tokens `NOT_CLAIMED`, `WITH_METADATA`, `WITH_QUALIFIER` (cautious wording).
3. **E-004 -- Safe-use legend** -- Inserted **How to read the safe-use matrix** with definitions for `YES`, `NO`, `WITH_QUALIFIER`, `WITH_METADATA`, `NOT_CLAIMED`, `NA`, and family-style gates `BRIDGE_ONLY`, `DOWNSTREAM_ONLY`, `DISPLAY_ONLY`, `DIAGNOSTIC_ONLY`, including: **`NOT_CLAIMED` is not "false"**; contracts do not certify physical interpretation; **`WITH_METADATA`** and **`WITH_QUALIFIER`** rules as required.

**Cross-reference:** **What is safe to use for what** now points readers to the legend for **`NOT_CLAIMED`** / **`WITH_METADATA`**.

**Preserved:** All prior **Explicit** bullets under **What this guide is / is not** (final naming, no renames, no physical validity claim, Track A/B, bridge, `tau_effective_seconds`, `FM_abs`, background/baseline/residual).

---

## Edits intentionally not applied (out of F7X9 scope)

From F7X8 recommended list, **not** part of this task: **E-003** (consolidated do-not-compare list), **E-005** (inline FM example pair), **E-006** (fake tau panel), **E-007** (docs promotion banner -- no `docs/` edit), **E-008** (CSV change -- unnecessary; legend in prose).

---

## Verification against F7X8 top recommendations

| F7X8 item | Status |
|-----------|--------|
| Quick-start procedure for naive readers | **Done** (E-001) |
| Glossary for repo jargon | **Done** (E-002) |
| Prose legend for safe-use matrix | **Done** (E-004) |

---

## Remaining caveats

- F7X5 open blockers **B-001--B-006** remain (inherited; not closed by this edit).
- Guide remains a **draft**; F7X7 CSVs unchanged -- users still open annex files for full rows.
- **E-003** style “do not compare” consolidation may still help; optional follow-up.

---

## Docs promotion recommendation

Suitable for a **future** `docs/` copy **after** one **human skim** (`YES_WITH_REVIEW` in status): verify anchors, link behavior, and whether a short “do not compare” bullet list (E-003) is desired before publication.

---

## Cross-module

No Switching, Relaxation, or MT changes.
