%% verify_tp_exclusion_patch.m  (Phase 1 - hardened dimension-safe test)
clc;

fprintf('=====================================================\n');
fprintf('Phase-1 Tp Exclusion Verification (Hardened)\n');
fprintf('=====================================================\n\n');

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath')))); % ...\Aging
cd(repoRoot);
addpath(genpath(repoRoot));

i_assert(exist('getValidSwitchTp','file')==2, 'Missing getValidSwitchTp.m on path.');
fprintf('[INFO] which(getValidSwitchTp) = %s\n\n', which('getValidSwitchTp'));

% ---- synthetic Tp-space with a degenerate outlier at 34 ----
Tp        = [10 14 18 22 26 30 34];                 % 7 points
Dp        = [1.0 0.9 0.8 0.7 0.6 0.5 0.0];          % AFM metric (Dip_A)
Fp        = [0.10 0.12 0.15 0.13 0.11 0.09 0.08];   % FM metric (FM_step_A)
Dip_sigma = [1.0 1.0 1.0 1.0 1.0 1.0 0.4];          % sigma stuck at 0.4 at Tp=34
Dip_area  = Dp .* Dip_sigma;                        % near-zero area at Tp=34

fprintf('[TEST DATA] N = %d Tp points\n', numel(Tp));
fprintf('[TEST DATA] Tp        = [%s]\n', sprintf('%g ', Tp));
fprintf('[TEST DATA] Dip_sigma = [%s]\n', sprintf('%.1f ', Dip_sigma));
fprintf('[TEST DATA] Dip_area  = [%s]\n\n', sprintf('%.2f ', Dip_area));

%% TEST 1: Manual exclusion only (auto OFF)
fprintf('--- TEST 1: Manual Exclusion Only ---\n');

params1 = struct();
params1.switchExcludeTp = [34];
params1.switchExcludeTpAbove = [];
params1.autoExcludeDegenerateDip = false;
params1.dipSigmaLowerBound  = 0.4;
params1.dipAreaLowPercentile = 5;

[Tp_valid1, mask_valid1, reasons1] = getValidSwitchTp(Tp, Dp, Fp, Dip_sigma, Dip_area, params1);

Tp_valid1 = Tp_valid1(:)';
fprintf('[RESULT] Tp_valid = [%s]\n', sprintf('%g ', Tp_valid1));
fprintf('[RESULT] mask_valid length = %d (expected %d)\n', numel(mask_valid1), numel(Tp));
fprintf('[RESULT] mask_valid = [%s]\n', sprintf('%d ', mask_valid1));
fprintf('[RESULT] manualExcludedTp = %s\n', mat2str(reasons1.manualExcludedTp));

expected1 = [10 14 18 22 26 30];
i_assert(isequal(Tp_valid1, expected1), 'TEST 1: Tp_valid mismatch after manual exclusion of 34.');
i_assert(numel(mask_valid1)==numel(Tp), 'TEST 1: mask_valid must be same length as Tp.');
i_assert(islogical(mask_valid1) || all(mask_valid1==0 | mask_valid1==1), 'TEST 1: mask_valid must be logical.');
i_assert(~mask_valid1(end), 'TEST 1: Tp=34 (last element) should be excluded.');
i_assert(isstruct(reasons1), 'TEST 1: reasons must be a struct.');
i_assert(isfield(reasons1,'manualExcludedTp'), 'TEST 1: reasons.manualExcludedTp missing.');
i_assert(any(reasons1.manualExcludedTp == 34), 'TEST 1: Expected 34 in manualExcludedTp.');

fprintf('[PASS] TEST 1 passed\n\n');
%% TEST 2: Auto exclusion ON (should exclude degenerate Tp=34)
fprintf('--- TEST 2: Auto Exclusion ON ---\n');

params2 = struct();
params2.switchExcludeTp = [];                 % manual OFF
params2.switchExcludeTpAbove = [];
params2.autoExcludeDegenerateDip = true;      % auto ON
params2.dipSigmaLowerBound  = 0.4;
params2.dipAreaLowPercentile = 5;

[Tp_valid2, mask_valid2, reasons2] = getValidSwitchTp(Tp, Dp, Fp, Dip_sigma, Dip_area, params2);
Tp_valid2 = Tp_valid2(:)';

fprintf('[RESULT] Tp_valid (auto ON) = [%s]\n', sprintf('%g ', Tp_valid2));
fprintf('[RESULT] mask_valid length = %d (expected %d)\n', numel(mask_valid2), numel(Tp));
fprintf('[RESULT] mask_valid = [%s]\n', sprintf('%d ', mask_valid2));
fprintf('[RESULT] autoExcludedTp = %s\n', mat2str(reasons2.autoExcludedTp));

% Tp=34 should be auto-excluded (sigma=0.4 stuck at lower bound, area near zero)
i_assert(~ismember(34, Tp_valid2), 'TEST 2: autoExcludeDegenerateDip=true but Tp=34 still included.');
i_assert(numel(mask_valid2)==numel(Tp), 'TEST 2: mask_valid must be same length as Tp.');
i_assert(isfield(reasons2,'autoExcludedTp'), 'TEST 2: reasons.autoExcludedTp missing.');
i_assert(any(reasons2.autoExcludedTp == 34), 'TEST 2: Expected 34 in autoExcludedTp.');

fprintf('[PASS] TEST 2 passed\n\n');

%% TEST 3: Exclude above threshold
fprintf('--- TEST 3: Exclude Above Threshold ---\n');

params3 = struct();
params3.switchExcludeTp = [];                 % manual OFF
params3.switchExcludeTpAbove = 26;            % exclude Tp > 26
params3.autoExcludeDegenerateDip = false;     % auto OFF
params3.dipSigmaLowerBound  = 0.4;
params3.dipAreaLowPercentile = 5;

[Tp_valid3, mask_valid3, reasons3] = getValidSwitchTp(Tp, Dp, Fp, Dip_sigma, Dip_area, params3);
Tp_valid3 = Tp_valid3(:)';

fprintf('[RESULT] Tp_valid (excludeAbove=26) = [%s]\n', sprintf('%g ', Tp_valid3));
fprintf('[RESULT] mask_valid length = %d (expected %d)\n', numel(mask_valid3), numel(Tp));
fprintf('[RESULT] excludedAbove = %s\n', mat2str(reasons3.excludedAbove));

expected3 = [10 14 18 22 26];
i_assert(isequal(Tp_valid3, expected3), 'TEST 3: Expected Tp <= 26 only.');
i_assert(all(Tp_valid3 <= 26), 'TEST 3: switchExcludeTpAbove did not exclude Tp > 26.');
i_assert(numel(mask_valid3)==numel(Tp), 'TEST 3: mask_valid must be same length as Tp.');
i_assert(isfield(reasons3,'excludedAbove'), 'TEST 3: reasons.excludedAbove missing.');
i_assert(numel(reasons3.excludedAbove) == 2, 'TEST 3: Should exclude 2 points (30, 34).');

fprintf('[PASS] TEST 3 passed\n\n');

%% Summary
fprintf('=====================================================\n');
fprintf('✅ ALL TESTS PASSED\n');
fprintf('=====================================================\n');
fprintf('TEST 1: Manual exclusion works, mask_valid dimension-safe\n');
fprintf('TEST 2: Auto exclusion works, no logical indexing errors\n');
fprintf('TEST 3: Exclude above threshold works correctly\n');
fprintf('\ngetValidSwitchTp is hardened and ready for production.\n');

%% Helper function
function i_assert(cond, msg)
    if ~cond, error(['ASSERT FAILED: ' msg]); end
end