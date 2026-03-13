# Agent Rules

Use these rules for all analysis and diagnostic work in this repository.

- All outputs must be written to run folders under `results/<experiment>/runs/run_<timestamp>_<label>/`.
- Never commit figures, ZIP archives, or other generated run artifacts.
- Never write outputs inside module directories such as `Aging/`, `Relaxation ver3/`, or `Switching/`.
- Always generate a ZIP archive for sharing results from a completed run.
- Before generating figures, read docs/visualization_rules.md and follow its standards.
- Before writing run artifacts, read docs/output_artifacts.md and use only its required artifact directories.
- Analysis scripts must not manage artifact paths directly. All artifact generation must use the repository helpers: save_run_figure, save_run_table, save_run_report.

## Documentation Precedence

When repository documents overlap, use this precedence order:

1. docs/AGENT_RULES.md for agent behavior and repository safety limits.
2. docs/results_system.md for output locations and run artifact layout.
3. docs/run_system.md for run creation and run-context invariants.
4. docs/repository_structure.md for code placement and repository layout.
5. docs/output_artifacts.md for artifact subfolder usage within a run.

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




