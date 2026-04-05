# Canonical Candidates Selection Report

## Summary

**Total scripts analyzed:** 111  
**Eligible scripts (RUN_CONTEXT=YES AND ROOT_DEPENDENCY=NO):** 0  
**Top 5 selected:** 0

## Findings

**Selection Criteria:**
- RUN_CONTEXT = YES
- ROOT_DEPENDENCY = NO

**Result:** Zero scripts meet both criteria.

### Structural Pattern Observed

- **All RUN_CONTEXT=YES scripts (42 total) have ROOT_DEPENDENCY=YES**
  - These scripts use createRunContext but depend on root-level setup
  - Example: `Switching/analysis/run_switching_canonical.m` (the only ENTRY_SIGNAL=YES script also has ROOT_DEPENDENCY=YES)

- **Only 1 script has ROOT_DEPENDENCY=NO:**
  - `Switching/analysis/run_width_interaction_closure_test.m`
  - But it has RUN_CONTEXT=NO (cannot be considered near-canonical)

## Next Steps

**Options to consider:**
1. Relax ROOT_DEPENDENCY requirement if deep dependency refactoring is acceptable
2. Target the 42 RUN_CONTEXT=YES scripts for dependency decoupling
3. Use `run_switching_canonical.m` as the template: it has ENTRY_SIGNAL=YES

**Recommended strategy:** Begin by decoupling `Switching/analysis/run_switching_canonical.m` (the most signaled script) from root dependencies, then use it as a pattern for others.

---
Generated: 2026-04-02
