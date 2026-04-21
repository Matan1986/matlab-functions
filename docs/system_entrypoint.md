# System entrypoint

Start here. This file does not define behavior; it routes you to the documents that do.

---

## 1. What this system is

- **Switching (canonical):** A registered pipeline and channel-aware stability analysis, described normatively in the Switching canonical documents belowâ€”not in this file.
- **Validation and I/O:** Validation runs before I/O; I/O is read-only data access; pipeline logic follows. See [io_validation_contract.md](io_validation_contract.md).
- **Execution model:** MATLAB runs use the approved wrapper, run identity, and signaling artifacts as specified in the execution contracts belowâ€”not summarized here.

---

## 2. How to read the docs

| Kind | Role |
|------|------|
| **Contracts** | **Authoritative rules** for behavior, boundaries, and obligations. |
| **Overviews** | Explanations and orientation; not a substitute for contracts. |
| **Reports** | Evidence, audits, phase history, and snapshotsâ€”**not** source of truth for what the system must do. |

Precedence when documents overlap: [AGENT_RULES.md](AGENT_RULES.md) (section â€œDocumentation Precedenceâ€).

---

## 3. Core contracts (links only)

| Topic | Contract document |
|--------|-------------------|
| I/O and validation layering | [io_validation_contract.md](io_validation_contract.md) |
| MATLAB execution, wrapper, signaling | [repo_execution_rules.md](repo_execution_rules.md) |
| Infrastructure (run roots, manifest, fingerprints, entrypoints) | [infrastructure_laws.md](infrastructure_laws.md) |
| Switching system (pipeline, channel representation, `S_canonical` boundary) | [canonical_switching_system.md](canonical_switching_system.md) |
| Switching canonical definition (entrypoint, scope, model) | [switching_canonical_definition.md](switching_canonical_definition.md) |
| Channel representation (report-stored contract text) | [../reports/channel_representation_contract.md](../reports/channel_representation_contract.md) |

---

## 4. Switching system

| Need | Document |
|------|----------|
| Canonical pipeline and enforcement | [canonical_switching_system.md](canonical_switching_system.md) |
| Normative definition (entrypoint, observable, model) | [switching_canonical_definition.md](switching_canonical_definition.md) |
| Direction lock (single pipeline, channel awareness) | [switching_canonical_direction.md](switching_canonical_direction.md) |
| Table-backed factual survey (â€œrealityâ€ lens) | [switching_canonical_reality.md](switching_canonical_reality.md) |

---

## 5. Migration (readtable)

| Need | Document |
|------|----------|
| What changed and why (overview) | [readtable_migration_overview.md](readtable_migration_overview.md) |
| Decisions preserved for context | [readtable_migration_decisions.md](readtable_migration_decisions.md) |
| Closure / rollout evidence (report) | [../reports/readtable_migration_closure.md](../reports/readtable_migration_closure.md) |

---

## 6. Rule

**Only contract documents define required behavior.**

Reports (including audits, phase notes, and closure writeups) are **not** authoritative specifications. Use them as evidence and history after you know the contracts above.

---

## 7. How to navigate

| If you wantâ€¦ | Go toâ€¦ |
|----------------|--------|
| Validation vs I/O vs pipeline | [io_validation_contract.md](io_validation_contract.md) |
| Switching pipeline, channels, `S_canonical` | [canonical_switching_system.md](canonical_switching_system.md) |
| Registered Switching entrypoint and canonical scope | [switching_canonical_definition.md](switching_canonical_definition.md) |
| Execution wrapper, `-batch`, artifacts, signaling | [repo_execution_rules.md](repo_execution_rules.md) |
| Run folders, manifest, fingerprints, infra architecture | [infrastructure_laws.md](infrastructure_laws.md) |
| Agent safety limits and doc precedence | [AGENT_RULES.md](AGENT_RULES.md) |
| Run layout and artifact folders | [results_system.md](results_system.md), [run_system.md](run_system.md), [output_artifacts.md](output_artifacts.md) |
| Readtable migration narrative and decisions | [readtable_migration_overview.md](readtable_migration_overview.md), [readtable_migration_decisions.md](readtable_migration_decisions.md) |

