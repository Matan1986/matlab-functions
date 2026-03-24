# Claims System Verification

## Evidence

- Claims JSON is explicitly read and parsed in:
  - `C:\Dev\matlab-functions\tools\survey_builder\build_rolling_surveys.m`
    - `claimsDir = fullfile(repoRoot, 'claims');` (line 20)
    - `claims = loadClaims(claimsDir);` (line 35)
    - `claimFiles = dir(fullfile(claimsDir, '*.json'));` (line 170)
    - parses claim fields: `claim_id` (line 182), `statement` (line 183), `source_runs` (line 185), `related_surveys` (line 186)
  - `C:\Dev\matlab-functions\tools\run_review_audit.ps1`
    - `Get-ClaimIndex` function (line 388)
    - reads `claims/*.json` via `Get-ChildItem ... -Filter *.json` (line 398)
    - parses `claim_id` (line 405) and `source_runs` (lines 407-408)
  - `C:\Dev\matlab-functions\tools\claims\list_claims.m`
    - reads `claims/*.json` (line 21)
    - parses `claim_id`, `status`, `statement`, `source_runs`, `related_surveys` (lines 52-56)

- Current repository content check:
  - `C:\Dev\matlab-functions\claims\` currently contains only `README.md` (no `*.json` claim files present at audit time).

## Execution Trace

- These are standalone tooling entry points; they are executable when invoked directly:
  - `tools/survey_builder/build_rolling_surveys.m`
  - `tools/run_review_audit.ps1`
  - `tools/claims/list_claims.m`

- Reference search found no callers from `scripts/`, `analysis/`, or other main entrypoint scripts into these claim loaders.
  - `build_rolling_surveys` appears only in its own file.
  - `list_claims(` appears only in its own file.
  - `run_review_audit.ps1` appears only as self-reference text inside that script.

## Bundle Integration

- `docs/context_bundle.json` does **not** include claims content.
  - It includes run-system and repo-state references (for example `run_manifest.json`, `docs/repo_state.json`) but no `claims`, `claim_id`, `source_runs`, or `related_surveys`.
- Bundle generation script `C:\Dev\matlab-functions\scripts\update_context.ps1` reads only:
  - `docs/repo_state.json`
  - `docs/model/repo_state_description.json`
  - `docs/model/repo_state_full_description.json`
  - and writes `docs/context_bundle.json` / `docs/context_bundle_full.json`.

## Agent Entry / Visibility

- Agent docs require reading `docs/context_bundle.json`:
  - `C:\Dev\matlab-functions\docs\AGENT_ENTRYPOINT.md:1`
  - `C:\Dev\matlab-functions\docs\AGENT_RULES.md:117-118`
- Therefore claims are not exposed through the required context bundle path.
- Snapshot packaging (`C:\Dev\matlab-functions\scripts\run_snapshot.ps1`) builds `core_infra` from root directories not in explicit exclusions; this likely carries `claims/` in snapshot artifacts, but this is packaging visibility, not context-bundle consumption.

## Final Verdict

**claims/ is ACTIVE**

Rationale: repository code does read and parse `claims/*.json` in active tooling paths (`survey_builder`, `run_review_audit`, `list_claims`).  
It is **not** part of the mandatory agent context bundle path, but it is still an executable, integrated subsystem and therefore not safe to classify as LEGACY/remove.

## Bundle Claims Consistency Check

### Bundles discovered

- docs/context_bundle.json
- docs/context_bundle_full.json

### Claims presence per bundle

- docs/context_bundle.json
  - claims key present: yes
  - claims count: 6
  - claim fields present per entry: claim_id, statement, status, role, confidence
  - duplicate claim_id values: none
- docs/context_bundle_full.json
  - claims key present: no
  - claims count: 0

### Duplication check

- Structural duplication of claims payload
  - No duplicate claims array under another key in docs/context_bundle.json.
  - No claim_id keys outside the claims array in docs/context_bundle.json.
- Semantic duplication of claim ideas outside claims array (explicitly checked)
  - Idea: X canonical coordinate definition appears outside claims
    - docs/context_bundle.json state.observable_definitions.X.definition
    - docs/context_bundle.json model.core.observables_meaning.X.definition
    - docs/model/repo_state_description.json observables_meaning.X.definition
    - docs/model/repo_state_full_description.json modules.Switching.notes and observable_definitions.X.formula
  - Idea: scaling relation A ~ X^beta appears outside claims
    - docs/context_bundle.json state.cross_experiment_physics.main_bridge.relation
    - docs/context_bundle.json model.core.cross_experiment_relations.main_bridge.relation
    - docs/model/repo_state_description.json cross_experiment_relations.main_bridge.relation
    - docs/model/repo_state_full_description.json cross_experiment_physics.main_bridge.relation
  - Idea: canonical wording for relaxation observable appears in both state/model layers
    - docs/context_bundle.json state.observable_definitions.A.definition
    - docs/context_bundle.json model.core.observables_meaning.A.definition

### Source of truth check

- claims files are present in claims directory and act as the intended authority source.
- Bundle generation script scripts/update_context.ps1 does not load claims or claims directory.
- Therefore current claims in docs/context_bundle.json are static copied content, not dynamically propagated from claims files.

### Generation pipeline check

- scripts/update_context.ps1 automatically builds docs/context_bundle.json and docs/context_bundle_full.json from:
  - docs/repo_state.json
  - docs/model/repo_state_description.json
  - docs/model/repo_state_full_description.json
- claims integration is not automated in this pipeline.

### Consistency between bundle variants

- docs/context_bundle.json and docs/context_bundle_full.json are inconsistent for claims.
- Full bundle does not carry the claims layer currently present in minimal bundle.

### Final verdict

BROKEN

Reason: claims are not consistently propagated across bundle variants, claims are not generated from a single automated source of truth in claims files, and major claim ideas are semantically duplicated in multiple non-claims sections.
