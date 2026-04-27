function run_aging_Q006_S0_canonical_svd_revalidation()
%RUN_AGING_Q006_S0_CANONICAL_SVD_REVALIDATION
%  Q006 step S0: recompute SVD on Q005b-approved canonical tables only.
%  Writes tables under tables/aging/aging_Q006_S0_*.csv (no edits to canonical sources).

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

outDir = fullfile(repoRoot, 'tables', 'aging');
assert(exist(outDir, 'dir') == 7, 'Missing output dir: %s', outDir);

trackAPath = fullfile(repoRoot, 'tables', 'aging', 'aging_trackA_replay_dataset.csv');
obsPath = fullfile(repoRoot, 'tables', 'aging', 'aging_observable_dataset.csv');
assert(exist(trackAPath, 'file') == 2);
assert(exist(obsPath, 'file') == 2);

fmtA = '%f%f%f%f%f%f%q%q%s%s%f%f%f%f%f%f%f%f%s';
trackA = readtable(trackAPath, 'Delimiter', ',', 'Format', fmtA, 'MultipleDelimsAsOne', false);
obs = readtable(obsPath, 'Delimiter', ',', 'Format', '%f%f%f%f%q');
trackA = stripBomVarNames(trackA);
obs = stripBomVarNames(obs);
trackA = forceTpTwNames(trackA);
obs = forceTpTwNames(obs);
trackA.Tp = toNumericCol(trackA.Tp);
trackA.tw = toNumericCol(trackA.tw);
obs.Tp = toNumericCol(obs.Tp);
obs.tw = toNumericCol(obs.tw);

tps = [18; 22; 26; 30];
tws = [360; 3600];

colHybrid = {'Dip_area_selected','Dip_depth','AFM_like','FM_like','FM_E','FM_abs'};
colTrackA = {'Dip_area_selected','AFM_like','FM_like','FM_E'};
colTrackB = {'Dip_depth','FM_abs'};

[X_hybrid, rowMeta] = buildMatrix(trackA, obs, tps, tws, colHybrid);
[X_A, ~] = buildMatrix(trackA, obs, tps, tws, colTrackA);
[X_B, ~] = buildMatrix(trackA, obs, tps, tws, colTrackB);

% --- Primary analysis: hybrid intersection LONG_TW, column-centered (default)
runId = 'HYBRID_LONGTW_COLCENTER';
[Xc, colMu] = centerCols(X_hybrid);
[Uh, Sh, Vh] = svd(Xc, 'econ');
sh = diag(Sh);
thr = max(sh) * 1e-12;
kEff = sum(sh > thr);
Uh = Uh(:, 1:kEff);
Sh = Sh(1:kEff, 1:kEff);
Vh = Vh(:, 1:kEff); %#ok<NASGU>
sh = diag(Sh);
tblS = buildSingularTable(runId, sh);
writetable(tblS, fullfile(outDir, 'aging_Q006_S0_singular_values.csv'));

% Sector association: correlation of each centered column with U(:,k)
tblAssoc = sectorAssociations(runId, Xc, Uh, colHybrid);
tblAssoc = appendModeSectorLabels(tblAssoc);
writetable(tblAssoc, fullfile(outDir, 'aging_Q006_S0_mode_sector_associations.csv'));

% Robustness variants
robRows = table();
robRows = [robRows; robustRow('HYBRID_RAW', X_hybrid, rowMeta, colHybrid)];
robRows = [robRows; robustRow('HYBRID_COLCENTER', Xc, rowMeta, colHybrid)];
[Xz, ~] = zscoreCols(X_hybrid);
robRows = [robRows; robustRow('HYBRID_ZSCORE', Xz, rowMeta, colHybrid)];
robRows = [robRows; robustRow('TRACK_A_ONLY_COLCENTER', centerCols(X_A), rowMeta, colTrackA)];
robRows = [robRows; robustRow('TRACK_B_ONLY_COLCENTER', centerCols(X_B), rowMeta, colTrackB)];

for dropTp = tps(:).'
    keep = rowMeta.Tp ~= dropTp;
    if sum(keep) < 4
        continue
    end
    [Xsub, metaSub] = buildMatrix(trackA, obs, tps(tps~=dropTp), tws, colHybrid);
    [Xcs, ~] = centerCols(Xsub);
    tag = sprintf('HYBRID_COLCENTER_DROP_TP_%d', dropTp);
    robRows = [robRows; robustRow(tag, Xcs, metaSub, colHybrid)]; %#ok<AGROW>
end

writetable(robRows, fullfile(outDir, 'aging_Q006_S0_mode_robustness.csv'));

fprintf('Wrote S0 SVD tables to %s\n', outDir);
end

function T = stripBomVarNames(T)
vn = T.Properties.VariableNames;
if ~isempty(vn)
    vn{1} = regexprep(vn{1}, '^\xEF\xBB\xBF', '');
    T.Properties.VariableNames = vn;
end
end

function T = forceTpTwNames(T)
vn = T.Properties.VariableNames;
if numel(vn) >= 2
    vn{1} = 'Tp';
    vn{2} = 'tw';
    T.Properties.VariableNames = vn;
end
end

function v = toNumericCol(v)
if isa(v, 'double') && ~isobject(v)
    return
end
if iscell(v)
    v = str2double(string(v));
elseif isstring(v)
    v = str2double(v);
elseif ischar(v)
    v = str2double(string(v));
end
end

function [X, rowMeta] = buildMatrix(trackA, obs, tps, tws, colNames)
trackA = ensureKeyColumns(trackA);
obs = ensureKeyColumns(obs);
nR = numel(tps) * numel(tws);
X = zeros(nR, numel(colNames));
tpCol = zeros(nR, 1);
twCol = zeros(nR, 1);
idx = 0;
for tp = tps(:).'
    for tw = tws(:).'
        idx = idx + 1;
        rA = trackA(abs(trackA.Tp_key - tp) < 1e-6 & abs(trackA.tw_key - tw) < 1e-6, :);
        rO = obs(abs(obs.Tp_key - tp) < 1e-6 & abs(obs.tw_key - tw) < 1e-6, :);
        assert(height(rA) == 1 && height(rO) == 1, 'Missing row Tp=%g tw=%g (rA=%d rO=%d)', tp, tw, height(rA), height(rO));
        for j = 1:numel(colNames)
            c = colNames{j};
            if ismember(c, trackA.Properties.VariableNames)
                v = rA.(c)(1);
            else
                v = rO.(c)(1);
            end
            assert(isfinite(v), 'Nonfinite %s at Tp=%g tw=%g', c, tp, tw);
            X(idx, j) = v;
        end
        tpCol(idx) = tp;
        twCol(idx) = tw;
    end
end
rowMeta = table(tpCol, twCol, 'VariableNames', {'Tp','tw'});
end

function T = ensureKeyColumns(T)
% First two columns of canonical Aging CSVs are Tp and tw (numeric).
Tp_raw = T{:, 1};
tw_raw = T{:, 2};
if ~isnumeric(Tp_raw)
    Tp_raw = str2double(string(Tp_raw));
end
if ~isnumeric(tw_raw)
    tw_raw = str2double(string(tw_raw));
end
T.Tp_key = Tp_raw;
T.tw_key = tw_raw;
end

function [Xc, mu] = centerCols(X)
mu = mean(X, 1, 'omitnan');
Xc = X - mu;
end

function [Xz, mu] = zscoreCols(X)
mu = mean(X, 1, 'omitnan');
sig = std(X, 0, 1, 'omitnan');
sig(sig < eps) = 1;
Xz = (X - mu) ./ sig;
end

function tblS = buildSingularTable(runId, s)
s = s(:);
thr = max(s) * 1e-12;
keep = s > thr;
s = s(keep);
n = numel(s);
expl = s.^2 / sum(s.^2);
cumv = cumsum(expl);
tblS = table(repmat(string(runId), n, 1), (1:n)', s(:), expl(:), cumv(:), ...
    'VariableNames', {'matrix_id','mode_index','singular_value','explained_variance_ratio','cumulative_explained_variance'});
end

function tbl = appendModeSectorLabels(tbl)
modes = unique(tbl.mode_index);
lab = strings(height(tbl), 1);
for i = 1:numel(modes)
    k = modes(i);
    idx = tbl.mode_index == k;
    sub = tbl(idx, :);
    dipObs = sub(sub.observable_lane == "dip_afm_lane", :);
    fmObs = sub(sub.observable_lane == "fm_lane", :);
    md = max(dipObs.abs_correlation, [], 'omitnan');
    mf = max(fmObs.abs_correlation, [], 'omitnan');
    if md > 1.5 * max(mf, eps)
        tag = "DIP_AFM_MODE";
    elseif mf > 1.5 * max(md, eps)
        tag = "FM_MODE";
    elseif max(md, mf) < 0.25
        tag = "RESIDUAL_OR_NOISE";
    else
        tag = "MIXED_MODE";
    end
    lab(idx) = tag;
end
tbl.mode_sector_label = lab;
end

function tbl = sectorAssociations(runId, X, U, colNames)
[nR, nC] = size(X);
nM = size(U, 2);
tbl = table();
for k = 1:nM
    for j = 1:nC
        % Small-n LONG_TW lattice: Pearson is less brittle than Spearman here.
        c = corr(X(:, j), U(:, k), 'type', 'Pearson', 'rows', 'complete');
        sec = classifySector(colNames{j}, abs(c));
        tbl = [tbl; table(string(runId), k, string(colNames{j}), c, abs(c), string(sec), ...
            'VariableNames', {'matrix_id','mode_index','observable','correlation','abs_correlation','observable_lane'})]; %#ok<AGROW>
    end
end
end

function s = classifySector(name, ~)
switch name
    case {'Dip_area_selected','Dip_depth','AFM_like'}
        s = 'dip_afm_lane';
    case {'FM_like','FM_E','FM_abs'}
        s = 'fm_lane';
    otherwise
        s = 'other';
end
end

function row = robustRow(tag, X, rowMeta, colNames)
[U, S, ~] = svd(X, 'econ');
s = diag(S);
thr = max(s) * 1e-12;
kEff = sum(s > thr);
U = U(:, 1:kEff);
S = S(1:kEff, 1:kEff);
s = diag(S);
row1 = modeStabilityRow(tag, 1, U, s, rowMeta, colNames, X);
row2 = modeStabilityRow(tag, 2, U, s, rowMeta, colNames, X);
row3 = modeStabilityRow(tag, 3, U, s, rowMeta, colNames, X);
row = [row1; row2; row3];
end

function row = modeStabilityRow(tag, k, U, s, rowMeta, colNames, X)
if numel(s) < k
    row = table(string(tag), k, NaN, NaN, NaN, NaN, NaN, NaN, string('NA'), ...
        'VariableNames', {'matrix_id','mode_index','singular_value','explained_frac','max_abs_U','dominant_tp_for_abs_U','col_max_corr','col_max_corr_abs','dominant_observable_corr'});
    return
end
expl = s(k)^2 / sum(s.^2);
u = U(:, k);
[~, im] = max(abs(u));
domTp = rowMeta.Tp(im);
corrs = zeros(1, numel(colNames));
for j = 1:numel(colNames)
    corrs(j) = corr(X(:, j), u, 'rows', 'complete');
end
[~, jc] = max(abs(corrs));
row = table(string(tag), k, s(k), expl, max(abs(u)), domTp, corrs(jc), abs(corrs(jc)), string(colNames{jc}), ...
    'VariableNames', {'matrix_id','mode_index','singular_value','explained_frac','max_abs_U','dominant_tp_for_abs_U','col_max_corr','col_max_corr_abs','dominant_observable_corr'});
end
