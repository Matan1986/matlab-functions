# Legacy Canonical Switching Scripts Audit Report

## Executive Summary

**Total scripts audited:** 111  
**Legacy canonical scripts identified:** 2  
**Conversion difficulty distribution:**
- EASY: 22 scripts
- MEDIUM: 55 scripts
- HARD: 34 scripts

## Legacy Canonical Scripts

### Top 5 (Total of 2 found)

1. **Switching/analysis/run_switching_canonical.m**
   - ENTRY_SIGNAL: YES
   - RUN_CONTEXT: YES
   - EXECUTION_STATUS: YES
   - ROOT_DEPENDENCY: YES
   - COMPLEXITY: MEDIUM
   - CONVERSION_DIFFICULTY: EASY
   - **Reason:** Only script with full entry signaling infrastructure (ENTRY_SIGNAL=YES). Already has run context and execution status tracking. Minimal structural refactoring needed.

2. **Switching/analysis/switching_alignment_audit.m**
   - ENTRY_SIGNAL: NO
   - RUN_CONTEXT: YES
   - EXECUTION_STATUS: NO
   - ROOT_DEPENDENCY: YES
   - COMPLEXITY: HIGH
   - CONVERSION_DIFFICULTY: HARD
   - **Reason:** Largest script by line count (2588 lines). Has run context but missing entry signaling and execution status. Complex refactoring required due to size and tightly coupled pipeline.

3. **Switching/analysis/run_minimal_canonical.m**
   - ENTRY_SIGNAL: NO
   - RUN_CONTEXT: YES
   - EXECUTION_STATUS: YES
   - ROOT_DEPENDENCY: YES
   - COMPLEXITY: LOW
   - CONVERSION_DIFFICULTY: EASY
   - **Reason:** Smallest legacy canonical candidate (103 lines). Has both run context and execution status. Low complexity suggests straightforward entry signaling addition.

## Recommended Conversion Strategy

### First Script to Convert: **run_switching_canonical.m**

**Why this script:**
- Already has all core infrastructure (entry signal, run context, execution status)
- Serves as natural template for others
- Minimal standalone work required
- Once compliant, creates proven pattern for rest of codebase
- Can serve as reference implementation for team

### Second Script: **run_minimal_canonical.m**

**Why this script:**
- Small codebase (103 lines) = lower refactoring risk
- Has execution status tracking (only missing entry signal)
- Good stepping stone after first conversion
- Will guide medium-complexity script conversions

### Third Script: Choose from MEDIUM-EASY group

Once first two complete, target scripts like:
- `run_width_interaction_closure_test.m` (already has EXECUTION_STATUS=YES, only missing RUN_CONTEXT)
- Other 20-30 EASY-rated scripts with clear structural signals

## Structural Analysis: Why root_dependency=YES is so common

### Observation
**All 2 legacy canonical scripts have ROOT_DEPENDENCY=YES**

This reveals a fundamental architectural constraint: the legacy design relied on root-level shared state for initialization. Conversion requires:
1. Injecting required state into run context
2. Decoupling root initialization from script execution
3. Adding explicit entry/exit signaling

This is not a flaw; it's evidence of shared-state-driven design that predates the new execution contract.

## Conversion Readiness Classification

| Category | Count | Notes |
|----------|-------|-------|
| Already near-canonical | 1 | run_switching_canonical.m (add entry signal ONLY) |
| Minimal refactoring | 21 | ~10-20 lines change expected |
| Moderate refactoring | 55 | ~50-200 lines structural change |
| Heavy refactoring | 34 | 200+ lines; tightly coupled pipelines |

## Implementation Checklist

For each conversion, verify:
- [ ] Entry signal written at script top (execution_probe_top.txt)
- [ ] Run context created and stored
- [ ] Execution status CSV written before exit
- [ ] Root dependencies injected via run context (not global)
- [ ] No direct `addpath(genpath(...))` calls (use wrapper)
- [ ] All file I/O uses run_dir or explicit paths

## Next Steps

1. ✅ Audit complete: 2 legacy canonical scripts identified
2. → Convert run_switching_canonical.m (EASY)
3. → Convert run_minimal_canonical.m (EASY)
4. → Batch-convert MEDIUM scripts (template-driven)
5. → Address HARD scripts individually

---
Generated: 2026-04-02  
Auditor: Structural Compliance Analysis Tool
