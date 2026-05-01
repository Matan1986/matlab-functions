# Switching Phi1 wording / normalization documentation repair

**Task type:** Narrow documentation/registry repair only (no MATLAB, no figure regeneration, no numeric Phi table edits, no analysis logic changes).  
**HEAD at repair:** `ddbe212` (repo state when repair ran; prior Phi1 audit referenced `df90052`).

---

## What changed

| Deliverable | Action |
|-------------|--------|
| `docs/switching_phi1_terminology_contract.md` | **Created** — Phi1-specific terminology contract (manuscript vs diagnostic, blocked names, definitions, non-equivalences, normalization/sign caveats, rename policy). |
| `tables/switching_phi1_terminology_registry.csv` | **Created** — Machine-readable term rows with `allowed_status`, replacements, paths, caveats. |
| `tables/switching_phi1_source_of_truth_pointer.csv` | **Created** — Key/value pointers for scanners (manuscript artifact, diagnostic artifact, blocked/safe wording, future gate). |
| `tables/switching_phi1_wording_repair_status.csv` | **Created** — Verdict keys for this repair. |
| `docs/switching_analysis_map.md` | **Updated** — Subsection **Phi1 terminology (narrow contract)** with pointer + safe one-line on `switching_canonical_phi1.csv`. |
| `docs/switching_artifact_policy.md` | **Updated** — Short **Phi1 / decomposition vocabulary pointer** subsection. |
| `docs/switching_canonical_definition.md` | **Updated** — One **Phi1 terminology note** after deprecation banner (does not rewrite body). |

---

## What did not change

- **Numeric** `*phi1*.csv` tables (including `tables/switching_corrected_old_authoritative_phi1.csv` and any run-scoped `switching_canonical_phi1.csv`).
- **Analysis scripts** (no comment-only edits required; contract lives in docs/tables).
- **`reports/switching_legacy_canonical_separation_contract.md`** — not in the allowed edit list for this repair; **left unchanged**; Phi1 contract **references** it for `Phi3_diag` / legacy bridge rules.
- **Filenames** — `switching_canonical_phi1.csv` **not** renamed (explicit **NO**).

---

## Pre-repair infrastructure duplication check

### Existing infrastructure found

| Artifact | Role | Gap for this repair |
|----------|------|---------------------|
| `tables/switching_corrected_old_authoritative_artifact_index.csv` | **Artifact-centric** inventory: paths, `namespace_id`, allowed/forbidden use | Does not list **term-level** allowed_status for `Phi1_canon`, `canonical Phi1`, or the **filename hazard** of `switching_canonical_phi1.csv` in one scan-friendly table |
| `tables/switching_forbidden_conflations.csv` | Equivalence bans (e.g. `Phi1_old == Phi1_canon`) | Does not encode **diagnostic vs manuscript-aligned** replacement vocabulary or **normalization split** |
| `reports/switching_corrected_canonical_current_state.md` | Global Switching state | Already states diagnostic phi1 class; **not** a dedicated Phi1 glossary |
| `docs/switching_analysis_map.md` | Broad namespace map | Phi1 detail spread across CANON_GEN / CORRECTED / collapse sections — **hard for grep-only scans** |
| `reports/switching_legacy_canonical_separation_contract.md` | Legacy vs `*_canon` conceptual rules | Lacks **switching_canonical_phi1.csv** filename caveat and **manuscript Phi1** path lock |
| `tables/switching_allowed_comparison_operations.csv` | **Not present** in repo (see audit) | N/A |

### Decisions

| Decision | Value | Justification |
|----------|--------|-----------------|
| `EXISTING_INFRASTRUCTURE_FOR_PHI1_TERMINOLOGY_FOUND` | **PARTIAL** | Strong artifact index + conflation table, but **no single term-centric Phi1 home** |
| `REUSE_EXISTING_INFRASTRUCTURE` | **PARTIAL** | **Minimal pointers** added to **allowed** docs; **no rows edited** in `switching_corrected_old_authoritative_artifact_index.csv` (would risk silent supersession) |
| `NEW_TERMINOLOGY_CONTRACT_NEEDED` | **YES** | Dedicated **`docs/switching_phi1_terminology_contract.md`** avoids bloating `switching_analysis_map.md` |
| `NEW_REGISTRY_NEEDED` | **YES** | **`switching_phi1_terminology_registry.csv`** is **term-primary**; distinct from artifact-index rows |
| `NEW_POINTER_TABLE_NEEDED` | **YES** | **`switching_phi1_source_of_truth_pointer.csv`** gives **one-row answers** for automation |

### How duplicate governance was avoided

- New files **explicitly declare** they **supplement** the artifact index and current-state entry; they **do not** replace **`tables/switching_corrected_old_authoritative_artifact_index.csv`** or **`reports/switching_corrected_canonical_current_state.md`**.
- **No** parallel “artifact_index v2” — **no** duplicate rows for the same CSV paths with conflicting `allowed_use`.
- **No** edits to **`tables/switching_forbidden_conflations.csv`** — FC rows remain authoritative; Phi1 contract **aligns** with FC1 language.

---

## Exact safe wording (recommended)

- **Manuscript-aligned Phi1 shape:** **`Phi1_corrected_old`** in **`tables/switching_corrected_old_authoritative_phi1.csv`**, namespace **`CORRECTED_CANONICAL_OLD_ANALYSIS`**, cite **`tables/switching_corrected_old_authoritative_artifact_index.csv`** row `corrected_old_authoritative_phi1`.
- **Diagnostic Phi1-like output (canonical run):** Use the **required safe sentence** in **`docs/switching_phi1_terminology_contract.md` §3.2 (verbatim block).**

## Exact blocked wording

- **`Phi1_canon`**, **`canonical Phi1`** (until a future certification gate).
- Treating **`switching_canonical_phi1.csv`** as the **manuscript-aligned** Phi1 shape or as **`Phi1_canon`**.
- Equating **residual-after-mode1**, **collapse defect**, or **C02/C02B primary collapse** artifacts with **Phi1**.

---

## Source-of-truth pointer (summary)

| Question | Answer |
|----------|--------|
| Manuscript-aligned Phi1 shape | `tables/switching_corrected_old_authoritative_phi1.csv` |
| Diagnostic Phi1-like output | `switching_canonical_phi1.csv` under `results/switching/runs/<run_id>/tables/` |
| Rename `switching_canonical_phi1.csv` now? | **NO** |
| Document misleading filename? | **YES** (contract + registry + pointers) |
| Later alias/deprecation review? | **YES** (compatibility-safe follow-on) |

Full table: **`tables/switching_phi1_source_of_truth_pointer.csv`**.

---

## Why `switching_canonical_phi1.csv` was not renamed

Producer and historical runs embed the filename; renaming would break consumers and run reproducibility without a **compatibility migration**. This repair **documents** diagnostic meaning and risk instead.

---

## Normalization / sign caveat (documentation only)

Single locked prose norm across producer + all consumers **does not exist**. **`docs/switching_phi1_terminology_contract.md` §6** summarizes **max-abs producer** vs **L2 consumer** renormalization and points to **script-level** truth for comparisons.

---

## Future gate before `Phi1_canon`

Publish a **certification record** naming: **exact CSV (or artifact id)**, **norm type**, **sign rule**, **allowed usage** (manuscript vs diagnostic). Until then **`SAFE_TO_USE_PHI1_CANON=NO`** per status CSV.

---

## Commit recommendation (exact paths)

If committing documentation-only repair:

- `docs/switching_phi1_terminology_contract.md`
- `tables/switching_phi1_terminology_registry.csv`
- `tables/switching_phi1_source_of_truth_pointer.csv`
- `tables/switching_phi1_wording_repair_status.csv`
- `reports/switching_phi1_wording_repair.md`
- `docs/switching_analysis_map.md`
- `docs/switching_artifact_policy.md`
- `docs/switching_canonical_definition.md`

**Note:** `.gitignore` may hide some `tables/**` and `reports/**` paths until **`git add -f`** or ignore-rule updates — verify with `git check-ignore -v <path>` before commit.

---

## Status verdicts

See **`tables/switching_phi1_wording_repair_status.csv`** (includes `PHI1_WORDING_REPAIR_COMPLETE`, `NO_DUPLICATE_GOVERNANCE_LAYER_CREATED`, `SAFE_TO_REVIEW_FOR_COMMIT`, `SAFE_TO_USE_MANUSCRIPT_ALIGNED_PHI1`, etc.).
