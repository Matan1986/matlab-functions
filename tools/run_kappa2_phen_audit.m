% run_kappa2_phen_audit.m
% Constrained phenomenological closure audit for kappa2 using exactly:
% Singles: I_peak, width_asymmetry, slope_asymmetry, local_curvature, antisym_area_res2
% Pairs:   I_peak+width_asymmetry, I_peak+local_curvature, slope_asymmetry+antisym_area_res2
%
% Execution contract:
% - Must be runnable via eval(fileread('absolute_path_to_script.m'))
% - No local function definitions (required for eval(fileread) execution)

repoRoot = 'C:/Dev/matlab-functions';
matFileAbs = fullfile(repoRoot, 'kappa2_phen_inputs.mat');
statusFileAbs = fullfile(repoRoot, 'kappa2_audit_status.txt');
errFileAbs = fullfile(repoRoot, 'kappa2_audit_error.log');
csvOutAbs = fullfile(repoRoot, 'tables', 'kappa2_phenomenological_audit.csv');
mdOutAbs = fullfile(repoRoot, 'reports', 'kappa2_phenomenological_audit.md');
buildStatusAbs = fullfile(repoRoot, 'kappa2_build_status.txt');

fid = fopen(statusFileAbs, 'w');
fprintf(fid, 'START %s\n', datestr(now));
fclose(fid);

% Fail-safe defaults: still write outputs if possible.
rows = table();
closureVerdict = 'NO';
hasSignature = 'NO';
bestModel = "";
sigModel = "";
physicalMeaning = 'no stable physical interpretation';

try
    if ~exist(matFileAbs, 'file')
        error('run_kappa2_phen_audit:missingMat', 'Missing kappa2_phen_inputs.mat at %s', matFileAbs);
    end

    S = load(matFileAbs);

    if isfield(S,'kappa2'); kappa2 = S.kappa2; else; kappa2 = []; end
    if isfield(S,'I_peak'); I_peak = S.I_peak; else; I_peak = []; end
    if isfield(S,'width_asymmetry'); width_asymmetry = S.width_asymmetry; else; width_asymmetry = []; end
    if isfield(S,'slope_asymmetry'); slope_asymmetry = S.slope_asymmetry; else; slope_asymmetry = []; end
    if isfield(S,'local_curvature'); local_curvature = S.local_curvature; else; local_curvature = []; end
    if isfield(S,'antisym_area_res2'); antisym_area_res2 = S.antisym_area_res2; else; antisym_area_res2 = []; end

    % Required observable fields for models
    requiredVars = {'I_peak','width_asymmetry','slope_asymmetry','local_curvature','antisym_area_res2'};
    usedVars = strings(0,1);
    for v = 1:numel(requiredVars)
        vn = requiredVars{v};
        if isfield(S, vn)
            vec = S.(vn);
            if ~isempty(vec) && any(isfinite(vec))
                usedVars(end+1) = vn; %#ok<AGROW>
            end
        end
    end
    missingVars = setdiff(requiredVars, usedVars);

    % Model list (fixed, but computation skipped if any required X is missing/empty/all-NaN)
    models = { ...
        'single', 'I_peak', I_peak,  {'I_peak'}; ...
        'single', 'width_asymmetry', width_asymmetry, {'width_asymmetry'}; ...
        'single', 'slope_asymmetry', slope_asymmetry, {'slope_asymmetry'}; ...
        'single', 'local_curvature', local_curvature, {'local_curvature'}; ...
        'single', 'antisym_area_res2', antisym_area_res2, {'antisym_area_res2'}; ...
        'pair',   'I_peak + width_asymmetry', [I_peak, width_asymmetry], {'I_peak','width_asymmetry'}; ...
        'pair',   'I_peak + local_curvature', [I_peak, local_curvature], {'I_peak','local_curvature'}; ...
        'pair',   'slope_asymmetry + antisym_area_res2', [slope_asymmetry, antisym_area_res2], {'slope_asymmetry','antisym_area_res2'}; ...
    };

    nModels = size(models,1);
    rows = table('Size',[nModels 10], ...
        'VariableTypes', {'string','string','double','double','double','double','double','double','double','string'}, ...
        'VariableNames', {'family','model','n','loocv_rmse','pearson','spearman','baseline_loocv_rmse','rmse_ratio','beats_baseline','status'});

    y = kappa2;
    for i = 1:nModels
        fam = string(models{i,1});
        name = string(models{i,2});
        Xfull = models{i,3};
        req = models{i,4};

        % Validate availability
        ok = true;
        if strcmp(fam,'single')
            if isempty(Xfull) || ~any(isfinite(Xfull))
                ok = false;
            end
        else
            if isempty(Xfull) || size(Xfull,2) < 2 || any(all(~isfinite(Xfull),1))
                ok = false;
            end
        end

        if isempty(y) || ~any(isfinite(y)) || ~ok
            rows.family(i) = fam;
            rows.model(i) = name;
            rows.n(i) = 0;
            rows.loocv_rmse(i) = NaN;
            rows.pearson(i) = NaN;
            rows.spearman(i) = NaN;
            rows.baseline_loocv_rmse(i) = NaN;
            rows.rmse_ratio(i) = NaN;
            rows.beats_baseline(i) = NaN;
            rows.status(i) = "SKIPPED";
            continue;
        end

        mask = isfinite(y) & all(isfinite(Xfull), 2);
        yv = y(mask);
        Xv = Xfull(mask,:);
        n = numel(yv);
        if n < 4
            rows.family(i) = fam;
            rows.model(i) = name;
            rows.n(i) = n;
            rows.loocv_rmse(i) = NaN;
            rows.pearson(i) = NaN;
            rows.spearman(i) = NaN;
            rows.baseline_loocv_rmse(i) = NaN;
            rows.rmse_ratio(i) = NaN;
            rows.beats_baseline(i) = NaN;
            rows.status(i) = "TOO_FEW";
            continue;
        end

        % LOOCV linear fit with intercept
        yhat = zeros(n,1);
        ybase = zeros(n,1);
        for k = 1:n
            tr = true(n,1);
            tr(k) = false;
            beta = [ones(sum(tr),1), Xv(tr,:)] \ yv(tr);
            yhat(k) = [1, Xv(k,:)] * beta;
            ybase(k) = mean(yv(tr), 'omitnan');
        end

        rmse = sqrt(mean((yv - yhat).^2, 'omitnan'));
        rmseBase = sqrt(mean((yv - ybase).^2, 'omitnan'));
        ratio = rmse / rmseBase;
        beat = double(rmse < rmseBase);

        C = corrcoef(yv, yhat);
        pear = C(1,2);
        trY = tiedrank(yv);
        trYh = tiedrank(yhat);
        Cr = corrcoef(trY, trYh);
        spear = Cr(1,2);

        rows.family(i) = fam;
        rows.model(i) = name;
        rows.n(i) = n;
        rows.loocv_rmse(i) = rmse;
        rows.pearson(i) = pear;
        rows.spearman(i) = spear;
        rows.baseline_loocv_rmse(i) = rmseBase;
        rows.rmse_ratio(i) = ratio;
        rows.beats_baseline(i) = beat;
        rows.status(i) = "OK";
    end

    % Persist CSV
    writetable(rows, csvOutAbs);

    % Best model among valid rows
    validMask = isfinite(rows.loocv_rmse) & rows.n > 0;
    idxValid = find(validMask);
    if ~isempty(idxValid)
        [bestRmse, ibLocal] = min(rows.loocv_rmse(idxValid));
        ib = idxValid(ibLocal);
        bestModel = rows.model(ib);
        bestPear = rows.pearson(ib);
        bestSpear = rows.spearman(ib);
        bestRatio = rows.rmse_ratio(ib);

        [~, idxLocalSig] = max(abs(rows.spearman(idxValid)));
        sigIdx = idxValid(idxLocalSig);
        sigModel = rows.model(sigIdx);
        sigSpear = rows.spearman(sigIdx);
        sigPear = rows.pearson(sigIdx);

        % Verdict thresholds
        if bestRatio <= 0.60 && abs(bestPear) >= 0.85 && abs(bestSpear) >= 0.85
            closureVerdict = 'YES';
        elseif bestRatio <= 0.90 && (abs(bestPear) >= 0.65 || abs(bestSpear) >= 0.65)
            closureVerdict = 'PARTIAL';
        else
            closureVerdict = 'NO';
        end

        if abs(sigSpear) >= 0.65
            hasSignature = 'YES';
        else
            hasSignature = 'NO';
        end

        % Physical meaning of kappa2 (choose one)
        if contains(sigModel, 'I_peak')
            physicalMeaning = 'deformation of collective response (linked to Phi1 derivatives)';
        elseif contains(sigModel, 'width_asymmetry') || contains(sigModel, 'slope_asymmetry') || contains(sigModel, 'local_curvature') || contains(sigModel, 'antisym_area_res2')
            physicalMeaning = 'local asymmetry mode near switching peak';
        else
            physicalMeaning = 'non-closed secondary collective coordinate';
        end
    else
        % No usable models found
        closureVerdict = 'NO';
        hasSignature = 'NO';
        bestModel = "";
        sigModel = "";
        physicalMeaning = 'no stable physical interpretation';
    end

    % Read build status for "what failed / recovered"
    buildStatusText = '';
    if exist(buildStatusAbs, 'file')
        try
            txt = fileread(buildStatusAbs);
            lines = splitlines(string(txt));
            tailN = min(6, numel(lines));
            buildStatusText = strjoin(lines(end-tailN+1:end), ' | ');
        catch
        end
    end

    % Compose markdown report
    mdLines = strings(0,1);
    mdLines(end+1) = '# kappa2 phenomenological closure audit';
    mdLines(end+1) = '';
    mdLines(end+1) = '## Build recovery and variables used';
    mdLines(end+1) = '- Build status (tail): ' + buildStatusText;
    if isempty(usedVars)
        mdLines(end+1) = '- Variables used (non-empty & finite): NONE';
    else
        mdLines(end+1) = '- Variables used (non-empty & finite): ' + strjoin(usedVars, ', ');
    end
    if isempty(missingVars)
        mdLines(end+1) = '- Variables missing: NONE';
    else
        mdLines(end+1) = '- Variables missing: ' + strjoin(missingVars, ', ');
    end
    mdLines(end+1) = '';

    mdLines(end+1) = '## Candidate observable definitions';
    mdLines(end+1) = '- `I_peak`: ridge peak location descriptor (switching map, ridge maximum on current axis).';
    mdLines(end+1) = '- `width_asymmetry`: local left/right width imbalance proxy (`asymmetry_q_spread`).';
    mdLines(end+1) = '- `slope_asymmetry`: local slope/shape asymmetry proxy (`skew_I_weighted`).';
    mdLines(end+1) = '- `local_curvature`: peak-neighborhood shoulder/curvature proxy (`q90_minus_q50 - q75_minus_q25`).';
    mdLines(end+1) = '- `antisym_area_res2`: residual-strip antisymmetric strength proxy (`rel_orth_leftover_norm`).';
    mdLines(end+1) = '';

    mdLines(end+1) = '## Single-observable results';
    for i = 1:nModels
        if rows.family(i) == "single"
            mdLines(end+1) = sprintf('- `%s`: LOOCV_RMSE=%.6g, Pearson=%.4f, Spearman=%.4f, baseline_RMSE=%.6g, ratio=%.4f', ...
                rows.model(i), rows.loocv_rmse(i), rows.pearson(i), rows.spearman(i), rows.baseline_loocv_rmse(i), rows.rmse_ratio(i));
        end
    end
    mdLines(end+1) = '';

    mdLines(end+1) = '## Two-observable results';
    for i = 1:nModels
        if rows.family(i) == "pair"
            mdLines(end+1) = sprintf('- `%s`: LOOCV_RMSE=%.6g, Pearson=%.4f, Spearman=%.4f, baseline_RMSE=%.6g, ratio=%.4f', ...
                rows.model(i), rows.loocv_rmse(i), rows.pearson(i), rows.spearman(i), rows.baseline_loocv_rmse(i), rows.rmse_ratio(i));
        end
    end
    mdLines(end+1) = '';

    mdLines(end+1) = '## Best model';
    if bestModel == ""
        mdLines(end+1) = '- Best LOOCV model: NONE (no valid fit)';
    else
        mdLines(end+1) = sprintf('- Best LOOCV model: `%s`.', bestModel);
    end
    mdLines(end+1) = '';

    mdLines(end+1) = '## Operational signature';
    if sigModel == ""
        mdLines(end+1) = '- Strongest monotonic signature: NONE (insufficient usable models).';
        mdLines(end+1) = '- KAPPA2_HAS_OPERATIONAL_SIGNATURE: NO';
    else
        mdLines(end+1) = sprintf('- Strongest monotonic signature: `%s` (abs Spearman >= 0.65 => %s).', sigModel, hasSignature);
        mdLines(end+1) = '- KAPPA2_HAS_OPERATIONAL_SIGNATURE: ' + hasSignature;
    end
    mdLines(end+1) = '';

    mdLines(end+1) = '## Final verdict';
    mdLines(end+1) = '- KAPPA2_PHENOMENOLOGICALLY_CLOSED: ' + closureVerdict;
    mdLines(end+1) = '- KAPPA2_HAS_OPERATIONAL_SIGNATURE: ' + hasSignature;
    mdLines(end+1) = '';

    mdLines(end+1) = '## Physical meaning of kappa2';
    mdLines(end+1) = '- ' + physicalMeaning;

    reportText = strjoin(cellstr(mdLines), newline);
    fid = fopen(mdOutAbs, 'w');
    fprintf(fid, '%s\n', reportText);
    fclose(fid);

    fid = fopen(statusFileAbs, 'a');
    fprintf(fid, 'DONE nModels=%d\n', nModels);
    fclose(fid);
catch ME
    fid = fopen(errFileAbs, 'w');
    fprintf(fid, 'ERROR %s\n\n', datestr(now));
    fprintf(fid, '%s\n', getReport(ME));
    fclose(fid);

    fid = fopen(statusFileAbs, 'a');
    fprintf(fid, 'FAIL\n');
    fclose(fid);

    % Best-effort: still write a minimal report/CSV if rows exists.
    try
        if ~isempty(rows) && height(rows) > 0
            writetable(rows, csvOutAbs);
        end
    catch
    end
    try
        fid = fopen(mdOutAbs, 'w');
        fprintf(fid, '# kappa2 phenomenological closure audit\n\nERROR: %s\n', ME.message);
        fclose(fid);
    catch
    end
end

