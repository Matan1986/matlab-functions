# Aging — Contract validation rules (F6T)

**Version:** F6T-1.0  
**Status:** Design for future validator implementation (F6U+).  
**Binding policy:** F6S tables and `aging_F6S_validation_rules.csv` remain normative; this document **operationalizes** checks and severities for tooling.

## Rule shape (every check)

Each check, when triggered, must emit:

1. **what failed** (machine and human readable)  
2. **why it matters** (link to namespace / wrong-claim risk)  
3. **how to fix it** (concrete: column rename, sidecar field, registry row)  
4. **quarantine vs reject** (whether `legacy_quarantine` is an allowed outcome in the current mode)

## Severity model

- **ERROR:** Fails validation in modes that enforce the rule; may still be **quarantined** in `audit_only` or labeled in output status.  
- **WARNING:** Never blocks in `audit_only` or `migration` (except when configured as promotion to ERROR for strict consumers).  
- **INFO:** Traceability and suggestions only.

## Mode gating (summary)

| Check class | audit_only | migration | strict |
|-------------|------------|-----------|--------|
| Unresolved plain `Dip_depth` in tau/R | WARN + label | ERROR for new tau/R writes | ERROR |
| S4A/S4B merge without bridge | WARN | ERROR on merge | ERROR |
| Cross-run compare without identity | WARN | ERROR on compare op | ERROR |
| Pooled table without sidecar | WARN + label | ERROR on new pool | ERROR |
| Legacy no sidecar | INFO/WARN, quarantine label | Read allowed as evidence | Not canonical input |

## Output artifacts (validator)

Machine-readable rows (CSV or JSONL) should include at minimum:

- `check_id`, `severity`, `path`, `row_or_column`, `message`, `suggested_fix`, `quarantine_eligible`, `validation_mode`

## Cross-reference

Full check list: `tables/aging/aging_F6T_validation_checks.csv`.  
Modes: `tables/aging/aging_F6T_validation_modes.csv`.
