## A. Canonical Truth

- PT is canonical as a core component of the strict reconstruction workflow.
- Phi1 is canonical and source-enforced to one canonical run source in active phi1 pipelines.
- Canonical reconstruction is trusted under strict LOTO evidence with final model PT_PLUS_PHI1.
- Execution gate is enforced through wrapper preflight and runnable-script contract.

## B. Open Items

- Kappa1 is not fully closed: canonical usage exists, but robustness is flagged fragile and projection validation attempts are execution-invalid.
- Migration is open: migration pilots are defined but not completed; preservation verdicts are invalid.
- Replay formalization is open: same-input replay exists for phi2 reconciliation, but no repository-wide replay plan artifact is established.
- Source-of-truth ambiguity remains open: run-scoped canonical policy and root-level global narrative artifacts coexist with documented tension.

## C. Invalid / Stale / Partial Layers

- Stale class: root-level global report/table narratives that predate or bypass run-scoped canonical policy.
- Representative examples: global reports under reports/ versus run-local reports under results/<experiment>/runs/.
- Partial class: review/approval and registry completeness layers where many runs are pending review or unresolved.
- Representative examples: run review coverage gaps and unresolved run inventory.
- Invalid class: artifacts explicitly marked invalid due to definition contamination.
- Representative examples: aging measurement definition contamination artifacts marked not valid for aging interpretation.

## D. Current Repository Phase

canonical core established, cleanup and consolidation not complete

## E. Immediate Priority Order

1. canonical state freeze
2. cleanup list
3. source-of-truth rule
4. narrow kappa1 closure
5. targeted replay
6. resume migration

## F. Final Freeze Statement

### Frozen Current State

- PT is canonical as part of the trusted reconstruction core, but PT-only sufficiency is not supported.
- Phi1 canonical-source enforcement is active; non-canonical and mixed-source usage is blocked in enforced paths.
- Kappa1 is canonical-in-use but not closed; robustness remains fragile and projection validation is unresolved.
- Canonical reconstruction (PT_PLUS_PHI1) is valid under strict LOTO evidence.
- Execution gating is enforced by wrapper preflight and runnable-script contract.
- Migration is defined but not executed to a valid preservation verdict.
- Replay exists for phi2 reconciliation only; repository-wide replay formalization is still open.
- Root-vs-run consistency is unresolved; run-level evidence remains the authoritative conflict resolver.
