# RLX-NAMING-AUDIT-09 — Relaxation naming contract audit, readiness verdict, and gap routing

## 1. Purpose and scope

This audit reads the **RLX-CANONICAL-SURVEY-08A** package (`relaxation_canonical_analysis_survey_08A.md`, naming contract `relaxation_activity_naming_contract_08A.md`, and associated CSV tables) plus optional **CLOSURE-07** references. It does **not** modify any AR01–08A artifact contents. It answers:

- Whether Relaxation module prose and tables are ready for further Relaxation-only work and for governed cross-module work.
- Whether naming rules are sufficient to prevent **`A`**, **`m0`**, **`A_T`**, and ambiguous **`A_obs`** usage without role labels.
- Which gaps remain **Relaxation-only** versus **cross-module**, with suggested task IDs and sequencing.

**Repo safety:** `git diff --cached --name-only` was empty before authoring this package; no MATLAB, Python, Switching, Aging, or cross-module fits were executed.

---

## 2. 08A file audit

All **eleven** expected 08A deliverables are present and readable (see `tables/relaxation/relaxation_naming_audit_09_file_audit.csv`).

| Artifact | Role |
|----------|------|
| `reports/relaxation/relaxation_canonical_analysis_survey_08A.md` | Executive survey |
| `docs/relaxation_activity_naming_contract_08A.md` | Naming contract prose |
| five `relaxation_canonical_analysis_survey_08A_*.csv` | Inventory, legacy gap, boundary, roadmap, survey status |
| four `relaxation_activity_naming_contract_08A_*.csv` | Aliases, usage rules, forbidden terms, A-policy |

**Minor completeness note:** In `relaxation_canonical_analysis_survey_08A.md` §7, the bullet list names three naming tables; **`relaxation_activity_naming_contract_08A_A_policy.csv`** is referenced in §8 rather than §7. Content is still discoverable.

---

## 3. Naming contract audit

The contract clearly defines:

| Symbol | Where defined |
|--------|----------------|
| **A_obs_canon** | Naming doc §2 table; aliases CSV |
| **A_svd_canon** | Naming doc §2; aliases as family |
| **A_T_canon** | Naming doc §2 (sigma1×U(:,1) representative); aliases bridge |
| **A_svd_LOO_canon** | Naming doc §2; aliases operational LOO |
| **A_svd_full_canon** | Naming doc §2; aliases full-map reference |
| **A_T_old** | Aliases: missing export, **non-numeric**, lineage audits only |

**Bare-symbol discipline (`relaxation_activity_naming_contract_08A_forbidden_terms.csv`):**

- **`A`**, **`m0`**, **`A_T`**: forbidden as bare prose; replacements listed ( **`m0`** allows legacy quoted code blocks labeled legacy).
- **`activity`**, **`amplitude`**: restricted bare category/noun with scoped exceptions (e.g. section headings if Relaxation-scoped, caption once with definitions)—stricter than **`A`**/**`m0`** but not absolute zero-use.
- **`canonical A`**, **`the canonical amplitude`**: forbidden undefined-namespace phrases.

Overall: naming rules are **clear enough** to prevent accidental collapse of **direct observable** vs **rank-1 SVD family** if authors follow the CSVs; residual risk is **prose discipline** on **`activity`**/**`amplitude`**, not structural ambiguity of **`A_obs_canon`** vs **`A_svd_canon`**.

---

## 4. A-policy audit

`tables/relaxation/relaxation_activity_naming_contract_08A_A_policy.csv` and `relaxation_activity_naming_contract_08A_usage_rules.csv` satisfy the required policy shape:

| Requirement | Verdict |
|-------------|---------|
| Main text / main figures favor **A_obs_canon** | **YES** — `main_paper_figure` row |
| Reconstruction / SVD narrative uses **A_svd_canon** family | **YES** — supplement row uses **A_svd_LOO_canon** (member of family); **A_svd_full_canon** diagnostic |
| Legacy SVD definition represented by **A_T_canon** | **YES** — aliases + `legacy_comparison` row with **A_T_old** prose-only |
| Non-leaky operational representative **A_svd_LOO_canon** | **YES** |
| Cross-module must test **A_obs_canon** and **A_svd_canon** representative | **YES** — `AX_cross_module` **MUST_TEST_BOTH_TRACKS** |

---

## 5. Relaxation-only gaps

Derived from `relaxation_canonical_analysis_survey_08A_legacy_gap_map.csv` and `relaxation_canonical_analysis_survey_08A_completion_roadmap.csv`. Detailed rows: `relaxation_naming_audit_09_relaxation_only_gap_route.csv`.

**Themes:**

| Theme | Status / next task |
|-------|---------------------|
| **Tau / beta / KWW** | Not consolidated with amplitude closure; **KWW-TAU-BETA-SURVEY-09** (Relaxation-only survey, explicit scope boundary). |
| **RF5A harmonization** | **RLX-RF5A-HARMON-09** — map RF5A outputs to **A_svd_canon** naming. |
| **Visualization / axis contract** | **RLX-FIG-READINESS-09**; merge with legacy visualization inventory backlog. |
| **Internal Relaxation collapse** | Narrow replay remains **DIAGNOSTIC_RLX** — label provenance, not primary amplitude. |
| **Figure readiness** | Same as visualization roadmap item. |
| **Legacy claims** | **A_T_old** numeric prohibition permanent; **Power_law_0p66** narrative **LOW** — defer to authorized refit task only. |

**Inputs:** RF3R2/RCON tables, CLOSURE-07, 08A naming tables, existing RF5A and tau scripts per inventory.

**Outputs:** Manifest CSV, mapping table, figure checklist MD, tau-beta survey MD (per task).

**Stop conditions:** Per roadmap column (e.g. checksum resolved, every cited amplitude mapped, axes labeled).

**Blocking:** None of these **block** continued Relaxation-only analysis on **existing closed lineage**; they **block full publication harmonization** and **clean RF5A/tau narrative** until completed.

---

## 6. Cross-module gaps

Derived from boundary table and roadmap. Detailed rows: `relaxation_naming_audit_09_cross_module_gap_route.csv`.

**Themes:**

| Theme | Task |
|-------|------|
| **AX reinterpretation** | **CM-SW-RLX-AX-10** — governed AX replay; **not** provable from Relaxation tables alone. |
| **Power-law retest** | **RLX-POWERLAW-RET-10** — dual **`A_obs_canon`** / **`A_svd_canon`** tracks; authorization-only in survey. |
| **Scalar sensitivity** | Enforced by **A-policy** and boundary CSV: cross-module joins require **both** tracks where applicable. |
| **Switching coordinate governance** | **CM-GOVERNANCE-LOCK-09**, **Switching_table_join** protocol; invalid joins forbidden. |
| **Aging boundary** | **relaxation_vs_aging_clock** — separate observable contract; not Relaxation-solo proof. |

**Blocking cross-module claims:** Yes — **governance lock** and **manifest-valid joins** must precede defensible cross-module statements.

---

## 7. Readiness verdicts

See `tables/relaxation/relaxation_naming_audit_09_readiness_matrix.csv` and `tables/relaxation/relaxation_naming_audit_09_status.csv`.

| Verdict | Value |
|---------|--------|
| **RELAXATION_READY_FOR_R_ONLY_CONTINUATION** | **YES** — 08A exists; naming contract is explicit; lineage closure preserved. |
| **RELAXATION_READY_FOR_TARGETED_R_ONLY_ANALYSIS** | **YES** — Relaxation-only gap route documented with stops. |
| **RELAXATION_READY_FOR_CROSS_MODULE_ANALYSIS** | **YES** — With caveat: execute under **governance + dual-A** briefs, not ad hoc. |
| **CROSS_MODULE_REQUIRES_DUAL_A_POLICY** | **YES** |
| **PAPER_READY_MAIN_TEXT_AOBS** | **YES** — **A_obs_canon** for transparent main-line panels with captions. |
| **PAPER_READY_ASVD_SUPPLEMENT** | **YES** — **A_svd_LOO_canon** / family members with LOO vs full caveat. |
| **SAFE_TO_RUN_AX_NEXT** | **YES** — Only as **governed CM task** testing **both** **A_obs_canon** and **A_svd_canon** representative; not “Relaxation-only next script.” |
| **SAFE_TO_RUN_POWERLAW_RETEST_NEXT** | **YES** — As **cross-module scalar-sensitive** authorized refit (**RLX-POWERLAW-RET-10**), not as restoring legacy exponent without fit. |
| **SAFE_TO_RUN_KWW_TAU_BETA_SURVEY_NEXT** | **YES** — As **Relaxation-only survey** defining scope **without** rewriting amplitude closure artifacts. |

---

## 8. Recommended next task sequence

1. **Commit / adopt this audit package** when ready (`SAFE_TO_COMMIT_AUDIT_PACKAGE` = YES for **09-only** files).
2. **Relaxation-only (order flexible after manifest discipline):**
   - **RLX-RF3R2-MANIFEST-09** — input integrity.
   - **KWW-TAU-BETA-SURVEY-09** — tau/beta/KWW scope vs amplitude closure.
   - **RLX-RF5A-HARMON-09** — RF5A ↔ **A_svd_canon** mapping.
   - **RLX-FIG-READINESS-09** — axis and caption contract.
3. **Cross-module (before claiming bridges):**
   - **CM-GOVERNANCE-LOCK-09**
   - **CM-SW-RLX-AX-10** (with dual tracks)
   - **RLX-POWERLAW-RET-10** when exponent claims are in scope.

---

## 9. Final decision: what can run next and what still cannot be claimed

**Can run next (Relaxation-only):** Continued analysis on **RF3R2 + RCON + closure lineage** using contract vocabulary; **KWW/tau/beta survey** as **non-closure-modifying** inventory; **RF5A naming harmonization** and **figure readiness** as documentation and mapping tasks.

**Cannot claim without further work:** **AX-style** equivalence or **Switching X_eff** bridges from Relaxation tables alone; **aging clock** ties without aging contract; **restored** power-law exponent without **RLX-POWERLAW-RET-10**; **numeric** **A_T_old** identity; **single ambiguous “canonical amplitude”** in paper prose.

---

*Survey inputs: `relaxation_canonical_analysis_survey_08A.md`, `relaxation_activity_naming_contract_08A.md`, associated 08A CSVs. Audit outputs: this file and `relaxation_naming_audit_09_*.csv`.*
