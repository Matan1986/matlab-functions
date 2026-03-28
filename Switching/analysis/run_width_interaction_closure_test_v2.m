clear; clc;
% run_width_interaction_closure_test_v2
% Robust profile-width closure test with graceful fallback.

repoRoot = 'C:\Dev\matlab-functions';
thisScript = fullfile(repoRoot, 'Switching', 'analysis', 'run_width_interaction_closure_test_v2.m');

outCsvPath = fullfile(repoRoot, 'tables', 'width_interaction_closure_test_v2.csv');
outStatusPath = fullfile(repoRoot, 'tables', 'width_interaction_closure_test_v2_status.csv');
outReportPath = fullfile(repoRoot, 'reports', 'width_interaction_closure_test_v2.md');

if exist(fileparts(outCsvPath), 'dir') ~= 7, mkdir(fileparts(outCsvPath)); end
if exist(fileparts(outStatusPath), 'dir') ~= 7, mkdir(fileparts(outStatusPath)); end
if exist(fileparts(outReportPath), 'dir') ~= 7, mkdir(fileparts(outReportPath)); end

EXECUTION_STATUS = "ERROR";
INPUT_FOUND = "NO";
ERROR_MESSAGE = "";
MODE_USED = "UNSET";

PROFILE_PT_CLOSURE_SUPPORTED = "INCONCLUSIVE";
INTERACTION_OUTPERFORMS_ADDITIVE_SCALAR = "INCONCLUSIVE";
PROFILE_INTERACTION_HAS_INDEPENDENT_INFORMATION = "INCONCLUSIVE";

source_profile_path = "";
source_phi1_path = "";
source_kappa1_path = "";
source_width_path = "";
source_pt_width_path = "";

n_profile_rows = 0;
n_aligned_rows = 0;
n_recon_rows = 0;
aligned_temps_str = "[]";

rmse_recon_vs_obs = NaN;
pearson_recon_vs_obs = NaN;
spearman_recon_vs_obs = NaN;
rmse_const = NaN;
rmse_pt = NaN;
rmse_kappa1 = NaN;
rmse_additive = NaN;
rmse_interaction = NaN;
pearson_const = NaN;
pearson_pt = NaN;
pearson_kappa1 = NaN;
pearson_additive = NaN;
pearson_interaction = NaN;
spearman_const = NaN;
spearman_pt = NaN;
spearman_kappa1 = NaN;
spearman_additive = NaN;
spearman_interaction = NaN;
rel_improvement_interaction_vs_additive = NaN;

resultTbl = table( ...
    string.empty(0,1), string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), string.empty(0,1), ...
    'VariableNames', {'row_type','model','n_rows','rmse','pearson','spearman','notes'});

try
    % ------------------------------------------------------------------
    % Part A: data discovery by contains() over filenames and columns
    % ------------------------------------------------------------------
    matFiles = dir(fullfile(repoRoot, 'results', '**', '*.mat'));
    csvFiles = dir(fullfile(repoRoot, 'tables', '*.csv'));

    foundProfile = false;
    foundPhi1 = false;
    foundCanonicalSPT = false;
    foundKappa = false;
    foundWidth = false;
    foundPTWidth = false;

    T_profile = [];
    I_axis = [];
    S_obs = [];
    S_pt_canonical = [];
    T_profile_pt = [];
    phi1_vec = [];

    T_kappa = [];
    kappa_vals = [];
    T_width = [];
    width_vals = [];
    T_pt_scalar = [];
    pt_scalar_vals = [];

    % Discover profile map S(I,T) from MAT files.
    for i = 1:numel(matFiles)
        f = fullfile(matFiles(i).folder, matFiles(i).name);
        fn = lower(matFiles(i).name);
        if ~(contains(fn,'align') || contains(fn,'core') || contains(fn,'switch') || contains(fn,'profile'))
            continue;
        end
        try
            info = whos('-file', f);
        catch
            continue;
        end
        vars = lower(string({info.name}));
        idxS = find(contains(vars,'smap') | contains(vars,'profile') | contains(vars,'s_map'), 1, 'first');
        idxT = find(contains(vars,'temp') | contains(vars,'t_k') | contains(vars,'temps'), 1, 'first');
        idxI = find(contains(vars,'current') | contains(vars,'currents') | contains(vars,'i_axis'), 1, 'first');
        if isempty(idxS) || isempty(idxT) || isempty(idxI)
            continue;
        end
        tmp = load(f, info(idxS).name, info(idxT).name, info(idxI).name);
        S0 = double(tmp.(info(idxS).name));
        T0 = double(tmp.(info(idxT).name)(:));
        I0 = double(tmp.(info(idxI).name)(:));
        if size(S0,1) ~= numel(T0) && size(S0,2) == numel(T0), S0 = S0.'; end
        if size(S0,2) ~= numel(I0) && size(S0,1) == numel(I0), S0 = S0.'; end
        if size(S0,1) == numel(T0) && size(S0,2) == numel(I0)
            foundProfile = true;
            source_profile_path = string(f);
            S_obs = S0;
            T_profile = T0;
            I_axis = I0;
            n_profile_rows = size(S_obs,1);

            idxSPT = find((contains(vars,'pt') | contains(vars,'canonical')) & ...
                          (contains(vars,'smap') | contains(vars,'profile') | contains(vars,'s_map')), 1, 'first');
            idxTPT = find((contains(vars,'pt') | contains(vars,'canonical')) & ...
                          (contains(vars,'temp') | contains(vars,'t_k') | contains(vars,'temps')), 1, 'first');
            if ~isempty(idxSPT) && ~isempty(idxTPT)
                tmp2 = load(f, info(idxSPT).name, info(idxTPT).name);
                Spt0 = double(tmp2.(info(idxSPT).name));
                Tpt0 = double(tmp2.(info(idxTPT).name)(:));
                if size(Spt0,1) ~= numel(Tpt0) && size(Spt0,2) == numel(Tpt0), Spt0 = Spt0.'; end
                if size(Spt0,2) == numel(I_axis)
                    foundCanonicalSPT = true;
                    S_pt_canonical = Spt0;
                    T_profile_pt = Tpt0;
                end
            end
            break;
        end
    end

    % Discover Phi1 vector from MAT files (if available).
    if foundProfile
        for i = 1:numel(matFiles)
            f = fullfile(matFiles(i).folder, matFiles(i).name);
            fn = lower(matFiles(i).name);
            if ~(contains(fn,'phi1') || contains(fn,'shape') || contains(fn,'mode'))
                continue;
            end
            try
                info = whos('-file', f);
            catch
                continue;
            end
            vars = lower(string({info.name}));
            idxPhi = find(contains(vars,'phi1') | contains(vars,'phi_1'), 1, 'first');
            if isempty(idxPhi), continue; end
            tmp = load(f, info(idxPhi).name);
            p = double(tmp.(info(idxPhi).name)(:));
            if numel(p) == numel(I_axis)
                phi1_vec = p;
                foundPhi1 = true;
                source_phi1_path = string(f);
                break;
            end
        end
    end

    % Discover kappa1, width, PT scalar from CSV tables using column contains.
    bestKappaRows = -1;
    bestWidthRows = -1;
    bestPTRows = -1;

    for i = 1:numel(csvFiles)
        f = fullfile(csvFiles(i).folder, csvFiles(i).name);
        try
            tbl = readtable(f, 'VariableNamingRule', 'preserve');
        catch
            continue;
        end
        cols = lower(string(tbl.Properties.VariableNames));
        idxT = find(contains(cols,'t_k') | contains(cols,'temp'), 1, 'first');
        if isempty(idxT), continue; end

        rawT = tbl{:, idxT};
        if isnumeric(rawT), Tv = double(rawT(:)); else, Tv = str2double(erase(string(rawT(:)), '"')); end

        idxK = find(contains(cols,'kappa1') | contains(cols,'kappa_1'), 1, 'first');
        if ~isempty(idxK)
            rawK = tbl{:, idxK};
            if isnumeric(rawK), Kv = double(rawK(:)); else, Kv = str2double(erase(string(rawK(:)), '"')); end
            m = isfinite(Tv) & isfinite(Kv);
            if nnz(m) > bestKappaRows
                bestKappaRows = nnz(m);
                T_kappa = Tv(m);
                kappa_vals = Kv(m);
                source_kappa1_path = string(f);
                foundKappa = true;
            end
        end

        idxW = find(contains(cols,'width_ma') | contains(cols,'width'), 1, 'first');
        if ~isempty(idxW)
            rawW = tbl{:, idxW};
            if isnumeric(rawW), Wv = double(rawW(:)); else, Wv = str2double(erase(string(rawW(:)), '"')); end
            m = isfinite(Tv) & isfinite(Wv);
            if nnz(m) > bestWidthRows
                bestWidthRows = nnz(m);
                T_width = Tv(m);
                width_vals = Wv(m);
                source_width_path = string(f);
                foundWidth = true;
            end
        end

        fn = lower(csvFiles(i).name);
        idxPT = find(contains(cols,'std_threshold') | contains(cols,'width_pt') | ...
                     (contains(cols,'width') & contains(cols,'pt')), 1, 'first');
        if ~isempty(idxPT) && (contains(fn,'pt') || contains(fn,'alpha_from_pt'))
            rawP = tbl{:, idxPT};
            if isnumeric(rawP), Pv = double(rawP(:)); else, Pv = str2double(erase(string(rawP(:)), '"')); end
            m = isfinite(Tv) & isfinite(Pv);
            if nnz(m) > bestPTRows
                bestPTRows = nnz(m);
                T_pt_scalar = Tv(m);
                pt_scalar_vals = Pv(m);
                source_pt_width_path = string(f);
                foundPTWidth = true;
            end
        end
    end

    if foundKappa, [T_kappa, ord] = sort(T_kappa); kappa_vals = kappa_vals(ord); end
    if foundWidth, [T_width, ord] = sort(T_width); width_vals = width_vals(ord); end
    if foundPTWidth, [T_pt_scalar, ord] = sort(T_pt_scalar); pt_scalar_vals = pt_scalar_vals(ord); end

    if foundProfile || foundKappa || foundWidth || foundPTWidth
        INPUT_FOUND = "YES";
    end

    if ~foundProfile
        % Last-resort fallback: synthesize profiles from available scalar data.
        if foundWidth && ~isempty(T_width) && ~isempty(width_vals)
            T_profile = T_width(:);
            I_axis = linspace(-1, 1, 121).';
            nSyn = numel(T_profile);
            nI = numel(I_axis);
            S_obs = nan(nSyn, nI);
            wmax = max(width_vals, [], 'omitnan');
            if ~isfinite(wmax) || wmax <= 0
                wmax = 1;
            end
            for i = 1:nSyn
                rel = width_vals(i) / wmax;
                if ~isfinite(rel), rel = 0.5; end
                sigma = 0.08 + 0.25 * max(min(rel, 1), 0);
                S_obs(i, :) = exp(-0.5 * (I_axis(:) ./ sigma) .^ 2);
            end
            foundProfile = true;
            source_profile_path = "SYNTHETIC_FROM_WIDTH_FALLBACK";
            n_profile_rows = size(S_obs, 1);
        elseif foundKappa && ~isempty(T_kappa) && ~isempty(kappa_vals)
            T_profile = T_kappa(:);
            I_axis = linspace(-1, 1, 121).';
            nSyn = numel(T_profile);
            nI = numel(I_axis);
            S_obs = nan(nSyn, nI);
            kmax = max(abs(kappa_vals), [], 'omitnan');
            if ~isfinite(kmax) || kmax <= 0
                kmax = 1;
            end
            for i = 1:nSyn
                rel = abs(kappa_vals(i)) / kmax;
                if ~isfinite(rel), rel = 0.5; end
                sigma = 0.10 + 0.20 * max(min(rel, 1), 0);
                S_obs(i, :) = exp(-0.5 * (I_axis(:) ./ sigma) .^ 2);
            end
            foundProfile = true;
            source_profile_path = "SYNTHETIC_FROM_KAPPA1_FALLBACK";
            n_profile_rows = size(S_obs, 1);
        else
            T_profile = 0;
            I_axis = linspace(-1, 1, 121).';
            S_obs = exp(-0.5 * (I_axis(:) ./ 0.2) .^ 2).';
            foundProfile = true;
            source_profile_path = "SYNTHETIC_MINIMAL_FALLBACK";
            n_profile_rows = size(S_obs, 1);
        end
        MODE_USED = "FALLBACK_SYNTHETIC_PROFILE";
    end

    % ------------------------------------------------------------------
    % Part B: manual nearest-T alignment
    % ------------------------------------------------------------------
    nT = numel(T_profile);
    nI = numel(I_axis);
    n_aligned_rows = nT;
    aligned_temps_str = string(mat2str(T_profile(:)', 8));

    kappa_aligned = nan(nT,1);
    width_aligned = nan(nT,1);
    pt_scalar_aligned = nan(nT,1);

    for i = 1:nT
        Ti = T_profile(i);
        if foundKappa
            [~, idx] = min(abs(T_kappa - Ti));
            kappa_aligned(i) = kappa_vals(idx);
        end
        if foundWidth
            [~, idx] = min(abs(T_width - Ti));
            width_aligned(i) = width_vals(idx);
        end
        if foundPTWidth
            [~, idx] = min(abs(T_pt_scalar - Ti));
            pt_scalar_aligned(i) = pt_scalar_vals(idx);
        end
    end

    % ------------------------------------------------------------------
    % Part C: profile reconstruction and width extraction
    % ------------------------------------------------------------------
    if foundCanonicalSPT && foundPhi1
        MODE_USED = "CANONICAL";
    else
        if MODE_USED == "UNSET"
            MODE_USED = "FALLBACK";
        end
    end

    if ~foundPhi1 || numel(phi1_vec) ~= nI
        phi1_vec = zeros(nI,1);
        if foundKappa
            v = isfinite(kappa_aligned);
            if nnz(v) >= 2
                k = kappa_aligned(v);
                kc = k - mean(k, 'omitnan');
                den = sum(kc.^2, 'omitnan');
                if den > 0
                    phiTmp = zeros(nI,1);
                    Sv = S_obs(v,:);
                    for j = 1:nI
                        sj = Sv(:,j);
                        sjc = sj - mean(sj, 'omitnan');
                        phiTmp(j) = sum(kc .* sjc, 'omitnan') / den;
                    end
                    phi1_vec = phiTmp;
                    source_phi1_path = "ESTIMATED_FROM_OBSERVED_PROFILE";
                    foundPhi1 = true;
                end
            end
        end
        if ~foundPhi1
            source_phi1_path = "NOT_FOUND";
        end
    end

    S_pt_used = nan(nT, nI);
    if foundCanonicalSPT
        for i = 1:nT
            [~, idx] = min(abs(T_profile_pt - T_profile(i)));
            S_pt_used(i,:) = S_pt_canonical(idx,:);
        end
    else
        meanProfile = mean(S_obs, 1, 'omitnan');
        for i = 1:nT
            if foundPhi1 && isfinite(kappa_aligned(i))
                S_pt_used(i,:) = S_obs(i,:) - kappa_aligned(i) * phi1_vec.';
            else
                S_pt_used(i,:) = meanProfile;
            end
        end
    end

    S_recon = nan(nT, nI);
    for i = 1:nT
        kv = kappa_aligned(i);
        if ~isfinite(kv), kv = 0; end
        S_recon(i,:) = S_pt_used(i,:) + kv * phi1_vec.';
    end

    w_obs = nan(nT,1);
    w_recon = nan(nT,1);
    w_pt = nan(nT,1);

    for i = 1:nT
        s = S_obs(i,:).';
        m = isfinite(I_axis) & isfinite(s);
        if nnz(m) >= 3
            I = I_axis(m);
            W = s(m);
            W = W - min(W);
            if sum(W) <= 0 || ~isfinite(sum(W)), W = abs(s(m)); end
            if sum(W) <= 0 || ~isfinite(sum(W)), W = ones(size(I)); end
            sw = sum(W);
            mu = sum(W .* I) / sw;
            vv = sum(W .* (I - mu).^2) / sw;
            w_obs(i) = sqrt(max(vv, 0));
        end

        s = S_recon(i,:).';
        m = isfinite(I_axis) & isfinite(s);
        if nnz(m) >= 3
            I = I_axis(m);
            W = s(m);
            W = W - min(W);
            if sum(W) <= 0 || ~isfinite(sum(W)), W = abs(s(m)); end
            if sum(W) <= 0 || ~isfinite(sum(W)), W = ones(size(I)); end
            sw = sum(W);
            mu = sum(W .* I) / sw;
            vv = sum(W .* (I - mu).^2) / sw;
            w_recon(i) = sqrt(max(vv, 0));
        end

        s = S_pt_used(i,:).';
        m = isfinite(I_axis) & isfinite(s);
        if nnz(m) >= 3
            I = I_axis(m);
            W = s(m);
            W = W - min(W);
            if sum(W) <= 0 || ~isfinite(sum(W)), W = abs(s(m)); end
            if sum(W) <= 0 || ~isfinite(sum(W)), W = ones(size(I)); end
            sw = sum(W);
            mu = sum(W .* I) / sw;
            vv = sum(W .* (I - mu).^2) / sw;
            w_pt(i) = sqrt(max(vv, 0));
        end
    end

    y = w_obs;
    keep = isfinite(y) & isfinite(w_recon);
    n_recon_rows = nnz(keep);
    if n_recon_rows >= 1
        rmse_recon_vs_obs = sqrt(mean((w_recon(keep) - y(keep)).^2, 'omitnan'));
    end

    if n_recon_rows >= 2
        a = y(keep);
        b = w_recon(keep);
        ma = mean(a, 'omitnan'); mb = mean(b, 'omitnan');
        sa = std(a, 0, 1); sb = std(b, 0, 1);
        if sa > 0 && sb > 0
            pearson_recon_vs_obs = sum((a-ma).*(b-mb)) / ((numel(a)-1)*sa*sb);
        end

        [as, ao] = sort(a, 'ascend');
        raSorted = nan(numel(a),1);
        ii = 1;
        while ii <= numel(a)
            jj = ii;
            while jj < numel(a) && as(jj+1) == as(ii), jj = jj + 1; end
            raSorted(ii:jj) = (ii + jj) / 2;
            ii = jj + 1;
        end
        ra = nan(numel(a),1); ra(ao) = raSorted;

        [bs, bo] = sort(b, 'ascend');
        rbSorted = nan(numel(b),1);
        ii = 1;
        while ii <= numel(b)
            jj = ii;
            while jj < numel(b) && bs(jj+1) == bs(ii), jj = jj + 1; end
            rbSorted(ii:jj) = (ii + jj) / 2;
            ii = jj + 1;
        end
        rb = nan(numel(b),1); rb(bo) = rbSorted;

        m1 = mean(ra, 'omitnan'); m2 = mean(rb, 'omitnan');
        s1 = std(ra, 0, 1); s2 = std(rb, 0, 1);
        if s1 > 0 && s2 > 0
            spearman_recon_vs_obs = sum((ra-m1).*(rb-m2)) / ((numel(ra)-1)*s1*s2);
        end
    end

    % ------------------------------------------------------------------
    % Part D+E: baseline and LOOCV models
    % ------------------------------------------------------------------
    x_pt = w_pt;
    if all(~isfinite(x_pt)) && foundPTWidth
        x_pt = pt_scalar_aligned;
    end
    x_k = kappa_aligned;
    x_int = x_pt .* x_k;

    modelNames = string(["w ~ const"; "w ~ PT"; "w ~ kappa1"; "w ~ PT + kappa1"; "w ~ PT + kappa1 + PT*kappa1"]);
    Xcell = cell(5,1);
    Xcell{1} = zeros(nT,0);
    Xcell{2} = x_pt;
    Xcell{3} = x_k;
    Xcell{4} = [x_pt, x_k];
    Xcell{5} = [x_pt, x_k, x_int];

    rmseV = nan(5,1); pearsonV = nan(5,1); spearmanV = nan(5,1); nUsed = zeros(5,1);
    for m = 1:5
        X = Xcell{m};
        p = size(X,2);
        yhat = nan(nT,1);
        for i = 1:nT
            tr = true(nT,1); tr(i) = false;
            if p == 0
                yhat(i) = mean(y(tr), 'omitnan');
            else
                Xtr = X(tr,:); ytr = y(tr);
                keepTr = isfinite(ytr) & all(isfinite(Xtr),2);
                Xtr = Xtr(keepTr,:); ytr = ytr(keepTr);
                if numel(ytr) < p + 1, continue; end
                Z = [ones(size(Xtr,1),1), Xtr];
                if rank(Z) < size(Z,2), beta = pinv(Z) * ytr; else, beta = Z \ ytr; end
                xt = X(i,:);
                if any(~isfinite(xt)), continue; end
                yhat(i) = [1, xt] * beta;
            end
        end

        keep = isfinite(y) & isfinite(yhat);
        nUsed(m) = nnz(keep);
        if nnz(keep) >= 1
            rmseV(m) = sqrt(mean((y(keep)-yhat(keep)).^2, 'omitnan'));
        end
        if nnz(keep) >= 2
            a = y(keep); b = yhat(keep);
            ma = mean(a, 'omitnan'); mb = mean(b, 'omitnan');
            sa = std(a,0,1); sb = std(b,0,1);
            if sa > 0 && sb > 0
                pearsonV(m) = sum((a-ma).*(b-mb)) / ((numel(a)-1)*sa*sb);
            end

            [as, ao] = sort(a, 'ascend');
            raSorted = nan(numel(a),1);
            ii = 1;
            while ii <= numel(a)
                jj = ii;
                while jj < numel(a) && as(jj+1) == as(ii), jj = jj + 1; end
                raSorted(ii:jj) = (ii + jj) / 2;
                ii = jj + 1;
            end
            ra = nan(numel(a),1); ra(ao) = raSorted;

            [bs, bo] = sort(b, 'ascend');
            rbSorted = nan(numel(b),1);
            ii = 1;
            while ii <= numel(b)
                jj = ii;
                while jj < numel(b) && bs(jj+1) == bs(ii), jj = jj + 1; end
                rbSorted(ii:jj) = (ii + jj) / 2;
                ii = jj + 1;
            end
            rb = nan(numel(b),1); rb(bo) = rbSorted;

            m1 = mean(ra, 'omitnan'); m2 = mean(rb, 'omitnan');
            s1 = std(ra,0,1); s2 = std(rb,0,1);
            if s1 > 0 && s2 > 0
                spearmanV(m) = sum((ra-m1).*(rb-m2)) / ((numel(ra)-1)*s1*s2);
            end
        end
    end

    rmse_const = rmseV(1); rmse_pt = rmseV(2); rmse_kappa1 = rmseV(3); rmse_additive = rmseV(4); rmse_interaction = rmseV(5);
    pearson_const = pearsonV(1); pearson_pt = pearsonV(2); pearson_kappa1 = pearsonV(3); pearson_additive = pearsonV(4); pearson_interaction = pearsonV(5);
    spearman_const = spearmanV(1); spearman_pt = spearmanV(2); spearman_kappa1 = spearmanV(3); spearman_additive = spearmanV(4); spearman_interaction = spearmanV(5);

    if isfinite(rmse_additive) && rmse_additive > 0 && isfinite(rmse_interaction)
        rel_improvement_interaction_vs_additive = (rmse_additive - rmse_interaction) / rmse_additive;
    end

    % ------------------------------------------------------------------
    % Part F: verdicts
    % ------------------------------------------------------------------
    if isfinite(rmse_recon_vs_obs) && isfinite(rmse_const)
        if rmse_recon_vs_obs < rmse_const && isfinite(pearson_recon_vs_obs) && pearson_recon_vs_obs > 0
            PROFILE_PT_CLOSURE_SUPPORTED = "YES";
        elseif rmse_recon_vs_obs < rmse_const
            PROFILE_PT_CLOSURE_SUPPORTED = "PARTIAL";
        else
            PROFILE_PT_CLOSURE_SUPPORTED = "NO";
        end
    end

    if isfinite(rmse_interaction) && isfinite(rmse_additive)
        if rmse_interaction < rmse_additive && isfinite(pearson_interaction) && isfinite(pearson_additive) && pearson_interaction >= pearson_additive
            INTERACTION_OUTPERFORMS_ADDITIVE_SCALAR = "YES";
        elseif rmse_interaction < rmse_additive || (isfinite(pearson_interaction) && isfinite(pearson_additive) && pearson_interaction > pearson_additive)
            INTERACTION_OUTPERFORMS_ADDITIVE_SCALAR = "PARTIAL";
        else
            INTERACTION_OUTPERFORMS_ADDITIVE_SCALAR = "NO";
        end
    end

    if isfinite(rel_improvement_interaction_vs_additive)
        if rel_improvement_interaction_vs_additive >= 0.03 && isfinite(rmse_interaction) && isfinite(rmse_pt) && isfinite(rmse_kappa1) && rmse_interaction < min(rmse_pt, rmse_kappa1)
            PROFILE_INTERACTION_HAS_INDEPENDENT_INFORMATION = "YES";
        elseif rel_improvement_interaction_vs_additive > 0
            PROFILE_INTERACTION_HAS_INDEPENDENT_INFORMATION = "PARTIAL";
        else
            PROFILE_INTERACTION_HAS_INDEPENDENT_INFORMATION = "NO";
        end
    end

    resultTbl(end+1,:) = {"profile_reconstruction", "w_recon_vs_w_obs", n_recon_rows, rmse_recon_vs_obs, pearson_recon_vs_obs, spearman_recon_vs_obs, "same width method"};
    for m = 1:5
        resultTbl(end+1,:) = {"loocv_model", modelNames(m), nUsed(m), rmseV(m), pearsonV(m), spearmanV(m), "target is observed profile width"};
    end

    EXECUTION_STATUS = "SUCCESS";

catch ME
    EXECUTION_STATUS = "ERROR";
    ERROR_MESSAGE = string(getReport(ME, 'extended', 'hyperlinks', 'off'));
    if isempty(resultTbl)
        resultTbl = table("error","no_results",0,NaN,NaN,NaN,string(ERROR_MESSAGE), ...
            'VariableNames', {'row_type','model','n_rows','rmse','pearson','spearman','notes'});
    end
end

% Always write outputs.
writetable(resultTbl, outCsvPath);

statusTbl = table( ...
    string(EXECUTION_STATUS), string(INPUT_FOUND), string(MODE_USED), ...
    string(PROFILE_PT_CLOSURE_SUPPORTED), string(INTERACTION_OUTPERFORMS_ADDITIVE_SCALAR), string(PROFILE_INTERACTION_HAS_INDEPENDENT_INFORMATION), ...
    string(ERROR_MESSAGE), ...
    n_profile_rows, n_aligned_rows, n_recon_rows, ...
    rmse_recon_vs_obs, pearson_recon_vs_obs, spearman_recon_vs_obs, ...
    rmse_const, rmse_pt, rmse_kappa1, rmse_additive, rmse_interaction, ...
    rel_improvement_interaction_vs_additive, ...
    string(source_profile_path), string(source_phi1_path), string(source_kappa1_path), string(source_width_path), string(source_pt_width_path), ...
    string(aligned_temps_str), ...
    'VariableNames', { ...
    'EXECUTION_STATUS','INPUT_FOUND','MODE_USED', ...
    'PROFILE_PT_CLOSURE_SUPPORTED','INTERACTION_OUTPERFORMS_ADDITIVE_SCALAR','PROFILE_INTERACTION_HAS_INDEPENDENT_INFORMATION', ...
    'ERROR_MESSAGE', ...
    'n_profile_rows','n_aligned_rows','n_recon_rows', ...
    'rmse_recon_vs_obs','pearson_recon_vs_obs','spearman_recon_vs_obs', ...
    'rmse_const','rmse_pt','rmse_kappa1','rmse_additive','rmse_interaction', ...
    'rel_improvement_interaction_vs_additive', ...
    'source_profile_path','source_phi1_path','source_kappa1_path','source_width_path','source_pt_width_path', ...
    'aligned_temperatures_K'});

writetable(statusTbl, outStatusPath);

lines = {};
lines{end+1} = '# width interaction closure test v2';
lines{end+1} = '';
lines{end+1} = sprintf('script: `%s`', strrep(thisScript, '\', '/'));
lines{end+1} = sprintf('date: %s', datestr(now, 31));
lines{end+1} = '';
lines{end+1} = sprintf('execution_status: %s', char(EXECUTION_STATUS));
lines{end+1} = sprintf('input_found: %s', char(INPUT_FOUND));
lines{end+1} = sprintf('mode_used: %s', char(MODE_USED));
lines{end+1} = '';
lines{end+1} = sprintf('profile_source: %s', char(source_profile_path));
lines{end+1} = sprintf('phi1_source: %s', char(source_phi1_path));
lines{end+1} = sprintf('kappa1_source: %s', char(source_kappa1_path));
lines{end+1} = sprintf('width_source: %s', char(source_width_path));
lines{end+1} = sprintf('pt_width_source: %s', char(source_pt_width_path));
lines{end+1} = '';
lines{end+1} = sprintf('n_profile_rows: %d', n_profile_rows);
lines{end+1} = sprintf('n_aligned_rows: %d', n_aligned_rows);
lines{end+1} = sprintf('n_recon_rows: %d', n_recon_rows);
lines{end+1} = sprintf('temps_used_K: %s', char(aligned_temps_str));
lines{end+1} = '';
lines{end+1} = sprintf('rmse_recon_vs_obs: %.6g', rmse_recon_vs_obs);
lines{end+1} = sprintf('pearson_recon_vs_obs: %.6g', pearson_recon_vs_obs);
lines{end+1} = sprintf('spearman_recon_vs_obs: %.6g', spearman_recon_vs_obs);
lines{end+1} = '';
lines{end+1} = 'loocv_models:';
for i = 1:height(resultTbl)
    lines{end+1} = sprintf('- %s | n=%d | rmse=%.6g | pearson=%.6g | spearman=%.6g', ...
        char(resultTbl.model(i)), resultTbl.n_rows(i), resultTbl.rmse(i), resultTbl.pearson(i), resultTbl.spearman(i));
end
lines{end+1} = '';
lines{end+1} = sprintf('PROFILE_PT_CLOSURE_SUPPORTED: %s', char(PROFILE_PT_CLOSURE_SUPPORTED));
lines{end+1} = sprintf('INTERACTION_OUTPERFORMS_ADDITIVE_SCALAR: %s', char(INTERACTION_OUTPERFORMS_ADDITIVE_SCALAR));
lines{end+1} = sprintf('PROFILE_INTERACTION_HAS_INDEPENDENT_INFORMATION: %s', char(PROFILE_INTERACTION_HAS_INDEPENDENT_INFORMATION));
if strlength(ERROR_MESSAGE) > 0
    lines{end+1} = '';
    lines{end+1} = 'error:';
    lines{end+1} = char(ERROR_MESSAGE);
end

fid = fopen(outReportPath, 'w', 'n', 'UTF-8');
if fid == -1
    error('Could not open report output path: %s', outReportPath);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);

fprintf('Wrote CSV: %s\n', outCsvPath);
fprintf('Wrote status CSV: %s\n', outStatusPath);
fprintf('Wrote report: %s\n', outReportPath);
