# Root Artifact Contract

## Purpose
This contract defines what belongs in repository root, what is forbidden, and what checks are mandatory before any future root-file movement.
This is governance-only and does not authorize cleanup execution.

## What Belongs in Repository Root
- repository metadata and bootstrap files
- top-level governed layers (`docs/`, `tools/`, `scripts/`, `analysis/`, `results/`, `tables/`, `reports/`, `figures/`, `runs/`)
- active module source roots (for example `Aging/`, `Switching/`, `Relaxation ver3/`, `MT ver2/`)

## What Is Forbidden in Root
- new ad hoc run outputs
- new root-level transient logs/probe dumps
- new durable maintenance tables/reports outside governed destinations
- unowned one-off diagnostics without contract and lineage context

## Known Current Root Disorder Classes
- overloaded root-level MATLAB runner scripts and wrappers
- root-level maintenance CSV/MD/log artifacts mixed with source entrypoints
- local environment state and temp/probe directories
- legacy/quarantine directories and duplicate historical roots

## Why No Root Cleanup Is Authorized Yet
No root cleanup is authorized in this phase because lineage and caller safety remain unresolved.
Policy requires index/contract completion first and explicit low-risk review before any movement.

## MATLAB Bare-Stem Invocation Risk
MATLAB scripts may be invoked by bare stem name or path-dependent workflows.
A missing text reference does not prove safe movement for `.m` files.
Therefore root MATLAB movement is blocked until invocation ownership and call paths are verified.

## Rules for Future Root Declutter Review
- review is phased and conservative
- only explicitly approved low-lineage candidates are eligible first
- root script movement requires stronger evidence than exact-string grep matches
- fixture-like trees (for example under `status/`) must be excluded from naive cleanup automation

## Required Checks Before Any Root File Movement
- module ownership confirmation
- lineage impact check
- consumer/reference check across code and docs
- MATLAB invocation-path review for `.m` scripts
- run-manifest/status evidence preservation check
- governance approval record in maintenance trackers

## Scientific Artifact Protection
No deletion of scientific artifacts is authorized by this contract.
No cleanup plan may rewrite, delete, or silently relocate scientific lineage artifacts.
