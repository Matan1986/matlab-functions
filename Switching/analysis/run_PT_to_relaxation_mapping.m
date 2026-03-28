% RUN_PT_TO_RELAXATION_MAPPING  Test mapping from PT(E) to relaxation R(T,t).
% Pure script. Absolute paths only.
%
% Run:
%   tools/run_matlab_safe.bat C:\Dev\matlab-functions\Switching\analysis\run_PT_to_relaxation_mapping.m
%   eval(fileread('C:/Dev/matlab-functions/Switching/analysis/run_PT_to_relaxation_mapping.m'))

repoRoot = 'C:/Dev/matlab-functions';
outCsv = 'C:/Dev/matlab-functions/tables/PT_to_relaxation_mapping.csv';
outMd = 'C:/Dev/matlab-functions/reports/PT_to_relaxation_mapping.md';
outStatus = 'C:/Dev/matlab-functions/tables/PT_to_relaxation_mapping_status.csv';

if exist('C:/Dev/matlab-functions/tables', 'dir') ~= 7
    mkdir('C:/Dev/matlab-functions/tables');
end
if exist('C:/Dev/matlab-functions/reports', 'dir') ~= 7
    mkdir('C:/Dev/matlab-functions/reports');
end

ptPath = 'C:/Dev/matlab-functions/results/switching/runs/run_2026_03_25_013356_pt_robust_canonical/tables/PT_matrix.csv';
rPath = 'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_derivative_smoothing/tables/S_time_cuts_values.csv';
metaPath = 'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_derivative_smoothing/tables/S_time_cuts_meta.csv';

PT_EXPLAINS_RELAXATION_SHAPE = 'NO';
PEAK_POSITION_MATCH = 'NO';
WIDTH_MATCH = 'NO';
EXECUTION_STATUS = 'FAIL';
ERROR_MESSAGE = '';

mapTbl = table();

try
    assert(isfile(ptPath), 'Missing PT matrix: %s', ptPath);
    assert(isfile(rPath), 'Missing relaxation data: %s', rPath);
    assert(isfile(metaPath), 'Missing time-cut meta: %s', metaPath);

    pt = readtable(ptPath, 'VariableNamingRule', 'preserve');
    rd = readtable(rPath, 'VariableNamingRule', 'preserve');
    meta = readtable(metaPath, 'VariableNamingRule', 'preserve');

    % Detect temperature columns with contains() only.
    ptNames = string(pt.Properties.VariableNames);
    rdNames = string(rd.Properties.VariableNames);
    metaNames = string(meta.Properties.VariableNames);

    ptTCol = 0;
    rdTCol = 0;
    metaTCol = 0;
    for i = 1:numel(ptNames)
        nm = lower(ptNames(i));
        if contains(nm, 't_k') || strcmp(nm, "t") || contains(nm, 'temp')
            ptTCol = i;
            break;
        end
    end
    for i = 1:numel(rdNames)
        nm = lower(rdNames(i));
        if contains(nm, 'temp') || contains(nm, 't_k') || strcmp(nm, "t")
            rdTCol = i;
            break;
        end
    end
    for i = 1:numel(metaNames)
        nm = lower(metaNames(i));
        if contains(nm, 'actual_t') || (contains(nm, 'time') && contains(nm, 's'))
            metaTCol = i;
            break;
        end
    end
    assert(ptTCol > 0, 'Could not detect PT temperature column.');
    assert(rdTCol > 0, 'Could not detect relaxation temperature column.');
    assert(metaTCol > 0, 'Could not detect relaxation time-cut column.');

    T_pt = double(pt{:, ptTCol});
    T_rd = double(rd{:, rdTCol});
    tCuts = double(meta{:, metaTCol});

    % PT energy bins from columns that contain Ith.
    eCols = [];
    E = [];
    for i = 1:numel(ptNames)
        nm = lower(ptNames(i));
        if contains(nm, 'ith')
            eCols(end + 1) = i; %#ok<AGROW>
            tok = regexp(char(ptNames(i)), '\d+\.?\d*', 'match');
            if isempty(tok)
                E(end + 1, 1) = numel(E) + 1; %#ok<AGROW>
            else
                E(end + 1, 1) = str2double(tok{1}); %#ok<AGROW>
            end
        end
    end
    assert(~isempty(eCols), 'No PT Ith columns found.');

    % Relaxation data columns S_t*.
    sCols = [];
    for i = 1:numel(rdNames)
        nm = lower(rdNames(i));
        if contains(nm, 's_t') || (contains(nm, 's') && contains(nm, 't'))
            sCols(end + 1) = i; %#ok<AGROW>
        end
    end
    assert(~isempty(sCols), 'No relaxation S(t) columns found.');

    nCuts = min(numel(sCols), numel(tCuts));
    sCols = sCols(1:nCuts);
    tCuts = tCuts(1:nCuts);

    % Manual T alignment (no joins): for each relaxation T, nearest PT T within tolerance.
    tolK = 1.1;
    idxPT_for_RD = nan(numel(T_rd), 1);
    for i = 1:numel(T_rd)
        dT = abs(T_pt - T_rd(i));
        [mn, ix] = min(dT);
        if isfinite(mn) && mn <= tolK
            idxPT_for_RD(i) = ix;
        end
    end

    shapeCorr = nan(nCuts, 1);
    peakDeltaK = nan(nCuts, 1);
    widthRatio = nan(nCuts, 1);
    nUsed = zeros(nCuts, 1);

    for c = 1:nCuts
        t0 = tCuts(c);
        yDataAll = double(rd{:, sCols(c)});
        yPredAll = nan(size(yDataAll));

        for i = 1:numel(T_rd)
            ip = idxPT_for_RD(i);
            if ~isfinite(ip)
                continue;
            end
            pRow = double(pt{ip, eCols});
            pRow(~isfinite(pRow)) = 0;
            pRow(pRow < 0) = 0;
            sP = sum(pRow);
            if sP <= 0
                continue;
            end
            P = pRow ./ sP;                  % Step 1: P(E)
            Tval = T_rd(i);
            tauE = exp(E ./ max(Tval, 1e-9)); % Step 2: t = exp(E/T)
            kern = exp(-t0 ./ max(tauE, 1e-12));
            yPredAll(i) = sum(P(:) .* kern(:)); % Step 3: R_pred(T,t)
        end

        m = isfinite(yDataAll) & isfinite(yPredAll);
        yD = yDataAll(m);
        yP = yPredAll(m);
        Tm = T_rd(m);
        nUsed(c) = sum(m);
        if numel(yD) < 4
            continue;
        end

        % Compare shapes (z-normalized over T).
        yDz = (yD - mean(yD)) ./ max(std(yD), eps);
        yPz = (yP - mean(yP)) ./ max(std(yP), eps);
        cc = corr(yDz, yPz, 'rows', 'complete');
        if ~isfinite(cc), cc = NaN; end
        shapeCorr(c) = cc;

        % Peak location in temperature.
        [~, iD] = max(yD);
        [~, iP] = max(yP);
        peakDeltaK(c) = abs(Tm(iD) - Tm(iP));

        % Width around weighted mean temperature.
        wD = max(yD - min(yD), 0);
        wP = max(yP - min(yP), 0);
        if sum(wD) <= 0 || sum(wP) <= 0
            continue;
        end
        muD = sum(Tm .* wD) / sum(wD);
        muP = sum(Tm .* wP) / sum(wP);
        sigD = sqrt(sum(((Tm - muD).^2) .* wD) / sum(wD));
        sigP = sqrt(sum(((Tm - muP).^2) .* wP) / sum(wP));
        if sigD > 0
            widthRatio(c) = sigP / sigD;
        end
    end

    mapTbl = table((1:nCuts).', tCuts(:), nUsed, shapeCorr, peakDeltaK, widthRatio, ...
        'VariableNames', {'cut_idx', 't_seconds', 'n_temperatures_used', 'shape_correlation', 'peak_delta_K', 'width_ratio_pred_over_data'});

    meanShape = mean(shapeCorr, 'omitnan');
    meanPeakDelta = mean(peakDeltaK, 'omitnan');
    meanWidthErr = mean(abs(log(max(widthRatio, eps))), 'omitnan');

    if isfinite(meanShape) && meanShape >= 0.70
        PT_EXPLAINS_RELAXATION_SHAPE = 'YES';
    end
    if isfinite(meanPeakDelta) && meanPeakDelta <= 2.5
        PEAK_POSITION_MATCH = 'YES';
    end
    if isfinite(meanWidthErr) && meanWidthErr <= log(1.35)
        WIDTH_MATCH = 'YES';
    end

    summaryRow = table(0, NaN, sum(nUsed), meanShape, meanPeakDelta, exp(meanWidthErr), ...
        'VariableNames', {'cut_idx', 't_seconds', 'n_temperatures_used', 'shape_correlation', 'peak_delta_K', 'width_ratio_pred_over_data'});
    mapTbl = [mapTbl; summaryRow];

    writetable(mapTbl, outCsv);
    EXECUTION_STATUS = 'SUCCESS';

catch ME
    ERROR_MESSAGE = getReport(ME);
    emptyTbl = table('Size', [0 6], ...
        'VariableTypes', {'double','double','double','double','double','double'}, ...
        'VariableNames', {'cut_idx','t_seconds','n_temperatures_used','shape_correlation','peak_delta_K','width_ratio_pred_over_data'});
    writetable(emptyTbl, outCsv);
end

statusTbl = table({EXECUTION_STATUS}, {PT_EXPLAINS_RELAXATION_SHAPE}, {PEAK_POSITION_MATCH}, {WIDTH_MATCH}, {ERROR_MESSAGE}, ...
    'VariableNames', {'EXECUTION_STATUS','PT_EXPLAINS_RELAXATION_SHAPE','PEAK_POSITION_MATCH','WIDTH_MATCH','ERROR_MESSAGE'});
writetable(statusTbl, outStatus);

lines = cell(0, 1);
lines{end + 1, 1} = '# PT to relaxation mapping';
lines{end + 1, 1} = '';
lines{end + 1, 1} = sprintf('**EXECUTION_STATUS:** %s', EXECUTION_STATUS);
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## Inputs';
lines{end + 1, 1} = sprintf('- PT: `%s`', ptPath);
lines{end + 1, 1} = sprintf('- Relaxation: `%s`', rPath);
lines{end + 1, 1} = sprintf('- Time-cuts meta: `%s`', metaPath);
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## Method';
lines{end + 1, 1} = '- Step 1: normalize PT row to P(E).';
lines{end + 1, 1} = '- Step 2: map barrier to time with `tau(E,T)=exp(E/T)`.';
lines{end + 1, 1} = '- Step 3: build `R_pred(T,t)=sum_E P(E) * exp(-t/tau(E,T))`.';
lines{end + 1, 1} = '- Step 4: compare against relaxation cuts over temperature.';
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## Verdicts';
lines{end + 1, 1} = sprintf('- **PT_EXPLAINS_RELAXATION_SHAPE:** %s', PT_EXPLAINS_RELAXATION_SHAPE);
lines{end + 1, 1} = sprintf('- **PEAK_POSITION_MATCH:** %s', PEAK_POSITION_MATCH);
lines{end + 1, 1} = sprintf('- **WIDTH_MATCH:** %s', WIDTH_MATCH);
if ~isempty(ERROR_MESSAGE)
    lines{end + 1, 1} = '';
    lines{end + 1, 1} = '## ERROR_MESSAGE';
    lines{end + 1, 1} = '```';
    lines{end + 1, 1} = ERROR_MESSAGE;
    lines{end + 1, 1} = '```';
end

fid = fopen(outMd, 'w');
if fid > 0
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
    fclose(fid);
end
