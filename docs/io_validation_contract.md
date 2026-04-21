# IO validation contract

This document defines **hard system rules** for validation, I/O, and pipeline behavior.

---

## Architecture

```
VALIDATION → IO → PIPELINE
```

**Definitions**

| Layer | Meaning |
|--------|---------|
| **VALIDATION** | Explicit pre-I/O checks only. No reading of pipeline outputs as input to “fix” I/O. |
| **IO** | Pure data access (`readtable` and equivalent read paths). |
| **PIPELINE** | All downstream logic after data are loaded. |

Data flow is one-way: validation authorizes a read; I/O loads bytes/tables; the pipeline consumes them.

---

## Hard rule

**`NO_ENFORCEMENT_IN_IO = TRUE`**

The I/O layer **must not**:

- validate (schema, types, ranges, row counts, column presence beyond what `readtable` itself does)
- reshape (squeeze, expand, pad, align dimensions)
- fix dimensions (`repmat`, padding tricks, forced vector/matrix shapes)
- apply defaults (fill missing, substitute values, implicit units)
- catch or suppress errors (empty `catch`, broad `try/catch` that hides load failures)

If something must be checked or corrected, it belongs in **VALIDATION** (before I/O) or **PIPELINE** (after a successful read), not inside I/O.

Violating this contract is considered a SYSTEM-LEVEL ERROR and must not be introduced in future changes.

---

## Validation rules

- Validation runs **only before I/O**.
- Validators are **explicitly named** (e.g. `local_*_input_ok` or project conventions that match this intent).
- Failures must **surface**: no `try/catch` that masks validation or load failures.

---

## Failure model

If a failure occurs **after** validation has passed and I/O has completed successfully:

- Treat it as a **PIPELINE** issue (assumptions, algorithms, downstream contracts).
- It is **not** attributed to validation having “missed” something that I/O should have enforced.
- It is **not** attributed to I/O unless the failure is literally a read/parse error that validation could not have anticipated without duplicating pipeline semantics.

---

## Anti-patterns (explicit)

Avoid:

- **`try/catch` around `readtable`** (or equivalent) to swallow errors or substitute empty data.
- **`repmat` (or similar) fixes** inside I/O to force shapes.
- **Silent fallbacks** (default paths, empty tables, guessed columns).
- **Duplicate validation downstream** that re-implements pre-I/O checks in a second, inconsistent way.
- **Multi-source validation in thin validators** — validators that must consult many unrelated sources or cross-cutting state are not “thin” and blur the contract; keep pre-I/O checks local and explicit, and push complex coupling to the pipeline or dedicated modules.

---

*This contract is documentation of intended system behavior for the readtable migration and future changes.*
