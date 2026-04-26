# Repository Markdown Survey for Prompting

## Purpose and Scope

This survey is a read-only synthesis of repository documentation to improve future agent prompts. It uses only Markdown/JSON docs named in the task plus explicitly linked docs needed for precedence, canonical boundaries, execution/artifact rules, module layout, and prompt-writing guidance.

## Source-of-Truth Hierarchy

Primary precedence comes from `docs/AGENT_RULES.md`:

1. `docs/AGENT_RULES.md` (agent behavior and safety)
1a. `docs/infrastructure_laws.md` (infrastructure architecture, run roots/manifests/fingerprints/entrypoints)
1b. `docs/system_master_plan.md` (phase model, trust domains, cross-module participation law)
2. `docs/results_system.md` (output locations and run artifact layout)
3. `docs/run_system.md` (strict run identity/context/artifact contract)
4. `docs/repository_structure.md` (layout and placement rules)
5. `docs/output_artifacts.md` (artifact subfolder usage)
6. `docs/agent_prompt_exclude.md` (do-not-bulk-load list for prompts)

Additional high-value orientation:
- `docs/system_entrypoint.md` (routing, contract-vs-overview framing)
- `docs/repo_execution_rules.md` (MATLAB execution/signaling contract)
- `docs/repo_context_minimal.md` and `docs/templates/*.md` (prompt scaffolding)
- `docs/system_registry.json` (authoritative module/system registry)

## Key Repo Rules Agents Must Obey

- MATLAB automation uses wrapper entrypoint only: `tools/run_matlab_safe.bat "<ABSOLUTE_PATH_TO_SCRIPT.m>"`.
- Direct MATLAB invocation for automated/agent runs is forbidden.
- Analysis outputs belong under `results/<experiment>/runs/run_<timestamp>_<label>/`.
- Do not use repo-root `reports/`, `tables/`, `figures/` or module folders as primary sinks for new run outputs.
- Required run identity artifacts include `run_manifest.json`; required execution status is `execution_status.csv` at run root.
- `execution_status.csv` canonical column schema/order is fixed (5 columns) via `docs/run_system.md` and `docs/execution_status_schema.md`.
- `observables.csv` is special: run-root index, not a `tables/` artifact.
- Infrastructure edits are serial-only and must not create parallel run/manifest/fingerprint systems.
- Cross-module analysis is allowed only when all participating modules are canonical for that scope (normative law; operational closure still gated by plan/audits).

## Canonical vs Non-Canonical Boundaries

Execution/infrastructure:
- Canonical run root: `results/<experiment>/runs/run_<timestamp>_<label>/`.
- Canonical manifest: one `run_manifest.json` per run root.
- Canonical fingerprint story: manifest provenance triple (`git_commit`, `script_hash`, environment fields).
- Canonical entrypoint for automated MATLAB execution: wrapper only.

Switching system:
- Canonical Switching entrypoint in active docs/context is `Switching/analysis/run_switching_canonical.m`.
- `docs/switching_canonical_definition.md` is explicitly marked deprecated and should not be treated as current canonical authority.
- `docs/canonical_switching_system.md` and `docs/switching_canonical_direction.md` define single-pipeline + channel-aware model constraints.

Historical/non-canonical:
- Legacy paths and older stacks may remain for reproducibility but are not patterns for new work.
- Deprecated docs can still exist; prompts should prefer current contracts and registry-backed definitions.

## High-Level Module Map (Prompt-Relevant)

From `docs/system_registry.json` + `docs/repository_structure.md`:

- Unified active stack: `Aging`, `Switching`, `Relaxation ver3`, `analysis`.
- Infrastructure layer includes `tools`, `results`, etc. (`system_registry.json`).
- Current active experiment modules in structure doc: `Aging/`, `Relaxation ver3/`, `Switching/`.
- Shared layers: `analysis/`, `results/`, `runs/`, `tests/`, `tools/`, `docs/`.
- Versioned folders are not auto-legacy by naming alone.

## Context That Should Always Appear in Future Prompts

- Task type: analysis vs infrastructure vs docs-only.
- Explicit instruction to honor `docs/AGENT_RULES.md` and `docs/repo_execution_rules.md`.
- Run/output policy: run-scoped outputs only (`results/<experiment>/runs/...`) and no module/root output sinks for run artifacts.
- If MATLAB execution is requested: wrapper-only command form and absolute script path requirement.
- Required artifact expectations for executed runs: `execution_status.csv`, run manifest, table/report outputs in canonical locations.
- Scope boundaries: exact files/folders to inspect or modify; explicitly forbid blind repo scans.
- Canonical module/entrypoint target (when task is module-specific), especially for Switching.

## Context That Should Usually Be Omitted

- Bulk inclusion of documents in `docs/agent_prompt_exclude.md` unless task explicitly needs them.
- Long historical narrative and closure prose when task is operational (run, fix, audit).
- Deprecated canonical-definition docs as primary authority.
- Full context bundles and broad claims JSON unless the task is specifically about claims synthesis.
- Irrelevant module science details when task is infra/logistics/doc maintenance.

## Risks, Contradictions, or Staleness Found

1. `docs/switching_canonical_definition.md` is marked deprecated but still contains strong normative wording; high risk of prompt drift if loaded.
2. Some execution docs contain overlapping/legacy-styled hard rules that may not fully align on implementation detail wording (for example, wrapper behavior descriptions differ across docs over time).
3. `docs/run_system.md` strict required_outputs manifest shape may diverge from implementation snapshots noted in `docs/repo_context_infra.md` (flat vs nested representation tension).
4. `docs/repository_structure.md` presents target `modules/` model while also stating current tree remains non-migrated; prompts must distinguish current vs target.
5. `docs/context_bundle.json` includes broad scientific claims and references that can over-bias infra/doc tasks if included by default.
6. Mixed maturity of “normative but not operationally closed” rules (cross-module canonical participation) can be misread as fully enforced.

## Recommended Compact Prompt Template

Use this for focused tasks:

```md
Follow: `docs/AGENT_RULES.md`, `docs/repo_execution_rules.md`.

Task:
<one concrete objective>

Scope:
<explicit files/folders only>

Constraints:
- No blind repo scans.
- No infrastructure changes unless requested.
- Use canonical output policy (`results/<experiment>/runs/run_<timestamp>_<label>/`) for run artifacts.
- If MATLAB is needed, use wrapper only:
  `tools/run_matlab_safe.bat "<ABSOLUTE_PATH_TO_SCRIPT.m>"`.

Deliverables:
- <exact output files/paths>
- <brief required sections>

Definition of done:
- <verification checks>
```

## Recommended Deep Prompt Template

Use this for multi-part or higher-risk tasks:

```md
Documentation authority:
1) `docs/AGENT_RULES.md`
1a) `docs/infrastructure_laws.md` (infra topics)
1b) `docs/system_master_plan.md` (phase/trust/cross-module law)
2) `docs/results_system.md`
3) `docs/run_system.md`
4) `docs/repository_structure.md`
5) `docs/output_artifacts.md`
6) `docs/agent_prompt_exclude.md`

Task objective:
<business/analysis goal in 1-2 sentences>

Operational mode:
- Type: <analysis | infrastructure | documentation>
- Allowed writes: <exact directories/files>
- Forbidden actions: <MATLAB/no MATLAB, no structure refactors, no blind scan, etc.>

Canonical boundaries:
- Module: <Aging/Switching/Relaxation/cross-experiment>
- Canonical entrypoint(s): <path(s)>
- Non-canonical/deprecated sources to ignore: <paths>

Execution/artifact contract (if run requested):
- Wrapper-only execution command format.
- Required run artifacts and locations.
- `execution_status.csv` schema and run-root placement.
- `observables.csv` run-root exception.

Context loading policy:
- Include only docs explicitly needed for this task.
- Exclude bulk docs listed in `docs/agent_prompt_exclude.md` unless named.

Deliverables:
- <files with exact paths>
- <tables/report sections expected>

Verification:
- <doc-derived checks, lint/tests if relevant, and scope confirmation>
```

## Practical Prompting Guidance

- Start from minimal context and add references only when needed by task domain.
- Always declare precedence in long prompts to avoid contradictory document interpretation.
- Name canonical/non-canonical boundaries explicitly to prevent accidental use of deprecated paths.
- Encode run/artifact constraints directly in prompt instructions so output placement remains consistent.
- Separate “must” rules (contracts) from “historical evidence” (reports) in prompt wording.

## Documents Surveyed (Core + Explicit Follow-Ons)

Core set from task:
- `docs/system_entrypoint.md`
- `docs/AGENT_RULES.md`
- `docs/repo_execution_rules.md`
- `docs/infrastructure_laws.md`
- `docs/repo_context_minimal.md`
- `docs/repo_context_infra.md`
- `docs/system_master_plan.md`
- `docs/repository_structure.md`
- `docs/results_system.md`
- `docs/run_system.md`
- `docs/output_artifacts.md`
- `docs/system_registry.json`

Explicitly followed references (needed for this survey goal):
- `docs/io_validation_contract.md`
- `docs/canonical_switching_system.md`
- `docs/switching_canonical_definition.md`
- `docs/switching_canonical_direction.md`
- `docs/switching_canonical_reality.md`
- `docs/agent_prompt_exclude.md`
- `docs/context_bundle.json`
- `docs/execution_status_schema.md`
- `docs/templates/run_template.md`
- `docs/templates/audit_template.md`
- `docs/templates/fix_template.md`
- `docs/templates/plan_template.md`
