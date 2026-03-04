# Aging Analysis Pipeline

This module implements the MATLAB pipeline for analyzing aging experiments in AFM/FM coexistence systems.

The pipeline extracts switching curves R(T,J) and fits a current-dependent coexistence model.

## Model

```
R(T,J) = (1 - g(J)) · A(T - δ(J)) + g(J) · B(T) + c
```

Where:

- **A(T)** — AFM dip component
- **B(T)** — FM background component
- **g(J)** — logistic gating between channels
- **δ(J)** — current-dependent temperature shift

## Pipeline Stages

The pipeline executes a sequence of analysis stages:

- **stage0_setupPaths** — Initialize paths and configuration
- **stage1_loadData** — Load experimental data
- **stage2_preprocess** — Data cleaning and preprocessing
- **stage3_computeDeltaM** — Compute magnetization changes
- **stage4_analyzeAFM_FM** — AFM/FM component analysis
- **stage5_fitFMGaussian** — Fit FM Gaussian envelopes
- **stage6_extractMetrics** — Extract key metrics
- **stage7_reconstructSwitching** — Reconstruct switching amplitudes with current-dependent effects
- **stage8_globalJfit_shiftGating** — Global optimization of J-dependent parameters
- **stage9_plotting** — Generate diagnostic and publication plots

## State Structure

### Stage 7 Outputs

```matlab
state.stage7.A_basis          % AFM basis (temperature-dependent)
state.stage7.B_basis          % FM basis (temperature-dependent)
state.stage7.C_basis          % Constant offset
state.stage7.Tsw              % Temperature grid for switching analysis
state.stage7.Tsw_valid        % Valid temperature mask
state.stage7.Rhat             % Fitted switching curve
```

### Stage 8 Outputs

```matlab
state.stage8.alpha            % Peak shift slope (K/mA)
state.stage8.J0               % Reference current (mA)
state.stage8.Jc               % Logistic center (mA)
state.stage8.dJ               % Logistic width (mA)
state.stage8.SSE_initial      % Initial sum of squared errors
state.stage8.SSE_final        % Final sum of squared errors
state.stage8.Rmodel_all       % All model curves
state.stage8.g_values         % Gating values at each current
state.stage8.delta_values     % Temperature shifts at each current
```

## Running the Pipeline

### Main Entry Point

The pipeline is executed via:

```matlab
run(fullfile('runs', 'run_aging.m'))
```

Or directly in the Aging module:

```matlab
cfg = agingConfig('MG119_6min');  % Load configuration
cfg.debug.enable = true;          % Enable diagnostics
state = Main_Aging(cfg);          % Execute pipeline
```

### Configuration

Edit `agingConfig.m` or pass configuration parameters to customize:

- Data directory paths
- Temperature windows and masking
- J-dependent model parameters
- Plotting options

## Model Physics

The coexistence model separates AFM and FM contributions:

- **AFM component**: R_AFM(T-δ) with peak shift δ proportional to current J
- **FM component**: R_FM(T) representing ferromagnetic background
- **Logistic gating**: Smooth transition from AFM to FM dominance with current

The global fit (stage 8) optimizes parameters across all measured currents simultaneously for robust parameter extraction.

## Diagnostics

When `diagnostics = true` in stage8_globalJfit_shiftGating.m:

- **Console output**: Comprehensive diagnostic summary with sanity checks
- **Figure 1**: Experimental vs. model curves for each current
- **Figure 2**: Logistic gating function g(J)
- **Figure 3**: Temperature shift function δ(J)
