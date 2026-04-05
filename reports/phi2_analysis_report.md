# Phi2 and Kappa2 Canonical Residual Mode Analysis

## Scope
- Canonical switching outputs only: S(I,T), I_peak(T), width(T), S_peak(T).
- Residual built from canonical CDF backbone using switching_residual_decomposition_analysis.
- Aligned x-grid points used globally: 220
- Temperatures used: 14 (T range 4.000 to 30.000 K)

## Mode Plots (Description)
- Phi1(x) is the leading residual mode from global SVD of M(x,T).
- Phi2(x) is the second residual mode from global SVD of M(x,T).
- Phi2 symmetry metrics: even fraction = 0.5984, odd fraction = 0.3976.
- Phi2 localization near x=0: center energy |x|<=1 is 1.0000; weighted RMS x is 0.3896.
- Corr(Phi2, x*Phi1)=0.8916; Corr(Phi2, dPhi1/dx)=0.8860.

## Reconstruction Comparison
- Mode-1 explained variance: 0.957642
- Mode-2 explained variance: 0.025487
- Global RMSE rank-1: 0.0104376
- Global RMSE rank-2: 0.00658722
- Global RMSE ratio rank2/rank1: 0.631104
- Per-temperature RMSE metrics are in tables/phi2_kappa2_summary.csv.

## Interpretation of Phi2
- PHI2_IS_DEFORMATION: YES (max deformation correlation 0.8916).
- Kappa correlations: Corr(kappa2,kappa1)=0.1152; Corr(kappa2,I_peak)=-0.4818.
- Regime behavior 22-24 K (|kappa2| ratio vs outside): 1.6870.

## Link to Aging Hypothesis (Qualitative)
- A stable and reconstructive second residual mode is consistent with a structured correction layer beyond a single collective mode.
- This is qualitatively compatible with the idea that memory/aging behavior can emerge from regime-dependent corrections to the leading switching manifold.

## Verdicts
- RANK1_SUFFICIENT=YES
- MODE2_SIGNIFICANT=NO
- RANK2_IMPROVES_RECONSTRUCTION=YES
- PHI2_SYMMETRIC=YES
- PHI2_ODD_DOMINANT=NO
- PHI2_IS_DEFORMATION=YES
- KAPPA2_LINKED_TO_KAPPA1=NO
- KAPPA2_REGIME_DEPENDENT=YES
