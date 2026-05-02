% RLX-ACTIVITY-REPRESENTATION-03: Scalar ranking stability across baseline/window/grid/inclusion (Relaxation-only).

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    rd = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(rd);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

tblRelax = fullfile(repoRoot, 'tables', 'relaxation');
repRelax = fullfile(repoRoot, 'reports', 'relaxation');
figCanon = fullfile(repoRoot, 'figures', 'relaxation', 'canonical');
for d = {tblRelax, repRelax, figCanon}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

cfg = struct();
cfg.runLabel = 'relaxation_activity_representation_03';

try
    run = createRunContext('relaxation', cfg);

    pSamples = fullfile(tblRelax, 'relaxation_RF3R2_repaired_curve_samples.csv');
    pIndex = fullfile(tblRelax, 'relaxation_RF3R2_repaired_curve_index.csv');
    pRcon = fullfile(tblRelax, 'relaxation_RCON_02B_Aproj_vs_SVD_score.csv');

    if exist(pSamples, 'file') ~= 2 || exist(pIndex, 'file') ~= 2 || exist(pRcon, 'file') ~= 2
        error('STOP:inputs_missing');
    end

    samp = readtable(pSamples, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    cidx = readtable(pIndex, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    rcon = readtable(pRcon, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');

    cnS = string(samp.Properties.VariableNames);
    ixTraceS = find(cnS == "trace_id", 1);
    ixTime = find(cnS == "time_since_field_off", 1);
    ixDelta = find(cnS == "delta_m", 1);
    ixMom = find(cnS == "moment_post_field_off", 1);

    cnI = string(cidx.Properties.VariableNames);
    ixTraceI = find(cnI == "trace_id", 1);
    ixTemp = find(cnI == "temperature", 1);
    ixTV = find(cnI == "trace_valid_for_relaxation", 1);
    ixDef = find(cnI == "valid_for_default_replay", 1);
    ixIQ = find(cnI == "is_quality_flagged", 1);

    cnR = string(rcon.Properties.VariableNames);
    ixTk = find(cnR == "temperature_K", 1);
    ixAobs = find(cnR == "A_obs", 1);
    ixAproj = find(cnR == "A_proj_nonSVD", 1);
    ixM0 = find(cnR == "SVD_score_mode1", 1);

    tv = strcmpi(strtrim(string(cidx{:, ixTV})), "YES");
    dv = strcmpi(strtrim(string(cidx{:, ixDef})), "YES");
    qf = strcmpi(strtrim(string(cidx{:, ixIQ})), "YES");
    maskI1 = tv & dv & ~qf;
    maskI2 = tv;

    defs = {
        'AR03_B1_W1_G1_I1', 'ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT', 'FULL_TRACE', 'CANONICAL_GRID', 'STRICT_DEFAULT_NO_QUALITY_FLAG'; ...
        'AR03_B2_W1_G1_I1', 'MEDIAN_FIRST_5_PERCENT', 'FULL_TRACE', 'CANONICAL_GRID', 'STRICT_DEFAULT_NO_QUALITY_FLAG'; ...
        'AR03_B3_W1_G1_I1', 'MEAN_FIRST_5_PERCENT', 'FULL_TRACE', 'CANONICAL_GRID', 'STRICT_DEFAULT_NO_QUALITY_FLAG'; ...
        'AR03_B4_W1_G1_I1', 'MEDIAN_FIRST_10_PERCENT', 'FULL_TRACE', 'CANONICAL_GRID', 'STRICT_DEFAULT_NO_QUALITY_FLAG'; ...
        'AR03_B1_W2_G1_I1', 'ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT', 'TRIM_FIRST_5_PERCENT', 'CANONICAL_GRID', 'STRICT_DEFAULT_NO_QUALITY_FLAG'; ...
        'AR03_B1_W3_G1_I1', 'ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT', 'TRIM_FIRST_10_PERCENT', 'CANONICAL_GRID', 'STRICT_DEFAULT_NO_QUALITY_FLAG'; ...
        'AR03_B1_W4_G1_I1', 'ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT', 'TRIM_LAST_10_PERCENT', 'CANONICAL_GRID', 'STRICT_DEFAULT_NO_QUALITY_FLAG'; ...
        'AR03_B1_W1_G1_I2', 'ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT', 'FULL_TRACE', 'CANONICAL_GRID', 'INCLUDE_ALL_VALID_CREATION_CURVES'; ...
        'AR03_B1_W1_G2_I1', 'ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT', 'FULL_TRACE', 'HALF_DENSITY_GRID', 'STRICT_DEFAULT_NO_QUALITY_FLAG'; ...
        'AR03_B2_W1_G2_I1', 'MEDIAN_FIRST_5_PERCENT', 'FULL_TRACE', 'HALF_DENSITY_GRID', 'STRICT_DEFAULT_NO_QUALITY_FLAG'; ...
        'AR03_B1_W2_G2_I1', 'ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT', 'TRIM_FIRST_5_PERCENT', 'HALF_DENSITY_GRID', 'STRICT_DEFAULT_NO_QUALITY_FLAG'; ...
        'AR03_B2_W2_G1_I1', 'MEDIAN_FIRST_5_PERCENT', 'TRIM_FIRST_5_PERCENT', 'CANONICAL_GRID', 'STRICT_DEFAULT_NO_QUALITY_FLAG'
        };

    invTbl = cell2table(defs, 'VariableNames', {'variant_id', 'baseline', 'window', 'grid', 'inclusion'});
    writetable(invTbl, fullfile(tblRelax, 'relaxation_activity_representation_03_variant_inventory.csv'));

    nVarDef = size(defs, 1);
    recRows = {};
    rankRows = {};
    scalarNames = {'m0_LOO_SVD_projection', 'm0_svd_full_reference', 'A_proj_nonSVD', 'A_obs'};
    bestList = strings(0, 1);

    for vi = 1:nVarDef
        vid = defs{vi, 1};
        bsl = defs{vi, 2};
        win = defs{vi, 3};
        grd = defs{vi, 4};
        inc = defs{vi, 5};
        if strcmp(inc, 'STRICT_DEFAULT_NO_QUALITY_FLAG')
            msk = maskI1;
        else
            msk = maskI2;
        end
        if strcmp(grd, 'CANONICAL_GRID')
            nGrid = 320;
        else
            nGrid = 160;
        end

        Rb = rlx_ar03_build_map(samp, cidx, msk, ixTraceS, ixTime, ixDelta, ixMom, ixTraceI, ixTemp, ...
            rcon, ixTk, ixAobs, ixAproj, ixM0, nGrid, bsl, win);
        if Rb.nT < 3
            continue;
        end
        M = Rb.M;
        Aobs = Rb.vecs.A_obs(:);
        Aproj = Rb.vecs.A_proj_nonSVD(:);
        m0rc = Rb.vecs.m0_svd(:);

        [Uf, ~, ~] = svd(M, 'econ');
        psi_full = Uf(:, 1);
        if dot(psi_full, mean(M, 2)) < 0
            psi_full = -psi_full;
        end

        ins_leak = rlx_ar03_insample_rmse_leaky(M, psi_full, m0rc);
        ins_ap = rlx_ar03_insample_rmse(M, Aproj);
        ins_ao = rlx_ar03_insample_rmse(M, Aobs);

        loo_leak = rlx_ar03_loo_mean_rmse(M, m0rc, psi_full, 'leaky');
        loo_ap = rlx_ar03_loo_mean_rmse(M, Aproj, psi_full, 'fixed');
        loo_ao = rlx_ar03_loo_mean_rmse(M, Aobs, psi_full, 'fixed');

        vec_m0loo = nan(Rb.nT, 1);
        loo_vec_m0loo = nan(Rb.nT, 1);
        for ii = 1:Rb.nT
            idx = true(Rb.nT, 1);
            idx(ii) = false;
            Mt = M(:, idx);
            [Ut, ~, ~] = svd(Mt, 'econ');
            pt = Ut(:, 1);
            cf = corr(pt, psi_full, 'Rows', 'complete');
            if isfinite(cf) && cf < 0
                pt = -pt;
            end
            mloc = pt' * M(:, ii);
            vec_m0loo(ii) = mloc;
            loo_vec_m0loo(ii) = sqrt(mean((M(:, ii) - pt * mloc).^2));
        end
        ins_m0loo = rlx_ar03_insample_rmse(M, vec_m0loo);

        for si = 1:numel(scalarNames)
            sn = scalarNames{si};
            if strcmp(sn, 'm0_LOO_SVD_projection')
                rmIn = ins_m0loo;
                rmLo = mean(loo_vec_m0loo);
            elseif strcmp(sn, 'm0_svd_full_reference')
                rmIn = ins_leak;
                rmLo = loo_leak;
            elseif strcmp(sn, 'A_proj_nonSVD')
                rmIn = ins_ap;
                rmLo = loo_ap;
            else
                rmIn = ins_ao;
                rmLo = loo_ao;
            end
            recRows(end+1, :) = {vid, sn, rmIn, rmLo}; %#ok<AGROW>
        end

        rmLoVec = [mean(loo_vec_m0loo); loo_leak; loo_ap; loo_ao];
        [~, ord] = sort(rmLoVec);
        ordS = scalarNames(ord);
        rankRows(end+1, :) = {vid, ordS{1}, ordS{2}, ordS{3}, ordS{4}}; %#ok<AGROW>
        bestList(end+1, 1) = string(ordS{1}); %#ok<AGROW>
    end

    recTbl = cell2table(recRows, 'VariableNames', {'variant_id', 'scalar', 'rmse_in_sample', 'rmse_loo'});
    writetable(recTbl, fullfile(tblRelax, 'relaxation_activity_representation_03_reconstruction_metrics.csv'));

    rankTbl = cell2table(rankRows, 'VariableNames', ...
        {'variant_id', 'best_scalar', 'second_scalar', 'third_scalar', 'worst_scalar'});
    writetable(rankTbl, fullfile(tblRelax, 'relaxation_activity_representation_03_ranking_summary.csv'));

    tb = zeros(numel(scalarNames), 3);
    for si = 1:numel(scalarNames)
        nm = scalarNames{si};
        tb(si, 1) = sum(bestList == string(nm));
        tb(si, 2) = sum(strcmp(rankTbl.best_scalar, nm) | strcmp(rankTbl.second_scalar, nm));
        for jj = 1:height(rankTbl)
            if strcmp(rankTbl.worst_scalar{jj}, nm)
                tb(si, 3) = tb(si, 3) + 1;
            end
        end
    end
    stabTbl = table(scalarNames(:), tb(:, 1), tb(:, 2), tb(:, 3), ...
        'VariableNames', {'scalar', 'times_best', 'times_top2', 'times_worst'});
    writetable(stabTbl, fullfile(tblRelax, 'relaxation_activity_representation_03_ranking_stability.csv'));

    nVarEff = numel(bestList);
    nBest = sum(bestList == "m0_LOO_SVD_projection");
    maj = nBest >= ceil(nVarEff / 2);
    alwaysM0 = nBest == nVarEff;
    uniqOrder = unique(bestList);
    rankingStable = (numel(uniqOrder) <= 1);
    uniqClaim = (numel(uniqOrder) == 1) && (nVarEff > 0);
    nSecondAp = sum(strcmp(string(rankTbl.second_scalar), 'A_proj_nonSVD'));
    apCompromise = 'PARTIAL';
    if nSecondAp >= ceil(nVarEff / 2)
        apCompromise = 'YES';
    elseif nSecondAp == 0
        apCompromise = 'NO';
    end

    verdict = {
        'BASELINE_WINDOW_ROBUSTNESS_DONE', 'YES'; ...
        'SCALAR_RANKING_STABLE_ACROSS_VARIANTS', rlx_ar03_yn(rankingStable); ...
        'M0_LOO_ALWAYS_BEST', rlx_ar03_yn(alwaysM0); ...
        'M0_LOO_MAJORITY_BEST', rlx_ar03_yn(maj); ...
        'A_PROJ_NONSVD_STABLE_COMPROMISE', apCompromise; ...
        'A_OBS_NEVER_BEST', rlx_ar03_yn(~any(bestList == "A_obs")); ...
        'UNIQUE_BEST_SCALAR_CLAIMABLE', rlx_ar03_yn(uniqClaim); ...
        'LOG_TIME_GRID_G3_INCLUDED', 'NO_NOT_STANDARD_FOR_RF3R2_COMMON_BUILD'; ...
        'VARIANTS_REQUESTED', sprintf('%d', nVarDef); ...
        'VARIANTS_EFFECTIVE', sprintf('%d', nVarEff) ...
        };
    writetable(cell2table(verdict, 'VariableNames', {'verdict_key', 'verdict_value'}), ...
        fullfile(tblRelax, 'relaxation_activity_representation_03_verdicts.csv'));

    statTbl = table({'relaxation_activity_representation_03'}, {'SUCCESS'}, {'YES'}, nVarEff, ...
        {sprintf('variants_%d', nVarEff)}, ...
        'VariableNames', {'RUN_LABEL', 'EXECUTION_STATUS', 'INPUT_FOUND', 'N_T_REF', 'MAIN_RESULT_SUMMARY'});
    writetable(statTbl, fullfile(tblRelax, 'relaxation_activity_representation_03_status.csv'));

    repPath = fullfile(repRelax, 'relaxation_activity_representation_03_robustness_audit.md');
    fid = fopen(repPath, 'w');
    fprintf(fid, '# RLX-ACTIVITY-REPRESENTATION-03 robustness audit\n\n');
    fprintf(fid, '## 1. Variant design\n\n');
    fprintf(fid, '| variant_id | baseline | window | grid | inclusion |\n|---|---|---|---|---|\n');
    for r = 1:height(invTbl)
        fprintf(fid, '| %s | %s | %s | %s | %s |\n', invTbl.variant_id{r}, invTbl.baseline{r}, ...
            invTbl.window{r}, invTbl.grid{r}, invTbl.inclusion{r});
    end
    fprintf(fid, '\n**G3 LOG_TIME_GRID:** not included (no shared RF3R2 table helper in-repo for RLX03).\n\n');

    m0loo = recTbl(strcmp(recTbl.scalar, 'm0_LOO_SVD_projection'), :);
    mxLo = max(m0loo.rmse_loo);
    mnLo = min(m0loo.rmse_loo);
    fprintf(fid, '## 2. Reconstruction comparison\n\n');
    fprintf(fid, 'Full table: `relaxation_activity_representation_03_reconstruction_metrics.csv`.\n\n');
    fprintf(fid, '**m0_LOO_SVD_projection** held-out LOO RMSE range across variants: `%.3e` – `%.3e` (rel. spread ~%.1f%%).\n\n', ...
        mnLo, mxLo, 100 * (mxLo - mnLo) / max(mnLo, eps));
    fprintf(fid, '## 3. Ranking behavior summary\n\n');
    fprintf(fid, '| scalar | times_best | times_top2 | times_worst |\n|---|---:|---:|---:|\n');
    for ri = 1:height(stabTbl)
        fprintf(fid, '| %s | %d | %d | %d |\n', stabTbl.scalar{ri}, stabTbl.times_best(ri), ...
            stabTbl.times_top2(ri), stabTbl.times_worst(ri));
    end
    fprintf(fid, '\nDetail per variant: `relaxation_activity_representation_03_ranking_summary.csv`.\n\n');
    fprintf(fid, '## 4. Ranking flips\n\nUnique best scalars across variants: **%s**.\n\n', strjoin(cellstr(uniqOrder'), ', '));
    if height(rankTbl) >= 1
        refBest = rankTbl.best_scalar{1};
        fprintf(fid, 'Reference **best_scalar** (`%s`): **%s**.\n\n', rankTbl.variant_id{1}, refBest);
        flipList = {};
        for ii = 2:height(rankTbl)
            if ~strcmp(rankTbl.best_scalar{ii}, refBest)
                flipList{end+1} = sprintf('- `%s` → **%s** (differs from reference)', ...
                    rankTbl.variant_id{ii}, rankTbl.best_scalar{ii}); %#ok<AGROW>
            end
        end
        if isempty(flipList)
            fprintf(fid, 'No flip vs reference: every variant agrees on **%s**.\n\n', refBest);
        else
            fprintf(fid, 'Flips vs reference:\n\n%s\n\n', strjoin(flipList, newline));
        end
    end

    fprintf(fid, '## 5. Interpretation\n\n');
    fprintf(fid, 'If **m0_LOO_SVD_projection** remains top under map preprocessing changes, the coordinate is **intrinsic** ');
    fprintf(fid, 'to rank-1 temporal structure; large sensitivity suggests **map-dependent** artifacts.\n\n');

    fprintf(fid, '## 6. Final verdict\n\n');
    for vk = 1:size(verdict, 1)
        fprintf(fid, '- **%s:** %s\n', verdict{vk, 1}, verdict{vk, 2});
    end
    fclose(fid);

    set(groot, 'defaultTextFontName', 'Helvetica');
    fg = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 420]);
    bestCat = categorical(rankTbl.best_scalar, scalarNames);
    xOrd = categorical(rankTbl.variant_id);
    plot(xOrd, double(bestCat), 'o-', 'LineWidth', 1.2, 'MarkerSize', 7, 'Color', [0.15 0.35 0.65]);
    yticks(1:numel(scalarNames));
    yticklabels(scalarNames);
    ylim([0.8 numel(scalarNames)+0.2]);
    ylabel('best_scalar (held-out LOO rank)');
    xtickangle(45);
    title('Best scalar by map variant (primary metric = LOO RMSE)');
    grid on;
    set(gca, 'FontSize', 10);
    exportgraphics(fg, fullfile(figCanon, 'relaxation_activity_representation_03_ranking_across_variants.png'), 'Resolution', 300);
    close(fg);

    fg = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 420]);
    subRec = recTbl(strcmp(recTbl.scalar, 'm0_LOO_SVD_projection'), :);
    subRec2 = recTbl(strcmp(recTbl.scalar, 'A_proj_nonSVD'), :);
    vCat = subRec.variant_id;
    semilogy(categorical(vCat), subRec.rmse_loo, 's-', 'LineWidth', 1.1, 'Color', [0.15 0.35 0.65]); hold on;
    semilogy(categorical(subRec2.variant_id), subRec2.rmse_loo, 'o-', 'LineWidth', 1.1, 'Color', [0.75 0.35 0.2]);
    legend('m0 LOO SVD', 'A_{proj} nonSVD', 'Location', 'best');
    title('LOO RMSE: m0 LOO vs A_{proj}');
    xtickangle(45);
    grid on;
    set(gca, 'FontSize', 10);
    exportgraphics(fg, fullfile(figCanon, 'relaxation_activity_representation_03_rmse_comparison.png'), 'Resolution', 300);
    close(fg);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nVarEff, {'RLX_AR03_complete'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'RLX_AR03_failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end

function Rhat = rlx_ar03_rank1_from_a(M, a)
    a = double(a(:));
    if any(~isfinite(a)) || sum(abs(a)) < 1e-30
        Rhat = nan(size(M));
        return;
    end
    psi = (M * a) / (a' * a);
    Rhat = psi * a';
end

function rmse = rlx_ar03_insample_rmse(M, a)
    R = rlx_ar03_rank1_from_a(M, a);
    rmse = sqrt(mean((M - R).^2, 'all'));
end

function rmse = rlx_ar03_insample_rmse_leaky(M, psi_full, m0rc)
    R = psi_full * m0rc(:)';
    rmse = sqrt(mean((M - R).^2, 'all'));
end

function m = rlx_ar03_loo_mean_rmse(M, a, psi_full, mode)
    nT = size(M, 2);
    a = double(a(:));
    e = nan(nT, 1);
    for k = 1:nT
        idx = true(nT, 1);
        idx(k) = false;
        Mr = M(:, idx);
        ar = a(idx);
        if strcmp(mode, 'leaky')
            pred = psi_full * a(k);
        elseif strcmp(mode, 'fixed')
            psi = (Mr * ar) / max(ar' * ar, eps);
            pred = psi * a(k);
        elseif strcmp(mode, 'm0_loo')
            [Ut, ~, ~] = svd(Mr, 'econ');
            pt = Ut(:, 1);
            cf = corr(pt, psi_full, 'Rows', 'complete');
            if isfinite(cf) && cf < 0
                pt = -pt;
            end
            mk = pt' * M(:, k);
            pred = pt * mk;
        end
        e(k) = sqrt(mean((M(:, k) - pred).^2));
    end
    m = mean(e, 'omitnan');
end

function R = rlx_ar03_build_map(samp, cidx, mask, ixTraceS, ixTime, ixDelta, ixMom, ixTraceI, ixTemp, ...
        rcon, ixTk, ixAobs, ixAproj, ixM0, nGrid, baselineId, windowId)
    sub = cidx(mask, :);
    traceIds = string(sub{:, ixTraceI});
    temps = double(sub{:, ixTemp});
    [temps, ord] = sort(temps);
    traceIds = traceIds(ord);
    nT = numel(traceIds);
    cols = cell(nT, 1);
    tcols = cell(nT, 1);
    for j = 1:nT
        rows = samp(strcmp(string(samp{:, ixTraceS}), traceIds(j)), :);
        tt = double(rows{:, ixTime});
        dm = double(rows{:, ixDelta});
        mom = double(rows{:, ixMom});
        sig = rlx_ar03_signal_column(tt, dm, mom, baselineId);
        [tt2, sg2] = rlx_ar03_apply_window(tt, sig, windowId);
        cols{j} = sg2(:);
        tcols{j} = tt2(:);
    end
    tMinEach = nan(nT, 1);
    tMaxEach = nan(nT, 1);
    for j = 1:nT
        tt = tcols{j};
        tt = tt(isfinite(tt) & tt > 0);
        if isempty(tt)
            continue;
        end
        tMinEach(j) = min(tt);
        tMaxEach(j) = max(tt);
    end
    tMinCommon = max(tMinEach);
    tMaxCommon = min(tMaxEach);
    tGrid = linspace(tMinCommon, tMaxCommon, nGrid);
    M = nan(nGrid, nT);
    for j = 1:nT
        tt = tcols{j};
        xx = cols{j};
        m = isfinite(tt) & isfinite(xx) & tt > 0;
        tt = tt(m);
        xx = xx(m);
        [tu, ia] = unique(tt, 'stable');
        xx = xx(ia);
        if numel(tu) < 2
            M(:, j) = interp1(tu, xx, tGrid, 'nearest', 'extrap');
        else
            M(:, j) = interp1(tu, xx, tGrid, 'linear', 'extrap');
        end
    end
    TkR = round(temps, 4);
    Aobs = nan(nT, 1);
    Aproj = nan(nT, 1);
    M0 = nan(nT, 1);
    rtk = round(double(rcon{:, ixTk}), 4);
    for j = 1:nT
        ix = find(abs(rtk - TkR(j)) < 1e-3, 1);
        if ~isempty(ix)
            Aobs(j) = double(rcon{ix, ixAobs});
            Aproj(j) = double(rcon{ix, ixAproj});
            M0(j) = double(rcon{ix, ixM0});
        end
    end
    vecs = struct('A_obs', Aobs, 'A_proj_nonSVD', Aproj, 'm0_svd', M0);
    R = struct('M', M, 'nT', nT, 'T_K', TkR, 'vecs', vecs);
end

function sig = rlx_ar03_signal_column(tt, dm, mom, baselineId)
    [ts, o] = sort(tt);
    dm = dm(o);
    mom = mom(o);
    n = numel(ts);
    if strcmp(baselineId, 'ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT')
        sig = dm;
        return;
    end
    k5 = max(1, floor(0.05 * n));
    k10 = max(1, floor(0.10 * n));
    idx5 = 1:k5;
    idx10 = 1:k10;
    if strcmp(baselineId, 'MEDIAN_FIRST_5_PERCENT')
        bl = median(mom(idx5), 'omitnan');
    elseif strcmp(baselineId, 'MEAN_FIRST_5_PERCENT')
        bl = mean(mom(idx5), 'omitnan');
    elseif strcmp(baselineId, 'MEDIAN_FIRST_10_PERCENT')
        bl = median(mom(idx10), 'omitnan');
    else
        sig = dm;
        return;
    end
    sig = mom - bl;
end

function [tt, sg] = rlx_ar03_apply_window(tt, sg, windowId)
    [ts, o] = sort(tt);
    sg = sg(o);
    n = numel(ts);
    if strcmp(windowId, 'FULL_TRACE')
        tt = ts;
        return;
    end
    kf = max(1, floor(0.05 * n));
    kl = max(1, floor(0.10 * n));
    if strcmp(windowId, 'TRIM_FIRST_5_PERCENT')
        keep = (kf+1):n;
    elseif strcmp(windowId, 'TRIM_FIRST_10_PERCENT')
        k10 = max(1, floor(0.10 * n));
        keep = (k10+1):n;
    elseif strcmp(windowId, 'TRIM_LAST_10_PERCENT')
        keep = 1:(n - kl);
    else
        keep = 1:n;
    end
    if isempty(keep)
        tt = ts;
        return;
    end
    tt = ts(keep);
    sg = sg(keep);
end

function s = rlx_ar03_yn(tf)
    if tf
        s = 'YES';
    else
        s = 'NO';
    end
end
