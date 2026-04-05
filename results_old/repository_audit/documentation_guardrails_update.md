# Documentation Guardrails Update

Updated documentation only. No repository refactor was performed.

Changes made:

- Added a documentation precedence note to `docs/AGENT_RULES.md`.
- Strengthened refactor-safety wording in `docs/AGENT_RULES.md` to forbid unrelated directory reorganization unless explicitly requested.
- Clarified in `docs/repository_structure.md` that the `modules/` layout is a target model and must not be created or migrated to by default.
- Clarified in `docs/repository_structure.md` when helpers belong in `tools/` versus module `utils/`.
- Updated `docs/run_system.md` so the documented run layout matches the standardized `figures/`, `tables/`, `reports/`, and `review/` structure, with `observables.csv` at the run root when used.
