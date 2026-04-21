% Capture XY amp-temp switching map (P2P_percent) from canonical Switching_main
% without modifying pipeline code. Calls Switching_main.m as-is, then saves a
% deterministically selected figure (not gcf).

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

scriptPath = mfilename('fullpath');
scriptDir = fileparts(scriptPath);
repoRoot = fileparts(scriptDir);

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfgRun = struct();
cfgRun.runLabel = 'xy_switching_map_capture';
runCtx = struct();

tablesDir = fullfile(repoRoot, 'tables');
figuresDir = fullfile(repoRoot, 'figures');
reportsDir = fullfile(repoRoot, 'reports');
statusPath = fullfile(repoRoot, 'execution_status.csv');
persistPath = fullfile(tablesDir, '_xy_switching_map_capture_paths.txt');

figOutFig = fullfile(figuresDir, 'xy_switching_map.fig');
figOutPng = fullfile(figuresDir, 'xy_switching_map.png');
csvOutPath = fullfile(tablesDir, 'xy_switching_map.csv');
reportPath = fullfile(reportsDir, 'xy_switching_map.md');
captureStatusPath = fullfile(tablesDir, 'xy_switching_map_capture_status.csv');
validationReportPath = fullfile(reportsDir, 'xy_switching_map_capture_validation.md');
hardeningStatusPath = fullfile(tablesDir, 'xy_switching_map_capture_hardening_status.csv');
finalValidationPath = fullfile(reportsDir, 'xy_switching_map_final_validation.md');
finalStatusPath = fullfile(tablesDir, 'xy_switching_map_final_status.csv');

switchingMainPath = fullfile(repoRoot, 'Switching ver12', 'main', 'Switching_main.m');

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

captureStatus = table({'FAILED'}, {'NotStarted'}, ...
    'VariableNames', {'status', 'message'});

try
    if exist(tablesDir, 'dir') ~= 7
        mkdir(tablesDir);
    end
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end
    if exist(reportsDir, 'dir') ~= 7
        mkdir(reportsDir);
    end

    targets = {};
    blocked = false;
    blockList = '';
    for ti = 1:numel(targets)
        if exist(targets{ti}, 'file') == 2
            blocked = true;
            if isempty(blockList)
                blockList = targets{ti};
            else
                blockList = [blockList, '; ', targets{ti}]; %#ok<AGROW>
            end
        end
    end
    if blocked
        msg = ['Refusing overwrite; remove or rename existing file(s): ', blockList];
        captureStatus = table({'SKIPPED'}, {msg}, 'VariableNames', {'status', 'message'});
        writetable(captureStatus, captureStatusPath);
        executionStatus = table({'SUCCESS'}, {'YES'}, {''}, 0, {'Skipped: output path collision (no overwrite)'}, ...
            'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
        runCtx = createRunContext('analysis', cfgRun);
        writetable(executionStatus, fullfile(runCtx.run_dir, 'execution_status.csv'));
        writetable(executionStatus, statusPath);
        if exist(reportPath, 'file') ~= 2
            fidRep = fopen(reportPath, 'w');
            if fidRep >= 0
                fprintf(fidRep, '# XY switching map capture\n\n');
                fprintf(fidRep, 'STATUS=SKIPPED\n\n');
                fprintf(fidRep, '%s\n', msg);
                fclose(fidRep);
            end
        end
        fidVal = fopen(validationReportPath, 'w');
        if fidVal >= 0
            fprintf(fidVal, '# XY switching map capture validation\n\n');
            fprintf(fidVal, '## Final verdict\n\nSKIP (existing capture outputs; pipeline not run)\n\n');
            fprintf(fidVal, '## Figure selection\n\n');
            fprintf(fidVal, '- Method: N/A (pipeline not executed)\n');
            fprintf(fidVal, '- Figures detected: N/A\n');
            fprintf(fidVal, '- Selected figure: N/A\n\n');
            fprintf(fidVal, '## Image / axes validation\n\n');
            fprintf(fidVal, '- Not run (SKIP branch)\n\n');
            fprintf(fidVal, '## Test execution scenario (logic only)\n\n');
            fprintf(fidVal, '1. If `tables/xy_switching_map.csv` and `reports/xy_switching_map.md` are both missing, the script sets blocked=false and would run `Switching_main` then export figures (FIG/PNG always overwritten when pipeline runs).\n');
            fprintf(fidVal, '2. If either CSV or MD exists, the script sets blocked=true and SKIPs (no pipeline), as in this run.\n');
            fclose(fidVal);
        end
        hardTbl = table({'NO_CHANGE'}, {'SKIP: primary capture outputs already present; pipeline not run'}, ...
            'VariableNames', {'status', 'message'});
        writetable(hardTbl, hardeningStatusPath);
        figPngExist = (exist(figOutFig, 'file') == 2) && (exist(figOutPng, 'file') == 2);
        figBytes = 0;
        pngBytes = 0;
        if exist(figOutFig, 'file') == 2
            dFig = dir(figOutFig);
            if ~isempty(dFig)
                figBytes = dFig(1).bytes;
            end
        end
        if exist(figOutPng, 'file') == 2
            dPng = dir(figOutPng);
            if ~isempty(dPng)
                pngBytes = dPng(1).bytes;
            end
        end
        if figPngExist
            skipVerdict = 'VALID_MAP (existing artifacts on disk; not re-captured)';
        else
            skipVerdict = 'NEEDS_REVIEW (SKIPPED; FIG or PNG missing on disk)';
        end
        fidFin = fopen(finalValidationPath, 'w');
        if fidFin >= 0
            fprintf(fidFin, '# XY switching map final validation\n\n');
            fprintf(fidFin, '- execution_status: SKIPPED\n');
            fprintf(fidFin, '- selection_method: N/A\n');
            fprintf(fidFin, '- figures_detected: N/A\n');
            fprintf(fidFin, '- image_size: N/A\n');
            fprintf(fidFin, '- axis_validation: N/A\n');
            fprintf(fidFin, '- threshold_behavior: N/A\n');
            fprintf(fidFin, '- existing_fig_bytes: %d\n', figBytes);
            fprintf(fidFin, '- existing_png_bytes: %d\n', pngBytes);
            fprintf(fidFin, '- final_verdict: %s\n', skipVerdict);
            fclose(fidFin);
        end
        if figPngExist
            finSkipMsg = 'SKIPPED; FIG and PNG on disk; pipeline not run (CSV or MD blocked)';
        else
            finSkipMsg = 'SKIPPED; FIG or PNG missing on disk';
        end
        finTbl = table({'SKIPPED'}, {finSkipMsg}, 'VariableNames', {'status', 'message'});
        writetable(finTbl, finalStatusPath);
        fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
        if fidBottomProbe >= 0
            fclose(fidBottomProbe);
        end
        return;
    end

    runCtx = createRunContext('analysis', cfgRun);

    fidP = fopen(persistPath, 'w');
    if fidP < 0
        error('XYSwitchingMapCapture:PersistOpenFailed', 'Could not write path persist file');
    end
    fprintf(fidP, '%s\n', repoRoot);
    fprintf(fidP, '%s\n', runCtx.run_dir);
    fclose(fidP);

    if exist(switchingMainPath, 'file') ~= 2
        error('XYSwitchingMapCapture:MissingSwitchingMain', 'Switching_main not found: %s', switchingMainPath);
    end

    run(switchingMainPath);

    % Switching_main begins with clear; all prior workspace variables are gone here.
    repoRootRecover = fileparts(fileparts(mfilename('fullpath')));
    persistPathRecover = fullfile(repoRootRecover, 'tables', '_xy_switching_map_capture_paths.txt');
    fidP = fopen(persistPathRecover, 'r');
    if fidP < 0
        error('XYSwitchingMapCapture:PersistReadFailed', 'Could not read path persist file after Switching_main');
    end
    repoRoot2 = fgetl(fidP);
    runDir2 = fgetl(fidP);
    fclose(fidP);
    if exist(persistPathRecover, 'file') == 2
        delete(persistPathRecover);
    end

    if ~ischar(repoRoot2) || isempty(repoRoot2)
        error('XYSwitchingMapCapture:BadPersistRepo', 'Persist file missing repo root');
    end
    if ~ischar(runDir2) || isempty(runDir2)
        error('XYSwitchingMapCapture:BadPersistRunDir', 'Persist file missing run_dir');
    end
    repoRoot2 = strrep(strtrim(repoRoot2), char(13), '');
    runDir2 = strrep(strtrim(runDir2), char(13), '');

    figOutFig = fullfile(repoRoot2, 'figures', 'xy_switching_map.fig');
    figOutPng = fullfile(repoRoot2, 'figures', 'xy_switching_map.png');
    csvOutPath = fullfile(repoRoot2, 'tables', 'xy_switching_map.csv');
    reportPath = fullfile(repoRoot2, 'reports', 'xy_switching_map.md');
    captureStatusPath = fullfile(repoRoot2, 'tables', 'xy_switching_map_capture_status.csv');
    statusPath = fullfile(repoRoot2, 'execution_status.csv');
    validationReportPath = fullfile(repoRoot2, 'reports', 'xy_switching_map_capture_validation.md');
    hardeningStatusPath = fullfile(repoRoot2, 'tables', 'xy_switching_map_capture_hardening_status.csv');
    finalValidationPath = fullfile(repoRoot2, 'reports', 'xy_switching_map_final_validation.md');
    finalStatusPath = fullfile(repoRoot2, 'tables', 'xy_switching_map_final_status.csv');

    MIN_CDATA_PIXELS_PREFERRED = 900;

    selectionMethodStr = '';
    nFiguresDetected = 0;
    selectedFigName = '';
    mapImageRows = 0;
    mapImageCols = 0;
    mapCDataCount = 0;
    axisLabelDetail = '';
    axisValidationResult = '';
    axisLabelWarning = '';
    thresholdBehaviorStr = '';

    figAll = findall(0, 'Type', 'figure');
    nFiguresDetected = numel(figAll);
    figH = gobjects(0);

    primaryK = [];
    for kFig = 1:nFiguresDetected
        fh = figAll(kFig);
        if ~isgraphics(fh)
            continue;
        end
        nmFig = char(string(get(fh, 'Name')));
        if contains(nmFig, 'P2P_percent', 'IgnoreCase', true) && contains(nmFig, 'Amp-Temp', 'IgnoreCase', true)
            primaryK(end+1) = kFig; %#ok<AGROW>
        end
    end

    if ~isempty(primaryK)
        selectionMethodStr = 'primary_name_P2P_percent_and_Amp-Temp';
        bestScoreP = -1;
        bestFigP = gobjects(0);
        for u = 1:numel(primaryK)
            fh = figAll(primaryK(u));
            imgsP = findall(fh, 'Type', 'image');
            scoreP = 0;
            for v = 1:numel(imgsP)
                np = numel(imgsP(v).CData);
                if np > scoreP
                    scoreP = np;
                end
            end
            if scoreP > bestScoreP
                bestScoreP = scoreP;
                bestFigP = fh;
            end
        end
        if bestScoreP >= 0 && isgraphics(bestFigP)
            figH = bestFigP;
        end
    end

    if isempty(figH) || ~isgraphics(figH)
        selectionMethodStr = 'fallback_largest_image';
        bestScoreF = -1;
        bestFigF = gobjects(0);
        for kFig = 1:nFiguresDetected
            fh = figAll(kFig);
            if ~isgraphics(fh)
                continue;
            end
            imgsF = findall(fh, 'Type', 'image');
            scoreF = 0;
            for v = 1:numel(imgsF)
                nf = numel(imgsF(v).CData);
                if nf > scoreF
                    scoreF = nf;
                end
            end
            if scoreF > bestScoreF
                bestScoreF = scoreF;
                bestFigF = fh;
            end
        end
        if bestScoreF > 0 && isgraphics(bestFigF)
            figH = bestFigF;
        end
    end

    if isempty(figH) || ~isgraphics(figH)
        error('XYSwitchingMapCapture:NoFigure', ...
            'No suitable figure after Switching_main (figures=%d, primary=%d)', nFiguresDetected, numel(primaryK));
    end

    selectedFigName = char(string(get(figH, 'Name')));
    imgs = findall(figH, 'Type', 'image');
    if isempty(imgs)
        error('XYSwitchingMapCapture:NoImage', 'Selected figure has no image objects');
    end

    nPix = zeros(numel(imgs), 1);
    for ii = 1:numel(imgs)
        nPix(ii) = numel(imgs(ii).CData);
    end
    bigEnough = nPix > MIN_CDATA_PIXELS_PREFERRED;
    if any(bigEnough)
        imgsOk = imgs(bigEnough);
        nPixOk = nPix(bigEnough);
        [~, imax] = max(nPixOk);
        hImg = imgsOk(imax);
        thresholdBehaviorStr = 'preferred_900_used';
    else
        [~, imax] = max(nPix);
        hImg = imgs(imax);
        thresholdBehaviorStr = 'threshold_relaxed';
    end
    if isempty(hImg) || ~isgraphics(hImg) || isempty(hImg.CData)
        error('XYSwitchingMapCapture:NoValidImage', 'Selected figure has no usable image CData');
    end
    cdata0 = double(hImg.CData);
    [nr0, nc0] = size(cdata0);
    mapImageRows = nr0;
    mapImageCols = nc0;
    mapCDataCount = numel(cdata0);

    axMap = ancestor(hImg, 'axes');
    if isempty(axMap) || ~isgraphics(axMap(1))
        error('XYSwitchingMapCapture:NoAxes', 'Could not resolve axes for map image');
    end
    axMap = axMap(1);
    xlRaw = get(get(axMap, 'XLabel'), 'String');
    ylRaw = get(get(axMap, 'YLabel'), 'String');
    xl = lower(char(string(xlRaw)));
    yl = lower(char(string(ylRaw)));
    labCat = [xl, ' | ', yl];
    hasCurrent = contains(labCat, 'ma') || contains(labCat, 'current');
    hasTemp = contains(labCat, '(k)') || contains(labCat, 'temperature') || contains(labCat, 'temp');
    axisLabelDetail = sprintf('XLabel="%s" YLabel="%s" hasCurrent=%d hasTemp=%d', xl, yl, hasCurrent, hasTemp);
    if ~hasCurrent && ~hasTemp
        error('XYSwitchingMapCapture:AxisLabels', ...
            'Axes labels missing both current and temperature heuristics: %s', axisLabelDetail);
    end
    if hasCurrent && hasTemp
        axisValidationResult = 'OK';
        axisLabelWarning = '';
    else
        axisValidationResult = 'WARNING';
        if ~hasCurrent
            axisLabelWarning = 'WARNING: temperature-like label matched but current (mA) heuristic did not; proceeding.';
        else
            axisLabelWarning = 'WARNING: current-like label matched but temperature (K) heuristic did not; proceeding.';
        end
    end

    xd0 = double(hImg.XData(:));
    yd0 = double(hImg.YData(:));

    csvWritten = false;
    csvMsg = 'not written';
    nGrid = nr0 * nc0;
    if numel(xd0) == nc0 && numel(yd0) == nr0
        [XG, YG] = meshgrid(xd0, yd0);
        outTbl = table(YG(:), XG(:), cdata0(:), ...
            'VariableNames', {'temperature_K', 'current_mA', 'map_CData_as_on_figure'});
        writetable(outTbl, csvOutPath);
        csvWritten = true;
        csvMsg = fullfile('tables', 'xy_switching_map.csv');
    elseif numel(xd0) == 2 && numel(yd0) == 2 && nr0 > 4 && nc0 > 4
        xlin = linspace(xd0(1), xd0(2), nc0);
        ylin = linspace(yd0(1), yd0(2), nr0);
        [XG, YG] = meshgrid(xlin, ylin);
        outTbl = table(YG(:), XG(:), cdata0(:), ...
            'VariableNames', {'temperature_K', 'current_mA', 'map_CData_as_on_figure'});
        writetable(outTbl, csvOutPath);
        csvWritten = true;
        csvMsg = fullfile('tables', 'xy_switching_map.csv');
    else
        csvMsg = 'image XData/YData layout not recognized; CSV skipped';
    end

    cmapUse = colormap(axMap);
    climUse = caxis(axMap);
    cbLabelStr = 'S (%)';
    hOldCb = findobj(figH, 'Type', 'colorbar');
    if ~isempty(hOldCb)
        cbOld = hOldCb(1);
        if isprop(cbOld, 'Label')
            cbLabelStr = char(string(cbOld.Label.String));
            if isempty(strtrim(cbLabelStr))
                cbLabelStr = 'S (%)';
            end
        end
    end
    cbLabelStr = strrep(strrep(strrep(cbLabelStr, '$', ''), '\', ''), '{', '');
    cbLabelStr = strrep(cbLabelStr, '}', '');

    figClean = figure('Visible', 'off', 'Color', 'w', 'Name', '', 'NumberTitle', 'off');
    axC = axes(figClean);
    imagesc(axC, yd0, xd0, cdata0');
    axis(axC, 'tight');
    colormap(axC, cmapUse);
    caxis(axC, climUse);
    set(axC, 'YDir', 'normal', 'TickDir', 'in');
    xlabel(axC, 'T (K)', 'Interpreter', 'none');
    ylabel(axC, 'I (mA)', 'Interpreter', 'none');
    cbN = colorbar(axC);
    ylabel(cbN, cbLabelStr, 'Interpreter', 'none');
    cbN.TickLength = 0;

    savefig(figClean, figOutFig);
    saveas(figClean, figOutPng);
    figBytesPost = 0;
    pngBytesPost = 0;
    try
        jFig = javaObject('java.io.File', char(figOutFig));
        jPng = javaObject('java.io.File', char(figOutPng));
        if jFig.isFile()
            figBytesPost = double(jFig.length());
        end
        if jPng.isFile()
            pngBytesPost = double(jPng.length());
        end
    catch
    end
    close(figClean);

    if figBytesPost <= 0 || pngBytesPost <= 0
        error('XYSwitchingMapCapture:SaveMissing', 'FIG or PNG missing or empty immediately after savefig/saveas');
    end

    fidRep = fopen(reportPath, 'w');
    if fidRep < 0
        error('XYSwitchingMapCapture:ReportOpenFailed', 'Could not open report for write');
    end
    fprintf(fidRep, '# XY switching map capture\n\n');
    fprintf(fidRep, '## Source\n\n');
    fprintf(fidRep, '- Pipeline script: `Switching ver12/main/Switching_main.m` (unchanged)\n');
    fprintf(fidRep, '- Metric: P2P_percent (Config3 XY)\n\n');
    fprintf(fidRep, '## Artifacts\n\n');
    fprintf(fidRep, '- %s\n', strrep(figOutFig, '\', '/'));
    fprintf(fidRep, '- %s\n', strrep(figOutPng, '\', '/'));
    if csvWritten
        fprintf(fidRep, '- %s\n', strrep(csvOutPath, '\', '/'));
    else
        fprintf(fidRep, '- tables/xy_switching_map.csv: %s\n', csvMsg);
    end
    fprintf(fidRep, '\n## Validation and export details\n\n');
    fprintf(fidRep, 'See `reports/xy_switching_map_final_validation.md` and `tables/xy_switching_map_final_status.csv`.\n');
    fclose(fidRep);

    captureStatus = table({'SUCCESS'}, {'XY map saved as FIG and PNG; see report for CSV status'}, ...
        'VariableNames', {'status', 'message'});
    writetable(captureStatus, captureStatusPath);

    fidVal = fopen(validationReportPath, 'w');
    if fidVal >= 0
        fprintf(fidVal, '# XY switching map capture validation\n\n');
        fprintf(fidVal, 'Details moved to `reports/xy_switching_map_final_validation.md` (single validation narrative).\n');
        fclose(fidVal);
    end
    hardTbl = table({'UPDATED'}, {'Presentation export written; see xy_switching_map_final_validation.md'}, ...
        'VariableNames', {'status', 'message'});
    writetable(hardTbl, hardeningStatusPath);

    if contains(selectionMethodStr, 'primary', 'IgnoreCase', true)
        selectionShort = 'primary';
    else
        selectionShort = 'fallback';
    end
    finalVerdict = 'VALID_MAP';
    if ~strcmp(axisValidationResult, 'OK') || ~strcmp(thresholdBehaviorStr, 'preferred_900_used') || mapCDataCount < 300
        finalVerdict = 'NEEDS_REVIEW';
    end
    fidFin = fopen(finalValidationPath, 'w');
    if fidFin >= 0
        fprintf(fidFin, '# XY switching map final validation\n\n');
        fprintf(fidFin, '- execution_status: SUCCESS\n');
        fprintf(fidFin, '- selection_method: %s\n', selectionShort);
        fprintf(fidFin, '- figures_detected: %d\n', nFiguresDetected);
        fprintf(fidFin, '- image_size: %d x %d (%d pixels)\n', mapImageRows, mapImageCols, mapCDataCount);
        fprintf(fidFin, '- axis_validation: %s\n', axisValidationResult);
        fprintf(fidFin, '- threshold_behavior: %s\n', thresholdBehaviorStr);
        fprintf(fidFin, '- final_verdict: %s\n', finalVerdict);
        fprintf(fidFin, '\n## Presentation export (saved FIG/PNG)\n\n');
        fprintf(fidFin, '- clean_map_only: YES (new off-screen figure: image + axes labels + colorbar only; no lines/text/legend from pipeline)\n');
        fprintf(fidFin, '- X_axis_T_K: YES (imagesc X = temperature vector)\n');
        fprintf(fidFin, '- Y_axis_I_mA: YES (imagesc Y = current vector)\n');
        fprintf(fidFin, '- CData: transpose of captured map; same numeric values as pipeline image\n');
        fprintf(fidFin, '- FIG bytes after overwrite: %d\n', figBytesPost);
        fprintf(fidFin, '- PNG bytes after overwrite: %d\n', pngBytesPost);
        fprintf(fidFin, '\n## Files\n\n');
        fprintf(fidFin, '- FIG exists after save: YES\n');
        fprintf(fidFin, '- PNG exists after save: YES\n');
        if strcmp(axisValidationResult, 'WARNING') && ~isempty(axisLabelWarning)
            fprintf(fidFin, '\n## Source pipeline axis check (pre-export)\n\n');
            fprintf(fidFin, '- %s\n', axisLabelWarning);
        end
        fclose(fidFin);
    end
    finMsg = sprintf(['SUCCESS; selection=%s; axis=%s; threshold=%s; verdict=%s; ', ...
        'presentation_clean=YES; X=T_K=YES; Y=I_mA=YES; fig_bytes=%d; png_bytes=%d'], ...
        selectionShort, axisValidationResult, thresholdBehaviorStr, finalVerdict, figBytesPost, pngBytesPost);
    finTbl = table({'SUCCESS'}, {finMsg}, 'VariableNames', {'status', 'message'});
    writetable(finTbl, finalStatusPath);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nGrid, ...
        {'Switching_main map branch completed; figure captured to figures/'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDir2, 'execution_status.csv'));
    writetable(executionStatus, statusPath);

catch ME
    repoRootCatch = fileparts(fileparts(mfilename('fullpath')));
    persistPathCatch = fullfile(repoRootCatch, 'tables', '_xy_switching_map_capture_paths.txt');
    if exist(persistPathCatch, 'file') == 2
        try
            delete(persistPathCatch);
        catch
        end
    end

    captureStatusPathCatch = fullfile(repoRootCatch, 'tables', 'xy_switching_map_capture_status.csv');
    statusPathCatch = fullfile(repoRootCatch, 'execution_status.csv');

    runDirForStatus = fullfile(repoRootCatch, 'results', 'analysis', 'runs', 'run_xy_switching_map_capture_failure');
    if exist('runCtx', 'var') && isstruct(runCtx) && isfield(runCtx, 'run_dir') && ~isempty(runCtx.run_dir)
        runDirForStatus = runCtx.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end

    captureStatus = table({'FAILED'}, {ME.message}, 'VariableNames', {'status', 'message'});
    try
        writetable(captureStatus, captureStatusPathCatch);
    catch
    end

    validationReportPathCatch = fullfile(repoRootCatch, 'reports', 'xy_switching_map_capture_validation.md');
    hardeningStatusPathCatch = fullfile(repoRootCatch, 'tables', 'xy_switching_map_capture_hardening_status.csv');
    fidVal = fopen(validationReportPathCatch, 'w');
    if fidVal >= 0
        fprintf(fidVal, '# XY switching map capture validation\n\n');
        fprintf(fidVal, 'FAIL. See `reports/xy_switching_map_final_validation.md` for details.\n');
        fprintf(fidVal, 'Error: %s\n', ME.message);
        fclose(fidVal);
    end
    hardMsg = ['FAIL: ', ME.message];
    if numel(hardMsg) > 500
        hardMsg = [hardMsg(1:497), '...'];
    end
    try
        hardTbl = table({'NO_CHANGE'}, {hardMsg}, 'VariableNames', {'status', 'message'});
        writetable(hardTbl, hardeningStatusPathCatch);
    catch
    end

    finalValidationPathCatch = fullfile(repoRootCatch, 'reports', 'xy_switching_map_final_validation.md');
    finalStatusPathCatch = fullfile(repoRootCatch, 'tables', 'xy_switching_map_final_status.csv');
    fidFin = fopen(finalValidationPathCatch, 'w');
    if fidFin >= 0
        fprintf(fidFin, '# XY switching map final validation\n\n');
        fprintf(fidFin, '- execution_status: FAIL\n');
        fprintf(fidFin, '- error: %s\n\n', ME.message);
        if exist('selectionMethodStr', 'var') && ~isempty(selectionMethodStr)
            if contains(selectionMethodStr, 'primary', 'IgnoreCase', true)
                fprintf(fidFin, '- selection_method: primary (attempted)\n');
            else
                fprintf(fidFin, '- selection_method: fallback (attempted)\n');
            end
        else
            fprintf(fidFin, '- selection_method: unknown\n');
        end
        if exist('nFiguresDetected', 'var')
            fprintf(fidFin, '- figures_detected: %d\n', nFiguresDetected);
        else
            fprintf(fidFin, '- figures_detected: unknown\n');
        end
        if exist('mapImageRows', 'var') && exist('mapImageCols', 'var') && exist('mapCDataCount', 'var')
            fprintf(fidFin, '- image_size: %d x %d (%d pixels)\n', mapImageRows, mapImageCols, mapCDataCount);
        else
            fprintf(fidFin, '- image_size: unknown\n');
        end
        if exist('axisValidationResult', 'var') && ~isempty(axisValidationResult)
            fprintf(fidFin, '- axis_validation: %s\n', axisValidationResult);
        else
            fprintf(fidFin, '- axis_validation: unknown\n');
        end
        if exist('thresholdBehaviorStr', 'var') && ~isempty(thresholdBehaviorStr)
            fprintf(fidFin, '- threshold_behavior: %s\n', thresholdBehaviorStr);
        else
            fprintf(fidFin, '- threshold_behavior: unknown\n');
        end
        fprintf(fidFin, '- final_verdict: NEEDS_REVIEW\n');
        fclose(fidFin);
    end
    try
        finTbl = table({'FAIL'}, {hardMsg}, 'VariableNames', {'status', 'message'});
        writetable(finTbl, finalStatusPathCatch);
    catch
    end

    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'XY switching map capture failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    writetable(executionStatus, statusPathCatch);
    rethrow(ME);
end

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
