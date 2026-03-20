# Observable Registry

This registry is the project-level dictionary for observable-layer variables.

| experiment | variable | role | units | description |
|---|---|---|---|---|
| switching | S_peak | coordinate | percent | maximum switching amplitude |
| switching | I_peak | coordinate | mA | current scale of switching |
| switching | halfwidth_diff_norm | coordinate | unitless | asymmetry of switching peak |
| switching | width_I | observable | mA | width of switching current distribution |
| switching | χ_amp(T) | observable | unitless | temperature susceptibility of switching amplitude; ≈ −dS_peak/dT; peaks ~10 K; **legacy code name: a1** |
| aging | Dip_depth | coordinate | unitless | amplitude of memory dip |
| relaxation | log_slope | coordinate | unitless | slope of logarithmic relaxation |

> **Note on naming:** The observable `a1` used in all MATLAB code and CSV files corresponds to `χ_amp(T)` in physical/report notation. See [observable_naming.md](../observable_naming.md) for full policy.
