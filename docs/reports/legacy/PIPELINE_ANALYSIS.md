# MATLAB Pipeline Analysis: Aging

## 1. Pipeline Structure (Aging/pipeline)

### Main Stages (Sequential Processing)
```
stage0_setupPaths.m              → Initialize paths
stage1_loadData.m                → Load experimental data
stage2_preprocess.m              → Data preprocessing (filtering, normalization)
stage3_computeDeltaM.m           → Compute magnetization changes
stage4_analyzeAFM_FM.m           → Analyze AFM/FM metrics
stage5_fitFMGaussian.m           → Fit Gaussian to FM data
stage6_extractMetrics.m          → Extract key metrics
stage7_reconstructSwitching.m    → Reconstruct switching amplitude (J-dependent model)
stage8_globalJfit_shiftGating.m  → Global optimization of J-dependent parameters ← NEW
stage8_plotting.m                → Generate plots
stage9_export.m                  → Export results
```

### Special Modules
- `agingConfig.m` – Configuration factory function
- `runPhaseC_leaveOneOut.m` – Cross-validation pipeline
- `stageC2_sweepDipWindow.m` – Parameter sweep analysis

---

## 2. Stage7: reconstructSwitching Summary

### Purpose
Reconstruct switching amplitude from AFM (low-manifold dip) and FM (high-manifold background) metrics using a J-dependent coexistence model.

### Function Signature
```matlab
[result, state] = stage7_reconstructSwitching(state, cfg)
```

### Key Operations
1. **Mode Selection**: Chooses between 'experimental' or 'fit' mode based on `cfg.switchingMetricMode`
2. **Calls reconstructSwitchingAmplitude**: Main decomposition engine
3. **FM Cross-Check** (optional): Correlates RMS FM background with fitted FM_step_A
4. **Interpolation Diagnostics** (optional): Checks for pchip overshoot in A/B basis interpolation
5. **Global J-fit Integration** (optional): Can enable pre-optimization via stage7's internal global J-fit

### Key Input Variables from cfg
- `cfg.Tsw` – Temperature grid for switching
- `cfg.Rsw` – Switching resistance curve(s)
- `cfg.switchingMetricMode` – 'direct' or 'fit'
- `cfg.switchParams` – Model parameters (allows J-dependent settings)
- `cfg.debug` – Debug flags (enable, logToFile, saveOutputs, etc.)
- `cfg.switchExcludeTp`, `cfg.switchExcludeTpAbove` – Temperature exclusion windows

### Key Output Fields (in `result` struct)
- **`result.Tp`** – Temperature vector for pause runs
- **`result.Tsw`** – Temperature grid for switching
- **`result.Tsw_valid`** – Valid temperature window (masked fit domain)
- **`result.A_basis`** – AFM basis function (dip component) on Tsw grid
- **`result.B_basis`** – FM basis function (background component) on Tsw grid
- **`result.Rhat`** – Model prediction on original Tsw grid
- **`result.wA`, `result.wB`** – Channel weights (optional J-model outputs)
- **`result.Tp_valid`** – Valid pause temperatures

---

## 3. Stage8: globalJfit_shiftGating Summary

### Purpose
Perform **global optimization** of J-dependent shift-and-gating model parameters across **ALL currents simultaneously**. Uses stage7 outputs (A/B bases) and experimental data to fit:

$$R(T,J) = [1-g(J)] \cdot A(T-\delta(J)) + g(J) \cdot B(T) + c$$

where:
- $\delta(J) = \text{alpha} \cdot (J - J0)$ – Current-dependent peak shift
- $g(J) = \frac{1}{1 + \exp(-(J-J_c)/dJ)}$ – Logistic gating function
- Parameters: `[alpha, J0, Jc, dJ]` optimized via `fminsearch`

### Function Signature
```matlab
state = stage8_globalJfit_shiftGating(state, cfg, Jlist)
```

### Inputs

#### Required Arguments
- **`state`** – Struct containing:
  - All data from stages 1–7 (not directly used except for accessing saved outputs)
  - Can contain `state.stage7.*` or `state.result.*` fields from previous pipeline runs
- **`cfg`** – Configuration struct containing:
  - **`cfg.Tsw`** (or stage7 equivalent) – Temperature grid
  - **`cfg.Rsw_15mA`, `cfg.Rsw_20mA`, ..., `cfg.Rsw_45mA`** – Experimental curves per current
  - **`cfg.debug.verbose`** (optional) – Controls optimizer verbosity
  - **`cfg.stage8.*`** (optional) – Initial parameter guesses
- **`Jlist`** – Vector of current values, e.g., `[15 20 25 30 35 45]`

### Key Variables Read from Stage7 Outputs
| Variable | Source Candidates (in priority order) | Purpose |
|----------|-------|---------|
| `Tsw` | `state.stage7.Tsw` → `state.result.Tsw` → `state.Tsw` → `cfg.Tsw` | Temperature grid (nT × 1) |
| `Tsw_valid` | `state.stage7.Tsw_valid` → `state.result.Tsw_valid` → `state.Tsw_valid` | Valid fit window (logical mask); defaults to full Tsw if missing |
| `A_basis` | `state.stage7.A_basis` → `state.result.A_basis` → `state.A_basis` | AFM subcomponent on Tsw grid (nT × 1) |
| `B_basis` | `state.stage7.B_basis` → `state.result.B_basis` → `state.B_basis` | FM subcomponent on Tsw grid (nT × 1) |
| `C_basis` (optional) | `state.stage7.C_basis` → `state.result.C_basis` → `state.C_basis` | Constant offset (scalar); defaults to 0 if missing |

### Key Variables Read from cfg
| Variable | Purpose |
|----------|---------|
| `cfg.Rsw_15mA` through `cfg.Rsw_45mA` | Experimental resistance per current (nT × 1 each) |
| `cfg.switchParams` | Base parameter template (not directly modified by stage8) |
| `cfg.debug.verbose` | Controls fminsearch display ('iter' vs 'off') |
| `cfg.stage8.alpha`, `cfg.stage8.J0`, ... (optional) | User-provided initial guesses for optimization |

---

## 4. Inputs and Outputs of stage8_globalJfit_shiftGating

### Inputs
```
Inputs: (state, cfg, Jlist)
  ├─ state: struct (previous pipeline state, may contain stage7 results)
  ├─ cfg: struct (configuration with Rsw_*mA fields + optional initial params)
  └─ Jlist: vector [15, 20, 25, 30, 35, 45] or other currents
```

### Outputs
```
Output: state (updated with stage8 results in state.stage8)
  └─ state.stage8: struct with fields:
       ├─ theta0: [alpha0, J0_0, Jc0, dJ0]  – Initial guess
       ├─ theta: [alpha, J0, Jc, dJ]  – Optimized parameters
       ├─ alpha: (scalar)  – Current-dependent peak shift slope (K/mA)
       ├─ J0: (scalar)  – Reference current for shift definition (mA)
       ├─ Jc: (scalar)  – Logistic switching center (mA)
       ├─ dJ: (scalar)  – Logistic switching width (mA)
       ├─ SSE_initial: (scalar)  – Sum-of-squared-errors before optimization
       ├─ SSE_final: (scalar)  – Sum-of-squared-errors after optimization
       ├─ SSE_ratio: (scalar)  – Final/Initial SSE ratio (≤1 indicates improvement)
       ├─ Jlist: vector  – Input current list
       └─ Tmask: logical vector  – Valid temperature mask used in optimization
```

---

## 5. Data Flow Summary

### From Stage7 to Stage8
```
stage7_reconstructSwitching
    ↓ returns result
    ├─→ result.A_basis (AFM basis on Tsw)
    ├─→ result.B_basis (FM basis on Tsw)
    ├─→ result.Tsw_valid (fit window)
    └─→ result.Rhat (optional: for diagnostics)
    
stage8_globalJfit_shiftGating
    ↓ reads these via:
    A_basis = firstField(state, cfg, {'stage7.A_basis','result.A_basis',...})
    B_basis = firstField(state, cfg, {'stage7.B_basis','result.B_basis',...})
    Tsw_valid = firstField(state, cfg, {'stage7.Tsw_valid','result.Tsw_valid',...})
```

### From cfg to Stage8
```
cfg.Rsw_15mA, cfg.Rsw_20mA, ..., cfg.Rsw_45mA
    ↓ built into
Rexp (nT × nJ matrix)
    ↓ used in
globalJObjectiveRaw (computes SSE across all J)
    ↓ minimized by
fminsearch([alpha, J0, Jc, dJ])
```

---

## 6. Model Computation in stage8

For each current $J$ in `Jlist`:
1. Compute shift: $\delta = \text{alpha} \cdot (J - J0)$
2. Compute gating: $g = \frac{1}{1 + \exp(-(J-J_c)/dJ)}$
3. Shift AFM basis: $A_{\text{shifted}} = \text{interp1}(\text{Tsw}, A_{\text{basis}}, \text{Tsw} - \delta)$
4. Model prediction: $R_{\text{model}}(T) = (1-g) \cdot A_{\text{shifted}} + g \cdot B + c$
5. Mask and residuals: $\text{residual} = R_{\text{model}}(\text{mask}) - R_{\text{exp}}(\text{mask})$
6. Sum across all $J$: $\text{SSE} = \sum_{J,T_{\text{valid}}} \text{residual}^2$

### Optimization
- **Objective**: Minimize SSE via `fminsearch`
- **Penalty**: $+10^6$ if $dJ \leq 0$ (enforce positivity)
- **Initial guess**: alpha=0, J0=median(Jlist), Jc=median(Jlist), dJ=(max-min)/6
- **Tolerance**: TolX=1e-4, TolFun=1e-4, MaxIter=300

---

## Key Design Features

### Robustness
- **No pauseRuns dependency**: stage8 uses only stage7 outputs (A/B bases) and cfg fields
- **Flexible field lookup**: `firstField()` helper tries multiple source paths before erroring
- **Clear error messages**: Missing Rsw_*mA fields are listed explicitly

### Physics
- **Linear shift model**: Peak moves linearly with current (natural for many systems)
- **Logistic gating**: Smooth transition between FM and AFM dominated regimes
- **Masked fit**: Only uses temperature window where switching data is reliable

### Efficiency
- **Single global optimization**: All currents fit simultaneously (vs. per-J fits)
- **Vectorized residuals**: All J values evaluated per fminsearch iteration
- **Optional verbosity**: Can suppress or display optimizer iterations

---

## Integration with Diagnostic Script

In `diagnostic.m`:
```matlab
Jlist = [15 20 25 30 35 45];
state = stage8_globalJfit_shiftGating(state, cfg, Jlist);  % Line 33
p8 = state.stage8;  % Extract results
% Use p8.alpha, p8.J0, p8.Jc, p8.dJ in per-J validation loop
```

This enables automated validation that stage8 parameters provide good physics-based fits across all measured currents.
