# Cross-module canonical enforcement

## Purpose

Prevent cross-module analysis unless every module listed in the call is marked `CANONICAL` in `tables/module_canonical_status.csv`.

## Registry

- File: `tables/module_canonical_status.csv`
- Columns: `MODULE`, `STATUS` (`CANONICAL` or `NON_CANONICAL`)

## Helper

- Function: `Switching/utils/assertModulesCanonical.m`
- Usage: pass a cell array of module names, e.g. `assertModulesCanonical({'Switching'})` or `assertModulesCanonical({'Switching','Relaxation'})` after setting `modules_used`.
- Failure: `CrossModuleNotAllowed:NonCanonicalModule` if any listed module is missing from the registry or not `CANONICAL`.

## Status

| Key | Value |
|-----|-------|
| CROSS_MODULE_PROTECTION_ACTIVE | YES |

Source of truth: `tables/module_enforcement_status.csv`.

## Scope notes

- Switching-only entrypoints may call `assertModulesCanonical({'Switching'})` when cross-module access is possible or for future-proofing; this does not block valid single-module Switching work while Switching remains `CANONICAL`.
- Relaxation and Aging pipelines are not modified by this layer; their status remains `NON_CANONICAL` until promoted in the registry.
