% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: DIAGNOSTIC_FORENSIC — stress tests on backbone/path variants; manuscript-safe only with explicit family ids in report prose
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
baseName = 'switching_backbone_stress_test';

fStressDone = 'NO';
fBackboneRobust = 'NO';
fPhi1Survives = 'NO';
fPhi2Survives = 'NO';
fTailReduced = 'NO';
fTailAwareNeeded = 'NO';
fAltOutperforms = 'NO';
fPhaseDContinue = 'NO';
fCanonicalRedesign = 'NO';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'canonical_backbone_stress';
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

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    % Canonical truth inputs
    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    phi1Path = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_phi1.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    reqPaths = {sLongPath, phi1Path, ampPath};
    for i = 1:numel(reqPaths)
        if exist(reqPaths{i}, 'file') ~= 2
            error('run_switching_backbone_stress_test:MissingInput', 'Missing required input: %s', reqPaths{i});
        end
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'canonical_phi1')));
    validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);
    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt'};
    if ~all(ismember(reqS, sLong.Properties.VariableNames))
        error('run_switching_backbone_stress_test:BadSchema', 'Missing required columns in S_long.');
    end

    % Build maps
    T = double(sLong.T_K);
    I = double(sLong.current_mA);
    S = double(sLong.S_percent);
    B = double(sLong.S_model_pt_percent);
    C = double(sLong.CDF_pt);
    v = isfinite(T) & isfinite(I);
    T = T(v); I = I(v); S = S(v); B = B(v); C = C(v);
    TI = table(T, I, S, B, C);
    TIg = groupsummary(TI, {'T','I'}, 'mean', {'S','B','C'});
    allT = unique(double(TIg.T), 'sorted');
    allI = unique(double(TIg.I), 'sorted');
    nT = numel(allT); nI = numel(allI);
    Smap = NaN(nT,nI); Bmap = NaN(nT,nI); Cmap = NaN(nT,nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(TIg.T)-allT(it))<1e-9 & abs(double(TIg.I)-allI(ii))<1e-9;
            if any(m)
                idx = find(m,1);
                Smap(it,ii) = double(TIg.mean_S(idx));
                Bmap(it,ii) = double(TIg.mean_B(idx));
                Cmap(it,ii) = double(TIg.mean_C(idx));
            end
        end
    end

    % Canonical Phi1/Phi2 references
    phiVars = string(phi1Tbl.Properties.VariableNames);
    iPhiCol = find(strcmpi(phiVars, "phi1"), 1);
    phi1Ref = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:,iPhiCol}), allI, 'linear', 'extrap');
    phi1Ref = phi1Ref(:);
    if norm(phi1Ref) > 0, phi1Ref = phi1Ref / norm(phi1Ref); end

    kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
    kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
    kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
    kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');
    pred1canon = Bmap - kappa1(:) * phi1Ref(:)';
    R1canon = Smap - pred1canon;
    R1z = R1canon; R1z(~isfinite(R1z)) = 0;
    [~,~,Vcanon] = svd(R1z, 'econ');
    if size(Vcanon,2)>=1
        phi2Ref = Vcanon(:,1);
    else
        phi2Ref = zeros(nI,1);
    end
    if norm(phi2Ref)>0, phi2Ref = phi2Ref / norm(phi2Ref); end

    % Shared CDF windows for burden
    cdfAxis = mean(Cmap, 1, 'omitnan');
    lowWin = cdfAxis <= 0.2;
    midWin = cdfAxis > 0.4 & cdfAxis < 0.6;
    highWin = cdfAxis >= 0.8;

    % Variant list
    varName = { ...
        'reference_current_PTCDF', ...
        'tail_aware_backbone_diagnostic', ...
        'derivative_first_PT_diagnostic', ...
        'amplitude_normalized_mean_shape_diagnostic', ...
        'no_PT_PCA_reference'};
    nVar = numel(varName);

    implemented = strings(nVar,1);
    notImplReason = strings(nVar,1);
    rmse0 = NaN(nVar,1);
    mode1frac = NaN(nVar,1);
    mode2frac = NaN(nVar,1);
    phi1likeCos = NaN(nVar,1);
    phi2likeCos = NaN(nVar,1);
    phi1Necessary = strings(nVar,1);
    phi2Persistence = strings(nVar,1);
    lowFrac = NaN(nVar,1);
    midFrac = NaN(nVar,1);
    highFrac = NaN(nVar,1);
    tailRatio = NaN(nVar,1);

    spVar = strings(0,1); spMode = zeros(0,1); spSV = zeros(0,1); spFrac = zeros(0,1);
    simVar = strings(0,1); simPhi1WithPhi1 = zeros(0,1); simPhi1WithPhi2 = zeros(0,1);
    simPhi2WithPhi1 = zeros(0,1); simPhi2WithPhi2 = zeros(0,1);

    for iv = 1:nVar
        Bv = NaN(size(Smap));
        implemented(iv) = "YES";
        notImplReason(iv) = "";

        if strcmp(varName{iv}, 'reference_current_PTCDF')
            Bv = Bmap;
        elseif strcmp(varName{iv}, 'tail_aware_backbone_diagnostic')
            % Tail-only smooth additive correction from mean tail residual trend (diagnostic only)
            Rref = Smap - Bmap;
            tailTrend = mean(Rref, 1, 'omitnan');
            tailTrend(~highWin) = 0;
            tailTrend = movmean(tailTrend, 3, 'omitnan');
            Bv = Bmap + ones(nT,1) * tailTrend;
        elseif strcmp(varName{iv}, 'derivative_first_PT_diagnostic')
            for it = 1:nT
                s = Smap(it,:);
                m = isfinite(s) & isfinite(allI');
                if sum(m) < 3, continue; end
                is = allI(m);
                ss = s(m);
                speak = max(ss, [], 'omitnan');
                if ~isfinite(speak) || speak<=0, continue; end
                ds = gradient(ss, is);
                ds(~isfinite(ds)) = 0;
                ds = max(ds, 0);
                a = trapz(is, ds);
                if a > 0, ds = ds / a; end
                cdf = cumtrapz(is, ds);
                if cdf(end) > 0, cdf = cdf / cdf(end); end
                cdf = max(min(cdf,1),0);
                row = NaN(1,nI);
                row(m) = speak * cdf;
                Bv(it,:) = row;
            end
        elseif strcmp(varName{iv}, 'amplitude_normalized_mean_shape_diagnostic')
            Speak = max(Smap, [], 2, 'omitnan');
            Snorm = Smap ./ max(Speak, eps);
            meanShape = mean(Snorm, 1, 'omitnan');
            meanShape = max(min(meanShape,1),0);
            for it = 1:nT
                Bv(it,:) = Speak(it) * meanShape;
            end
        elseif strcmp(varName{iv}, 'no_PT_PCA_reference')
            Sz = Smap;
            Sz(~isfinite(Sz)) = 0;
            [U,Sv,V] = svd(Sz, 'econ');
            if size(U,2) >= 1
                Bv = U(:,1) * Sv(1,1) * V(:,1)';
            else
                implemented(iv) = "NO";
                notImplReason(iv) = "SVD rank too small for PCA reference.";
            end
        else
            implemented(iv) = "NO";
            notImplReason(iv) = "Variant not recognized.";
        end

        if implemented(iv) ~= "YES"
            continue;
        end

        R0 = Smap - Bv;
        R0z = R0;
        R0z(~isfinite(R0z)) = 0;
        rmse0(iv) = sqrt(mean(R0z(:).^2, 'omitnan'));

        [~,Svd,Vv] = svd(R0z, 'econ');
        sv = diag(Svd);
        ev = sv.^2;
        fr = ev / max(sum(ev), eps);
        mode1frac(iv) = fr(1);
        if numel(fr)>=2, mode2frac(iv) = fr(2); end

        % Mode similarities to canonical Phi1/Phi2
        if size(Vv,2)>=1
            v1 = Vv(:,1); if norm(v1)>0, v1 = v1/norm(v1); end
            phi1likeCos(iv) = abs(dot(v1,phi1Ref)/(max(norm(v1),eps)*max(norm(phi1Ref),eps)));
        end
        if size(Vv,2)>=2
            v2 = Vv(:,2); if norm(v2)>0, v2 = v2/norm(v2); end
            phi2likeCos(iv) = abs(dot(v2,phi2Ref)/(max(norm(v2),eps)*max(norm(phi2Ref),eps)));
        end

        if isfinite(mode1frac(iv)) && mode1frac(iv) >= 0.35
            phi1Necessary(iv) = "YES";
        elseif isfinite(mode1frac(iv)) && mode1frac(iv) >= 0.2
            phi1Necessary(iv) = "PARTIAL";
        else
            phi1Necessary(iv) = "NO";
        end

        if isfinite(mode2frac(iv)) && mode2frac(iv) >= 0.10
            phi2Persistence(iv) = "PERSISTS";
        elseif isfinite(mode2frac(iv)) && mode2frac(iv) >= 0.05
            phi2Persistence(iv) = "WEAKENS";
        else
            phi2Persistence(iv) = "DISAPPEARS";
        end

        % Tail burden
        eLow = mean(R0z(:,lowWin).^2, 'all', 'omitnan');
        eMid = mean(R0z(:,midWin).^2, 'all', 'omitnan');
        eHigh = mean(R0z(:,highWin).^2, 'all', 'omitnan');
        etot = eLow + eMid + eHigh;
        lowFrac(iv) = eLow / max(etot, eps);
        midFrac(iv) = eMid / max(etot, eps);
        highFrac(iv) = eHigh / max(etot, eps);
        tailRatio(iv) = eHigh / max(eMid, eps);

        % Spectrum table (first 8 modes)
        nKeep = min(8, numel(sv));
        for k = 1:nKeep
            spVar(end+1,1) = string(varName{iv}); %#ok<SAGROW>
            spMode(end+1,1) = k; %#ok<SAGROW>
            spSV(end+1,1) = sv(k); %#ok<SAGROW>
            spFrac(end+1,1) = fr(k); %#ok<SAGROW>
        end

        % Similarity table (top-2 variant modes vs canonical phi1/phi2)
        if size(Vv,2)>=2
            v1 = Vv(:,1); v2 = Vv(:,2);
            if norm(v1)>0, v1=v1/norm(v1); end
            if norm(v2)>0, v2=v2/norm(v2); end
            simVar(end+1,1) = string(varName{iv}); %#ok<SAGROW>
            simPhi1WithPhi1(end+1,1) = abs(dot(v1,phi1Ref)); %#ok<SAGROW>
            simPhi1WithPhi2(end+1,1) = abs(dot(v1,phi2Ref)); %#ok<SAGROW>
            simPhi2WithPhi1(end+1,1) = abs(dot(v2,phi1Ref)); %#ok<SAGROW>
            simPhi2WithPhi2(end+1,1) = abs(dot(v2,phi2Ref)); %#ok<SAGROW>
        end
    end

    variantsTbl = table(string(varName(:)), implemented, notImplReason, rmse0, mode1frac, mode2frac, phi1Necessary, phi2Persistence, ...
        'VariableNames', {'variant','implemented','not_implemented_reason','rmse_backbone_only','mode1_energy_fraction','mode2_energy_fraction','phi1_remains_necessary','phi2_persistence_label'});
    switchingWriteTableBothPaths(variantsTbl, repoRoot, runTables, 'switching_backbone_stress_variants.csv');

    spectrumTbl = table(spVar, spMode, spSV, spFrac, ...
        'VariableNames', {'variant','mode_index','singular_value','energy_fraction'});
    switchingWriteTableBothPaths(spectrumTbl, repoRoot, runTables, 'switching_backbone_stress_spectrum.csv');

    simTbl = table(simVar, simPhi1WithPhi1, simPhi1WithPhi2, simPhi2WithPhi1, simPhi2WithPhi2, ...
        'VariableNames', {'variant','variant_mode1_vs_canonical_phi1_abs_cos','variant_mode1_vs_canonical_phi2_abs_cos', ...
        'variant_mode2_vs_canonical_phi1_abs_cos','variant_mode2_vs_canonical_phi2_abs_cos'});
    switchingWriteTableBothPaths(simTbl, repoRoot, runTables, 'switching_backbone_stress_mode_similarity.csv');

    tailTbl = table(string(varName(:)), implemented, lowFrac, midFrac, highFrac, tailRatio, ...
        'VariableNames', {'variant','implemented','residual_energy_low_cdf_fraction','residual_energy_mid_cdf_fraction','residual_energy_high_cdf_fraction','high_to_mid_tail_burden_ratio'});
    switchingWriteTableBothPaths(tailTbl, repoRoot, runTables, 'switching_backbone_stress_tail_burden.csv');

    % Status logic
    fStressDone = 'YES';
    iRef = find(strcmp(varName, 'reference_current_PTCDF'),1);
    refRmse = rmse0(iRef);
    refTail = highFrac(iRef);
    refPhi1 = phi1Necessary(iRef);
    refPhi2 = phi2Persistence(iRef);

    impMask = implemented=="YES";
    altMask = impMask;
    altMask(iRef) = false;

    betterRmse = sum(rmse0(altMask) < refRmse - 1e-9, 'omitnan');
    betterTail = sum(highFrac(altMask) < refTail - 0.03, 'omitnan');
    phi1Yes = sum(phi1Necessary(altMask)=="YES");
    phi2Persist = sum(phi2Persistence(altMask)=="PERSISTS");
    phi2Disappear = sum(phi2Persistence(altMask)=="DISAPPEARS");

    if betterRmse >= 2
        fAltOutperforms = 'YES';
    elseif betterRmse == 1
        fAltOutperforms = 'PARTIAL';
    else
        fAltOutperforms = 'NO';
    end

    if phi1Yes >= 3
        fPhi1Survives = 'YES';
    elseif phi1Yes >= 2
        fPhi1Survives = 'PARTIAL';
    else
        fPhi1Survives = 'NO';
    end

    if phi2Persist >= 2
        fPhi2Survives = 'YES';
    elseif phi2Persist >= 1 && phi2Disappear <= 2
        fPhi2Survives = 'PARTIAL';
    else
        fPhi2Survives = 'NO';
    end

    if betterTail >= 2
        fTailReduced = 'YES';
    elseif betterTail == 1
        fTailReduced = 'PARTIAL';
    else
        fTailReduced = 'NO';
    end

    if strcmp(fTailReduced,'YES') || strcmp(fAltOutperforms,'YES')
        fTailAwareNeeded = 'YES';
    elseif strcmp(fTailReduced,'PARTIAL') || strcmp(fAltOutperforms,'PARTIAL')
        fTailAwareNeeded = 'PARTIAL';
    else
        fTailAwareNeeded = 'NO';
    end

    if strcmp(refPhi1,'YES') && ~strcmp(fPhi1Survives,'NO') && strcmp(fAltOutperforms,'NO')
        fBackboneRobust = 'PARTIAL';
    elseif strcmp(refPhi1,'YES') && strcmp(fAltOutperforms,'NO') && strcmp(fTailReduced,'NO')
        fBackboneRobust = 'YES';
    else
        fBackboneRobust = 'PARTIAL';
    end

    if strcmp(fBackboneRobust,'NO')
        fPhaseDContinue = 'NO';
    elseif strcmp(fBackboneRobust,'PARTIAL')
        fPhaseDContinue = 'PARTIAL';
    else
        fPhaseDContinue = 'YES';
    end

    if strcmp(fAltOutperforms,'YES') || strcmp(fTailAwareNeeded,'YES')
        fCanonicalRedesign = 'PARTIAL';
    elseif strcmp(fBackboneRobust,'NO')
        fCanonicalRedesign = 'YES';
    else
        fCanonicalRedesign = 'NO';
    end

    statusTbl = table( ...
        {'STRESS_TEST_COMPLETED'; 'CURRENT_PTCDF_BACKBONE_ROBUST'; 'PHI1_SURVIVES_BACKBONE_VARIANTS'; ...
         'PHI2_SURVIVES_BACKBONE_VARIANTS'; 'HIGH_CDF_TAIL_BURDEN_REDUCED_BY_ALT_BACKBONE'; ...
         'TAIL_AWARE_BACKBONE_NEEDED'; 'ALTERNATIVE_BACKBONE_OUTPERFORMS_CURRENT'; ...
         'CAN_CONTINUE_PHASE_D_WITH_CURRENT_BACKBONE'; 'CANONICAL_DECOMPOSITION_REDESIGN_REQUIRED'}, ...
        {fStressDone; fBackboneRobust; fPhi1Survives; fPhi2Survives; fTailReduced; fTailAwareNeeded; fAltOutperforms; fPhaseDContinue; fCanonicalRedesign}, ...
        {sprintf('implemented variants=%d/%d', sum(impMask), nVar); ...
         sprintf('reference rmse=%.6g, alt_better_count=%d', refRmse, betterRmse); ...
         sprintf('reference phi1=%s; surviving YES count among alternatives=%d', refPhi1, phi1Yes); ...
         sprintf('reference phi2=%s; persists=%d disappears=%d', refPhi2, phi2Persist, phi2Disappear); ...
         sprintf('reference highCDF=%.6g; improved alternatives=%d', refTail, betterTail); ...
         sprintf('tail reduction=%s and outperform=%s', fTailReduced, fAltOutperforms); ...
         sprintf('alt variants with lower RMSE than reference=%d', betterRmse); ...
         'Proceed only with explicit tail-caveat controls and diagnostic-only alternative interpretation.'; ...
         'No producer change requested; redesign decision is planning-level only.'}, ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_backbone_stress_status.csv');

    % Figures
    fig = figure('Visible','off','Color','w','Position',[80 80 1600 900]);
    tl = tiledlayout(2,2,'Parent',fig,'TileSpacing','compact','Padding','compact');

    nexttile(tl);
    bar(categorical(string(varName(:))), rmse0);
    title('RMSE by backbone variant'); ylabel('RMSE (backbone only)'); xtickangle(20); grid on;

    nexttile(tl);
    hold on;
    uVars = unique(spVar, 'stable');
    for i = 1:numel(uVars)
        m = spVar==uVars(i);
        plot(spMode(m), spFrac(m), '-o', 'LineWidth', 1.2, 'DisplayName', char(uVars(i)));
    end
    hold off;
    title('Residual SVD spectra by variant'); xlabel('Mode'); ylabel('Energy fraction'); legend('Location','best'); grid on;

    nexttile(tl);
    bar(categorical(simVar), [simPhi1WithPhi1 simPhi2WithPhi2]);
    title('Phi1-like / Phi2-like similarity'); ylabel('|cos|'); legend({'mode1~Phi1','mode2~Phi2'},'Location','best'); xtickangle(20); grid on;

    nexttile(tl);
    bar(categorical(string(varName(:))), highFrac);
    title('High-CDF tail burden by variant'); ylabel('High-CDF residual fraction'); xtickangle(20); grid on;

    sgtitle(tl, 'Switching backbone stress test (diagnostic variants)', 'Interpreter', 'none');
    figPath = fullfile(runFigures, [baseName '.fig']);
    pngPath = fullfile(runFigures, [baseName '.png']);
    savefig(fig, figPath);
    exportgraphics(fig, pngPath, 'Resolution', 300);
    close(fig);

    lines = {};
    lines{end+1} = '# Switching controlled alternative-backbone stress test';
    lines{end+1} = '';
    lines{end+1} = '## Scope';
    lines{end+1} = '- Diagnostic-only stress test. No producer edits, no canonical replacement, no mode-definition changes.';
    lines{end+1} = '- No width scaling or alignment coordinates used.';
    lines{end+1} = '- Alternative backbones are non-canonical diagnostics only.';
    lines{end+1} = '';
    lines{end+1} = '## Variants tested';
    for i = 1:nVar
        if implemented(i)=="NO"
            lines{end+1} = sprintf('- %s: implemented=%s (reason: %s)', varName{i}, implemented(i), notImplReason(i));
        else
            lines{end+1} = sprintf('- %s: implemented=%s', varName{i}, implemented(i));
        end
    end
    lines{end+1} = '';
    lines{end+1} = '## Key outcomes';
    lines{end+1} = sprintf('- Reference RMSE (current PT/CDF): %.6g', refRmse);
    lines{end+1} = sprintf('- Alternatives with lower RMSE than reference: %d', betterRmse);
    lines{end+1} = sprintf('- Alternatives with lower high-CDF tail burden: %d', betterTail);
    lines{end+1} = sprintf('- Phi1 survives across variants: %s', fPhi1Survives);
    lines{end+1} = sprintf('- Phi2 survives across variants: %s', fPhi2Survives);
    lines{end+1} = '';
    lines{end+1} = '## Required status flags';
    lines{end+1} = sprintf('- STRESS_TEST_COMPLETED = %s', fStressDone);
    lines{end+1} = sprintf('- CURRENT_PTCDF_BACKBONE_ROBUST = %s', fBackboneRobust);
    lines{end+1} = sprintf('- PHI1_SURVIVES_BACKBONE_VARIANTS = %s', fPhi1Survives);
    lines{end+1} = sprintf('- PHI2_SURVIVES_BACKBONE_VARIANTS = %s', fPhi2Survives);
    lines{end+1} = sprintf('- HIGH_CDF_TAIL_BURDEN_REDUCED_BY_ALT_BACKBONE = %s', fTailReduced);
    lines{end+1} = sprintf('- TAIL_AWARE_BACKBONE_NEEDED = %s', fTailAwareNeeded);
    lines{end+1} = sprintf('- ALTERNATIVE_BACKBONE_OUTPERFORMS_CURRENT = %s', fAltOutperforms);
    lines{end+1} = sprintf('- CAN_CONTINUE_PHASE_D_WITH_CURRENT_BACKBONE = %s', fPhaseDContinue);
    lines{end+1} = sprintf('- CANONICAL_DECOMPOSITION_REDESIGN_REQUIRED = %s', fCanonicalRedesign);
    lines{end+1} = '';
    lines{end+1} = '## Artifacts';
    lines{end+1} = '- `tables/switching_backbone_stress_variants.csv`';
    lines{end+1} = '- `tables/switching_backbone_stress_spectrum.csv`';
    lines{end+1} = '- `tables/switching_backbone_stress_mode_similarity.csv`';
    lines{end+1} = '- `tables/switching_backbone_stress_tail_burden.csv`';
    lines{end+1} = '- `tables/switching_backbone_stress_status.csv`';
    lines{end+1} = '- `reports/switching_backbone_stress_test.md`';
    lines{end+1} = sprintf('- run figure `.fig`: `%s`', figPath);
    lines{end+1} = sprintf('- run figure `.png`: `%s`', pngPath);

    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_backbone_stress_test:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_backbone_stress_test.md'), lines, 'run_switching_backbone_stress_test:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nVar, {'backbone stress test completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_backbone_stress_test_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    failMsg = char(string(ME.message));
    statusTbl = table( ...
        {'STRESS_TEST_COMPLETED'; 'CURRENT_PTCDF_BACKBONE_ROBUST'; 'PHI1_SURVIVES_BACKBONE_VARIANTS'; ...
         'PHI2_SURVIVES_BACKBONE_VARIANTS'; 'HIGH_CDF_TAIL_BURDEN_REDUCED_BY_ALT_BACKBONE'; ...
         'TAIL_AWARE_BACKBONE_NEEDED'; 'ALTERNATIVE_BACKBONE_OUTPERFORMS_CURRENT'; ...
         'CAN_CONTINUE_PHASE_D_WITH_CURRENT_BACKBONE'; 'CANONICAL_DECOMPOSITION_REDESIGN_REQUIRED'}, ...
        {'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'}, ...
        repmat({failMsg}, 9, 1), ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_backbone_stress_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_backbone_stress_status.csv'));

    lines = {};
    lines{end+1} = '# Switching backbone stress test — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_backbone_stress_test:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_backbone_stress_test.md'), lines, 'run_switching_backbone_stress_test:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'backbone stress test failed'}, true);
    rethrow(ME);
end
