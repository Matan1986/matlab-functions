# Phi2 second-order deformation test

## Method
- **Recompute**: `switching_residual_decomposition_analysis` only (no reuse of prior CSV conclusions).
- **Normalization**: Phi2 raw on fit mask; basis columns unit-L2 on mask; LSQ `X \\ t` in unit-Phi2 space; metrics reported on **raw** Phi2 scale except `rmse_unit`.
- **Mask**: `edgeExclude = 2` grid points removed at each end for derivative stability.

## Basis families
- **First-order (A)**: `dPhi1/dx`, `x*Phi1`.
- **Pure second-order (B)**: `d2Phi1/dx2`, `x*dPhi1/dx`, `x^2*Phi1`.
- **Combined (C)**: A ∪ B (5 columns).

## Symmetry (baseline)
- x_center = 0.0620061 (midpoint of xGrid)
- Phi2: fraction L2 energy even=0.4424, odd=0.5576
### Residual structure (per fit, baseline variant)
- After **first-order** fit: residual even=0.8105 odd=0.1895 | label=even_residual_dominated
- After **pure second-order** fit: residual even=0.2594 odd=0.7406 | label=odd_residual_dominated
- After **combined** fit: residual even=0.7051 odd=0.2949 | center=0.6455 tails=0.1916 | label=even_residual_dominated

## Robustness (Phi1 pre-smoothed movmean 3 before derivatives)
- SECOND_ORDER_OUTPERFORMS_FIRST_ORDER: YES
- PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER: YES

## Answers (baseline)
1. **Pure second-order vs first-order (combined 2-term vs 3-term):** second-order achieves lower `rel_rmse` and substantially higher cosine than first-order alone; the second-order sector captures structure first-order misses (see CSV rows).
   - First-order: |cos|=0.4030, rel_rmse=0.06227
   - Pure second-order: |cos|=0.5309, rel_rmse=0.05766
2. **First+second (5-term) deformation closure:** cosine is high (~0.93) but `rmse_unit` remains slightly above the strict closure cutoff used elsewhere (`0.02`); therefore **deformation closure is not quite achieved** under that criterion (see `FIRST_PLUS_SECOND_SUFFICIENT`).
   - Combined: |cos|=0.9300, rmse_unit=0.02500 (threshold: cosine≥0.90 and rmse_unit≤0.02)
3. **Irreducible beyond second-order in the span {dPhi1,d2Phi1,xPhi1,x dPhi1,x^2 Phi1}:** residual after the 5-basis fit still carries a substantial odd-symmetry mismatch fraction and does not meet strict unit-RMSE closure; interpret as **not fully explained** as a low-order deformation subspace at this numerical bar.

## Comparison to earlier extended-basis narrative
- Prior extended test reported `EXTENDED_BASIS_IMPROVES: NO` and `PHI2_IRREDUCIBLE_BEYOND_DEFORMATION: YES` using a broader combinatorial search over four generators.
- This run **isolates** interpretable first / pure-second / first+second families. The isolated second-order sector **does** outperform first-order on cosine/RMSE, but neither pure second nor the full first+second set meets the strict `rmse_unit≤0.02` closure rule; the irreducible verdict therefore **aligns** with the earlier conclusion at that bar.

## Required verdicts
SECOND_ORDER_OUTPERFORMS_FIRST_ORDER: YES
SECOND_ORDER_SUFFICIENT: NO
FIRST_PLUS_SECOND_SUFFICIENT: NO
PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER: YES
VERDICT_STABLE_TO_NUMERICS: YES

