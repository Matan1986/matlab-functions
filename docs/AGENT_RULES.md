# Agent Rules

Use these rules for all analysis and diagnostic work in this repository.

- All outputs must be written to run folders under `results/<experiment>/runs/run_<timestamp>_<label>/`.
- Never commit figures, ZIP archives, or other generated run artifacts.
- Never write outputs inside module directories such as `Aging/`, `Relaxation ver3/`, or `Switching/`.
- Always generate a ZIP archive for sharing results from a completed run.

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
