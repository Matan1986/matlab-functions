# Module Alias Registry

## Purpose
This registry defines policy-level mapping between source module folder names and stable artifact aliases.
This is alias governance only and does not rename physical directories.

## Policy-Only Alias Mapping
| source_module_folder | artifact_alias | status | notes |
|---|---|---|---|
| `Switching/` | `switching` | active | use alias in artifact destinations |
| `Aging/` | `aging` | active | use alias in artifact destinations |
| `Relaxation ver3/` | `relaxation` | active | versioned source name maps to stable alias |
| `MT ver2/` | `mt` | active | current repo source folder for MT alias |
| `MT/` | `mt` | reserved-if-present | apply only if folder appears in future |

## Alias Usage Contract
Artifact paths should use lowercase stable aliases under:
- `results/<alias>/`
- `tables/<alias>/`
- `reports/<alias>/`
- `figures/<alias>/`

## Physical Rename Clarification
Alias mapping is policy-only in this phase.
No physical folder rename is authorized or implied by this registry.

## MT Ambiguity Tracking
Current state: `MT ver2/` exists and `MT/` is not present, so no active ambiguity is open now.
If both `MT/` and `MT ver2/` exist simultaneously, alias ambiguity must be logged as unresolved until ownership and routing policy are explicitly reconciled.
