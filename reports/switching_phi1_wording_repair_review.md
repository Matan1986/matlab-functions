# Switching Phi1 wording repair — pre-commit review

**Review type:** Narrow static review of listed documentation/registry changes only. **No file edits** to the repair deliverables (except this report + status CSV as required outputs). **No MATLAB, no figures, no stage, no commit, no push.**

**HEAD at review:** `ddbe212` (matches opening `git log`).

**Staged index at review start:** **Empty** (`git diff --cached --name-only` produced no output).

---

## Files reviewed (8 paths)

1. `docs/switching_phi1_terminology_contract.md`  
2. `tables/switching_phi1_terminology_registry.csv`  
3. `tables/switching_phi1_source_of_truth_pointer.csv`  
4. `tables/switching_phi1_wording_repair_status.csv`  
5. `reports/switching_phi1_wording_repair.md`  
6. `docs/switching_analysis_map.md` (delta: Phi1 subsection)  
7. `docs/switching_artifact_policy.md` (delta: pointer subsection)  
8. `docs/switching_canonical_definition.md` (delta: one banner note)

---

## Checklist

| # | Check | Result |
|---|--------|--------|
| 1 | No numeric/scientific claims changed in listed files | **PASS** — Edits to the three existing docs are **+10 lines** of pointers/warnings only (`git diff --stat`). New content is **governance vocabulary**; contract §6 is **documentation-only** pipeline caveats (max-abs / L2 / sign), aligned with the prior audit, not new fitted results. **No** numeric `*phi1*.csv` files were modified. |
| 2 | No duplicate governance layer | **PASS** — `docs/switching_phi1_terminology_contract.md` §1 states **supplement, not replace** for `switching_corrected_old_authoritative_artifact_index.csv` and related artifacts. |
| 3 | `Phi1_canon` and `canonical Phi1` blocked consistently | **PASS** — Blocked in contract §2; registry rows `Phi1_canon` and `canonical Phi1` = **BLOCKED**; `switching_analysis_map.md` and `switching_artifact_policy.md` call out blocked names; `switching_canonical_definition.md` banner warns. |
| 4 | `switching_canonical_phi1.csv` diagnostic only | **PASS** — Contract §3.2 (required safe sentence + filename risk); registry `DIAGNOSTIC_ONLY` row; pointer `diagnostic_only_phi1_like_artifact`; analysis map one-liner. |
| 5 | `tables/switching_corrected_old_authoritative_phi1.csv` manuscript-aligned | **PASS** — Contract §3.1, §4 table, registry `MANUSCRIPT_ALIGNED_SOURCE` row, pointer `manuscript_aligned_phi1_shape_artifact`. |
| 6 | residual-after-mode1, DeltaS_after_mode1, collapse defect, C02/C02B ≠ Phi1 | **PASS** — Contract §§3.4–3.7, §5; registry **ALLOWED_BUT_NOT_PHI1** rows with explicit forbidden_conflation_notes. |
| 7 | Three existing docs: short pointers only | **PASS** — `git diff --stat`: **10 insertions** across 3 files (no large rewrites). |
| 8 | Status CSV supports `SAFE_TO_REVIEW_FOR_COMMIT=YES` | **PASS** — `tables/switching_phi1_wording_repair_status.csv` row `SAFE_TO_REVIEW_FOR_COMMIT=YES`. Operational note: same row references force-add when paths are ignored (see below). |
| 9 | Ignored paths for explicit `git add -f` | **PASS** — Listed below from `git check-ignore -v`. |

---

## Verdict

- **Overall:** **PASS**  
- **Blocking issues:** **None**

---

## Exact commit path list

**Tracked / normal add (verify with `git status`):**

```text
docs/switching_phi1_terminology_contract.md
docs/switching_analysis_map.md
docs/switching_artifact_policy.md
docs/switching_canonical_definition.md
```

**Force-add (`tables/**`, `tables/*status*`, `reports/**` ignore rules):**

```text
git add -f tables/switching_phi1_terminology_registry.csv
git add -f tables/switching_phi1_source_of_truth_pointer.csv
git add -f tables/switching_phi1_wording_repair_status.csv
git add -f reports/switching_phi1_wording_repair.md
```

**This review package (also ignored by default — force-add if committing):**

```text
git add -f tables/switching_phi1_wording_repair_review_status.csv
git add -f reports/switching_phi1_wording_repair_review.md
```

---

## Confirm

- **Reviewer edits:** Only creation of **`tables/switching_phi1_wording_repair_review_status.csv`** and **`reports/switching_phi1_wording_repair_review.md`** (required outputs). No edits to the eight reviewed repair files.  
- **MATLAB / figures / staging / commit / push:** Not performed.
