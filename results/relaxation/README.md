# Relaxation Results Namespace README

## Namespace Role
`results/relaxation/` is the run-lineage container namespace for Relaxation executions.

Current observed structure includes:
- `results/relaxation/runs/<run_id>/...` for run-scoped lineage
- related Relaxation candidate namespaces such as `results/relaxation_canonical/`, `results/relaxation_post_field_off_canonical/`, and `results/relaxation_post_field_off_RF3R_canonical/`

## Expected Future Run Container Contract
Each run container under `results/relaxation/runs/<run_id>/` is expected to include:
- run manifest (`run_manifest.json` or equivalent)
- execution status (`execution_status.csv` or equivalent)
- run logs
- config or entrypoint snapshot
- raw and intermediate run outputs
- lineage links to promoted durable tables/reports/figures when promotion occurs

## Current Caveat
Relaxation artifacts still exist across multiple namespaces, including module-local source-adjacent and legacy/historical locations (for example under `Relaxation ver3/` and older result trees).

This README documents namespace expectations only and does not assert that all Relaxation artifacts are already normalized into one location.

## Migration Authorization
No migration, file movement, rename, or cleanup is authorized by this README.
This document is contract/index guidance only.

