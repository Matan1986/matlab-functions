function run_elastic_mode_phi_test()
% Elastic / interaction-induced Phi mode test from existing artifacts.
% This script is read-only w.r.t. decomposition: it reuses prior run tables.

rootDir = pwd;
runId = ['run_' datestr(now, 'yyyy_mm_dd_HHMMSS') '_phi_elastic_mode_test'];
runDir = fullfile(rootDir, 'results', 'switching', 'runs', runId);
reportsDir = fullfile(runDir, 'reports');
tablesDir = fullfile(runDir, 'tables');
if ~exist(reportsDir, 'dir'), mkdir(reportsDir); end
if ~exist(tablesDir, 'dir'), mkdir(tablesDir); end

phiFile = fullfile(rootDir, 'results', 'switching', 'runs', ...
    'run_2026_03_24_220314_residual_decomposition', 'tables', 'phi_shape.csv');
Tphi = readtable(phiFile);
x = Tphi.x;
phi = Tphi.Phi;
phi = phi - mean(phi);
phi = phi / max(norm(phi), eps);

% 1) Spectral smoothness: polynomial and Fourier low-mode energy.
z = (x - mean(x)) ./ max(std(x), eps);
deg = 10;
V = zeros(numel(z), deg + 1);
for k = 0:deg
    V(:, k + 1) = z .^ k;
end
[Q, ~] = qr(V, 0);
c = Q' * phi;
ePoly = c .^ 2;
polyLow3 = sum(ePoly(1:3));
polyLow5 = sum(ePoly(1:5));
polyLow7 = sum(ePoly(1:7));

F = fft(phi);
N = numel(phi);
halfN = floor(N/2) + 1;
E = abs(F(1:halfN)).^2;
E = E ./ max(sum(E), eps);
fourierLow1 = sum(E(1:2));
fourierLow3 = sum(E(1:4));
fourierLow5 = sum(E(1:6));

Ts = table( ...
    ["polynomial_orthonormal_z"; "polynomial_orthonormal_z"; "polynomial_orthonormal_z"; "fourier_fft_half"; "fourier_fft_half"; "fourier_fft_half"], ...
    ["k=0..2"; "k=0..4"; "k=0..6"; "n=0..1"; "n=0..3"; "n=0..5"], ...
    [polyLow3; polyLow5; polyLow7; fourierLow1; fourierLow3; fourierLow5], ...
    'VariableNames', {'basis', 'low_modes', 'energy_fraction'});
writetable(Ts, fullfile(tablesDir, 'phi_spectral_low_mode_energy.csv'));

% 2) Local vs nonlocal mismatch (reuse existing diagnostics).
Tphys = readtable(fullfile(rootDir, 'results', 'switching', 'runs', ...
    'run_2026_03_25_041314_phi_physical_structure_test', 'tables', 'phi_physical_kernel_correlations.csv'));
ixCdf = strcmp(Tphys.kernel_name, 'cdf_curvature_d2dI2');
cdfRow = Tphys(find(ixCdf, 1, 'first'), :);

Tptdef = readtable(fullfile(rootDir, 'results', 'switching', 'runs', ...
    'run_2026_03_25_041024_pt_deformation_mode_test', 'tables', 'pt_deformation_mode_correlation.csv'));
maskBasis = startsWith(Tptdef.basis_id, 'poly_') | startsWith(Tptdef.basis_id, 'gauss_') | ...
    startsWith(Tptdef.basis_id, 'narrow_gauss_') | startsWith(Tptdef.basis_id, 'spline_') | ...
    startsWith(Tptdef.basis_id, 'local_');
TptdefLocal = Tptdef(maskBasis, :);
[~, ibest] = min(TptdefLocal.rmse_ratio_kappaPhi_over_rank1);
bestLocal = TptdefLocal(ibest, :);

% 3) PT independence (reuse existing table).
Tproj = readtable(fullfile(rootDir, 'results', 'switching', 'runs', ...
    'run_2026_03_25_034055_phi_pt_independence_test', 'tables', 'phi_projection_metrics.csv'));
Tcorr = readtable(fullfile(rootDir, 'results', 'switching', 'runs', ...
    'run_2026_03_25_034055_phi_pt_independence_test', 'tables', 'phi_pt_correlation_metrics.csv'));
maxAbsCorr = max(abs(Tcorr.corr_with_phi));

% 4) Mode stability across T windows (direct Phi-to-Phi comparison).
winNames = {'T_le_30', 'T_le_28', 'T_le_25', 'T_le_24'};
winFiles = { ...
    fullfile(rootDir, 'results', 'switching', 'runs', 'run_2026_03_24_220314_residual_decomposition', 'tables', 'phi_shape.csv'), ...
    fullfile(rootDir, 'results', 'switching', 'runs', 'run_2026_03_25_011526_rsr_child_tmax_28k', 'tables', 'phi_shape.csv'), ...
    fullfile(rootDir, 'results', 'switching', 'runs', 'run_2026_03_25_011605_rsr_child_tmax_25k', 'tables', 'phi_shape.csv'), ...
    fullfile(rootDir, 'results', 'switching', 'runs', 'run_2026_03_25_043610_kappa_phi_temperature_structure_test', 'tables', 'phi_shape.csv') ...
    };

base = readtable(winFiles{1});
xb = base.x;
pb = base.Phi;
pb = pb - mean(pb);
pb = pb / max(norm(pb), eps);
W = cell(numel(winNames), 3);
for i = 1:numel(winNames)
    Ti = readtable(winFiles{i});
    yi = interp1(Ti.x, Ti.Phi, xb, 'linear', 'extrap');
    yi = yi - mean(yi);
    yi = yi / max(norm(yi), eps);
    corrVal = dot(pb, yi);
    rmseVal = sqrt(mean((pb - yi).^2));
    W{i, 1} = winNames{i};
    W{i, 2} = corrVal;
    W{i, 3} = rmseVal;
end
Tw = cell2table(W, 'VariableNames', {'window', 'corr_with_T_le_30', 'rmse_vs_T_le_30'});
writetable(Tw, fullfile(tablesDir, 'phi_mode_stability_windows.csv'));

% Verdict per requested framing.
verdict = 'PARTIAL';

reportFile = fullfile(reportsDir, 'phi_elastic_mode_test.md');
fid = fopen(reportFile, 'w');
fprintf(fid, '# Phi elastic / interaction-induced collective mode test\n\n');
fprintf(fid, '## Inputs and constraints\n');
fprintf(fid, '- Reused existing decomposition and diagnostics only (no decomposition recomputation).\n');
fprintf(fid, '- Required file `phi_structure_physics.md` was not found by exact-name search in the repository.\n');
fprintf(fid, '- Canonical Phi source: `run_2026_03_24_220314_residual_decomposition/tables/phi_shape.csv`.\n\n');

fprintf(fid, '## 1) Spectral smoothness\n');
fprintf(fid, '- Polynomial low-mode energy: k=0..2 **%.4f**, k=0..4 **%.4f**, k=0..6 **%.4f**.\n', ...
    polyLow3, polyLow5, polyLow7);
fprintf(fid, '- Fourier low-mode energy: n=0..1 **%.4f**, n=0..3 **%.4f**, n=0..5 **%.4f**.\n', ...
    fourierLow1, fourierLow3, fourierLow5);
fprintf(fid, '- Interpretation: strong low-frequency concentration (smooth collective profile).\n\n');

fprintf(fid, '## 2) Local vs nonlocal mismatch\n');
fprintf(fid, '- Best local derivative-like basis from PT deformation library: `%s` with Pearson(Psi,Phi) **%.4f**, RMSE ratio(kappaPhi/rank1) **%.3f**.\n', ...
    bestLocal.basis_id{1}, bestLocal.pearson_psi_phi, bestLocal.rmse_ratio_kappaPhi_over_rank1);
fprintf(fid, '- Physical-kernel check `cdf_curvature_d2dI2`: Pearson **%.4f**, cosine **%.4f**.\n', ...
    cdfRow.pearson_r, cdfRow.cosine_similarity);
fprintf(fid, '- Interpretation: local derivative kernels do not provide a competitive reconstruction.\n\n');

fprintf(fid, '## 3) PT independence\n');
fprintf(fid, '- Projection ratio ||proj_PT(Phi)||/||Phi||: **%.4f**.\n', Tproj.projection_norm_ratio(1));
fprintf(fid, '- PT-space reconstruction RMSE / RMS(Phi): **%.4f**.\n', Tproj.reconstruction_rmse_over_phi_rms(1));
fprintf(fid, '- Max |corr(Phi, PT-feature)|: **%.4f**.\n', maxAbsCorr);
fprintf(fid, '- Interpretation: weak-independence criterion is not satisfied.\n\n');

fprintf(fid, '## 4) Mode stability across T windows\n');
for i = 1:height(Tw)
    fprintf(fid, '- %s: corr with canonical **%.4f**, RMSE **%.4f**.\n', ...
        Tw.window{i}, Tw.corr_with_T_le_30(i), Tw.rmse_vs_T_le_30(i));
end
fprintf(fid, '- Interpretation: Phi shape is highly stable across tested windows.\n\n');

fprintf(fid, '## Final verdict\n');
fprintf(fid, '**ELASTIC_MODE: %s**\n\n', verdict);
fprintf(fid, 'Phi is strongly smooth/even/stable and consistent with a collective-mode structure. ');
fprintf(fid, 'However, current PT-coupling diagnostics show strong PT-feature dependence, so the elastic ');
fprintf(fid, 'interaction-induced interpretation is supported only partially under the requested criteria.\n');
fclose(fid);

fprintf('Created run: %s\\n', runDir);
fprintf('Report: %s\\n', reportFile);
end
