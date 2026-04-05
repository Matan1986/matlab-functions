# Integrity Invalid Artifacts Audit

## Scope
Contaminated lineage audited for integrity enforcement where relaxation measurement logic was applied to aging.

## Contaminated Lineage Targets
- run_aging_measurement_definition_audit.m
- tables/aging_measurement_definition_audit.csv
- tables/aging_measurement_definition_audit_status.csv
- reports/aging_measurement_definition_audit.md
- results/relaxation/runs/run_2026_03_30_124149_aging_measurement_definition_audit
- results/relaxation/runs/run_2026_03_30_133703_aging_measurement_definition_audit

## What Was Missing
- Script-level INVALID header markers for aging misuse.
- Table-level invalidity columns indicating non-use for aging.
- Report invalidity section and explicit definition mismatch warning.
- Run-level manifest flags for aging invalidity and definition contamination.

## What Was Patched
- Added script header markers: INVALID_FOR_AGING = YES and DEFINITION_CONTAMINATION = YES.
- Added table columns: VALID_FOR_AGING = NO, DEFINITION_CONTAMINATION = YES, SHOULD_BE_USED = NO.
- Added report section: INVALID AGING ANALYSIS with explicit mismatch explanation.
- Added/updated run manifests with valid_for_aging=false and definition_contamination=true.

## Final Integrity State
- All identified contaminated artifacts are explicitly marked invalid for aging use.
- No target artifact remains ambiguous for aging validity.

## Explicit Warning
These artifacts originate from a definition mismatch (relaxation logic applied to aging). They must not be used for aging interpretation, model fitting, ranking, or conclusions.

## Verdict Block
INVALID_ARTIFACTS_IDENTIFIED=YES
INVALID_ARTIFACTS_MARKED=YES
AUTO_FIX_APPLIED=YES
INTEGRITY_LAYER_CONSISTENT=YES
