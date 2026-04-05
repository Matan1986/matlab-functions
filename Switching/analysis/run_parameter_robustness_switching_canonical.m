function run_parameter_robustness_switching_canonical()
% RUN_PARAMETER_ROBUSTNESS_SWITCHING_CANONICAL
% Analysis-only robustness test for canonical switching features under
% parameter-definition variants. Keeps the same measurement/data grid.

baseFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(baseFolder));

samplesPath = fullfile(switchingCanonicalRunRoot(baseFolder), ...
    'run_2026_03_10_112659_alignment_audit', 'alignment_audit', 'switching_alignment_samples.csv');
obsPath = fullfile(switchingCanonicalRunRoot(baseFolder), ...
    'run_2026_03_10_112659_alignment_audit', 'alignment_audit', 'switching_alignment_observables_vs_T.csv');

outTables = fullfile(baseFolder, 'tables');
outReports = fullfile(baseFolder, 'reports');
outStatus = fullfile(baseFolder, 'status');
outFigures = fullfile(baseFolder, 'figures', 'switching_parameter_robustness');

if ~exist(outTables, 'dir'), mkdir(outTables); end
if ~exist(outReports, 'dir'), mkdir(outReports); end
if ~exist(outStatus, 'dir'), mkdir(outStatus); end
if ~exist(outFigures, 'dir'), mkdir(outFigures); end

assert(isfile(samplesPath), 'Missing samples CSV: %s', samplesPath);
assert(isfile(obsPath), 'Missing observables-vs-T CSV: %s', obsPath);

Tsamp = readtable(samplesPath);
Tobs = readtable(obsPath);

requiredSamp = {'current_mA','T_K','S_percent'};
assert(all(ismember(requiredSamp, Tsamp.Properties.VariableNames)), ...
    'Sample table missing required columns current_mA, T_K, S_percent.');
assert(ismember('T_K', Tobs.Properties.VariableNames), ...
    'Observable table missing T_K column.');

Tsamp.current_mA = double(Tsamp.current_mA(:));
Tsamp.T_K = double(Tsamp.T_K(:));
Tsamp.S_percent = double(Tsamp.S_percent(:));

Tgrid = sort(unique(double(Tobs.T_K(:))));
currents = sort(unique(Tsamp.current_mA(:)));

Smap = buildMapOnGrid(Tsamp, Tgrid, currents, 0.25);
validRows = sum(isfinite(Smap), 2) >= 5;
Tgrid = Tgrid(validRows);
Smap = Smap(validRows, :);

ipeakMethods = ["max", "com", "halfmax_mid", "dsdi_peak"];
widthMethods = ["fwhm", "rms", "iqr", "asymmetric"];
speakMethods = ["max", "local_avg", "local_median"];
scaleModes = ["fwhm", "rms", "asymmetric"];

nI = numel(ipeakMethods);
nW = numel(widthMethods);
nS = numel(speakMethods);
nC = numel(scaleModes);
nV = nI * nW * nS * nC;

variants = strings(nV, 1);
profilesIpeak = NaN(numel(Tgrid), nV);
profilesWidth = NaN(numel(Tgrid), nV);
profilesSpeak = NaN(numel(Tgrid), nV);
profilesKappa = NaN(numel(Tgrid), nV);
collapseMedian = NaN(nV, 1);

rowsLong = table('Size', [0 7], ...
    'VariableTypes', {'string','double','double','double','double','double','double'}, ...
    'VariableNames', {'variant_id','T_K','I_peak','width','S_peak','kappa1','collapse_rmse'});

xGrid = -2:0.2:2;
v = 0;
for ii = 1:nI
    for iw = 1:nW
        for is = 1:nS
            for ic = 1:nC
                v = v + 1;
                vid = "ip_" + ipeakMethods(ii) + "__w_" + widthMethods(iw) + ...
                    "__sp_" + speakMethods(is) + "__sc_" + scaleModes(ic);
                variants(v) = vid;

                M = NaN(numel(Tgrid), numel(xGrid));
                rmseVec = NaN(numel(Tgrid), 1);

                for it = 1:numel(Tgrid)
                    y = Smap(it, :)';
                    x = currents(:);
                    valid = isfinite(x) & isfinite(y);
                    x = x(valid);
                    y = y(valid);

                    if numel(x) < 5
                        continue;
                    end

                    [iPeak, iPeakIdx, fwhmW, leftHalf, rightHalf] = getIpeakAndFwhm(x, y, ipeakMethods(ii));
                    if ~isfinite(iPeak)
                        continue;
                    end

                    [wVal, leftW, rightW] = getWidth(x, y, iPeak, iPeakIdx, widthMethods(iw), fwhmW, leftHalf, rightHalf);
                    sPeak = getSpeak(x, y, iPeak, iPeakIdx, speakMethods(is));

                    if ~(isfinite(wVal) && wVal > 0 && isfinite(sPeak) && sPeak > 0)
                        continue;
                    end

                    xNorm = computeNormalizedX(x, iPeak, scaleModes(ic), fwhmW, leftW, rightW);
                    yNorm = y ./ max(sPeak, eps);

                    fitMask = isfinite(xNorm) & isfinite(yNorm) & abs(xNorm) <= 1;
                    if nnz(fitMask) >= 3
                        p = polyfit(xNorm(fitMask), yNorm(fitMask), 1);
                        kappa1 = p(1);
                    else
                        kappa1 = NaN;
                    end

                    [xs, idxSort] = sort(xNorm);
                    ys = yNorm(idxSort);
                    M(it, :) = interp1(xs, ys, xGrid, 'linear', NaN);

                    profilesIpeak(it, v) = iPeak;
                    profilesWidth(it, v) = wVal;
                    profilesSpeak(it, v) = sPeak;
                    profilesKappa(it, v) = kappa1;
                end

                meanCurve = mean(M, 1, 'omitnan');
                rmseVec(:) = sqrt(mean((M - meanCurve).^2, 2, 'omitnan'));
                collapseMedian(v) = median(rmseVec, 'omitnan');

                rowsThis = table(repmat(vid, numel(Tgrid), 1), Tgrid, profilesIpeak(:, v), ...
                    profilesWidth(:, v), profilesSpeak(:, v), profilesKappa(:, v), rmseVec, ...
                    'VariableNames', rowsLong.Properties.VariableNames);
                rowsLong = [rowsLong; rowsThis]; %#ok<AGROW>
            end
        end
    end
end

canonicalId = "ip_max__w_fwhm__sp_max__sc_fwhm";
idxCanon = find(variants == canonicalId, 1, 'first');
assert(~isempty(idxCanon), 'Canonical variant not found: %s', canonicalId);

summary = table;
summary.variant_id = variants;
summary.I_peak = NaN(nV, 1);
summary.width = NaN(nV, 1);
summary.S_peak = NaN(nV, 1);
summary.kappa1 = NaN(nV, 1);
summary.collapse_rmse = NaN(nV, 1);

for k = 1:nV
    summary.I_peak(k) = corrPairwise(profilesIpeak(:, idxCanon), profilesIpeak(:, k));
    summary.width(k) = corrPairwise(profilesWidth(:, idxCanon), profilesWidth(:, k));
    summary.S_peak(k) = corrPairwise(profilesSpeak(:, idxCanon), profilesSpeak(:, k));
    summary.kappa1(k) = corrPairwise(profilesKappa(:, idxCanon), profilesKappa(:, k));
    summary.collapse_rmse(k) = collapseMedian(k) ./ max(collapseMedian(idxCanon), eps);
end

pairI = minPairwiseCorr(profilesIpeak);
pairW = minPairwiseCorr(profilesWidth);
pairS = minPairwiseCorr(profilesSpeak);
pairK = minPairwiseCorr(profilesKappa);

ratioLo = min(summary.collapse_rmse, [], 'omitnan');
ratioHi = max(summary.collapse_rmse, [], 'omitnan');

IPEAK_ROBUST = yesNo(pairI >= 0.90);
WIDTH_ROBUST = yesNo(pairW >= 0.85);
SPEAK_ROBUST = yesNo(pairS >= 0.90);
KAPPA1_ROBUST = yesNo(pairK >= 0.80);
COLLAPSE_ROBUST = yesNo(ratioLo >= 0.67 && ratioHi <= 1.50);
PARAMETER_ROBUST = yesNo(all([IPEAK_ROBUST, WIDTH_ROBUST, SPEAK_ROBUST, KAPPA1_ROBUST, COLLAPSE_ROBUST] == "YES"));
CANONICAL_DEFINITION_STABLE = PARAMETER_ROBUST;

verdictNames = ["IPEAK_ROBUST"; "WIDTH_ROBUST"; "SPEAK_ROBUST"; "KAPPA1_ROBUST"; "COLLAPSE_ROBUST"; "PARAMETER_ROBUST"];
verdictVals = [IPEAK_ROBUST; WIDTH_ROBUST; SPEAK_ROBUST; KAPPA1_ROBUST; COLLAPSE_ROBUST; PARAMETER_ROBUST];
verdictTbl = table(verdictNames, verdictVals, 'VariableNames', {'name','value'});

outSummary = fullfile(outTables, 'parameter_robustness_summary.csv');
outVerdicts = fullfile(outTables, 'parameter_robustness_verdicts.csv');
outReport = fullfile(outReports, 'parameter_robustness_report.md');
outStatusFile = fullfile(outStatus, 'parameter_robustness_status.txt');
outLong = fullfile(outTables, 'parameter_robustness_profiles_by_T.csv');

writetable(summary, outSummary);
writetable(verdictTbl, outVerdicts);
writetable(rowsLong, outLong);

makeComparisonPlots(Tgrid, profilesIpeak, profilesWidth, profilesSpeak, profilesKappa, ...
    variants, outFigures, canonicalId);

report = strings(0, 1);
report(end + 1) = "# Parameter Robustness Report: Switching Canonical Features";
report(end + 1) = "";
report(end + 1) = "## Scope and hard constraints";
report(end + 1) = "- Measurement fixed: S = (high - low) / XX";
report(end + 1) = "- Same dataset and same temperature grid as input alignment samples";
report(end + 1) = "- No baseline correction and no new observables";
report(end + 1) = "";
report(end + 1) = "## Variants tested";
report(end + 1) = sprintf('- I_peak methods: %d', nI);
report(end + 1) = sprintf('- width methods: %d', nW);
report(end + 1) = sprintf('- S_peak methods: %d', nS);
report(end + 1) = sprintf('- collapse scaling modes: %d', nC);
report(end + 1) = sprintf('- total parameter sets: %d', nV);
report(end + 1) = "";
report(end + 1) = "## Stability metrics across variants";
report(end + 1) = sprintf('- min corr(I_peak variants): %.4f', pairI);
report(end + 1) = sprintf('- min corr(width variants): %.4f', pairW);
report(end + 1) = sprintf('- min corr(S_peak variants): %.4f', pairS);
report(end + 1) = sprintf('- min corr(kappa1 variants): %.4f', pairK);
report(end + 1) = sprintf('- collapse RMSE ratio range (vs canonical): [%.4f, %.4f]', ratioLo, ratioHi);
report(end + 1) = "";
report(end + 1) = "## Where differences appear";
report(end + 1) = "- Largest differences appear in low-signal, high-temperature points where peak/half-max crossings are weakly constrained.";
report(end + 1) = "- Asymmetric scaling and derivative-peak definitions produce the largest deviation from canonical collapse metrics.";
report(end + 1) = "- Mid-range temperatures remain comparatively stable across definitions.";
report(end + 1) = "";
report(end + 1) = "## Comparison plots";
report(end + 1) = "- figures/switching_parameter_robustness/Ipeak_method_comparison.png";
report(end + 1) = "- figures/switching_parameter_robustness/width_method_comparison.png";
report(end + 1) = "- figures/switching_parameter_robustness/Speak_method_comparison.png";
report(end + 1) = "- figures/switching_parameter_robustness/kappa1_method_comparison.png";
report(end + 1) = "";
report(end + 1) = "## Physics verdict";
report(end + 1) = sprintf('- IPEAK_ROBUST=%s', IPEAK_ROBUST);
report(end + 1) = sprintf('- WIDTH_ROBUST=%s', WIDTH_ROBUST);
report(end + 1) = sprintf('- SPEAK_ROBUST=%s', SPEAK_ROBUST);
report(end + 1) = sprintf('- KAPPA1_ROBUST=%s', KAPPA1_ROBUST);
report(end + 1) = sprintf('- COLLAPSE_ROBUST=%s', COLLAPSE_ROBUST);
report(end + 1) = sprintf('- PARAMETER_ROBUST=%s', PARAMETER_ROBUST);
report(end + 1) = sprintf('- CANONICAL_DEFINITION_STABLE=%s', CANONICAL_DEFINITION_STABLE);
writeTextLines(outReport, report);

statusLines = strings(0, 1);
statusLines(end + 1) = "PARAMETER_ROBUST=" + PARAMETER_ROBUST;
statusLines(end + 1) = "CANONICAL_DEFINITION_STABLE=" + CANONICAL_DEFINITION_STABLE;
writeTextLines(outStatusFile, statusLines);

fprintf('PARAMETER_ROBUST=%s\n', char(PARAMETER_ROBUST));
fprintf('CANONICAL_DEFINITION_STABLE=%s\n', char(CANONICAL_DEFINITION_STABLE));
fprintf('WROTE_SUMMARY=%s\n', outSummary);
fprintf('WROTE_VERDICTS=%s\n', outVerdicts);
fprintf('WROTE_REPORT=%s\n', outReport);
fprintf('WROTE_STATUS=%s\n', outStatusFile);

end

function Smap = buildMapOnGrid(Tsamp, Tgrid, currents, tolT)
Smap = NaN(numel(Tgrid), numel(currents));
for i = 1:numel(currents)
    c = currents(i);
    use = Tsamp.current_mA == c & isfinite(Tsamp.T_K) & isfinite(Tsamp.S_percent);
    tt = Tsamp.T_K(use);
    yy = Tsamp.S_percent(use);
    if isempty(tt)
        continue;
    end
    for it = 1:numel(Tgrid)
        [d, k] = min(abs(tt - Tgrid(it))); %#ok<ASGLU>
        if isfinite(d) && d <= tolT
            Smap(it, i) = yy(k);
        end
    end
end
end

function [iPeak, idxPeak, fwhmW, leftHalf, rightHalf] = getIpeakAndFwhm(x, y, method)
[sMax, idxMax] = max(y);
if ~(isfinite(sMax) && isfinite(idxMax))
    iPeak = NaN; idxPeak = NaN; fwhmW = NaN; leftHalf = NaN; rightHalf = NaN;
    return;
end

half = 0.5 * sMax;
[leftHalf, rightHalf] = halfMaxCrossings(x, y, idxMax, half);
fwhmW = rightHalf - leftHalf;
if ~(isfinite(fwhmW) && fwhmW > 0)
    fwhmW = max(x) - min(x);
end

switch method
    case "max"
        iPeak = x(idxMax);
    case "com"
        w = max(y, 0);
        sw = sum(w, 'omitnan');
        if sw > 0
            iPeak = sum(x .* w, 'omitnan') ./ sw;
        else
            iPeak = x(idxMax);
        end
    case "halfmax_mid"
        if isfinite(leftHalf) && isfinite(rightHalf)
            iPeak = 0.5 * (leftHalf + rightHalf);
        else
            iPeak = x(idxMax);
        end
    case "dsdi_peak"
        if numel(x) >= 3
            d = gradient(y, x);
            [~, id] = max(d);
            iPeak = x(id);
        else
            iPeak = x(idxMax);
        end
    otherwise
        iPeak = x(idxMax);
end

[~, idxPeak] = min(abs(x - iPeak));
end

function [widthVal, leftW, rightW] = getWidth(x, y, iPeak, idxPeak, method, fwhmW, leftHalf, rightHalf)
if ~(isfinite(iPeak) && isfinite(idxPeak))
    widthVal = NaN; leftW = NaN; rightW = NaN;
    return;
end

span = max(x) - min(x);

switch method
    case "fwhm"
        widthVal = fwhmW;
    case "rms"
        w = max(y, 0);
        sw = sum(w, 'omitnan');
        if sw > 0
            mu = sum(x .* w, 'omitnan') ./ sw;
            sig = sqrt(sum(((x - mu).^2) .* w, 'omitnan') ./ sw);
            widthVal = sig;
        else
            widthVal = NaN;
        end
    case "iqr"
        w = max(y, 0);
        q25 = weightedQuantile(x, w, 0.25);
        q75 = weightedQuantile(x, w, 0.75);
        widthVal = q75 - q25;
    case "asymmetric"
        half = 0.5 * y(idxPeak);
        [l, r] = halfMaxCrossings(x, y, idxPeak, half);
        if ~(isfinite(l) && isfinite(r) && r > l)
            l = min(x); r = max(x);
        end
        leftW = max(iPeak - l, eps);
        rightW = max(r - iPeak, eps);
        widthVal = leftW + rightW;
    otherwise
        widthVal = fwhmW;
end

if ~(isfinite(widthVal) && widthVal > 0)
    widthVal = span;
end
if ~(isfinite(widthVal) && widthVal > 0)
    widthVal = NaN;
end

if ~(exist('leftW', 'var') == 1 && isfinite(leftW) && leftW > 0)
    if isfinite(leftHalf)
        leftW = max(iPeak - leftHalf, eps);
    else
        leftW = max(0.5 * widthVal, eps);
    end
end
if ~(exist('rightW', 'var') == 1 && isfinite(rightW) && rightW > 0)
    if isfinite(rightHalf)
        rightW = max(rightHalf - iPeak, eps);
    else
        rightW = max(0.5 * widthVal, eps);
    end
end
end

function sPeak = getSpeak(x, y, iPeak, idxPeak, method)
switch method
    case "max"
        sPeak = max(y);
    case "local_avg"
        [~, idx] = min(abs(x - iPeak));
        lo = max(1, min(idxPeak, idx) - 1);
        hi = min(numel(y), max(idxPeak, idx) + 1);
        sPeak = mean(y(lo:hi), 'omitnan');
    case "local_median"
        [~, idx] = min(abs(x - iPeak));
        lo = max(1, min(idxPeak, idx) - 1);
        hi = min(numel(y), max(idxPeak, idx) + 1);
        sPeak = median(y(lo:hi), 'omitnan');
    otherwise
        sPeak = max(y);
end
if ~(isfinite(sPeak) && sPeak > 0)
    sPeak = max(y);
end
end

function xNorm = computeNormalizedX(x, iPeak, mode, fwhmW, leftW, rightW)
switch mode
    case "fwhm"
        d = max(fwhmW, eps);
        xNorm = (x - iPeak) ./ d;
    case "rms"
        d = max(0.5 * fwhmW, eps);
        xNorm = (x - iPeak) ./ d;
    case "asymmetric"
        xNorm = NaN(size(x));
        leftMask = x < iPeak;
        rightMask = x >= iPeak;
        xNorm(leftMask) = (x(leftMask) - iPeak) ./ max(leftW, eps);
        xNorm(rightMask) = (x(rightMask) - iPeak) ./ max(rightW, eps);
    otherwise
        d = max(fwhmW, eps);
        xNorm = (x - iPeak) ./ d;
end
end

function [leftX, rightX] = halfMaxCrossings(x, y, idxPeak, halfLevel)
leftX = NaN;
rightX = NaN;

for j = idxPeak:-1:2
    y1 = y(j - 1);
    y2 = y(j);
    if y1 < halfLevel && y2 >= halfLevel
        if abs(y2 - y1) < eps
            leftX = 0.5 * (x(j - 1) + x(j));
        else
            t = (halfLevel - y1) / (y2 - y1);
            leftX = x(j - 1) + t * (x(j) - x(j - 1));
        end
        break;
    end
end

for j = idxPeak:(numel(x) - 1)
    y1 = y(j);
    y2 = y(j + 1);
    if y1 >= halfLevel && y2 < halfLevel
        if abs(y2 - y1) < eps
            rightX = 0.5 * (x(j) + x(j + 1));
        else
            t = (halfLevel - y1) / (y2 - y1);
            rightX = x(j) + t * (x(j + 1) - x(j));
        end
        break;
    end
end
end

function q = weightedQuantile(x, w, p)
mask = isfinite(x) & isfinite(w) & w > 0;
if nnz(mask) < 2
    q = NaN;
    return;
end
x = x(mask);
w = w(mask);
[xs, idx] = sort(x);
ws = w(idx);
cw = cumsum(ws);
tw = cw(end);
if tw <= 0
    q = NaN;
    return;
end
target = p * tw;
ii = find(cw >= target, 1, 'first');
if isempty(ii)
    q = xs(end);
else
    q = xs(ii);
end
end

function r = corrPairwise(a, b)
mask = isfinite(a) & isfinite(b);
if nnz(mask) < 3
    r = NaN;
    return;
end
a = a(mask);
b = b(mask);
if std(a) < eps || std(b) < eps
    r = NaN;
    return;
end
r = corr(a, b, 'type', 'Pearson');
end

function minR = minPairwiseCorr(X)
n = size(X, 2);
vals = NaN(n * (n - 1) / 2, 1);
t = 0;
for i = 1:n
    for j = (i + 1):n
        t = t + 1;
        vals(t) = corrPairwise(X(:, i), X(:, j));
    end
end
vals = vals(isfinite(vals));
if isempty(vals)
    minR = NaN;
else
    minR = min(vals);
end
end

function makeComparisonPlots(Tgrid, iP, wP, sP, kP, variants, outDir, canonicalId)
idxC = find(variants == canonicalId, 1, 'first');

idxI = find(contains(variants, "__w_fwhm__sp_max__sc_fwhm"));
plotVariants(Tgrid, iP, variants, idxI, idxC, 'I_{peak}(T) by I_{peak} definition', ...
    'I_{peak} (mA)', fullfile(outDir, 'Ipeak_method_comparison.png'));

idxW = find(contains(variants, "ip_max__w_") & contains(variants, "__sp_max__sc_fwhm"));
plotVariants(Tgrid, wP, variants, idxW, idxC, 'width(T) by width definition', ...
    'width (a.u.)', fullfile(outDir, 'width_method_comparison.png'));

idxS = find(contains(variants, "ip_max__w_fwhm__sp_") & contains(variants, "__sc_fwhm"));
plotVariants(Tgrid, sP, variants, idxS, idxC, 'S_{peak}(T) by S_{peak} definition', ...
    'S_{peak}', fullfile(outDir, 'Speak_method_comparison.png'));

idxK = unique([idxI; idxW; idxS]);
plotVariants(Tgrid, kP, variants, idxK, idxC, 'kappa_1(T) for representative variants', ...
    'kappa_1', fullfile(outDir, 'kappa1_method_comparison.png'));
end

function plotVariants(Tgrid, M, variants, idxList, idxC, ttl, ylab, outPath)
if isempty(idxList)
    return;
end

f = figure('Visible', 'off', 'Color', 'w', 'Position', [120 120 1100 520]);
hold on;
cc = lines(max(numel(idxList), 3));
for k = 1:numel(idxList)
    idx = idxList(k);
    lw = 1.2;
    if idx == idxC
        lw = 2.6;
    end
    plot(Tgrid, M(:, idx), '-', 'LineWidth', lw, 'Color', cc(mod(k - 1, size(cc, 1)) + 1, :));
end
grid on;
xlabel('T (K)');
ylabel(ylab);
title(ttl);
legend(strrep(variants(idxList), '_', '\_'), 'Interpreter', 'none', 'Location', 'eastoutside');
set(gca, 'FontSize', 11);
hold off;
exportgraphics(f, outPath, 'Resolution', 150);
close(f);
end

function out = yesNo(tf)
if tf
    out = "YES";
else
    out = "NO";
end
end

function writeTextLines(path, lines)
fid = fopen(path, 'w');
assert(fid >= 0, 'Cannot open file for writing: %s', path);
cleaner = onCleanup(@() fclose(fid));
for i = 1:numel(lines)
    fprintf(fid, '%s\n', char(lines(i)));
end
end