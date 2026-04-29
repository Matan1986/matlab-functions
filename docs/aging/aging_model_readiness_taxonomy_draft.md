# Aging model-readiness taxonomy (draft, F6Z)

**Status:** Draft — machine-readable rows live in `tables/aging/aging_F6Z_model_readiness_taxonomy.csv`.

## Purpose

Separate **diagnostic** and **evidence** uses from **model_candidate**, **model_ready**, and **canonical** paths. No artifact should be labeled **`model_ready`** unless observable identities and lineage metadata are resolved per `aging_semantic_naming_taxonomy.md`.

## Scale (summary)

| Label | Short meaning |
|-------|----------------|
| `diagnostic_only` | QA / smoke; unstable |
| `evidence_only` | Legacy readable; quarantine routing |
| `analysis_ready` | Repeatable within a bounded cohort |
| `model_candidate` | Pilot fits with explicit caveats |
| `model_ready` | Identities resolved for intended model use |
| `canonical_candidate` | Parity/review staging |
| `canonical` | Registry ratified |
| `blocked` | Identity/clash stop |
| `unknown` | Triage required |

## Enforcement

Strict automation deferred; audit_only validators and documentation apply first (`aging_contract_validation_rules.md`).
