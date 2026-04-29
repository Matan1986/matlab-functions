% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: CANON_COLLAPSE_FAMILY + EXPERIMENTAL_PTCDF_DIAGNOSTIC (PT/CDF columns from S_long for overlay)
% EVIDENCE_STATUS: DIAGNOSTIC_OVERLAY — CDF_pt often plot axis; not manuscript primary backbone
% BACKBONE_FORMULA: reads S_model_pt_percent / CDF_pt / PT_pdf from switching_canonical_S_long per map
% SVD_INPUT: per overlay stage if any
% COORDINATE_GRID: native I + CDF_pt axis where used — label EXPERIMENTAL for PTCDF
% SAFE_USE: overlay figures with dual-namespace caption (see docs/switching_analysis_map.md CANON_COLLAPSE_FAMILY)
% UNSAFE_USE: equating overlay to CORRECTED_CANONICAL_OLD_ANALYSIS backbone; independent PT construction claim
% NOT_MAIN_MANUSCRIPT_EVIDENCE_IF_APPLICABLE: YES for PTCDF read path
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
baseName = 'switching_canonical_ptcdf_collapse_overlay';

vBackboneSufficient = 'NO';
vPhi1Required = 'YES';
vPhi2Improves = 'YES';

sLongPath = '';
phi1Path = '';
ampPath = '';
figPath = '';
pngPath = '';

gateRows = struct('table_name', string.empty(0,1), 'table_path', string.empty(0,1), ...
    'validation_status', string.empty(0,1), 'failure_code', string.empty(0,1), ...
    'failure_message', string.empty(0,1), 'metadata_path', string.empty(0,1));

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'canonical_ptcdf_collapse_overlay';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    runFigures = fullfile(runDir, 'figures');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(runFigures, 'dir') ~= 7, mkdir(runFigures); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0, fprintf(fidTop, 'SCRIPT_ENTERED\n'); fclose(fidTop); end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    phi1Path = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_phi1.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');

    reqPaths = {sLongPath, phi1Path, ampPath};
    reqNames = {'switching_canonical_S_long.csv', 'switching_canonical_phi1.csv', 'switching_mode_amplitudes_vs_T.csv'};
    for i = 1:numel(reqPaths)
        if strlength(string(reqPaths{i})) == 0 || exist(reqPaths{i}, 'file') ~= 2
            error('run_switching_canonical_ptcdf_collapse_overlay:MissingInput', ...
                'Missing required canonical input: %s (%s)', reqNames{i}, reqPaths{i});
        end
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    try
        validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_S_long.csv', sLongPath, 'PASS', '', '', [sLongPath '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_S_long.csv', sLongPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [sLongPath '.meta.json']);
        rethrow(MEv);
    end
    try
        validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_phi1.csv', phi1Path, 'PASS', '', '', [phi1Path '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_phi1.csv', phi1Path, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [phi1Path '.meta.json']);
        rethrow(MEv);
    end
    try
        validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_mode_amplitudes_vs_T.csv', ampPath, 'PASS', '', '', [ampPath '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_mode_amplitudes_vs_T.csv', ampPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [ampPath '.meta.json']);
        rethrow(MEv);
    end

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);

    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt'};
    for i = 1:numel(reqS)
        if ~ismember(reqS{i}, sLong.Properties.VariableNames)
            error('run_switching_canonical_ptcdf_collapse_overlay:BadSLongSchema', ...
                'switching_canonical_S_long.csv missing required column: %s', reqS{i});
        end
    end
    reqP = {'current_mA','Phi1'};
    for i = 1:numel(reqP)
        if ~ismember(reqP{i}, phi1Tbl.Properties.VariableNames)
            error('run_switching_canonical_ptcdf_collapse_overlay:BadPhi1Schema', ...
                'switching_canonical_phi1.csv missing required column: %s', reqP{i});
        end
    end
    reqA = {'T_K','kappa1','kappa2'};
    for i = 1:numel(reqA)
        if ~ismember(reqA{i}, ampTbl.Properties.VariableNames)
            error('run_switching_canonical_ptcdf_collapse_overlay:BadAmpSchema', ...
                'switching_mode_amplitudes_vs_T.csv missing required column: %s', reqA{i});
        end
    end

    % Aggregate to canonical (T, I) grid and carry canonical CDF_pt.
    T = double(sLong.T_K);
    I = double(sLong.current_mA);
    S = double(sLong.S_percent);
    B = double(sLong.S_model_pt_percent);
    C = double(sLong.CDF_pt);
    v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B) & isfinite(C);
    T = T(v); I = I(v); S = S(v); B = B(v); C = C(v);
    TI = table(T, I, S, B, C);
    TIg = groupsummary(TI, {'T','I'}, 'mean', {'S','B','C'});
    allT = unique(double(TIg.T), 'sorted');
    allI = unique(double(TIg.I), 'sorted');
    nT = numel(allT);
    nI = numel(allI);
    Smap = NaN(nT, nI);
    Bmap = NaN(nT, nI);
    Cmap = NaN(nT, nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(TIg.T) - allT(it)) < 1e-9 & abs(double(TIg.I) - allI(ii)) < 1e-9;
            if any(m)
                idx = find(m, 1);
                Smap(it, ii) = double(TIg.mean_S(idx));
                Bmap(it, ii) = double(TIg.mean_B(idx));
                Cmap(it, ii) = double(TIg.mean_C(idx));
            end
        end
    end

    % Reconstruct hierarchy exactly as canonical collapse hierarchy.
    pI = double(phi1Tbl.current_mA);
    pV = double(phi1Tbl.Phi1);
    pv = isfinite(pI) & isfinite(pV);
    pI = pI(pv); pV = pV(pv);
    Pg = groupsummary(table(pI, pV), {'pI'}, 'mean', {'pV'});
    phi1Vec = interp1(double(Pg.pI), double(Pg.mean_pV), allI, 'linear', NaN)';
    if all(isnan(phi1Vec))
        error('run_switching_canonical_ptcdf_collapse_overlay:Phi1InterpolationFailed', ...
            'Phi1 could not be mapped onto canonical current grid.');
    end
    phi1Vec = fillmissing(phi1Vec, 'linear', 'EndValues', 'nearest');
    nrm1 = norm(phi1Vec);
    if nrm1 > 0, phi1Vec = phi1Vec / nrm1; end

    kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
    kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
    kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
    kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

    pred0 = Bmap;
    pred1 = pred0 - kappa1(:) * phi1Vec(:)'; % hierarchy sign convention
    R1 = Smap - pred1;
    R1z = R1;
    R1z(~isfinite(R1z)) = 0;
    [~, ~, V] = svd(R1z, 'econ');
    if size(V,2) >= 1
        phi2Vec = V(:,1);
    else
        phi2Vec = zeros(nI,1);
    end
    nrm2 = norm(phi2Vec);
    if nrm2 > 0, phi2Vec = phi2Vec / nrm2; end
    pred2 = pred1 + kappa2(:) * phi2Vec(:)';

    res0 = Smap - pred0;
    res1 = Smap - pred1;
    res2 = Smap - pred2;

    rmse0 = switchingRowRmse(Smap, pred0);
    rmse1 = switchingRowRmse(Smap, pred1);
    rmse2 = switchingRowRmse(Smap, pred2);
    g0 = sqrt(mean(rmse0.^2, 'omitnan'));
    g1 = sqrt(mean(rmse1.^2, 'omitnan'));
    g2 = sqrt(mean(rmse2.^2, 'omitnan'));
    frac1 = switchingSafeFraction(g0 - g1, g0);
    frac2 = switchingSafeFraction(g1 - g2, g1);

    if isfinite(frac1) && frac1 < 0.10
        vBackboneSufficient = 'YES';
        vPhi1Required = 'NO';
    elseif isfinite(frac1) && frac1 < 0.25
        vBackboneSufficient = 'PARTIAL';
        vPhi1Required = 'PARTIAL';
    else
        vBackboneSufficient = 'NO';
        vPhi1Required = 'YES';
    end
    if ~isfinite(frac2) || frac2 <= 0
        vPhi2Improves = 'NO';
    elseif frac2 < 0.10
        vPhi2Improves = 'PARTIAL';
    else
        vPhi2Improves = 'YES';
    end

    % 7 overlay panels vs CDF_pt colored by T.
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1700, 900]);
    tl = tiledlayout(2, 4, 'Parent', fig, 'TileSpacing', 'compact', 'Padding', 'compact');
    cmap = turbo(max(nT, 2));

    panelTitles = {'Measured S vs CDF_{pt}', 'Backbone vs CDF_{pt}', 'Backbone + Phi1 vs CDF_{pt}', ...
        'Backbone + Phi1 + Phi2 vs CDF_{pt}', 'Residual after backbone', 'Residual after +Phi1', ...
        'Residual after +Phi1+Phi2'};
    Ycells = {Smap, pred0, pred1, pred2, res0, res1, res2};

    for ip = 1:7
        nexttile(tl);
        hold on;
        Y = Ycells{ip};
        for it = 1:nT
            x = Cmap(it, :);
            y = Y(it, :);
            m = isfinite(x) & isfinite(y);
            if any(m)
                xs = x(m);
                ys = y(m);
                [xs, ord] = sort(xs, 'ascend');
                ys = ys(ord);
                plot(xs, ys, '-', 'Color', cmap(it,:), 'LineWidth', 1.2);
            end
        end
        hold off;
        xlabel('CDF_{pt}');
        ylabel('Signal');
        title(panelTitles{ip}, 'Interpreter', 'tex');
        grid on;
    end
    axC = nexttile(tl);
    axis(axC, 'off');
    colormap(axC, cmap);
    cb = colorbar(axC, 'Location', 'eastoutside');
    cb.Label.String = 'Temperature (K)';
    caxis(axC, [min(allT), max(allT)]);

    sgtitle(tl, 'Canonical PT-CDF collapse overlay (inspection-first)', 'Interpreter', 'none');
    figPath = fullfile(runFigures, [baseName '.fig']);
    pngPath = fullfile(runFigures, [baseName '.png']);
    savefig(fig, figPath);
    exportgraphics(fig, pngPath, 'Resolution', 300);
    close(fig);

    statusTbl = table( ...
        {'X_AXIS'; 'WIDTH_SCALING_USED'; 'LEGACY_COLLAPSE_USED'; 'PER_T_ALIGNMENT_USED'; ...
         'INPUT_GATE_PASSED'; 'COLLAPSE_OVERLAY_IMPLEMENTED'; ...
         'BACKBONE_COLLAPSE_VISUALLY_SUFFICIENT'; 'PHI1_REQUIRED_FOR_COLLAPSE'; ...
         'PHI2_VISIBLY_IMPROVES_COLLAPSE'}, ...
        {'CDF_pt'; 'NO'; 'NO'; 'NO'; ...
         'YES'; 'YES'; ...
         vBackboneSufficient; vPhi1Required; vPhi2Improves}, ...
        {'Canonical PT-derived CDF coordinate from gated switching_canonical_S_long.csv'; ...
         'No width scaling or width-normalized coordinate used'; ...
         'No legacy/alignment-backed collapse artifacts used'; ...
         'No fitted per-temperature shift/scale alignment used'; ...
         sprintf('Validated canonical inputs: %s', strjoin(reqNames, ', ')); ...
         char(figPath); ...
         sprintf('Based on global RMSE reduction frac1=%.6g', frac1); ...
         sprintf('Based on global RMSE reduction frac1=%.6g', frac1); ...
         sprintf('Based on global RMSE reduction frac2=%.6g', frac2)}, ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_canonical_ptcdf_collapse_status.csv');
    switchingWriteTableBothPaths(switchingInputGateRowsToTable(gateRows), repoRoot, runTables, 'switching_canonical_ptcdf_collapse_input_gate_status.csv');

    lines = {};
    lines{end+1} = '# Canonical PT-CDF collapse overlay (inspection-first)';
    lines{end+1} = '';
    lines{end+1} = '## Inputs (gated canonical only)';
    for i = 1:numel(reqPaths)
        lines{end+1} = sprintf('- `%s`', reqPaths{i});
    end
    lines{end+1} = '';
    lines{end+1} = '## X-axis definition';
    lines{end+1} = '- X_AXIS = `CDF_pt` from `switching_canonical_S_long.csv`';
    lines{end+1} = '- No width, `I_peak/width`, legacy scaling, or per-temperature fitted alignment used.';
    lines{end+1} = '';
    lines{end+1} = '## Reconstruction/sign conventions';
    lines{end+1} = '- `pred0 = Bmap`';
    lines{end+1} = '- `pred1 = pred0 - kappa1*phi1Vec''` (same sign convention as canonical collapse hierarchy)';
    lines{end+1} = '- `pred2 = pred1 + kappa2*phi2Vec''` with `phi2Vec = V(:,1)` from `svd(Smap - pred1)`';
    lines{end+1} = '';
    lines{end+1} = '## Global diagnostics (for inspection flags)';
    lines{end+1} = sprintf('- rmse_backbone_global = %.6g', g0);
    lines{end+1} = sprintf('- rmse_backbone_phi1_global = %.6g', g1);
    lines{end+1} = sprintf('- rmse_backbone_phi1_phi2_global = %.6g', g2);
    lines{end+1} = sprintf('- fractional_gain_phi1 = %.6g', frac1);
    lines{end+1} = sprintf('- fractional_gain_phi2 = %.6g', frac2);
    lines{end+1} = '';
    lines{end+1} = '## Outputs';
    lines{end+1} = sprintf('- Figure `.fig`: `%s`', figPath);
    lines{end+1} = sprintf('- Figure `.png`: `%s`', pngPath);
    lines{end+1} = '- `tables/switching_canonical_ptcdf_collapse_status.csv`';
    lines{end+1} = '- `reports/switching_canonical_ptcdf_collapse_overlay.md`';
    lines{end+1} = '';
    lines{end+1} = '## Status flags';
    lines{end+1} = '- X_AXIS = CDF_pt';
    lines{end+1} = '- WIDTH_SCALING_USED = NO';
    lines{end+1} = '- LEGACY_COLLAPSE_USED = NO';
    lines{end+1} = '- PER_T_ALIGNMENT_USED = NO';
    lines{end+1} = '- INPUT_GATE_PASSED = YES';
    lines{end+1} = '- COLLAPSE_OVERLAY_IMPLEMENTED = YES';
    lines{end+1} = sprintf('- BACKBONE_COLLAPSE_VISUALLY_SUFFICIENT = %s', vBackboneSufficient);
    lines{end+1} = sprintf('- PHI1_REQUIRED_FOR_COLLAPSE = %s', vPhi1Required);
    lines{end+1} = sprintf('- PHI2_VISIBLY_IMPROVES_COLLAPSE = %s', vPhi2Improves);
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_canonical_ptcdf_collapse_overlay:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_ptcdf_collapse_overlay.md'), lines, 'run_switching_canonical_ptcdf_collapse_overlay:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'canonical PT-CDF collapse overlay completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_canonical_ptcdf_collapse_overlay_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    if isempty(gateRows.table_name)
        gateRows = switchingAddInputGateRow(gateRows, 'unknown', 'unknown', 'FAIL', char(string(ME.identifier)), char(string(ME.message)), '');
    end
    gateTbl = switchingInputGateRowsToTable(gateRows);
    writetable(gateTbl, fullfile(runDir, 'tables', 'switching_canonical_ptcdf_collapse_input_gate_status.csv'));
    writetable(gateTbl, fullfile(repoRoot, 'tables', 'switching_canonical_ptcdf_collapse_input_gate_status.csv'));

    failMsg = char(string(ME.message));
    statusTbl = table( ...
        {'X_AXIS'; 'WIDTH_SCALING_USED'; 'LEGACY_COLLAPSE_USED'; 'PER_T_ALIGNMENT_USED'; ...
         'INPUT_GATE_PASSED'; 'COLLAPSE_OVERLAY_IMPLEMENTED'; ...
         'BACKBONE_COLLAPSE_VISUALLY_SUFFICIENT'; 'PHI1_REQUIRED_FOR_COLLAPSE'; ...
         'PHI2_VISIBLY_IMPROVES_COLLAPSE'}, ...
        {'CDF_pt'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'}, ...
        {failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg}, ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_canonical_ptcdf_collapse_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_canonical_ptcdf_collapse_status.csv'));

    lines = {};
    lines{end+1} = '# Canonical PT-CDF collapse overlay — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_canonical_ptcdf_collapse_overlay:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_ptcdf_collapse_overlay.md'), lines, 'run_switching_canonical_ptcdf_collapse_overlay:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'canonical PT-CDF collapse overlay failed'}, true);
    rethrow(ME);
end
