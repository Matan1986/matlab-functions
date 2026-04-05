# Out-of-plan containment: kappa1_pt_control_analysis (Switching only)

## Purpose

This document classifies and quarantines artifacts from a **premature kappa1 versus PT (probability-transform / PT-descriptor) control analysis** so they cannot be mistaken for canonical Switching truth or used as inputs to downstream work. **Aging and Relaxation are out of scope** for this note.

## Classification (each listed artifact)

| Field | Value |
| --- | --- |
| classification | OUT_OF_PLAN |
| stage_violation | YES |
| violated_stage | Phi-tier precedence |
| allowed_in_canonical | NO |
| allowed_as_input | NO |
| trusted | NO |

## What was executed

A **kappa1 PT control analysis** run produced at least one repo-root artifact documenting correlations and models relating **kappa1** to **PT descriptors** (weighted moments and quantiles of current using PT_pdf), scoped to TRUSTED_CANONICAL Switching runs (see the artifact body in `reports/kappa1_pt_control_analysis.md`).

## Why this violates execution order

The agreed Switching execution order is:

**Phi-tier -> kappa1-tier -> PT**

Running **kappa1 <- PT** analysis before **Phi1-tier canonical validation** is complete means the stage precondition for interpreting kappa1 in this stack was not satisfied. This is recorded as **stage_violation = YES** with **violated_stage = "Phi-tier precedence"** (Unicode phi written as `Phi` here for ASCII safety in filenames; the intended meaning is Phi1-tier).

## Exact artifacts

| Full path | Status |
| --- | --- |
| `C:\Dev\matlab-functions\reports\kappa1_pt_control_analysis.md` | **Present** — markdown report |
| `C:\Dev\matlab-functions\tables\kappa1_pt_control_analysis.csv` | **Not found** at containment audit (no file at this path in the repository) |

The canonical Switching model definition in `docs/switching_canonical_definition.md` describes the locked **S = Scdf + kappa1 * Phi1** structure and canonical kappa1 control tests; it does **not** elevate this out-of-plan kappa1<-PT table to canonical status.

Switching canonical audit tables (e.g. `tables/switching_canonical_definition_audit.csv`, `tables/switching_analysis_canonical_status.csv`) were used only as **context for documentation**; they were not modified.

## Why these artifacts are not trusted

- They were generated **out of plan** relative to **Phi-tier -> kappa1-tier -> PT**.
- The markdown report shows **empty correlation/model tables and zero R2** placeholders, so it does not constitute a verified numerical result suitable for physics or modeling conclusions.
- **allowed_in_canonical = NO**, **allowed_as_input = NO**, **trusted = NO** per containment policy.

## Propagation risk audit

Searches were performed for the exact basename/string **`kappa1_pt_control_analysis`** (scripts, docs, tables, reports, tools).

| Finding | dependency_risk | needs_isolation |
| --- | ---: | ---: |
| No `.m` or other tracked file references `kappa1_pt_control_analysis` (load/read of these exact paths) | NO | NO |
| No downstream dependency on these filenames identified | NO | NO |

**Note:** Other repo code refers to **different** kappa1/PT tests (e.g. `kappa1_pt_vs_speak_*`). Those are **not** the same as `kappa1_pt_control_analysis` and are not reclassified here.

## Explicit statement

These artifacts are **OUT_OF_PLAN** and **MUST NOT** be used for physics, modeling, or context updates.

## Guard Rule

**kappa1<-PT analysis is forbidden before Phi1 canonical validation is fully completed and verified.**

This guard is **documentation only**; no validators or executable pipeline code were changed as part of this containment.

## Registry

Authoritative machine-readable rows: `tables/out_of_plan_artifacts_registry.csv`  
Status summary: `tables/out_of_plan_status.csv`
