# Agent Rules

Use these rules for all analysis and diagnostic work in this repository.

- All outputs must be written to run folders under `results/<experiment>/runs/run_<timestamp>_<label>/`.
- Never commit figures, ZIP archives, or other generated run artifacts.
- Never write outputs inside module directories such as `Aging/`, `Relaxation ver3/`, or `Switching/`.
- Always generate a ZIP archive for sharing results from a completed run.
- Before generating figures, read docs/visualization_rules.md and follow its standards.
- STRICT: Figure naming must follow docs/visualization_rules.md (Figure Window Naming): set figure Name, set NumberTitle off, and keep Name == saved filename base (no title(...) naming).
- Before writing run artifacts, read docs/output_artifacts.md and use only its required artifact directories.
- Analysis scripts must not manage artifact paths directly. Artifact generation should use the repository helpers: save_run_figure, save_run_table, save_run_report.
- Exception: run-level `observables.csv` must remain at run root and should not be moved into `tables/` by `save_run_table`.

## Documentation Precedence

When repository documents overlap, use this precedence order:

1. docs/AGENT_RULES.md for agent behavior and repository safety limits.
2. docs/results_system.md for output locations and run artifact layout.
3. docs/run_system.md for run creation and run-context invariants.
4. docs/repository_structure.md for code placement and repository layout.
5. docs/output_artifacts.md for artifact subfolder usage within a run.

- Versioned folders (for example `* verX`) must NOT be assumed legacy or inactive based on naming alone.

## Architecture Alignment Policy

Not all modules in the repository are fully aligned with the current
architecture (pipeline / analysis / utils / run-based results).

Modules may gradually be aligned with the new architecture when they are
actively modified. Agents must not perform repository-wide refactors
to enforce architectural alignment.

Agents must not rename, relocate, normalize, or reorganize unrelated
modules, legacy folders, or directory trees unless the task explicitly
requires it.

## Legacy Visualization Code

Agents must not reuse visualization or figure post-processing utilities
from `General ver2/` in new development.

`General ver2/` is preserved for reproducibility only. All new figures
must follow `docs/figure_style_guide.md`.

## Visualization Helpers

All figure exports must go through `tools/save_run_figure.m`.

New figures should be created with `tools/figures/create_figure.m` when possible.

Visualization helpers must reside in `tools/figures/`.

## Agent Output Template

When reporting repository changes, use this structure:

Changes made

- repository policy or behavior changes
- documentation updates

Scripts modified

- list of modified scripts or helpers

Artifacts removed or relocated

- removed output folders or generated artifacts

Verification

- checks performed such as `git status`, path verification, or run-folder validation

Agents should keep reports concise and avoid repeating repository context that is already documented in repository_structure.md or results_system.md.
## System Registry (Authoritative Source)

`docs/system_registry.json` is the authoritative source for:

- module classification
- pipeline grouping
- system structure

All documentation MUST be consistent with this registry.

## Structural Change Gate (STRICT)

Any structural change task is COMPLETE only if ALL conditions are satisfied:

1. Registry update (if needed):

   * `docs/system_registry.json` reflects the current system structure

2. Registry <-> filesystem consistency:

   * All active folders == `system_registry.json["active_modules"]`
   * No extra or missing active modules

3. Documentation sync:

   * `docs/repository_map.md`
   * `docs/root_inventory_table.md`
   * `docs/snapshot_system_design.md`
     are consistent with `docs/system_registry.json`

4. Snapshot consistency:

   * Snapshot includes all modules required by `docs/system_registry.json`

If ANY condition fails:
-> Task is NOT complete

## Context Bundle Usage (Required)

- Read `docs/context_bundle.json` before starting.
- Optional: use `docs/context_bundle_full.json` for ChatGPT/analysis.
- Workflow: `RUN → SNAPSHOT → CONTEXT → TASK`.
