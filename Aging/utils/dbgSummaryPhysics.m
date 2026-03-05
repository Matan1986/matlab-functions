function dbgSummaryPhysics(cfg, physicsContext, result, state)
% =========================================================
% dbgSummaryPhysics — Save comprehensive physics diagnostic summary
% =========================================================
%
% PURPOSE:
%   Save formatted physics context and reconstruction details
%   in a human-readable format for experimental documentation.
%
% INPUTS:
%   cfg               - configuration struct
%   physicsContext    - output from dbgExtractPhysicsContext
%   result            - stage7 reconstruction results
%   state             - pipeline state
%
% OUTPUT:
%   Saves to: diagnostics/physics_context.txt
%
% =========================================================

if nargin < 1
    return;
end

% Determine output directory
if isfield(cfg, 'outFolder') && ~isempty(cfg.outFolder)
    baseFolder = cfg.outFolder;
elseif isfield(cfg, 'outputFolder') && ~isempty(cfg.outputFolder)
    baseFolder = cfg.outputFolder;
else
    return;
end

% Diagnostics subdirectory
diagDir = fullfile(baseFolder, 'diagnostics');
if ~isfolder(diagDir)
    mkdir(diagDir);
end

% Output file
outFile = fullfile(diagDir, 'physics_context.txt');
fid = fopen(outFile, 'w');
if fid <= 0
    return;
end

% =========================================================
% Header
% =========================================================
fprintf(fid, '╔════════════════════════════════════════════════════════════════╗\n');
fprintf(fid, '║         AGING SPIN-GLASS RECONSTRUCTION EXPERIMENTAL LOG        ║\n');
fprintf(fid, '╠════════════════════════════════════════════════════════════════╣\n');
fprintf(fid, '\n');

fprintf(fid, 'Generated: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
fprintf(fid, '\n');

% =========================================================
% Sample Information
% =========================================================
fprintf(fid, '┌─ SAMPLE INFORMATION ────────────────────────────────────────────┐\n');
if isfield(physicsContext, 'sample_name')
    fprintf(fid, '  Sample:          %s\n', physicsContext.sample_name);
end
if isfield(physicsContext, 'dataset_name')
    fprintf(fid, '  Dataset:         %s\n', physicsContext.dataset_name);
end
fprintf(fid, '└────────────────────────────────────────────────────────────────┘\n');
fprintf(fid, '\n');

% =========================================================
% Experimental Configuration
% =========================================================
fprintf(fid, '┌─ EXPERIMENTAL CONFIGURATION ────────────────────────────────────┐\n');

if isfield(physicsContext, 'reference_current_mA')
    fprintf(fid, '  Primary Current:         %.1f mA\n', physicsContext.reference_current_mA);
end

if isfield(physicsContext, 'available_currents_mA')
    currents = physicsContext.available_currents_mA;
    fprintf(fid, '  Available Currents:      [');
    fprintf(fid, '%.0f', currents(1));
    for i = 2:numel(currents)
        fprintf(fid, ', %.0f', currents(i));
    end
    fprintf(fid, '] mA\n');
end

if isfield(physicsContext, 'n_pause_runs')
    fprintf(fid, '  Pause Runs:              %d\n', physicsContext.n_pause_runs);
end

if isfield(physicsContext, 'pause_temperatures_K')
    Tp = physicsContext.pause_temperatures_K;
    if ~isempty(Tp)
        fprintf(fid, '  Pause Temperatures:      [');
        fprintf(fid, '%.1f', Tp(1));
        for i = 2:numel(Tp)
            fprintf(fid, ', %.1f', Tp(i));
        end
        fprintf(fid, '] K\n');
    end
end

fprintf(fid, '└────────────────────────────────────────────────────────────────┘\n');
fprintf(fid, '\n');

% =========================================================
% Temperature Grid
% =========================================================
fprintf(fid, '┌─ RECONSTRUCTION TEMPERATURE GRID ───────────────────────────────┐\n');

if isfield(physicsContext, 'temperature_min_K')
    fprintf(fid, '  Temperature Range:       %.2f – %.2f K\n', ...
        physicsContext.temperature_min_K, physicsContext.temperature_max_K);
end

if isfield(physicsContext, 'temperature_range_K')
    fprintf(fid, '  Total Range:             %.2f K\n', physicsContext.temperature_range_K);
end

if isfield(physicsContext, 'n_temperature_points')
    fprintf(fid, '  Grid Points:             %d\n', physicsContext.n_temperature_points);
end

if isfield(physicsContext, 'fit_window_min_K')
    fprintf(fid, '  Fit Window:              %.2f – %.2f K\n', ...
        physicsContext.fit_window_min_K, physicsContext.fit_window_max_K);
end

if isfield(physicsContext, 'reconstruction_mode')
    fprintf(fid, '  Metric Mode:             %s\n', physicsContext.reconstruction_mode);
end

fprintf(fid, '└────────────────────────────────────────────────────────────────┘\n');
fprintf(fid, '\n');

% =========================================================
% Reconstruction Results
% =========================================================
fprintf(fid, '┌─ RECONSTRUCTION RESULTS ────────────────────────────────────────┐\n');

if isfield(result, 'lambda') && ~isnan(result.lambda)
    fprintf(fid, '  Coexistence Parameter λ:  %.4f\n', result.lambda);
    fprintf(fid, '    → Governs mixing between AFM and FM\n');
    fprintf(fid, '    → Lower λ: AFM-dominated, Higher λ: FM-dominated\n');
end

if isfield(result, 'a') && ~isnan(result.a)
    fprintf(fid, '  Reconstruction Coeff. a:  %.4f\n', result.a);
    fprintf(fid, '    → Amplitude scaling for reconstruction\n');
end

if isfield(result, 'b') && ~isnan(result.b)
    fprintf(fid, '  Reconstruction Coeff. b:  %.4f\n', result.b);
    fprintf(fid, '    → Offset correction in reconstruction\n');
end

if isfield(result, 'R2') && ~isnan(result.R2)
    fprintf(fid, '  Fit Quality (R²):         %.4f\n', result.R2);
    percent = result.R2 * 100;
    if result.R2 > 0.95
        quality = 'Excellent';
    elseif result.R2 > 0.90
        quality = 'Good';
    elseif result.R2 > 0.80
        quality = 'Fair';
    else
        quality = 'Poor';
    end
    fprintf(fid, '    → %s fit (%.1f%% variance explained)\n', quality, percent);
end

fprintf(fid, '└────────────────────────────────────────────────────────────────┘\n');
fprintf(fid, '\n');

% =========================================================
% Physical Basis Functions
% =========================================================
fprintf(fid, '┌─ DECOMPOSITION BASIS FUNCTIONS ─────────────────────────────────┐\n');
fprintf(fid, '  The reconstruction decomposes Rsw(T) as:\n');
fprintf(fid, '  \n');
fprintf(fid, '    Rsw(T,J) ≈ a · C(T) + b\n');
fprintf(fid, '    \n');
fprintf(fid, '  where C(T) is the coexistence functional:\n');
fprintf(fid, '    \n');
fprintf(fid, '    C(T) = 1 - |A(T) - B(T)|\n');
fprintf(fid, '    \n');
fprintf(fid, '  Components:\n');
fprintf(fid, '    A(T) = AFM basis  (low-manifold dip, 0→1)\n');
fprintf(fid, '    B(T) = FM basis   (high-manifold step, 0→1)\n');
fprintf(fid, '  \n');
fprintf(fid, '  Alternative mechanisms compared:\n');
fprintf(fid, '    • Overlap:      M_overlap = A(T) × B(T)\n');
fprintf(fid, '    • Coexistence:  M_coex    = 1 - |A(T) - B(T)|\n');
fprintf(fid, '    • Dominance:    M_dom     = 1 - A(T)\n');
fprintf(fid, '└────────────────────────────────────────────────────────────────┘\n');
fprintf(fid, '\n');

% =========================================================
% Measurement Configuration
% =========================================================
fprintf(fid, '┌─ MEASUREMENT CONFIGURATION ─────────────────────────────────────┐\n');
fprintf(fid, '  AFM metric:      Area of ΔM(T) dip (direct extraction)\n');
fprintf(fid, '  FM metric:       Plateau step in ΔM(T) (high-T magnitude)\n');
fprintf(fid, '  Switching Data:  Measured R(T) at applied current\n');
fprintf(fid, '  Aging Memory:    Analyzed via ΔM = M(pause) - M(no-pause)\n');
fprintf(fid, '└────────────────────────────────────────────────────────────────┘\n');
fprintf(fid, '\n');

% =========================================================
% Footer
% =========================================================
fprintf(fid, '╔════════════════════════════════════════════════════════════════╗\n');
fprintf(fid, '║  This summary allows physical interpretation of the            ║\n');
fprintf(fid, '║  reconstruction without needing to access raw MATLAB data.     ║\n');
fprintf(fid, '║                                                                ║\n');
fprintf(fid, '║  For complete analysis details, see diagnostic_log.txt         ║\n');
fprintf(fid, '╚════════════════════════════════════════════════════════════════╝\n');

fclose(fid);

dbg(cfg, "summary", "Physics context saved to: %s", outFile);

end
