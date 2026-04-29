# Switching Phase 2 — Semantic contract materialization

Read-only materialization of Phase 1.5D **`semantic_family_id`** taxonomy into registry, allowed-use, writer-contract, and lint-rule tables. No analysis code edits; no MATLAB; no replay execution; no staging or commit.

## Anchor and hygiene

| Check | Result |
|--------|--------|
| Expected `HEAD` | **`19397d1`** Add Switching semantic taxonomy and alias plan |
| Staged at task start | **None** (`git diff --cached` empty) |

## Required inputs

Committed taxonomy and synthesis artifacts (`tables/switching_semantic_*.csv`, `reports/switching_semantic_synthesis_and_rename_plan.md`), **`docs/switching_pre_replay_contract_reset.md`**, **`tables/switching_pre_replay_registry_contract.csv`**, **`tables/switching_pre_replay_namespace_contract.csv`**, **`tables/switching_pre_replay_writer_contract_template.csv`**, **`docs/switching_analysis_map.md`**, **`tables/switching_analysis_namespace_clean_map.csv`**, **`reports/switching_stale_governance_supersession.md`**.

## What was materialized

| Artifact | Purpose |
|----------|---------|
| `tables/switching_semantic_materialized_artifact_registry.csv` | Maps scripts, outputs, **column-level** `switching_canonical_S_long` splits, and REG00x registry seeds to **`semantic_family_id`** + governance **`namespace_id`** hints. |
| `tables/switching_semantic_allowed_use_matrix.csv` | Machine-readable **YES / NO / CONDITIONAL / WARN** grid per family vs canonical-source claims, corrected-old pathway, diagnostics, visualization, replay, future comparison, **forbidden-evidence tagging**, old-analysis gating, cross-module gating. |
| `tables/switching_semantic_writer_contract.csv` | Practical metadata/header fields for future writers (extends Phase 1 template with **Phase 2** fields such as **`source_column_class`**, **supersession**, **quarantine flags**). |
| `tables/switching_semantic_lint_rules.csv` | WARN-first lint catalog mapping **`tables/switching_semantic_forbidden_terms.csv`** into agent-checkable rules; **HARD_FAIL** reserved for unsafe authority promotion (rule **SW_LINT_019**). |
| `tables/switching_semantic_materialization_status.csv` | Gate keys for Phase 2 completion. |
| `reports/switching_semantic_contract_materialization.md` | This narrative. |

### Mixed producer rule (column-level)

**`switching_canonical_S_long.csv`** is represented as:

- **`::column/S_percent`**, **`T_K`**, **`current_mA`** → **`CANON_GEN_SOURCE`** (measured / identity coordinate layer).
- **`::column/PT_pdf`**, **`CDF_pt`**, **`S_model_pt_percent`** → **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**.
- **`::column/residual_percent`** → **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** / diagnostic-mode classification aligned with **`tables/switching_analysis_classification_status.csv`** (not corrected-old residual authority).
- Producer script **`run_switching_canonical.m`** remains **`CANON_GEN_MIXED_PRODUCER`** at **script** row granularity only.

This preserves **`CANON_GEN_SOURCE` split** and **`EXPERIMENTAL_PTCDF_QUARANTINE`**.

### Alias-only vs rename

**Rename execution remains deferred** — consistent with **`RENAME_EXECUTION_RECOMMENDED_NOW=NO`** in materialization status and Phase 1.5 synthesis. Use **`recommended_alias`** + **`semantic_family_id`** in contracts until a governed rename wave exists.

### Broad old-analysis replay

**Blocked for unattended execution** — **`BROAD_OLD_ANALYSIS_REPLAY_ALLOWED_NOW=NO`**. Phase 2 contracts **do not** authorize blind replay; narrow audited runners remain **`CONDITIONAL`** in the allowed-use matrix only where explicitly labeled.

### Phase 3 — Lint / preflight

**`SAFE_TO_PROCEED_TO_PHASE3_LINT_PREFLIGHT=YES`** — Implement tooling that reads **`switching_semantic_lint_rules.csv`** with default **WARN/SUGGEST**, escalating to **HARD_FAIL** only on unsafe authoritative promotion (**SW_LINT_019** pattern and publish-path violations for forbidden alias stems **SW_LINT_008**).

### Phase 4 — Corrected-old replay

**`SAFE_TO_PROCEED_TO_PHASE4_CORRECTED_OLD_REPLAY=NO`** until Phase 3 lint/preflight exists and passes on touched paths. Corrected-old **authority** remains tied to **`CORRECTED_OLD_AUTH_BUILDER`**, artifact index rows, and **`builder_status`** — not replay helpers.

### Stale governance

**`CLASSIFICATION_OR_GOVERNANCE_STATUS`** materialization requires **`supersession_reference`** before interpreting legacy **`NO`** existence keys — see **`reports/switching_stale_governance_supersession.md`**.

## Status snapshot

See **`tables/switching_semantic_materialization_status.csv`** for all **`YES`/`NO`** keys including **geocanon vs residual**, **PT/CDF quarantine**, **forbidden terms as WARN rules**, and **hard-fail reservation**.

---

*Phase 2 semantic contract materialization complete. No staging or commit performed in this task.*
