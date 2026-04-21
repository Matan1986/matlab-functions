# Analysis Module Reconstruction and Canonicalization Playbook

---

## DOCUMENT USAGE WARNING

This document is NOT a plug-and-play workflow and must NOT be executed as a linear procedure.

Some steps were executed once and must not be repeated.
Some conditional steps may overwrite tables, reports, or auxiliary state.

Always verify repository state before applying any step.

If unsure whether a step has already been executed, assume it HAS and verify before re-running anything.

---

## 1. Purpose

This document defines a **controlled workflow** for repairing and canonicalizing analysis modules that already contain **non-canonical, unstable, or inconsistent analysis**.

This document provides guidance and structure, not an executable procedure.
Steps should be applied selectively and with understanding of the current repository state.

It is based on the full set of actions performed while repairing the first module (**Switching**), and is intended to be reused for:

* Aging
* Relaxation

---

## 2. Scope

### Applies to:

Modules that already contain analysis which is:

* unstable
* inconsistent
* not reproducible
* mixing logic and artifacts

Examples:

* Switching (completed)
* Aging (pending)
* Relaxation (pending)

---

### Does NOT apply to:

Modules without prior analysis.

These should follow a **separate canonical-first workflow** (not defined here).

---

## 3. Core Principles

* Run = truth
* Tables / reports = evidence
* Classification before interpretation
* No fixing before full system understanding
* No mixing between:

  * canonical
  * non-canonical
  * experimental
  * artifacts

---

---

## X. Execution Boundary & Contract (CRITICAL ADDITION)

### Purpose

Define the **true execution semantics boundary** of the system.

This layer clarifies:

* where execution begins
* where determinism is enforced
* who owns ordering, IO, and run identity

---

### Key Principle

Execution correctness is not guaranteed by infrastructure components alone.

It depends on a **well-defined boundary** between:

* PRE_MATLAB layer
* MATLAB execution layer
* POST execution layer (if exists)

---

### Definitions

#### PRE_MATLAB Layer

Includes:

* file discovery
* ordering
* batching
* environment setup
* run_dir creation

This layer may affect:

* ordering
* IO structure
* determinism

---

#### MATLAB Layer

Includes:

* data loading
* processing
* observable extraction
* output writing
* manifest / fingerprint generation

---

#### POST Layer (if exists)

Includes:

* aggregation
* validation extensions
* reporting extensions

---

### Critical Insight

❗ Infrastructure phases (0–5) establish components
❗ But do NOT fully define execution ownership

Therefore:

> Execution boundary must be explicitly understood before any optimization or restructuring

---

### Risks Without Boundary Definition

* hidden state dependencies
* ordering instability
* IO race conditions
* silent determinism break
* invalid optimization assumptions

---

### Relationship to Existing Phases

* Phase 2 → establishes execution trust components
* Phase 4 → validates execution behavior
* Phase 5G → defines contracts (PARTIAL)

This section **completes the missing layer**:

👉 explicit execution boundary definition

---

### Operational Rule

Before:

* optimization
* parallelization
* restructuring

You MUST ensure:

EXECUTION_BOUNDARY_DEFINED = YES

---

### Classification

TYPE: GLOBAL
STATUS: REQUIRED FOR SAFE OPTIMIZATION
DO NOT SKIP BEFORE PHASE 7.5E

---

SUCCESS CONDITION:

* clear ownership of ordering
* clear ownership of IO
* no ambiguity in execution flow

---

## X+1. Controlled Investigation Exception — MATLAB Startup Latency

### Purpose

Allow a **strictly controlled investigation** of MATLAB startup latency identified during Phase 7.5E-LITE.

This investigation is permitted because:

* startup time (~20–25s) is a **dominant execution cost**
* it affects all future phases, including Phase 8
* it is independent of analysis logic

---

### Scope

This step allows:

* measurement of MATLAB startup time
* investigation of startup.m behavior
* analysis of path loading overhead
* identification of root causes

---

### Strict Limitations

This step is:

* READ-ONLY
* MEASUREMENT ONLY

It MUST NOT:

* modify execution model
* introduce persistent sessions
* introduce batching
* modify wrapper or guard
* modify execution contract

---

### Classification

TYPE: CONTROLLED EXCEPTION
SCOPE: PHASE 7.5 ONLY
DOES NOT CHANGE PHASE ORDER

---

### Rationale

This investigation is allowed **before Phase 8** because:

* it addresses a confirmed system-wide bottleneck
* it does not affect execution semantics
* it does not violate execution contract

---

### Exit Condition

* startup latency is understood
* optimization opportunities are identified (but not implemented)

---

### Extended Scope — Targeted Performance Investigation

In addition to MATLAB startup latency, the following targeted investigations are permitted under the same constraints:

* data loading cost (e.g., repeated load() operations, large tables)
* repeated re-computation of identical intermediates
* loop structure inefficiencies (e.g., nested loops, repeated work inside loops)

---

### Environment Contamination Discovery & Mitigation

During Phase 7.5E-INV (startup and performance investigation), a critical environment-level issue was discovered:

* MATLAB global state (startup.m, savepath)
* uncontrolled path injection
* function shadowing (e.g., load.m overriding MATLAB built-in)

---

### Key Insight

Execution-layer correctness (Phases 0–5) was successfully established, but:

```text
environment isolation was not guaranteed
```

This revealed a missing layer in the system design:

```text
Environment Isolation Layer
```

---

### Impact

* Does NOT invalidate canonical runs or scientific results
* DOES invalidate measurement and performance attribution
* Introduces risk of non-deterministic behavior in future phases

---

### Resolution Actions

A controlled fix was applied:

* startup.m side effects neutralized (non-destructive)
* global path reset
* shadowing removed (e.g., load.m renamed)
* temporary probe artifacts cleaned

---

### Updated Principle

```text
No measurement is valid without environment isolation
```

---

### System Update

The system definition is extended:

Before:

```text
system = pipeline + artifacts
```

After:

```text
system = pipeline + artifacts + environment control
```

---

### Classification

TYPE: GLOBAL DISCOVERY
SCOPE: Phase 7.5E-INV
DOES NOT CHANGE PHASE ORDER

---

### Exit Condition

* STARTUP_CLEAN = YES
* SHADOWING_DETECTED = NO
* SYSTEM_CLEAN = YES

---

### Constraints (Same as Above)

These investigations MUST remain:

* READ-ONLY
* MEASUREMENT ONLY

They MUST NOT:

* modify execution model
* introduce caching
* introduce batching
* introduce parallelization
* modify wrapper, guard, or execution contract

---

### Purpose

These checks are allowed because they:

* may reveal dominant costs affecting Phase 8
* do not depend on scientific logic
* do not alter execution semantics

---

### Exit Condition

* major performance characteristics are understood
* potential bottlenecks are identified (but not implemented)

---

## 4. CRITICAL WARNING

> This document is NOT a script.

```text
DO NOT re-execute phases blindly.
```

Before applying any step:

1. Verify whether it already exists
2. Verify whether it is already correct
3. Only then decide whether action is required

⚠️ Any step or script that writes to `tables/*` or `reports/*` should be assumed to overwrite existing outputs unless explicitly documented otherwise.

---

## 5. Phase Classification

Each phase is marked as:

* **ONCE** — must not be repeated
* **CONDITIONAL** — run only if needed
* **PER-MODULE** — must be applied per module

---

## 6. What Was Executed (Switching Module)

---

### Phase 0 — Problem Recognition

**TYPE: ONCE**

* System contained mixed:

  * truth
  * experiments
  * artifacts
* No reliable scientific state

---

### Phase 1 — Execution Stabilization

**TYPE: ONCE**

* Introduced execution wrapper
* Eliminated silent failures
* Unified execution status

---

### Phase 2 — Execution Identity & Determinism

**TYPE: ONCE**

* run_dir defined
* manifest introduced
* fingerprint introduced
* ensured:

  * reproducibility
  * no hidden state

⚠ DO NOT RE-IMPLEMENT

---

### Phase 3 — System Reality Audit

**TYPE: ONCE**

* analyzed:

  * execution graph
  * IO flow
  * dependencies
  * failure modes

---

### Phase 4 — Canonical Isolation

**TYPE: ONCE**

* defined:

  * canonical entrypoint
  * backend
  * boundaries
* separated:

  * canonical vs non-canonical

Rule:
Canonical = declared, not inferred

---

### Phase 5 — Formalization + Gap Detection

**TYPE: ONCE**

* introduced:

  * contracts
  * rules
  * enforcement
* identified gaps
* created backlog

Status:
SYSTEM = CONTROLLED (NOT SEALED)

---

### Phase 6 — Scientific Formalization

#### Phase 6A — Canonical Core Validation (ACTUAL)

During the Switching module work, Phase 6 was NOT executed as full reconstruction.

Instead, the following was completed:

- identification of canonical core components
- definition of canonical entrypoint
- validation of canonical pipeline correctness
- verification that canonical-labeled outputs satisfy criteria:
  - SINGLE_SOURCE_RUN
  - FIXED_PIPELINE
  - PARAMETER_FREE
  - REPRODUCIBLE

Result:

CANONICAL_CORE_VALIDATED = YES
FULL_RECONSTRUCTION_COMPLETED = NO

Interpretation:

Phase 6 was realized as a preparation stage,
establishing a trustworthy canonical base rather than rebuilding all analyses.

---

#### Phase 6A — Inventory

**TYPE: CONDITIONAL**

* identified analysis units
* detected unknown regions

---

#### Phase 6B — Classification

**TYPE: CONDITIONAL**

Assigned:

* type
* authority
* role

---

#### Phase 6C — Scientific State

**TYPE: CONDITIONAL**

Assigned:

* scientific_state
* risk
* action

---

#### Audit 1 — Integrity Audit

**TYPE: CONDITIONAL**

Validated:

* consistency across 6A → 6B → 6C

---

#### Phase 6B — Full Analysis Reconstruction (DEFERRED)

The original intent of Phase 6 includes:

Rebuild all analyses canonically

However, this step was intentionally NOT executed during the Switching stabilization effort.

Reason:

- Phase 7-8 infrastructure work (execution trust and batching) was prioritized
- Full reconstruction on unstable or inefficient execution would be unreliable

Current status:

FULL_ANALYSIS_RECONSTRUCTION = NOT_STARTED

This phase is expected to occur AFTER:

- Phase 7 (execution trust) completion
- Phase 8 (execution system realization)

Interpretation:

Phase 6B represents the future reconstruction of:

- Φ₁
- κ₁
- residual decomposition
- observables
- all analysis outputs

as functions of canonical S(I,T).

---

#### Phase 6 — Actual Status Clarification

PHASE6_DEFINED = YES
PHASE6_PARTIALLY_EXECUTED = YES

Breakdown:

- Phase 6A (canonical core validation) = DONE
- Phase 6B (full reconstruction) = NOT DONE

Conclusion:

The system currently contains a verified canonical foundation,
but the full analysis stack has not yet been reconstructed on top of it.

---

## 7. Current System State

The system now contains:

* one canonical truth layer (execution)
* support layers (validation / audit / registry)
* unknown units (not yet resolved)
* isolated noise

Infrastructure already exists:

* execution wrapper
* manifest system
* fingerprint
* validation

```text
DO NOT recreate infrastructure components
```

---

## 8. What Must NOT Be Repeated

The following are **ONCE operations**:

* execution system creation
* identity system (manifest / fingerprint)
* canonical boundary definition
* infrastructure-level fixes

Recreating them may:

* break the system
* create duplication
* corrupt truth tracking

⚠️ Re-running infrastructure-level steps (execution system, identity system, registry definitions) may break the system or create conflicting state.

---

## 9. What Must Be Applied Per Module

The following must be applied for each module:

* reconstruction of analysis logic
* separation of canonical vs non-canonical
* validation of outputs
* classification and state assignment

---

## 10. Planned Phases (NOT YET EXECUTED)

---

### Phase 6D — System & Authority Formalization

**TYPE: GLOBAL (ONCE)**

Define:

* artifact types:

  * run
  * table
  * report
  * snapshot
  * view

* source-of-truth hierarchy

* allowed vs forbidden usage

---

### Phase 7 — Controlled Resolution

---

#### 7A — UNKNOWN Resolution

**TYPE: PER-MODULE**

* resolve unknown units
* no physics inference
* no deletion

---

#### 7B — NOISE Audit

**TYPE: GLOBAL**

* distinguish:

  * noise
  * residue
  * duplicated signal

---

#### 7C — Backlog Integration

**TYPE: GLOBAL**

* integrate Phase 5 backlog
* decide:

  * FIX
  * DISCARD
  * REDEFINE
  * KEEP

---

#### 7D — Controlled Cleanup

**TYPE: GLOBAL**

Only after:

* classification ✔
* authority ✔
* state ✔

---

### Phase 8 — Scientific System Closure

* unified scientific system
* validated truth + support layers
* ready for:

  * reconstruction
  * prediction
  * publication

Phase 8 assumes:
- execution model supports batching
- startup is no longer dominant per logical run

### Consistency Note — Phase Ordering vs Execution Reality

Original plan:

Phase 6 -> reconstruction
Phase 7 -> execution trust
Phase 8 -> execution system

Actual execution:

Phase 6A -> canonical core validation
Phase 7 -> execution trust
Phase 8 -> execution system
Phase 6B -> deferred reconstruction

Interpretation:

Execution order was adjusted to ensure that reconstruction occurs on a stable,
deterministic, and efficient system.

---

## Phase 7 — Execution Model Resolution & System Efficiency (ACTUAL)

### 7.5 — Performance & Environment Layer Discovery

Observed and confirmed:

- startup dominance identified (~57-87s startup vs ~20s compute)
- environment contamination discovered:
  - startup.m side effects
  - path pollution
  - shadowing (load.m)

Resolution applied:

- restoredefaultpath
- shadow removal
- environment isolation

```text
SYSTEM_REGIME = STARTUP_DOMINATED
SYSTEM_CLEAN = YES
```

### 7.6 — Execution Model Resolution (CRITICAL)

Core conclusion:

- primary bottleneck was not compute alone; it was execution model overhead
- target execution model was defined:

```text
STATELESS_BATCHED_EXECUTION
```

Completed stages:

| stage | description |
| ----- | ----------- |
| 7.6A | execution model analysis |
| 7.6B | safe design |
| 7.6C | policy delta |
| 7.6D | approval proposal |

```text
SAFE_EXECUTION_MODEL_EXISTS = YES
POLICY_DELTA_DEFINED = YES
APPROVAL_READY = YES
```

### 7.7 — Controlled Implementation & Validation

Implementation (7.7B):

- minimal change
- entrypoint-only modification
- wrapper unchanged
- optional batch path

Validation (7.7C):

```text
BATCH_SIZE_1_EQUIVALENT = YES
STATE_LEAKAGE = NO
ORDER_DEPENDENCE = NO
BATCH_DETERMINISTIC = YES
ARTIFACT_SEPARATION = YES
ROLLBACK_WORKS = YES
VALIDATION_PASSED = YES
```

### Phase 7 Conclusion

```text
SYSTEM_READY_FOR_SCALE = YES
EXECUTION_MODEL = BATCHED_SAFE
```

---

### Consistency Audit Addendum (Phase 7 Actual)

This addendum records legacy assumptions that are now outdated relative to completed Phase 7.6-7.7 work:

```text
OUTDATED_ASSUMPTION = YES
POLICY_MISMATCH = YES
```

Outdated in-document assumptions identified:

- historical investigation constraints that forbid batching in `X+1` were valid for measurement-only scope and are not the final post-implementation state
- planned-only framing of Phase 7 no longer reflects actual completed execution-model resolution and controlled implementation

Execution boundary clarification:

- PRE_MATLAB retains discovery/order/environment responsibilities
- batching now occurs inside MATLAB entrypoint
- NOT wrapper orchestration

### Phase 7 Closure Addendum (FINAL — Post 7.8E/7.8F/7.8G)

#### Purpose

This section records the **actual final closure state of Phase 7** after complete verification.

It replaces any implicit assumption that Phase 7 closure is achieved solely through:

* execution validation
* backlog reconciliation
* partial guarantees

---

#### Core Principle

System closure is defined by:

absence of critical failure modes

NOT by:

full backlog alignment

---

#### Final Closure Verification (Phase 7.8E-R)

The system was explicitly verified against the only four critical failure modes:

1. SHARED_STATE
2. FAILURE_LEAKAGE
3. ORDER_DEPENDENCE
4. ARTIFACT_INTEGRITY

Final verified state:

SHARED_STATE = NO
FAILURE_LEAKAGE = NO
ORDER_DEPENDENCE = NO
ARTIFACT_INTEGRITY = NO
SYSTEM_CLOSED = YES

---

#### Supporting Fixes (Phase 7.8F)

Closure required two minimal, localized fixes:

* removal of global MATLAB appdata from canonical execution path
* conversion of all canonical artifact writes to atomic write pattern (temp → commit)

No architectural or execution-model changes were introduced.

---

#### Shared State Proof (Phase 7.8G)

A static call-graph trace verified:

CANONICAL_SHARED_STATE = NO

No reachable global appdata usage exists in canonical execution.

---

#### Backlog Alignment Clarification

Backlog reconciliation remains:

BACKLOG_ALIGNMENT = PARTIAL

This does NOT block Phase 8, because:

* backlog represents governance and coverage
* closure is determined by system-level guarantees

---

#### Final Gate Decision (Phase 7.9 Basis)

PHASE7_INFRA_CLOSURE = YES
SYSTEM_CLOSED = YES
PHASE8_ENTRY_ALLOWED = YES

---

#### Interpretation

The system is now:

* deterministic
* isolated
* artifact-safe
* free of shared state

and is therefore safe for Phase 8 execution.

---

---

## 11. Hard Rules (DO NOT BREAK)

* no phase jumping
* no fixing before understanding
* no canonical inference
* no mixing layers
* no system modification during audits
* If unsure whether a step was already executed, assume it was and verify before re-running

---

## 12. Final Statement

This playbook transforms a module from:

> unstable, mixed, and unreliable analysis

into:

> a structured system with explicit separation between
> canonical truth, support, unknown, and noise

---

END

### Phase 7.9 — Empirical Failure Propagation Completion (FINAL)

Following Phase 7.9.2F:

* A canonical pipeline failure was executed via the wrapper
* execution_status.csv was written at run scope
* EXECUTION_STATUS = FAILED was recorded
* ERROR_MESSAGE was populated
* a report artifact was generated
* wrapper exit code correctly reflected failure

Final empirical verdict:

FAILURE_PROPAGATION_PROVEN = YES

This resolves the previous empirical gap noted in Phase 7.9.

---

### Updated Final Closure State

SYSTEM_CLOSED = YES (STRUCTURAL + EMPIRICAL)

PHASE7_FULL_CLOSURE = YES

PHASE8_ENTRY_ALLOWED = YES (CONFIRMED)

---

### Interpretation

The system is now:

* deterministically executable
* failure-safe (no silent success)
* artifact-consistent
* empirically verified under real execution conditions

This completes Phase 7 closure.

---

### Phase 7.10 — Execution Efficiency Preparation (PRE-PHASE 8)

#### Purpose

Ensure that the system can execute large-scale canonical analysis efficiently, without introducing execution bottlenecks that may interfere with scientific work.

---

#### Rationale

Phase 7 guarantees correctness and trust.

Phase 8 introduces heavy analysis workloads.

Therefore, a minimal preparation step is required to ensure:

* execution overhead is controlled
* batching behavior is well understood
* data loading and recomputation costs are identified

---

#### Scope

This phase is:

* measurement-focused
* minimal
* non-invasive

It MUST NOT:

* modify execution model
* modify wrapper
* change pipeline semantics

---

#### Key Checks

* startup overhead vs compute time
* batching effectiveness (as implemented in Phase 7.6–7.7)
* repeated IO or recomputation hotspots

---

#### Exit Condition

SYSTEM_EFFICIENCY_UNDERSTOOD = YES

---

#### Interpretation

This phase does not replace Phase 8.

It ensures that Phase 8 can execute smoothly, without performance-related ambiguity or instability.

---

## Phase 8 - Execution System Realization (ACTUAL)

POST-PHASE 8 / ACTUAL STATE

PHASE8_IMPLEMENTED = YES
SYSTEM_EXECUTION_MODE = BATCHED
EXECUTION_REGIME = STARTUP_ELIMINATED

Phase 8 is implemented as an operational execution system, not a theoretical future state.

Execution batching was moved into the MATLAB entrypoint.
The wrapper remains unchanged.
Execution now supports multiple tasks per MATLAB session.

## Phase 8.X - Task System (ACTUAL)

POST-PHASE 8 / ACTUAL STATE

TASK = DECLARED EXECUTION UNIT

The task abstraction is formalized and explicit.

A task is defined by:

* parameters (for example temperature)
* expected outcome

Tasks are no longer treated as loop values.
Tasks are explicit, traceable execution entities.

## Phase 8.X - Artifact-Driven Execution Model

POST-PHASE 8 / ACTUAL STATE

EXECUTION = FUNCTION(TASK_SPEC)

Extended model:

EXECUTION = FUNCTION(TASK_SPEC, SELECTION_SPEC)

Task specification is stored in CSV artifacts.
Execution reloads from artifacts.
There is no hidden task-selection logic in code.

## Phase 8.X - Task Selection Layer (ACTUAL)

POST-PHASE 8 / ACTUAL STATE

TASK_SPEC = FULL UNIVERSE
SELECTION_SPEC = EXECUTION SLICE

Selection is deterministic filtering over the full task universe.
Subset execution is supported without modifying the full task specification.

EXECUTION_SUPPORTS_SUBSET = YES
SCALABLE_WORKLOAD_CONTROL = YES

## Phase 8.X - External Selection Specification (ACTUAL)

POST-PHASE 8 / ACTUAL STATE

SELECTION_SPEC = CSV ARTIFACT

Selection is no longer code-embedded.
Selection is reproducible as an external artifact.
Execution is fully artifact-driven.

## Phase 8 - System Capability Transition

POST-PHASE 8 / ACTUAL STATE

Before:

SYSTEM = TRUSTED BUT LIMITED EXECUTION

After:

SYSTEM =
✔ batched
✔ deterministic
✔ artifact-driven
✔ sliceable
✔ failure-local
✔ scalable

## Phase 8 - Scientific Readiness State

POST-PHASE 8 / ACTUAL STATE

SYSTEM_READY_FOR_EXPERIMENTS = YES

The system can run subsets, define experiments through artifacts, and execute new runs without code modification.

## Execution Identity (UPDATED)

POST-PHASE 8 / ACTUAL STATE

Execution identity is now defined as:

RUN = FUNCTION(TASK_SPEC, SELECTION_SPEC)

Run identity now depends on:

* task universe
* selection
* execution model

## Consistency Addendum - Phase 8 Actual

POST-PHASE 8 / ACTUAL STATE

OUTDATED_ASSUMPTION = YES
POLICY_MISMATCH = YES

Outdated assumptions clarified:

* per-script execution is no longer dominant
* execution is no longer single-task
* selection is no longer code-driven

## Phase 8 Closure (FINAL)

POST-PHASE 8 / ACTUAL STATE

PHASE8_CLOSED = YES

SYSTEM =
✔ deterministic
✔ batched
✔ artifact-driven
✔ sliceable
✔ failure-safe
✔ scalable
✔ experiment-ready

