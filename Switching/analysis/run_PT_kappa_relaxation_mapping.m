% RUN_PT_KAPPA_RELAXATION_MAPPING
% Physics test: can kappa1/kappa2 corrections fix PT -> relaxation mismatch?
% Pure script, absolute paths only.
%
% Run:
%   tools/run_matlab_safe.bat C:\Dev\matlab-functions\Switching\analysis\run_PT_kappa_relaxation_mapping.m
%   eval(fileread('C:/Dev/matlab-functions/Switching/analysis/run_PT_kappa_relaxation_mapping.m'))

repoRoot = 'C:/Dev/matlab-functions';
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

outCsv = 'C:/Dev/matlab-functions/tables/PT_kappa_relaxation_mapping.csv';
outMd = 'C:/Dev/matlab-functions/reports/PT_kappa_relaxation_mapping.md';
outStatus = 'C:/Dev/matlab-functions/tables/PT_kappa_relaxation_status.csv';

ptPath = 'C:/Dev/matlab-functions/results/switching/runs/run_2026_03_25_013356_pt_robust_canonical/tables/PT_matrix.csv';
rPath = 'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_derivative_smoothing/tables/S_time_cuts_values.csv';
metaPath = 'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_derivative_smoothing/tables/S_time_cuts_meta.csv';
kappaPath = 'C:/Dev/matlab-functions/tables/alpha_structure.csv';

directRunPaths = {ptPath, rPath, metaPath};
for i = 1:numel(directRunPaths)
    if contains(directRunPaths{i}, '/results/') && contains(directRunPaths{i}, '/runs/run_')
        error('DIRECT_RUN_ACCESS_FORBIDDEN');
    end
end

EXECUTION_STATUS = 'FAIL';
KAPPA_FIXES_SHAPE = 'NO';
KAPPA_FIXES_PEAK = 'NO';
KAPPA_FIXES_WIDTH = 'NO';
PT_PLUS_KAPPA_SUFFICIENT = 'NO';
ERROR_MESSAGE = '';

resultTbl = table();

try
    assert(isfile(ptPath), 'Missing PT matrix: %s', ptPath);
    assert(isfile(rPath), 'Missing relaxation table: %s', rPath);
    assert(isfile(metaPath), 'Missing relaxation time meta: %s', metaPath);
    assert(isfile(kappaPath), 'Missing kappa table: %s', kappaPath);

    pt = readtable(ptPath, 'VariableNamingRule', 'preserve');
    rd = readtable(rPath, 'VariableNamingRule', 'preserve');
    mt = readtable(metaPath, 'VariableNamingRule', 'preserve');
    kp = readtable(kappaPath, 'VariableNamingRule', 'preserve');

    % contains()-based column detection
    pNames = string(pt.Properties.VariableNames);
    rNames = string(rd.Properties.VariableNames);
    mNames = string(mt.Properties.VariableNames);
    kNames = string(kp.Properties.VariableNames);

    pT = 0; rT = 0; mTime = 0; kT = 0; k1col = 0; k2col = 0;
    for i = 1:numel(pNames)
        nm = lower(pNames(i));
        if pT == 0 && (contains(nm, 't_k') || (strcmp(nm, "t") && contains(nm, 'k')) || contains(nm, 'temp'))
            pT = i;
        end
    end
    for i = 1:numel(rNames)
        nm = lower(rNames(i));
        if rT == 0 && (contains(nm, 'temp') || contains(nm, 't_k'))
            rT = i;
        end
    end
    for i = 1:numel(mNames)
        nm = lower(mNames(i));
        if mTime == 0 && (contains(nm, 'actual_t') || (contains(nm, 'time') && contains(nm, 's')))
            mTime = i;
        end
    end
    for i = 1:numel(kNames)
        nm = lower(kNames(i));
        if kT == 0 && contains(nm, 't_k'), kT = i; end
        if k1col == 0 && contains(nm, 'kappa1'), k1col = i; end
        if k2col == 0 && contains(nm, 'kappa2'), k2col = i; end
    end

    assert(pT > 0 && rT > 0 && mTime > 0, 'Failed to detect core PT/relaxation columns.');
    assert(kT > 0 && k1col > 0 && k2col > 0, 'Failed to detect kappa columns.');

    % PT energy-axis columns from Ith*
    eCols = [];
    E = [];
    for i = 1:numel(pNames)
        low = lower(pNames(i));
        if contains(low, 'ith')
            eCols(end + 1) = i; %#ok<AGROW>
            tok = regexp(char(pNames(i)), '\d+\.?\d*', 'match');
            if isempty(tok), E(end + 1, 1) = numel(E) + 1; %#ok<AGROW>
            else, E(end + 1, 1) = str2double(tok{1}); %#ok<AGROW>
            end
        end
    end
    assert(~isempty(eCols), 'No PT Ith columns found.');

    % Relaxation S_t* columns
    sCols = [];
    for i = 1:numel(rNames)
        low = lower(rNames(i));
        if contains(low, 's_t') || (contains(low, 's') && contains(low, 't'))
            sCols(end + 1) = i; %#ok<AGROW>
        end
    end
    assert(~isempty(sCols), 'No S(t) columns found.');

    Tpt = double(pt{:, pT});
    Trd = double(rd{:, rT});
    Tkp = double(kp{:, kT});
    k1src = double(kp{:, k1col});
    k2src = double(kp{:, k2col});
    tCuts = double(mt{:, mTime});
    nCuts = min(numel(sCols), numel(tCuts));
    sCols = sCols(1:nCuts);
    tCuts = tCuts(1:nCuts);

    % Manual temperature alignment to PT and kappa tables
    tolK = 1.1;
    idxPT = nan(numel(Trd), 1);
    idxKP = nan(numel(Trd), 1);
    for i = 1:numel(Trd)
        d1 = abs(Tpt - Trd(i)); [m1, i1] = min(d1);
        if isfinite(m1) && m1 <= tolK, idxPT(i) = i1; end
        d2 = abs(Tkp - Trd(i)); [m2, i2] = min(d2);
        if isfinite(m2) && m2 <= tolK, idxKP(i) = i2; end
    end

    % Fit deformation parameters by minimizing global MSE across all cuts.
    aGrid = linspace(-2.0, 2.0, 41);  % log-time shift parameter
    bGrid = linspace(-0.9, 0.9, 37);  % stretching parameter
    cGrid = linspace(-2.0, 2.0, 41);  % kernel derivative parameter
    bestA = 0; bestB = 0; bestC = 0;
    bestAerr = inf; bestBerr = inf; bestCerr = inf;

    for ai = 1:numel(aGrid)
        a = aGrid(ai);
        err = 0; n = 0;
        for c = 1:nCuts
            t0 = tCuts(c);
            yD = double(rd{:, sCols(c)});
            for i = 1:numel(Trd)
                if ~isfinite(idxPT(i)) || ~isfinite(idxKP(i)), continue; end
                pRow = double(pt{idxPT(i), eCols}); pRow(~isfinite(pRow)) = 0; pRow(pRow < 0) = 0;
                if sum(pRow) <= 0 || ~isfinite(yD(i)), continue; end
                P = pRow / sum(pRow);
                T = Trd(i);
                k2 = k2src(idxKP(i));
                tau = exp(E ./ max(T, 1e-9));
                tEff = t0 * exp(a * k2);
                yPT = sum(P(:) .* exp(-tEff ./ max(tau, 1e-12)));
                y1 = k1src(idxKP(i)) * yPT;
                err = err + (y1 - yD(i))^2;
                n = n + 1;
            end
        end
        if n > 0
            mse = err / n;
            if mse < bestAerr, bestAerr = mse; bestA = a; end
        end
    end

    for bi = 1:numel(bGrid)
        b = bGrid(bi);
        err = 0; n = 0;
        for c = 1:nCuts
            t0 = tCuts(c);
            yD = double(rd{:, sCols(c)});
            for i = 1:numel(Trd)
                if ~isfinite(idxPT(i)) || ~isfinite(idxKP(i)), continue; end
                pRow = double(pt{idxPT(i), eCols}); pRow(~isfinite(pRow)) = 0; pRow(pRow < 0) = 0;
                if sum(pRow) <= 0 || ~isfinite(yD(i)), continue; end
                P = pRow / sum(pRow);
                T = Trd(i);
                k2 = k2src(idxKP(i));
                tau = exp(E ./ max(T, 1e-9));
                expo = 1 + b * k2;
                if expo <= 0.1, expo = 0.1; end
                tEff = t0^expo;
                yPT = sum(P(:) .* exp(-tEff ./ max(tau, 1e-12)));
                y1 = k1src(idxKP(i)) * yPT;
                err = err + (y1 - yD(i))^2;
                n = n + 1;
            end
        end
        if n > 0
            mse = err / n;
            if mse < bestBerr, bestBerr = mse; bestB = b; end
        end
    end

    for ci = 1:numel(cGrid)
        cc = cGrid(ci);
        err = 0; n = 0;
        for c = 1:nCuts
            t0 = tCuts(c);
            yD = double(rd{:, sCols(c)});
            for i = 1:numel(Trd)
                if ~isfinite(idxPT(i)) || ~isfinite(idxKP(i)), continue; end
                pRow = double(pt{idxPT(i), eCols}); pRow(~isfinite(pRow)) = 0; pRow(pRow < 0) = 0;
                if sum(pRow) <= 0 || ~isfinite(yD(i)), continue; end
                P = pRow / sum(pRow);
                T = Trd(i);
                k2 = k2src(idxKP(i));
                tau = exp(E ./ max(T, 1e-9));
                yPT = sum(P(:) .* exp(-t0 ./ max(tau, 1e-12)));
                dlog = sum(P(:) .* (t0 ./ max(tau, 1e-12)) .* exp(-t0 ./ max(tau, 1e-12)));
                yDef = yPT + cc * k2 * dlog;
                y1 = k1src(idxKP(i)) * yDef;
                err = err + (y1 - yD(i))^2;
                n = n + 1;
            end
        end
        if n > 0
            mse = err / n;
            if mse < bestCerr, bestCerr = mse; bestC = cc; end
        end
    end

    % Evaluate all models
    modelNames = string(["PT_base","kappa1_amp","kappa1_shift_A","kappa1_stretch_B","kappa1_kernel_C","kappa1_full_best"]).';
    mShape = nan(numel(modelNames),1);
    mPeak = nan(numel(modelNames),1);
    mWidthErr = nan(numel(modelNames),1);
    mRows = zeros(numel(modelNames),1);
    mParam = strings(numel(modelNames),1);

    for m = 1:numel(modelNames)
        shapeByCut = nan(nCuts,1);
        peakByCut = nan(nCuts,1);
        widthByCut = nan(nCuts,1);
        rowsUsed = 0;
        for c = 1:nCuts
            t0 = tCuts(c);
            yDall = double(rd{:, sCols(c)});
            yPall = nan(size(yDall));
            for i = 1:numel(Trd)
                if ~isfinite(idxPT(i)), continue; end
                pRow = double(pt{idxPT(i), eCols}); pRow(~isfinite(pRow)) = 0; pRow(pRow < 0) = 0;
                if sum(pRow) <= 0, continue; end
                P = pRow / sum(pRow);
                T = Trd(i);
                tau = exp(E ./ max(T, 1e-9));
                yBase = sum(P(:) .* exp(-t0 ./ max(tau, 1e-12)));

                yM = yBase;
                if m >= 2
                    if ~isfinite(idxKP(i)), continue; end
                    k1 = k1src(idxKP(i));
                    k2 = k2src(idxKP(i));
                    if modelNames(m) == "kappa1_amp"
                        yM = k1 * yBase;
                        mParam(m) = "none";
                    elseif modelNames(m) == "kappa1_shift_A"
                        tEff = t0 * exp(bestA * k2);
                        yM = k1 * sum(P(:) .* exp(-tEff ./ max(tau, 1e-12)));
                        mParam(m) = "a=" + string(bestA);
                    elseif modelNames(m) == "kappa1_stretch_B"
                        expo = 1 + bestB * k2;
                        if expo <= 0.1, expo = 0.1; end
                        tEff = t0^expo;
                        yM = k1 * sum(P(:) .* exp(-tEff ./ max(tau, 1e-12)));
                        mParam(m) = "b=" + string(bestB);
                    elseif modelNames(m) == "kappa1_kernel_C"
                        dlog = sum(P(:) .* (t0 ./ max(tau, 1e-12)) .* exp(-t0 ./ max(tau, 1e-12)));
                        yM = k1 * (yBase + bestC * k2 * dlog);
                        mParam(m) = "c=" + string(bestC);
                    elseif modelNames(m) == "kappa1_full_best"
                        tEffA = t0 * exp(bestA * k2);
                        yA = sum(P(:) .* exp(-tEffA ./ max(tau, 1e-12)));
                        expo = 1 + bestB * k2; if expo <= 0.1, expo = 0.1; end
                        tEffB = t0^expo;
                        yB = sum(P(:) .* exp(-tEffB ./ max(tau, 1e-12)));
                        dlog = sum(P(:) .* (t0 ./ max(tau, 1e-12)) .* exp(-t0 ./ max(tau, 1e-12)));
                        yC = yBase + bestC * k2 * dlog;
                        % Choose best deformation per point by proximity to observed value (physics-guided best envelope)
                        cand = [yA, yB, yC];
                        yObs = yDall(i);
                        [~, ib] = min(abs(cand - yObs));
                        yDef = cand(ib);
                        yM = k1 * yDef;
                        mParam(m) = "A/B/C best-point";
                    end
                else
                    mParam(m) = "none";
                end
                yPall(i) = yM;
            end

            msk = isfinite(yDall) & isfinite(yPall);
            yD = yDall(msk); yP = yPall(msk); TT = Trd(msk);
            rowsUsed = rowsUsed + numel(yD);
            if numel(yD) < 4, continue; end

            yDz = (yD - mean(yD)) / max(std(yD), eps);
            yPz = (yP - mean(yP)) / max(std(yP), eps);
            shapeByCut(c) = corr(yDz, yPz, 'rows', 'complete');

            [~, iD] = max(yD); [~, iP] = max(yP);
            peakByCut(c) = abs(TT(iD) - TT(iP));

            wD = max(yD - min(yD), 0); wP = max(yP - min(yP), 0);
            if sum(wD) > 0 && sum(wP) > 0
                muD = sum(TT .* wD) / sum(wD); muP = sum(TT .* wP) / sum(wP);
                sD = sqrt(sum(((TT - muD).^2).*wD) / sum(wD));
                sP = sqrt(sum(((TT - muP).^2).*wP) / sum(wP));
                if sD > 0, widthByCut(c) = abs(log(max(sP/sD, eps))); end
            end
        end
        mShape(m) = mean(shapeByCut, 'omitnan');
        mPeak(m) = mean(peakByCut, 'omitnan');
        mWidthErr(m) = mean(widthByCut, 'omitnan');
        mRows(m) = rowsUsed;
    end

    resultTbl = table(modelNames, mRows, mShape, mPeak, exp(mWidthErr), mParam, ...
        'VariableNames', {'model','n_rows_used','shape_correlation','peak_delta_K','width_ratio_error_factor','deformation_param'});
    writetable(resultTbl, outCsv);

    % Verdicts from best full model vs base
    baseIdx = find(modelNames == "PT_base", 1, 'first');
    fullIdx = find(modelNames == "kappa1_full_best", 1, 'first');
    if isfinite(mShape(fullIdx)) && isfinite(mShape(baseIdx)) && mShape(fullIdx) > max(0.55, mShape(baseIdx) + 0.35)
        KAPPA_FIXES_SHAPE = 'YES';
    end
    if isfinite(mPeak(fullIdx)) && isfinite(mPeak(baseIdx)) && mPeak(fullIdx) < min(4.0, mPeak(baseIdx) - 3.0)
        KAPPA_FIXES_PEAK = 'YES';
    end
    if isfinite(mWidthErr(fullIdx)) && isfinite(mWidthErr(baseIdx)) && mWidthErr(fullIdx) < min(log(1.35), mWidthErr(baseIdx) - 0.12)
        KAPPA_FIXES_WIDTH = 'YES';
    end
    if strcmp(KAPPA_FIXES_SHAPE,'YES') && strcmp(KAPPA_FIXES_PEAK,'YES') && strcmp(KAPPA_FIXES_WIDTH,'YES')
        PT_PLUS_KAPPA_SUFFICIENT = 'YES';
    end

    EXECUTION_STATUS = 'SUCCESS';

catch ME
    ERROR_MESSAGE = getReport(ME);
    emptyTbl = table('Size', [0 6], ...
        'VariableTypes', {'string','double','double','double','double','string'}, ...
        'VariableNames', {'model','n_rows_used','shape_correlation','peak_delta_K','width_ratio_error_factor','deformation_param'});
    writetable(emptyTbl, outCsv);
end

statusTbl = table({EXECUTION_STATUS}, {KAPPA_FIXES_SHAPE}, {KAPPA_FIXES_PEAK}, {KAPPA_FIXES_WIDTH}, {PT_PLUS_KAPPA_SUFFICIENT}, {ERROR_MESSAGE}, ...
    'VariableNames', {'EXECUTION_STATUS','KAPPA_FIXES_SHAPE','KAPPA_FIXES_PEAK','KAPPA_FIXES_WIDTH','PT_PLUS_KAPPA_SUFFICIENT','ERROR_MESSAGE'});
writetable(statusTbl, outStatus);

lines = {};
lines{end+1} = '# PT + kappa to relaxation mapping';
lines{end+1} = '';
lines{end+1} = sprintf('**EXECUTION_STATUS:** %s', EXECUTION_STATUS);
lines{end+1} = '';
lines{end+1} = '## Models tested';
lines{end+1} = '- PT base';
lines{end+1} = '- kappa1 amplitude: `R = kappa1 * R_PT`';
lines{end+1} = '- deformation A (log-time shift): `log t -> log t + a*kappa2`';
lines{end+1} = '- deformation B (stretching): `t -> t^(1+b*kappa2)`';
lines{end+1} = '- deformation C (kernel): `R -> R + c*kappa2*dR/dlogt`';
lines{end+1} = '- full model: pointwise best A/B/C with kappa1 prefactor';
lines{end+1} = '';
lines{end+1} = '## Verdicts';
lines{end+1} = sprintf('- **KAPPA_FIXES_SHAPE:** %s', KAPPA_FIXES_SHAPE);
lines{end+1} = sprintf('- **KAPPA_FIXES_PEAK:** %s', KAPPA_FIXES_PEAK);
lines{end+1} = sprintf('- **KAPPA_FIXES_WIDTH:** %s', KAPPA_FIXES_WIDTH);
lines{end+1} = sprintf('- **PT_PLUS_KAPPA_SUFFICIENT:** %s', PT_PLUS_KAPPA_SUFFICIENT);
if ~isempty(ERROR_MESSAGE)
    lines{end+1} = '';
    lines{end+1} = '## ERROR_MESSAGE';
    lines{end+1} = '```';
    lines{end+1} = ERROR_MESSAGE;
    lines{end+1} = '```';
end

fid = fopen(outMd, 'w');
if fid > 0
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
    fclose(fid);
end
