# MAINT-FINDINGS-TRIAGE-01 — Published maintenance guard/steward triage (2026-05-04)

Triage only. No code, documentation (outside this report), analysis, or repair work was performed in this task. No git stage, commit, or push was performed.

## Executive summary

Five 2026-05-04 advisory sources were consolidated: **GitHub Issues #28, #29, and #30** (fetched from [Matan1986/matlab-functions](https://github.com/Matan1986/matlab-functions)), two **PR-branch** publications described in the triage brief (**run-output audit** under `maintenance/status-pack-runner/.../2026_05_04`, **canonicalization progress guard** on `publish/canonicalization-progress-guard-2026-04-29`). Local paths `reports/maintenance/agent_outputs/2026_05_04` and `reports/maintenance/module_stewards/2026_05_04` were **not present** in this worktree; those rows rely on the published route metadata in the brief and in GitHub issue bodies.

Deduplication shows **Switching output routing and identity** as the primary ACTION_NOW cluster, with **run-output audit access (RO_SUSPICIOUS_006)** as **BLOCKED_BY_ACCESS** for completeness validation, and **cross-module synthesis promotion** as **DEFER** pending charter.

## Source inventory (by publication route)

| Source | Route | Key artifact |
|--------|--------|----------------|
| Run output audit | PR branch | `.../agent_outputs/2026_05_04` (per brief); rule **RO_SUSPICIOUS_006** |
| Helper duplication guard | [Issue #29](https://github.com/Matan1986/matlab-functions/issues/29) | `HD_*` rules; five normalized rows |
| Canonicalization progress guard | PR branch `publish/canonicalization-progress-guard-2026-04-29` | Narrative bullets; synthetic rule ids **CANON_GUARD_*** in inventory CSV |
| Switching steward | [Issue #30](https://github.com/Matan1986/matlab-functions/issues/30) | **SAS_*** findings; four normalized rows |
| Repository drift guard | [Issue #28](https://github.com/Matan1986/matlab-functions/issues/28) | **RS_*** findings; five normalized rows |

## Deduplication map (cross-issue and cross-source)

- **SAS_SOURCE_009 (Issue #30)** overlaps **CANON_GUARD_SW_IDENTITY (canonicalization PR)** on conflicting or absent **switching_canonical_identity.csv** versus resolver behavior — single family **F01**.
- **SAS_OUTPUT_003 (Issue #30)** overlaps **RS_OUT_001 (Issue #28)** (flat or multi-surface outputs), **HD_EXPORT_004 (Issue #29)** (copied export helpers), and **steward WATCH** rows **SAS_STATUS_007 / SAS_SCIENCE_008** on surfaces and claims — grouped under **F02** with mixed ACTION_NOW vs WATCH.
- **RS_LEGACY_004 (Issue #28)** depends on output-path stability from **F02** — **F03** as PLAN_NEXT.
- **RS_HELPER_003 (Issue #28)** clusters with **HD_*** rules (Issue #29) under **F04** (different symbols, same maintenance theme).
- **RO_SUSPICIOUS_006** stands alone as workspace-access-limited validation — **F05**.

## Maintenance families and disposition

| Family | Theme | action_class (aggregate) |
|--------|--------|---------------------------|
| F01 | Switching identity/source-of-truth drift | ACTION_NOW |
| F02 | Switching output routing / flat fallback drift | ACTION_NOW + WATCH (status and science boundary) |
| F03 | Legacy flat output references | PLAN_NEXT |
| F04 | Helper duplication / helper placement | PLAN_NEXT |
| F05 | Run-root visibility limitation | BLOCKED_BY_ACCESS |
| F06 | Ignore/tracked generated artifact policy | PLAN_NEXT |
| F07 | Aging WIP/non-canonical migration risk | DEFER |
| F08 | Relaxation ver3 naming/status drift | PLAN_NEXT |
| F09 | MT status/narrative drift | WATCH |
| F10 | Non-canonical cross-module science promotion | DEFER |

## Findings that must not be fixed directly before a charter

- **F10** — `analysis/unified_dynamical_crossover_synthesis.m` promotional stance; needs **cross-module governance charter** before re-labeling or “paper-ready” claims.
- **F07** — Aging `pwd/results` fallbacks and non-canonical hygiene; defer large pipeline migration until **Aging pathway / run-root charter** (or equivalent owner decision).
- **F06** — **RS_GIT_005** large tracked vs ignore intersection; issue body flags **human approval**; avoid wholesale untrack without policy decision.

## Recommended bounded next-agent sequence

1. **Governance / identity memo agent (F01)** — Owner decision on identity table vs mtime fallback (implementation deferred to a follow-up).
2. **Output-route policy and bounded implementation list (F02)** — Pair **RS_OUT_001** with **SAS_OUTPUT_003** scope; keep **SAS_STATUS_007 / SAS_SCIENCE_008** as labeling and claim WATCH.
3. **Legacy consumer update plan (F03)** after F02 stabilizes.
4. **Single pilot helper dedup (F04)** per Issue #29 minimal options.
5. **Re-run run-output audit (F05)** when workspace exposes `results/<experiment>/runs/run_*`.
6. **Charter drafting for F10** before touching synthesis script claims.

## Delivered tables

- `tables/maintenance_findings_triage_01_inventory.csv`
- `tables/maintenance_findings_triage_01_deduped_families.csv`
- `tables/maintenance_findings_triage_01_action_plan.csv`
- `tables/maintenance_findings_triage_01_status.csv`

## Git check (task start)

- `git diff --cached --name-only`: **empty** (proceeded).
- `git log --oneline -12` and `git status --short`: captured at triage time; working tree had unrelated changes — triage outputs add **five new files** only.
