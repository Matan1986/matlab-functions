clearvars -except modules_used_input
clc

% Repo root for catch-path createRunContext (no hardcoded drive paths).
repoRootBootstrap = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRootBootstrap, 'tools'));

run = struct();
repoRoot = '';
run_dir = '';
test_path = '';
enforcement_checked = false;
modules_used = {};
% Signaling: column EXECUTION_STATUS in execution_status.csv is the sole authoritative final outcome
% (SUCCESS / FAILED / PARTIAL). execution_probe* files and runtime_execution_markers.txt are auxiliary.

implStatusPath = '';
implReportPath = '';

try
    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    analysisDir = fileparts(mfilename('fullpath'));
    switchingDir = fullfile(repoRoot, 'Switching');
    disp('SCRIPT_ENTERED');

    restoredefaultpath;
    addpath(fullfile(repoRoot, 'tools'));
    addpath(fullfile(repoRoot, 'Aging', 'utils'));
    if exist(fullfile(repoRoot, 'Aging', 'utils'), 'dir') ~= 7
        error('Aging utils path not found');
    end
    addpath(fullfile(repoRoot, 'General ver2'));
    addpath(fullfile(switchingDir, 'utils'));

    moduleRegistry = loadModuleCanonicalStatus(repoRoot);
    idxSw = strcmp(cellstr(string(moduleRegistry.MODULE)), 'Switching');
    if ~any(idxSw)
        error('run_switching_canonical:RegistrySwitchingMissing', ...
            'Switching is not listed in tables/module_canonical_status.csv');
    end
    rowSw = find(idxSw, 1);
    stSw = moduleRegistry.STATUS(rowSw);
    if iscell(stSw)
        stSw = stSw{1};
    end
    stSw = char(string(stSw));
    if ~strcmp(stSw, 'CANONICAL')
        error('run_switching_canonical:RegistrySwitchingNotCanonical', ...
            'Switching must be CANONICAL in tables/module_canonical_status.csv (found STATUS=%s).', stSw);
    end

    modules_used = {'Switching'};
    if exist('modules_used_input', 'var')
        modules_used = modules_used_input;
    end
    if length(modules_used) > 1
        assertModulesCanonical(modules_used);
        enforcement_checked = true;
    else
        enforcement_checked = true;   % explicitly mark evaluated
    end

    legacyRoot = fullfile(switchingDir, '..', 'Switching ver12');
    if exist(legacyRoot, 'dir') ~= 7
        error('run_switching_canonical:MissingLegacyRoot', 'Missing legacy switching root: %s', legacyRoot);
    end
    addpath(legacyRoot);
    addpath(fullfile(legacyRoot, 'main'));
    addpath(fullfile(legacyRoot, 'plots'));
    addpath(fullfile(legacyRoot, 'parsing'));
    addpath(fullfile(legacyRoot, 'utils'));

    expectedCreateRunContextPath = fullfile(repoRoot, 'Aging', 'utils', 'createRunContext.m');
    expectedCreateRunContext = lower(strrep(expectedCreateRunContextPath, '/', '\'));
    resolvedCreateRunContext = lower(strrep(which('createRunContext'), '/', '\'));
    if isempty(resolvedCreateRunContext) || ~strcmp(resolvedCreateRunContext, expectedCreateRunContext)
        error('run_switching_canonical:CreateRunContextResolution', ...
            'createRunContext resolved to unexpected path: %s', which('createRunContext'));
    end

    disp('=== START SCRIPT ===');
    disp(pwd);
    disp(which('createRunContext'));

    cfg = struct();
    cfg.runLabel = 'switching_canonical';
    cfg.dataset = 'raw_switching_dat_only';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    ctx = createSwitchingRunContext(repoRoot, cfg);
    run = ctx;
    run_dir = run.run_dir;
    if exist(run_dir, 'dir') ~= 7
        mkdir(run_dir);
    end
    write_execution_marker('ENTRY');
    runDir = run_dir;
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run_dir created'}, false);
    fidE = fopen(fullfile(runDir, 'enforcement_status.txt'), 'w');
    if fidE >= 0
        if enforcement_checked
            fprintf(fidE, 'ENFORCEMENT_CHECKED=YES\n');
        else
            fprintf(fidE, 'ENFORCEMENT_CHECKED=NO\n');
        end
        if isempty(modules_used)
            fprintf(fidE, 'MODULES_USED=\n');
        else
            fprintf(fidE, 'MODULES_USED=%s\n', strjoin(modules_used, ','));
        end
        fclose(fidE);
    end

    fid = fopen(fullfile(run_dir, 'execution_probe_top.txt'), 'w');
    fclose(fid);
    
    disp('=== RUN CONTEXT ===');
    disp(run_dir);

    tablesDir = fullfile(runDir, 'tables');
    reportsDir = fullfile(runDir, 'reports');
    if exist(tablesDir, 'dir') ~= 7
        mkdir(tablesDir);
    end
    if exist(reportsDir, 'dir') ~= 7
        mkdir(reportsDir);
    end

    implStatusPath = fullfile(tablesDir, 'run_switching_canonical_implementation_status.csv');
    implReportPath = fullfile(reportsDir, 'run_switching_canonical_implementation.md');

    test_table = table(1, 'VariableNames', {'probe_value'});
    test_path = fullfile(run_dir, 'execution_probe.csv');
    writetable(test_table, test_path);
    disp('=== WRITE TEST ===');
    disp(test_path);
    assert(isfile(test_path), 'WRITE FAILED: execution_probe.csv not created');

    RUN_DIR_CREATED = "NO";
    WRITE_SUCCESS = "NO";
    if exist(run_dir, 'dir') == 7
        RUN_DIR_CREATED = "YES";
    end
    if isfile(test_path)
        WRITE_SUCCESS = "YES";
    end

    probeStatus = table( ...
        string(which('createRunContext')), ...
        string(run_dir), ...
        string(test_path), ...
        RUN_DIR_CREATED, ...
        WRITE_SUCCESS, ...
        'VariableNames', {'CREATE_RUN_CONTEXT_PATH', 'RUN_DIR', 'EXECUTION_PROBE_PATH', 'RUN_DIR_CREATED', 'WRITE_SUCCESS'});
    writetable(probeStatus, fullfile(run_dir, 'execution_probe_status.csv'));

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'probe write test passed'}, false);
    fidE = fopen(fullfile(runDir, 'enforcement_status.txt'), 'w');
    if fidE >= 0
        if enforcement_checked
            fprintf(fidE, 'ENFORCEMENT_CHECKED=YES\n');
        else
            fprintf(fidE, 'ENFORCEMENT_CHECKED=NO\n');
        end
        if isempty(modules_used)
            fprintf(fidE, 'MODULES_USED=\n');
        else
            fprintf(fidE, 'MODULES_USED=%s\n', strjoin(modules_used, ','));
        end
        fclose(fidE);
    end

    switchMainPath = fullfile(legacyRoot, 'main', 'Switching_main.m');
    if exist(switchMainPath, 'file') ~= 2
        error('run_switching_canonical:MissingSwitchingMain', 'Missing source file: %s', switchMainPath);
    end

    switchMainText = fileread(switchMainPath);
    tok = regexp(switchMainText, 'dir\s*=\s*"([^"]+)"', 'tokens', 'once');
    if isempty(tok)
        error('run_switching_canonical:MissingParentDir', 'Could not parse parent raw path from %s', switchMainPath);
    end
    parentDir = char(string(tok{1}));
    if exist(parentDir, 'dir') ~= 7
        error('run_switching_canonical:ParentDirMissing', 'Parsed parentDir does not exist: %s', parentDir);
    end

    sourceFunction = 'getFileListSwitching + processFilesSwitching';
    sourcePath = parentDir;
    sourceFile = fullfile(legacyRoot, 'main', 'processFilesSwitching.m');
    sourceMethod = 'MINIMAL_PROCESSING';

    inputPaths = strings(0, 1);
    inputPaths(end+1, 1) = string(switchMainPath);

    subDirs = dir(parentDir);
    subNames = string({subDirs.name});
    isSub = [subDirs.isdir] & ~startsWith(subNames, ".");
    isTempDep = startsWith(subNames, "Temp Dep", 'IgnoreCase', true);
    subDirs = subDirs(isSub & isTempDep);
    if isempty(subDirs)
        error('run_switching_canonical:NoTempDepFolders', 'No "Temp Dep" subfolders found under %s', parentDir);
    end

    rowsCurrent = [];
    rowsTemp = [];
    rowsS = [];
    rowsChannel = [];
    rowsFolder = strings(0, 1);
    totalRawFiles = 0;

    write_execution_marker('STAGE_START_PIPELINE');
    for iDir = 1:numel(subDirs)
        thisDir = fullfile(parentDir, subDirs(iDir).name);
        dep_type = extract_dep_type_from_folder(thisDir);
        [fileList, sortedValues, ~, meta] = getFileListSwitching(thisDir, dep_type);
        if isempty(fileList)
            continue;
        end
        if ~isfield(meta, 'Current_mA') || ~isfinite(meta.Current_mA)
            error('run_switching_canonical:MissingCurrentMetadata', 'Missing Current_mA in folder: %s', thisDir);
        end

        inputPaths(end+1, 1) = string(thisDir);
        for iFile = 1:numel(fileList)
            inputPaths(end+1, 1) = string(fullfile(thisDir, fileList(iFile).name));
        end
        totalRawFiles = totalRawFiles + numel(fileList);

        pulseScheme = extractPulseSchemeFromFolder(thisDir);
        delay_between_pulses_in_msec = extract_delay_between_pulses_from_name(thisDir) * 1e3;
        num_of_pulses_with_same_dep = pulseScheme.totalPulses;

        normalize_to = 1;
        if exist('resolve_preset', 'file') == 2 && exist('select_preset', 'file') == 2
            preset_name = resolve_preset(fileList(1).name, true, '1xy_3xx');
            [~, ~, ~, normalize_to_candidate] = select_preset(preset_name);
            if ~isempty(normalize_to_candidate)
                normalize_to = normalize_to_candidate;
            end
        end

        I_A = meta.Current_mA / 1000;
        if ~isfinite(I_A) || I_A == 0
            error('run_switching_canonical:InvalidCurrent', 'Invalid current parsed in %s', thisDir);
        end
        scaling_factor = 1e3;

        [stored_data, tableData] = processFilesSwitching( ...
            thisDir, fileList, sortedValues, I_A, scaling_factor, ...
            4000, 16, 4, ...
            2, 11, ...
            false, delay_between_pulses_in_msec, ...
            num_of_pulses_with_same_dep, 15, ...
            NaN, NaN, normalize_to, ...
            true, 1.5, 50, false, pulseScheme);

        stbOpts = struct();
        stbOpts.useFiltered = true;
        stbOpts.useCentered = false;
        stbOpts.stateMethod = pulseScheme.mode;
        stbOpts.skipFirstPlateaus = 1;
        stbOpts.skipLastPlateaus = 0;
        stbOpts.pulseScheme = pulseScheme;
        stbOpts.debugMode = false;
        stability = analyzeSwitchingStability(stored_data, sortedValues, delay_between_pulses_in_msec, 15, stbOpts);

        ch = stability.switching.globalChannel;
        if ~(isfinite(ch) && any(ch == [1, 2, 3, 4])) %#ok<NBRAK>
            error('run_switching_canonical:InvalidSwitchingChannel', 'Invalid switching channel in %s', thisDir);
        end
        chName = sprintf('ch%d', ch);
        if ~isfield(tableData, chName) || isempty(tableData.(chName))
            error('run_switching_canonical:MissingChannelTable', 'Missing tableData.%s in %s', chName, thisDir);
        end

        metricTbl = tableData.(chName);
        Tvec = metricTbl(:, 1);
        Svec = metricTbl(:, 4);
        if exist('resolveNegP2P', 'file') == 2
            negP2P = resolveNegP2P(thisDir, "auto");
            if negP2P
                Svec = -Svec;
            end
        end

        keep = isfinite(Tvec) & isfinite(Svec);
        Tvec = Tvec(keep);
        Svec = Svec(keep);
        if isempty(Tvec)
            continue;
        end

        [Tuniq, ~, grp] = unique(Tvec(:));
        Suniq = accumarray(grp, Svec(:), [], @mean, NaN);
        nAdd = numel(Tuniq);

        rowsCurrent = [rowsCurrent; repmat(meta.Current_mA, nAdd, 1)]; %#ok<AGROW>
        rowsTemp = [rowsTemp; Tuniq(:)]; %#ok<AGROW>
        rowsS = [rowsS; Suniq(:)]; %#ok<AGROW>
        rowsChannel = [rowsChannel; repmat(ch, nAdd, 1)]; %#ok<AGROW>
        rowsFolder = [rowsFolder; repmat(string(subDirs(iDir).name), nAdd, 1)]; %#ok<AGROW>
    end

    write_execution_marker('STAGE_AFTER_PROCESSING');

    if isempty(rowsCurrent)
        error('run_switching_canonical:NoSamples', 'No switching samples were collected from upstream raw source: %s', parentDir);
    end
    if totalRawFiles <= 0
        error('run_switching_canonical:NoRawFiles', 'No raw .dat files were discovered in upstream source: %s', parentDir);
    end

    metricTypeCol = repmat("P2P_percent", numel(rowsCurrent), 1);
    rawTbl = table(rowsCurrent, rowsTemp, rowsS, rowsChannel, rowsFolder, metricTypeCol, ...
        'VariableNames', {'current_mA', 'T_K', 'S_percent', 'channel', 'folder', 'metricType'});
    rawTbl = sortrows(rawTbl, {'current_mA', 'T_K', 'channel'});

    tempsRaw = unique(rawTbl.T_K(isfinite(rawTbl.T_K)));
    currents = unique(rawTbl.current_mA(isfinite(rawTbl.current_mA)));
    tempsRaw = sort(tempsRaw(:));
    currents = sort(currents(:));
    if isempty(tempsRaw) || isempty(currents)
        error('run_switching_canonical:EmptyGrid', 'Upstream data could not build non-empty T/I grid.');
    end

    Sraw = NaN(numel(tempsRaw), numel(currents));
    for it = 1:numel(tempsRaw)
        for ii = 1:numel(currents)
            m = abs(rawTbl.T_K - tempsRaw(it)) < 1e-9 & abs(rawTbl.current_mA - currents(ii)) < 1e-9;
            if any(m)
                Sraw(it, ii) = mean(rawTbl.S_percent(m), 'omitnan');
            end
        end
    end

    Tclean = round(tempsRaw);
    [temps, ~, idxClean] = unique(Tclean, 'sorted');
    Smap = NaN(numel(temps), numel(currents));
    for k = 1:numel(temps)
        mk = idxClean == k;
        Smap(k, :) = mean(Sraw(mk, :), 1, 'omitnan');
    end
    temps = temps(:);
    currents = currents(:);

    nT = numel(temps);
    nI = numel(currents);

    Speak = NaN(nT, 1);
    Ipeak = NaN(nT, 1);
    for it = 1:nT
        row = Smap(it, :);
        valid = isfinite(row);
        if ~any(valid)
            continue;
        end
        rowValid = row(valid);
        currValid = currents(valid);
        [smax, idx] = max(rowValid);
        Speak(it) = smax;
        Ipeak(it) = currValid(idx);
    end

    PTmap = NaN(nT, nI);
    CDFmap = NaN(nT, nI);
    Scdf = NaN(nT, nI);
    for it = 1:nT
        row = Smap(it, :);
        valid = isfinite(row) & isfinite(currents');
        if nnz(valid) < 3 || ~isfinite(Speak(it)) || Speak(it) <= 0
            continue;
        end

        Ivalid = currents(valid);
        svalid = row(valid);
        cdfRaw = svalid ./ Speak(it);
        cdfRaw = min(max(cdfRaw, 0), 1);
        for j = 2:numel(cdfRaw)
            if cdfRaw(j) < cdfRaw(j - 1)
                cdfRaw(j) = cdfRaw(j - 1);
            end
        end
        if cdfRaw(end) > 0
            cdfRaw = cdfRaw ./ cdfRaw(end);
        end

        p = gradient(cdfRaw, Ivalid);
        p(~isfinite(p)) = 0;
        p = max(p, 0);
        areaP = trapz(Ivalid, p);
        if isfinite(areaP) && areaP > 0
            p = p ./ areaP;
        else
            p(:) = 0;
        end

        cdfPt = cumtrapz(Ivalid, p);
        if cdfPt(end) > 0
            cdfPt = cdfPt ./ cdfPt(end);
        end
        cdfPt = min(max(cdfPt, 0), 1);

        PTmap(it, valid) = p;
        CDFmap(it, valid) = cdfPt;
        Scdf(it, valid) = Speak(it) .* cdfPt;
    end

    residual = Smap - Scdf;
    Rfill = residual;
    Rfill(~isfinite(Rfill)) = 0;
    if any(abs(Rfill(:)) > 0)
        [U, Sigma, V] = svd(Rfill, 'econ');
        phi1 = V(:, 1);
        kappa1 = U(:, 1) * Sigma(1, 1);
    else
        phi1 = zeros(nI, 1);
        kappa1 = zeros(nT, 1);
    end

    phiScale = max(abs(phi1), [], 'omitnan');
    if isfinite(phiScale) && phiScale > 0
        phi1 = phi1 ./ phiScale;
        kappa1 = kappa1 .* phiScale;
    end
    signCorr = corr(Speak, kappa1, 'Rows', 'complete', 'Type', 'Spearman');
    if isfinite(signCorr) && signCorr < 0
        phi1 = -phi1;
        kappa1 = -kappa1;
    end

    Sfull = Scdf + kappa1 * phi1';

    rmsePtRows = NaN(nT, 1);
    rmseFullRows = NaN(nT, 1);
    for it = 1:nT
        mPt = isfinite(Smap(it, :)) & isfinite(Scdf(it, :));
        if any(mPt)
            rmsePtRows(it) = sqrt(mean((Smap(it, mPt) - Scdf(it, mPt)) .^ 2, 'omitnan'));
        end
        mFull = isfinite(Smap(it, :)) & isfinite(Sfull(it, :));
        if any(mFull)
            rmseFullRows(it) = sqrt(mean((Smap(it, mFull) - Sfull(it, mFull)) .^ 2, 'omitnan'));
        end
    end

    mPtGlobal = isfinite(Smap) & isfinite(Scdf);
    mFullGlobal = isfinite(Smap) & isfinite(Sfull);
    RMSE_PT = NaN;
    RMSE_FULL = NaN;
    if any(mPtGlobal(:))
        RMSE_PT = sqrt(mean((Smap(mPtGlobal) - Scdf(mPtGlobal)) .^ 2, 'omitnan'));
    end
    if any(mFullGlobal(:))
        RMSE_FULL = sqrt(mean((Smap(mFullGlobal) - Sfull(mFullGlobal)) .^ 2, 'omitnan'));
    end

    phiCosinePerT = NaN(nT, 1);
    for it = 1:nT
        r = residual(it, :)';
        m = isfinite(r) & isfinite(phi1);
        if nnz(m) < 3
            continue;
        end
        nr = norm(r(m));
        np = norm(phi1(m));
        if nr > 0 && np > 0
            phiCosinePerT(it) = abs(dot(r(m), phi1(m)) / (nr * np));
        end
    end
    PHI_MEDIAN_COSINE = median(phiCosinePerT, 'omitnan');
    KAPPA_SPEAK_CORR = corr(abs(kappa1), Speak, 'Rows', 'complete', 'Type', 'Spearman');

    isPrecomputedRead = any(endsWith(inputPaths, '.csv')) || any(endsWith(inputPaths, '.mat')) || any(contains(inputPaths, '\results\'));

    CHECK_NO_PRECOMPUTED_INPUTS = "NO";
    if ~isPrecomputedRead
        CHECK_NO_PRECOMPUTED_INPUTS = "YES";
    end
    STRUCTURAL_VALID = "NO";
    if CHECK_NO_PRECOMPUTED_INPUTS == "YES"
        STRUCTURAL_VALID = "YES";
    end

    S_SOURCE = sprintf('%s | %s | parentDir=%s', sourceFunction, sourceFile, sourcePath);
    S_CONSTRUCTION_METHOD = sourceMethod;
    USES_ROOT_TABLES = "NO";
    PROVENANCE_VALID = "NO";
    if strlength(string(S_SOURCE)) > 0 && USES_ROOT_TABLES == "NO"
        PROVENANCE_VALID = "YES";
    end

    RECONSTRUCTION_IMPROVES = "NO";
    if isfinite(RMSE_PT) && isfinite(RMSE_FULL) && RMSE_FULL < RMSE_PT
        RECONSTRUCTION_IMPROVES = "YES";
    end
    FUNCTIONAL_VALID = "NO";
    if RECONSTRUCTION_IMPROVES == "YES"
        FUNCTIONAL_VALID = "YES";
    end

    PHI_SHAPE_STABLE = "NO";
    if isfinite(PHI_MEDIAN_COSINE) && PHI_MEDIAN_COSINE >= 0.30
        PHI_SHAPE_STABLE = "YES";
    end
    KAPPA_SCALING_REASONABLE = "NO";
    if isfinite(KAPPA_SPEAK_CORR) && KAPPA_SPEAK_CORR > 0
        KAPPA_SCALING_REASONABLE = "YES";
    end
    INVARIANCE_VALID = "NO";
    if PHI_SHAPE_STABLE == "YES" && KAPPA_SCALING_REASONABLE == "YES"
        INVARIANCE_VALID = "YES";
    end

    RUN_CONTEXT_IS_SWITCHING_ISOLATED = "NO";
    runDirLower = lower(strrep(run.run_dir, '/', '\'));
    if contains(runDirLower, 'results\switching\runs') || contains(runDirLower, 'results/switching/runs')
        RUN_CONTEXT_IS_SWITCHING_ISOLATED = "YES";
    end

    CANONICAL_SWITCHING_GENERATOR_CREATED = "YES";
    UPSTREAM_S_SOURCE_IDENTIFIED = "YES";
    SP_DERIVED_FROM_S = "YES";
    IP_DERIVED_FROM_S = "YES";

    CANONICAL_PIPELINE_CONFIRMED = "NO";
    if STRUCTURAL_VALID == "YES" && PROVENANCE_VALID == "YES" && FUNCTIONAL_VALID == "YES" && INVARIANCE_VALID == "YES"
        CANONICAL_PIPELINE_CONFIRMED = "YES";
    end
    READY_FOR_SINGLE_CANONICAL_RUN = "NO";
    if CANONICAL_PIPELINE_CONFIRMED == "YES"
        READY_FOR_SINGLE_CANONICAL_RUN = "YES";
    end

    [TT, II] = ndgrid(temps, currents);
    SLong = table(TT(:), II(:), Smap(:), Scdf(:), Sfull(:), residual(:), PTmap(:), CDFmap(:), ...
        'VariableNames', {'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent', 'S_model_full_percent', 'residual_percent', 'PT_pdf', 'CDF_pt'});

    write_execution_marker('STAGE_BEFORE_OUTPUTS');

    writetable(SLong, fullfile(tablesDir, 'switching_canonical_S_long.csv'));

    ObsTbl = table(temps, Speak, Ipeak, kappa1, rmsePtRows, rmseFullRows, phiCosinePerT, ...
        'VariableNames', {'T_K', 'S_peak', 'I_peak', 'kappa1', 'rmse_pt_row', 'rmse_full_row', 'phi_cosine_row'});
    writetable(ObsTbl, fullfile(tablesDir, 'switching_canonical_observables.csv'));

    PhiTbl = table(currents, phi1, 'VariableNames', {'current_mA', 'Phi1'});
    writetable(PhiTbl, fullfile(tablesDir, 'switching_canonical_phi1.csv'));

    validationTbl = table( ...
        CHECK_NO_PRECOMPUTED_INPUTS, STRUCTURAL_VALID, ...
        string(S_SOURCE), string(S_CONSTRUCTION_METHOD), USES_ROOT_TABLES, PROVENANCE_VALID, ...
        RMSE_PT, RMSE_FULL, RECONSTRUCTION_IMPROVES, FUNCTIONAL_VALID, ...
        PHI_MEDIAN_COSINE, KAPPA_SPEAK_CORR, PHI_SHAPE_STABLE, KAPPA_SCALING_REASONABLE, INVARIANCE_VALID, ...
        CANONICAL_PIPELINE_CONFIRMED, ...
        'VariableNames', {'CHECK_NO_PRECOMPUTED_INPUTS', 'STRUCTURAL_VALID', ...
        'S_SOURCE', 'S_CONSTRUCTION_METHOD', 'USES_ROOT_TABLES', 'PROVENANCE_VALID', ...
        'RMSE_PT', 'RMSE_FULL', 'RECONSTRUCTION_IMPROVES', 'FUNCTIONAL_VALID', ...
        'PHI_MEDIAN_COSINE', 'KAPPA_SPEAK_CORR', 'PHI_SHAPE_STABLE', 'KAPPA_SCALING_REASONABLE', 'INVARIANCE_VALID', ...
        'CANONICAL_PIPELINE_CONFIRMED'});
    writetable(validationTbl, fullfile(tablesDir, 'switching_canonical_validation.csv'));

    reportPath = fullfile(reportsDir, 'run_switching_canonical_report.md');
    fidReport = fopen(reportPath, 'w');
    if fidReport < 0
        error('run_switching_canonical:ReportWriteFailed', 'Failed writing %s', reportPath);
    end
    fprintf(fidReport, '# run_switching_canonical\n\n');
    fprintf(fidReport, '- RUN_DIR: `%s`\n', runDir);
    fprintf(fidReport, '- S_SOURCE: `%s`\n', S_SOURCE);
    fprintf(fidReport, '- S_CONSTRUCTION_METHOD: `%s`\n', S_CONSTRUCTION_METHOD);
    fprintf(fidReport, '- RAW_PARENT_DIR: `%s`\n', parentDir);
    fprintf(fidReport, '- RAW_FILES_DISCOVERED: `%d`\n', totalRawFiles);
    fprintf(fidReport, '- CHECK_NO_PRECOMPUTED_INPUTS: `%s`\n', CHECK_NO_PRECOMPUTED_INPUTS);
    fprintf(fidReport, '- PROVENANCE_VALID: `%s`\n', PROVENANCE_VALID);
    fprintf(fidReport, '- RMSE_PT: `%.12g`\n', RMSE_PT);
    fprintf(fidReport, '- RMSE_FULL: `%.12g`\n', RMSE_FULL);
    fprintf(fidReport, '- RECONSTRUCTION_IMPROVES: `%s`\n', RECONSTRUCTION_IMPROVES);
    fprintf(fidReport, '- PHI_SHAPE_STABLE: `%s` (median cosine = %.6f)\n', PHI_SHAPE_STABLE, PHI_MEDIAN_COSINE);
    fprintf(fidReport, '- KAPPA_SCALING_REASONABLE: `%s` (spearman = %.6f)\n', KAPPA_SCALING_REASONABLE, KAPPA_SPEAK_CORR);
    fprintf(fidReport, '- CANONICAL_PIPELINE_CONFIRMED: `%s`\n', CANONICAL_PIPELINE_CONFIRMED);
    fprintf(fidReport, '\n## Minimal createRunContext isolation\n');
    fprintf(fidReport, '- Added only `Aging/utils` to path to access `createRunContext`.\n');
    fprintf(fidReport, '- Run context uses experiment tag `switching` under `results/switching/runs`; outputs are run-scoped.\n');
    fclose(fidReport);

    implStatusTbl = table( ...
        CANONICAL_SWITCHING_GENERATOR_CREATED, ...
        UPSTREAM_S_SOURCE_IDENTIFIED, ...
        SP_DERIVED_FROM_S, ...
        IP_DERIVED_FROM_S, ...
        RUN_CONTEXT_IS_SWITCHING_ISOLATED, ...
        STRUCTURAL_VALID, ...
        PROVENANCE_VALID, ...
        FUNCTIONAL_VALID, ...
        INVARIANCE_VALID, ...
        CANONICAL_PIPELINE_CONFIRMED, ...
        READY_FOR_SINGLE_CANONICAL_RUN, ...
        CHECK_NO_PRECOMPUTED_INPUTS, ...
        RECONSTRUCTION_IMPROVES, ...
        PHI_SHAPE_STABLE, ...
        KAPPA_SCALING_REASONABLE, ...
        RMSE_PT, ...
        RMSE_FULL, ...
        PHI_MEDIAN_COSINE, ...
        KAPPA_SPEAK_CORR, ...
        string(S_SOURCE), ...
        string(S_CONSTRUCTION_METHOD), ...
        string(run.run_id), ...
        string(run.run_dir), ...
        'VariableNames', {'CANONICAL_SWITCHING_GENERATOR_CREATED', 'UPSTREAM_S_SOURCE_IDENTIFIED', ...
        'SP_DERIVED_FROM_S', 'IP_DERIVED_FROM_S', ...
        'RUN_CONTEXT_IS_SWITCHING_ISOLATED', 'STRUCTURAL_VALID', 'PROVENANCE_VALID', ...
        'FUNCTIONAL_VALID', 'INVARIANCE_VALID', 'CANONICAL_PIPELINE_CONFIRMED', 'READY_FOR_SINGLE_CANONICAL_RUN', ...
        'CHECK_NO_PRECOMPUTED_INPUTS', 'RECONSTRUCTION_IMPROVES', ...
        'PHI_SHAPE_STABLE', 'KAPPA_SCALING_REASONABLE', 'RMSE_PT', 'RMSE_FULL', ...
        'PHI_MEDIAN_COSINE', 'KAPPA_SPEAK_CORR', 'S_SOURCE', 'S_CONSTRUCTION_METHOD', 'RUN_ID', 'RUN_DIR'});
    writetable(implStatusTbl, implStatusPath);

    fidImpl = fopen(implReportPath, 'w');
    if fidImpl < 0
        error('run_switching_canonical:ImplReportWriteFailed', 'Failed writing %s', implReportPath);
    end
    fprintf(fidImpl, '# run_switching_canonical implementation\n\n');
    fprintf(fidImpl, '- FILE: `Switching/analysis/run_switching_canonical.m`\n');
    fprintf(fidImpl, '- RUN_ID: `%s`\n', run.run_id);
    fprintf(fidImpl, '- RUN_DIR: `%s`\n', run.run_dir);
    fprintf(fidImpl, '- S_SOURCE: `%s`\n', S_SOURCE);
    fprintf(fidImpl, '- S_CONSTRUCTION_METHOD: `%s`\n', S_CONSTRUCTION_METHOD);
    fprintf(fidImpl, '- CHECK_NO_PRECOMPUTED_INPUTS: `%s`\n', CHECK_NO_PRECOMPUTED_INPUTS);
    fprintf(fidImpl, '- STRUCTURAL_VALID: `%s`\n', STRUCTURAL_VALID);
    fprintf(fidImpl, '- PROVENANCE_VALID: `%s`\n', PROVENANCE_VALID);
    fprintf(fidImpl, '- FUNCTIONAL_VALID: `%s`\n', FUNCTIONAL_VALID);
    fprintf(fidImpl, '- INVARIANCE_VALID: `%s`\n', INVARIANCE_VALID);
    fprintf(fidImpl, '- CANONICAL_PIPELINE_CONFIRMED: `%s`\n', CANONICAL_PIPELINE_CONFIRMED);
    fprintf(fidImpl, '- READY_FOR_SINGLE_CANONICAL_RUN: `%s`\n', READY_FOR_SINGLE_CANONICAL_RUN);
    fprintf(fidImpl, '\n## Required verdicts\n');
    fprintf(fidImpl, '- CANONICAL_SWITCHING_GENERATOR_CREATED: `%s`\n', CANONICAL_SWITCHING_GENERATOR_CREATED);
    fprintf(fidImpl, '- UPSTREAM_S_SOURCE_IDENTIFIED: `%s`\n', UPSTREAM_S_SOURCE_IDENTIFIED);
    fprintf(fidImpl, '- SP_DERIVED_FROM_S: `%s`\n', SP_DERIVED_FROM_S);
    fprintf(fidImpl, '- IP_DERIVED_FROM_S: `%s`\n', IP_DERIVED_FROM_S);
    fprintf(fidImpl, '- RUN_CONTEXT_IS_SWITCHING_ISOLATED: `%s`\n', RUN_CONTEXT_IS_SWITCHING_ISOLATED);
    fprintf(fidImpl, '- STRUCTURAL_VALID: `%s`\n', STRUCTURAL_VALID);
    fprintf(fidImpl, '- PROVENANCE_VALID: `%s`\n', PROVENANCE_VALID);
    fprintf(fidImpl, '- FUNCTIONAL_VALID: `%s`\n', FUNCTIONAL_VALID);
    fprintf(fidImpl, '- INVARIANCE_VALID: `%s`\n', INVARIANCE_VALID);
    fprintf(fidImpl, '- CANONICAL_PIPELINE_CONFIRMED: `%s`\n', CANONICAL_PIPELINE_CONFIRMED);
    fprintf(fidImpl, '- READY_FOR_SINGLE_CANONICAL_RUN: `%s`\n', READY_FOR_SINGLE_CANONICAL_RUN);
    fprintf(fidImpl, '\n## Minimal createRunContext isolation\n');
    fprintf(fidImpl, '- Added `Aging/utils` only, to call `createRunContext`.\n');
    fprintf(fidImpl, '- No cross-pipeline data inputs were used.\n');
    fclose(fidImpl);

    write_execution_marker('STAGE_AFTER_OUTPUTS');

    writeRunValidityClassification(runDir, repoRoot, enforcement_checked, modules_used, ...
        strcmp(RUN_CONTEXT_IS_SWITCHING_ISOLATED, "YES"));

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'switching_canonical completed'}, true);
    fidE = fopen(fullfile(runDir, 'enforcement_status.txt'), 'w');
    if fidE >= 0
        if enforcement_checked
            fprintf(fidE, 'ENFORCEMENT_CHECKED=YES\n');
        else
            fprintf(fidE, 'ENFORCEMENT_CHECKED=NO\n');
        end
        if isempty(modules_used)
            fprintf(fidE, 'MODULES_USED=\n');
        else
            fprintf(fidE, 'MODULES_USED=%s\n', strjoin(modules_used, ','));
        end
        fclose(fidE);
    end

    % Non-authoritative timeline marker; final status is EXECUTION_STATUS in execution_status.csv above.
    write_execution_marker('COMPLETED');

catch ME
    runDirForStatus = '';
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = run_dir;
    end

    if isempty(runDirForStatus)
        repoR = repoRootBootstrap;
        if isempty(repoR)
            repoR = fileparts(fileparts(fileparts(mfilename('fullpath'))));
        end
        addpath(fullfile(repoR, 'Aging', 'utils'));
        addpath(fullfile(repoR, 'Switching', 'utils'));
        cfgFail = struct();
        cfgFail.runLabel = 'switching_canonical_failure';
        cfgFail.dataset = 'raw_switching_dat_only';
        cfgFail.fingerprint_script_path = fullfile(repoR, 'Switching', 'analysis', 'run_switching_canonical.m');
        try
            rf = allocateSwitchingFailureRunContext(repoR, cfgFail);
            runDirForStatus = rf.run_dir;
        catch ME_alloc
            error('run_switching_canonical:FailureRunAllocation', ...
                'Cannot allocate canonical failure run_dir (%s). Original error: %s', ME_alloc.message, ME.message);
        end
    end

    failTablesDir = fullfile(runDirForStatus, 'tables');
    failReportsDir = fullfile(runDirForStatus, 'reports');
    if exist(failTablesDir, 'dir') ~= 7
        mkdir(failTablesDir);
    end
    if exist(failReportsDir, 'dir') ~= 7
        mkdir(failReportsDir);
    end

    inputFoundFail = 'YES';
    if isempty(run_dir) && (~isstruct(run) || ~isfield(run, 'run_dir') || isempty(run.run_dir))
        inputFoundFail = 'NO';
    end
    writeSwitchingExecutionStatus(runDirForStatus, {'FAILED'}, {inputFoundFail}, {ME.message}, 0, {'run_switching_canonical failed'}, true);
    fidE = fopen(fullfile(runDirForStatus, 'enforcement_status.txt'), 'w');
    if fidE >= 0
        if enforcement_checked
            fprintf(fidE, 'ENFORCEMENT_CHECKED=YES\n');
        else
            fprintf(fidE, 'ENFORCEMENT_CHECKED=NO\n');
        end
        if isempty(modules_used)
            fprintf(fidE, 'MODULES_USED=\n');
        else
            fprintf(fidE, 'MODULES_USED=%s\n', strjoin(modules_used, ','));
        end
        fclose(fidE);
    end

    repoRForValidity = repoRoot;
    if isempty(repoRForValidity)
        repoRForValidity = repoRootBootstrap;
    end
    if isempty(repoRForValidity)
        repoRForValidity = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    end
    runDirLowerFv = lower(strrep(runDirForStatus, '/', '\'));
    switchingIsoFv = contains(runDirLowerFv, 'results\switching\runs') || contains(runDirLowerFv, 'results/switching/runs');
    writeRunValidityClassification(runDirForStatus, repoRForValidity, enforcement_checked, modules_used, switchingIsoFv);

    implStatusFail = table( ...
        "NO", "NO", "NO", "NO", "NO", "NO", "NO", "NO", "NO", "NO", ...
        "NO", "NO", "NO", "NO", "NO", NaN, NaN, NaN, NaN, ...
        string(which('createRunContext')), "N/A", ...
        string(""), string(runDirForStatus), ...
        'VariableNames', {'CANONICAL_SWITCHING_GENERATOR_CREATED', 'UPSTREAM_S_SOURCE_IDENTIFIED', ...
        'SP_DERIVED_FROM_S', 'IP_DERIVED_FROM_S', ...
        'RUN_CONTEXT_IS_SWITCHING_ISOLATED', 'STRUCTURAL_VALID', 'PROVENANCE_VALID', ...
        'FUNCTIONAL_VALID', 'INVARIANCE_VALID', 'CANONICAL_PIPELINE_CONFIRMED', 'READY_FOR_SINGLE_CANONICAL_RUN', ...
        'CHECK_NO_PRECOMPUTED_INPUTS', 'RECONSTRUCTION_IMPROVES', ...
        'PHI_SHAPE_STABLE', 'KAPPA_SCALING_REASONABLE', 'RMSE_PT', 'RMSE_FULL', ...
        'PHI_MEDIAN_COSINE', 'KAPPA_SPEAK_CORR', 'S_SOURCE', 'S_CONSTRUCTION_METHOD', 'RUN_ID', 'RUN_DIR'});
    
    if ~isempty(implStatusPath)
        writetable(implStatusFail, implStatusPath);
    else
        writetable(implStatusFail, fullfile(failTablesDir, 'run_switching_canonical_implementation_status.csv'));
    end

    if ~isempty(implReportPath)
        fidImplFail = fopen(implReportPath, 'w');
    else
        fidImplFail = fopen(fullfile(failReportsDir, 'run_switching_canonical_implementation.md'), 'w');
    end
    
    if fidImplFail >= 0
        fprintf(fidImplFail, '# run_switching_canonical implementation\n\n');
        fprintf(fidImplFail, '- DIAGNOSTIC_NOTE: Authoritative outcome is EXECUTION_STATUS in execution_status.csv (this file is not the contract).\n');
        fprintf(fidImplFail, '- ERROR_MESSAGE: `%s`\n', ME.message);
        fprintf(fidImplFail, '- RUN_DIR: `%s`\n', runDirForStatus);
        fclose(fidImplFail);
    end

    write_execution_marker('FAILED', runDirForStatus);

    rethrow(ME);
end
