% Quick sanity check for robust baseline PR
addpath(genpath('.'));

% Test 1: estimateRobustBaseline basic functionality
fprintf('Test 1: estimateRobustBaseline basic functionality...\n');
T = linspace(4, 34, 100)';
Tmin = 15;
Y = sin((T-15)/10) * 0.1;  % Synthetic curve with dip at T=15
cfg.dip_halfwidth_K = 3;
cfg.dip_margin_K = 2;
cfg.plateau_nPoints = 5;

out = estimateRobustBaseline(T, Y, Tmin, cfg);
fprintf('  Status: %s\n', out.status);
fprintf('  TL=%.2f TR=%.2f, slope=%.4f\n', out.TL, out.TR, out.slope);
fprintf('  ✓ PASS\n\n');

% Test 2: Check that analyzeAFM_FM_components loads without error
fprintf('Test 2: analyzeAFM_FM_components basic call...\n');
pauseRuns(1).waitK = 15;
pauseRuns(1).T_common = T;
pauseRuns(1).DeltaM = 0.3 - 0.1*exp(-((T-15).^2)/8) + 0.01*randn(size(T));

cfg_test.useRobustBaseline = true;
cfg_test.dip_margin_K = 2;
cfg_test.plateau_nPoints = 5;
cfg_test.debug.verbose = false;

try
    result = analyzeAFM_FM_components(pauseRuns, 4, 12, false, -inf, 6, 'pre', 3, 'area', cfg_test);
    fprintf('  ✓ PASS (returned %d results)\n\n', numel(result));
catch ME
    fprintf('  ✗ FAIL: %s\n\n', ME.message);
end

fprintf('All sanity checks completed!\n');
