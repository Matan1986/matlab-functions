# SW-ID-RESOLVER-F01B — Switching canonical identity governance decision

**Baseline:** F01A audit commit **`c64b683`** — `docs(maintenance): audit Switching identity resolver conflict`  
**Mode:** Governance decision only — **no code**, **no edits** to `tables/switching_canonical_identity.csv`, **no git operations**, **no MATLAB/Python/Node**.

## 1. Options compared (F01A → F01B choice)

| Option | Role in final policy |
|--------|----------------------|
| **OPT1** Track / un-ignore identity CSV | **Adopted** as the portable mechanism: `tables/switching_canonical_identity.csv` becomes a **tracked governance mirror** (see §3). |
| **OPT2** Doc/status alignment only | **Adopted as Stage F01C (mandatory first)** — cannot stand alone; clone reproducibility still requires OPT1 or OPT4. |
| **OPT3** Fail-closed resolver | **Adopted for canonical Switching consumers in Stage F01E** — silent mtime must not stand in for locked identity. |
| **OPT4** Generator from registry | **Optional alternative implementation** of the mirror: if used, generated CSV is **not** authoritative over `run_registry.csv`; generator must be deterministic from anchor row. |
| **OPT5** Registry-only resolver | **Partially adopted**: resolver logic should **prefer `analysis/knowledge/run_registry.csv` anchor row** as the declared canonical run id; identity CSV remains the **operational mirror** for humans/agents and fast path once tracked. Full resolver refactor without mirror is **deferred** unless mirror path fails. |

## 2. Canonical identity governance policy (single coherent story)

**Authoritative declared canonical run id for Switching identity routing**

- **`analysis/knowledge/run_registry.csv`** is the **authoritative registry row** for which run id is the **canonical identity anchor**: the unique row with role **`canonical_identity_anchor`** (currently `run_2026_04_03_000147_switching_canonical`, verified 2026-05-04 grep).
- **Caveat (preserved from `docs/project_control_board.md`):** the registry is a **query/discovery registry** and **not** a complete filesystem inventory of every run directory. Authority here is **nomination of the identity anchor**, not “every path that exists on disk.”

**Portable repo artifact**

- **`tables/switching_canonical_identity.csv`** is decided to be a **tracked governance mirror** of that anchor: same **`CANONICAL_RUN_ID`** as the registry anchor row; **`STATUS=LOCKED`** until an explicit owner procedure changes the anchor.
- It is **not** a second competing source of truth: on conflict, **`run_registry.csv` anchor row wins**; the identity CSV must be **reconciled** to match (regenerate or edit under change control).
- It is **not deprecated**; ignoring it in git was the defect F01A exposed.

**Latest / mtime fallback**

- **Not allowed** as **silent canonical** behavior for Switching identity or for resolving “canonical” `switching_canonical_*.csv` tables under the **canonical Switching** narrative.
- If any fallback remains for engineering convenience, outputs must be **explicitly labeled non-canonical / advisory / diagnostic** in caller contracts (Stage F01E design); **no** implicit equivalence to the locked run.

**Clean clone / missing identity file**

- Until the mirror is tracked (Stage F01D), clean clones **lack** the identity CSV — matching F01A “missing portable artifact.”
- **Policy after F01D+F01E:** for **canonical** analysis runners and audits, the resolver path must **fail closed** (error or hard stop) when identity cannot be resolved to the **registry anchor** and the anchored run-root artifact is missing — **or** must document an explicit **advisory-only** code path that cannot be mistaken for canonical (implementation in F01E, not here).

**Docs/status alignment**

- **`docs/project_control_board.md`** and **`tables/project_workstream_status.csv`** must use **consistent definitions**: distinguish **on-disk in workspace**, **tracked in git**, and **authoritative anchor in registry** (Stage F01C).

## 3. Explicit answers (task checklist)

| Question | Decision |
|----------|----------|
| Is `tables/switching_canonical_identity.csv` portable source-of-truth, generated mirror, or deprecated? | **Tracked governance mirror** of the registry anchor (optional future **generated** mirror per OPT4 only if it is clearly subordinate to registry). **Not** deprecated. |
| Is `analysis/knowledge/run_registry.csv` authoritative? | **Yes** for **which run id** is the **canonical identity anchor** (the `canonical_identity_anchor` row). Not repurposed as full filesystem inventory. |
| Is latest/mtime fallback allowed for canonical Switching? | **No** as silent canonical. Advisory/diagnostic only if explicitly labeled. |
| Missing identity in clean clone — fail closed or fallback? | **Fail closed** for canonical consumers after implementation; **until F01D**, behavior stays as today — documented as **unsafe for canonical claims**. |
| What docs/status must update? | **`docs/project_control_board.md`**, **`tables/project_workstream_status.csv`** (Switching row); optionally **`docs/AGENT_RULES.md`** / Switching resolver notes when F01E documents behavior. |
| What code changes allowed later? | Resolver and callers per Stage F01E; `.gitignore` exception + track mirror per F01D; optional generator per OPT4. |
| What is forbidden until a later charter? | Conflating **corrected-old manuscript authority** with resolver identity; **cross-module** closure or synthesis promotion changes; wholesale rewrite of **results routing** (F02) without identity policy landed. |

## 4. Implementation sequence (F01C / F01D / F01E — not executed here)

See `tables/maintenance_switching_identity_resolver_F01B_stage_plan.csv`.

**Summary**

1. **F01C — Documentation and status alignment** (no code): align definitions of present/missing/authoritative; update timestamps.
2. **F01D — Git portability of mirror**: `.gitignore` exception for `tables/switching_canonical_identity.csv` (or maintenance-approved path), commit mirror content aligned to registry anchor; document update protocol when anchor changes.
3. **F01E — Resolver and caller semantics**: remove or fence silent mtime canonical use; fail-closed or explicit advisory mode; tests/smoke as appropriate in later tasks.

## 5. Deliverables

- `tables/maintenance_switching_identity_resolver_F01B_policy.csv`
- `tables/maintenance_switching_identity_resolver_F01B_required_changes.csv`
- `tables/maintenance_switching_identity_resolver_F01B_stage_plan.csv`
- `tables/maintenance_switching_identity_resolver_F01B_status.csv`
