# Module Alignment Policy Check

Checked:

- `docs/AGENT_RULES.md`
- `docs/repository_structure.md`

Findings:

- `docs/repository_structure.md` already describes a transitional repository state and notes current exceptions to the target structure.
- `docs/AGENT_RULES.md` did not explicitly state that module alignment may happen gradually or that agents must avoid repository-wide refactors.
- The full policy requested was therefore not clearly present across the two files.

Change made:

- Added an `Architecture Alignment Policy` section to `docs/AGENT_RULES.md` stating that not all modules are fully aligned yet, alignment may happen gradually when modules are actively modified, and agents must not perform repository-wide refactors to enforce alignment.
