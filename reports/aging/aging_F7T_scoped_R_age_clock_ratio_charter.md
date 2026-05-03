# Aging F7T — Scoped R_age / clock-ratio execution charter

## Purpose

Machine-readable **planning charter only** for a **future** Aging step that may compute **scoped** \(R_{\mathrm{age}} = \tau_{\mathrm{FM}} / \tau_{\mathrm{dip}}\)-style ratios from **hardened** FM tau outputs and **explicit** dip-tau tables. This document **does not** execute ratios, fit models, rank branches, select a canonical branch, or make physics claims.

## Anchors

- **F7S** readiness: `bcccf8d` — Audit Aging F7S post-repair readiness  
- **F7R2** hardened outputs: `074a9c7` — Implement Aging F7R2 FM tau metadata hardening  
- **Evidence**: F7S tables (`aging_F7S_*`), F7R gates, F7Q/F7O branch decisions, F7R2 schema.

## Allowed future execution (summary)

| Allowed | Not allowed |
|---------|-------------|
| Read **F7R2-style hardened** `tau_FM_vs_Tp.csv` with required metadata columns | Non-hardened or legacy FM tau CSV without lineage columns |
| Read **one** explicit `tau_vs_Tp.csv` (dip) path, recorded in cfg and echoed to outputs | Silent dip path fallback or implicit pairing across branches |
| Join FM and dip rows on **Tp** under declared **branch mode** and path equality checks | Mixing 22-row and 30-row streams in one ratio table |
| Emit ratio **tables + audits + manifest + status** per `aging_F7T_future_output_contract.csv` | Headline “single number” ratio implying canonical truth |
| Copy **units/semantics** from source column documentation; ratio as defined operation | Interpreting ratio magnitude as validated physics in the execution step |

## Branch modes (no ranking; no canonical pick)

Three **compatible** modes (see `aging_F7T_branch_mode_contract.csv`):

1. **`BRANCH_30ROW_F7R2_SMOKE_COMPATIBLE`** — aligns with F7O **FM_O_30row_B** triple (archival 30-row dataset + paired dip run + failed-clock metrics path policy).  
2. **`BRANCH_22ROW_F7O_A_COMPATIBLE`** — aligns with F7O **FM_O_22row_A** triple (22-row consolidation dataset + Run A dip tau).  
3. **`CUSTOM_EXPLICIT_CFG`** — caller supplies full cfg triple + `branch_id` string; must match every row’s recorded metadata for that run.

## Row inclusion (charter eligibility)

Future ratio rows are allowed only when **charter eligibility** (CEL) passes: see `aging_F7T_row_inclusion_policy.csv`.  

**Note on `row_ratio_use_allowed`:** F7R2 currently emits **`NO`** on every row for conservative global policy. The charter treats that as **non-permission**, not as “forbid joining numerically.” **CEL** requires finite \(\tau_{\mathrm{FM}}\) and \(\tau_{\mathrm{dip}}\), `has_fm` true (or equivalent), **Tp** overlap, and **branch/path/metadata** match to the declared mode. The execution step **must** record in outputs that global CSV flags remain conservative and that ratio inclusion is **charter-scoped**, not an upgrade of `row_ratio_use_allowed` in the source file.

## Ratio definition (declarative only)

Default numerical operation for the future step:

\[
R_{\mathrm{age}}(T_p) = \frac{\tau_{\mathrm{FM}}(T_p)}{\tau_{\mathrm{dip}}(T_p)}
\]

using **`tau_effective_seconds`** (or the charter-named dip equivalent column) **exactly as stored**, with **no** log transform, **no** normalization, **no** physical interpretation in the execution charter.

## Preconditions (pre-execution gates)

See `aging_F7T_pre_execution_gates.csv`. All gates **PASS** before any script computes ratios.

## Outputs (future only)

Artifact names and roles are fixed in `aging_F7T_future_output_contract.csv`; **no files are created in F7T**.

## Forbidden actions

Listed in `aging_F7T_forbidden_actions.csv`.

## Remaining blockers

See `aging_F7T_remaining_blockers.csv` (convention partial, failed-clock governance **NEEDS_POLICY**, etc.). Blockers **do not** void this charter; they constrain **interpretation and governance**, not the mechanical join definition.

## Status

Verdicts: `tables/aging/aging_F7T_status.csv`.
