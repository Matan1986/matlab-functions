function run_kappa1_simplification_test(varargin)
%RUN_KAPPA1_SIMPLIFICATION_TEST
% LOOCV simplification audit for kappa1:
% - single-observable models
% - max two-variable models (comparison only)
%
% Required output:
%   tables/kappa1_simplification_models.csv
%
% Additional output:
%   reports/kappa1_simplification_report.md

opts = localParseOpts(varargin{:});

if ~local_kappa1_simplification_input_ok(opts.inputPath)
    error('run_kappa1_simplification_test:invalidInput', ...
        'Input table failed precondition: %s', opts.inputPath);
end

src = readtable(opts.inputPath, 'VariableNamingRule', 'preserve');
required = {'kappa1', 'tail_width_q90_q50', 'S_peak'};
assert(all(ismember(required, src.Properties.VariableNames)), ...
    'Input table must include: kappa1, tail_width_q90_q50, S_peak');

% Canonical aliases used in this audit.
src.spread90_50 = double(src.tail_width_q90_q50(:));
src.kappa1 = double(src.kappa1(:));
src.S_peak = double(src.S_peak(:));

% Candidate models (strictly limited and interpretable).
specs = localModelSpecs(src);

rows = table();
for i = 1:numel(specs)
    X = specs(i).X;
    y = src.kappa1;
    keep = isfinite(y) & all(isfinite(X), 2);
    y0 = y(keep);
    X0 = X(keep, :);
    nUsed = numel(y0);

    [rmse, yhat] = localLoocvOls(y0, X0);
    rP = corr(y0, yhat, 'type', 'Pearson', 'rows', 'complete');
    rS = corr(y0, yhat, 'type', 'Spearman', 'rows', 'complete');

    rows = [rows; table({specs(i).model}, nUsed, rmse, rP, rS, ...
        'VariableNames', {'model','n_used','LOOCV_RMSE','Pearson','Spearman'})]; %#ok<AGROW>
end

rows = sortrows(rows, 'LOOCV_RMSE');
writetable(rows, opts.outputCsvPath);

baselineName = 'kappa1 ~ spread90_50 + S_peak';
idx2 = find(strcmp(rows.model, baselineName), 1);
assert(~isempty(idx2), 'Internal error: baseline 2-variable model not found.');
rmse2 = rows.LOOCV_RMSE(idx2);

isSingle = ~contains(rows.model, ' + ');
singleRows = rows(isSingle, :);
[~, jBestSingle] = min(singleRows.LOOCV_RMSE);
bestSingle = singleRows(jBestSingle, :);

lossAbs = bestSingle.LOOCV_RMSE - rmse2;
lossPct = 100 * lossAbs / max(rmse2, eps);

if lossPct <= 5
    verdict = "YES";
elseif lossPct <= 20
    verdict = "PARTIAL";
else
    verdict = "NO";
end

interp = localInterpretation(bestSingle.model);
rep = localBuildReport(opts.inputPath, rows, bestSingle, baselineName, rmse2, verdict, lossAbs, lossPct, interp);
writelines(rep, opts.reportPath);

fprintf(1, 'Wrote: %s\n', opts.outputCsvPath);
fprintf(1, 'Wrote: %s\n', opts.reportPath);
end

function tf = local_kappa1_simplification_input_ok(path)
if exist(path, 'file') ~= 2
    tf = false;
    return;
end
tbl = readtable(path, 'VariableNamingRule', 'preserve');
required = {'kappa1', 'tail_width_q90_q50', 'S_peak'};
tf = all(ismember(required, tbl.Properties.VariableNames)) && height(tbl) >= 20;
end

function specs = localModelSpecs(src)
spread = double(src.spread90_50(:));
speak = double(src.S_peak(:));
q90 = localCol(src, 'q90_I');
q75 = localCol(src, 'q75_I');
q50 = localCol(src, 'q50_I');
q95 = localCol(src, 'q95_I');
ext = localCol(src, 'extreme_tail_q95_q75');
tailMass = localCol(src, 'tail_mass_quantile_top12p5');
pdf90 = localCol(src, 'pdf_at_q90');

normTail_q90_q50 = (q90 - q50) ./ max(abs(q50), eps);
normTail_q95_q75 = (q95 - q75) ./ max(abs(q75), eps);

specs = struct('model', {}, 'X', {});
specs(end + 1) = struct('model', 'kappa1 ~ spread90_50', 'X', spread); %#ok<AGROW>
specs(end + 1) = struct('model', 'kappa1 ~ S_peak', 'X', speak); %#ok<AGROW>
specs(end + 1) = struct('model', 'kappa1 ~ spread90_50 * S_peak', 'X', spread .* speak); %#ok<AGROW>
specs(end + 1) = struct('model', 'kappa1 ~ spread90_50 / S_peak', 'X', spread ./ max(abs(speak), eps)); %#ok<AGROW>
specs(end + 1) = struct('model', 'kappa1 ~ tail_mass_quantile_top12p5', 'X', tailMass); %#ok<AGROW>
specs(end + 1) = struct('model', 'kappa1 ~ pdf_at_q90', 'X', pdf90); %#ok<AGROW>
specs(end + 1) = struct('model', 'kappa1 ~ normalized_tail_q90_q50', 'X', normTail_q90_q50); %#ok<AGROW>
specs(end + 1) = struct('model', 'kappa1 ~ normalized_tail_q95_q75', 'X', normTail_q95_q75); %#ok<AGROW>
specs(end + 1) = struct('model', 'kappa1 ~ extreme_tail_q95_q75', 'X', ext); %#ok<AGROW>

% Two-variable comparison-only models (restricted).
specs(end + 1) = struct('model', 'kappa1 ~ spread90_50 + S_peak', 'X', [spread, speak]); %#ok<AGROW>
specs(end + 1) = struct('model', 'kappa1 ~ extreme_tail_q95_q75 + S_peak', 'X', [ext, speak]); %#ok<AGROW>
end

function x = localCol(tbl, name)
if ismember(name, tbl.Properties.VariableNames)
    x = double(tbl.(name)(:));
else
    x = nan(height(tbl), 1);
end
end

function [rmse, yhat] = localLoocvOls(y, X)
n = numel(y);
p = size(X, 2);
yhat = nan(n, 1);

if n <= p + 1
    rmse = NaN;
    return;
end

for i = 1:n
    tr = true(n, 1);
    tr(i) = false;
    Z = [ones(sum(tr), 1), X(tr, :)];
    yt = y(tr);
    if rank(Z) < size(Z, 2)
        yhat(i) = NaN;
        continue;
    end
    b = Z \ yt;
    yhat(i) = [1, X(i, :)] * b;
end

rmse = sqrt(mean((y - yhat).^2, 'omitnan'));
end

function interp = localInterpretation(modelName)
if contains(modelName, 'spread90_50') || contains(modelName, 'tail')
    interp.label = 'tail weight';
    interp.reason = 'Best-performing simplified model is dominated by upper-tail spread/tail descriptors, indicating kappa1 tracks how much probability weight sits in the high-current tail.';
elseif contains(modelName, 'S_peak')
    interp.label = 'scale effect';
    interp.reason = 'Best simplified model is S_peak-driven, indicating kappa1 behaves primarily as an amplitude scale coordinate.';
else
    interp.label = 'landscape susceptibility';
    interp.reason = 'Best simplified model reflects sensitivity to distribution-shape response rather than pure amplitude.';
end
end

function txt = localBuildReport(inputPath, rows, bestSingle, baselineName, rmse2, verdict, lossAbs, lossPct, interp)
lines = {};
lines{end+1} = '# kappa1 physical simplification';
lines{end+1} = '';
lines{end+1} = sprintf('- Input table: `%s`', strrep(inputPath, '\', '/'));
lines{end+1} = sprintf('- Best single-observable model: `%s`', bestSingle.model{1});
lines{end+1} = sprintf('- Best single LOOCV RMSE: `%.6g` (Pearson=`%.4f`, Spearman=`%.4f`, n=%d)', ...
    bestSingle.LOOCV_RMSE, bestSingle.Pearson, bestSingle.Spearman, bestSingle.n_used);
lines{end+1} = sprintf('- Reference 2-variable model: `%s` with LOOCV RMSE=`%.6g`', baselineName, rmse2);
lines{end+1} = '';
lines{end+1} = '## Final section';
lines{end+1} = sprintf('KAPPA1_SINGLE_OBSERVABLE_SUFFICIENT: %s', verdict);
if verdict == "PARTIAL"
    lines{end+1} = sprintf('- Loss vs 2-variable model: +%.6g RMSE (%.2f%%)', lossAbs, lossPct);
end
if verdict == "NO"
    lines{end+1} = sprintf('- Loss vs 2-variable model: +%.6g RMSE (%.2f%%)', lossAbs, lossPct);
end
lines{end+1} = '';
lines{end+1} = '## Physical interpretation';
lines{end+1} = sprintf('- Selected interpretation: **%s**', interp.label);
lines{end+1} = sprintf('- Justification: %s', interp.reason);
lines{end+1} = '';
lines{end+1} = '## Model table snapshot';
lines{end+1} = '| model | n_used | LOOCV RMSE | Pearson | Spearman |';
lines{end+1} = '|---|---:|---:|---:|---:|';
for i = 1:height(rows)
    lines{end+1} = sprintf('| %s | %d | %.6g | %.6g | %.6g |', ...
        rows.model{i}, rows.n_used(i), rows.LOOCV_RMSE(i), rows.Pearson(i), rows.Spearman(i)); %#ok<AGROW>
end
txt = string(strjoin(lines, newline));
end

function opts = localParseOpts(varargin)
thisPath = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisPath));
opts = struct();
opts.inputPath = fullfile(repoRoot, 'tables', 'kappa1_from_PT_aligned.csv');
opts.outputCsvPath = fullfile(repoRoot, 'tables', 'kappa1_simplification_models.csv');
opts.reportPath = fullfile(repoRoot, 'reports', 'kappa1_simplification_report.md');

if mod(numel(varargin), 2) ~= 0
    error('Name-value pairs expected.');
end

for k = 1:2:numel(varargin)
    name = lower(string(varargin{k}));
    value = char(string(varargin{k + 1}));
    switch name
        case "inputpath"
            opts.inputPath = value;
        case "outputcsvpath"
            opts.outputCsvPath = value;
        case "reportpath"
            opts.reportPath = value;
        otherwise
            error('Unknown option: %s', varargin{k});
    end
end
end
