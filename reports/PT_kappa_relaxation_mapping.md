# PT + kappa to relaxation mapping

**EXECUTION_STATUS:** SUCCESS

## Models tested
- PT base
- kappa1 amplitude: `R = kappa1 * R_PT`
- deformation A (log-time shift): `log t -> log t + a*kappa2`
- deformation B (stretching): `t -> t^(1+b*kappa2)`
- deformation C (kernel): `R -> R + c*kappa2*dR/dlogt`
- full model: pointwise best A/B/C with kappa1 prefactor

## Verdicts
- **KAPPA_FIXES_SHAPE:** NO
- **KAPPA_FIXES_PEAK:** NO
- **KAPPA_FIXES_WIDTH:** NO
- **PT_PLUS_KAPPA_SUFFICIENT:** NO
