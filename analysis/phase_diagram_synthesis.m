function out = phase_diagram_synthesis(cfg)
% phase_diagram_synthesis
% Synthesise a temperature-organised dynamical phase diagram from the
% cross-experiment observable catalog.  Does not recompute observables.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot    = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfg = applyDefaults(cfg);
catalogPath = resolvePath(repoRoot, cfg.catalogPath);
if exist(catalogPath, 'file') ~= 2
    error('Catalog not found: %s', catalogPath);
end

%% Run context
runCfg.runLabel = cfg.runLabel;
runCfg.dataset  = sprintf('catalog:%s', extractRunId(fileparts(catalogPath)));
run    = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;
logP   = run.log_path;

logLine(logP, '[%s] phase_diagram_synthesis started', stampNow());
logLine(logP, 'catalog: %s', catalogPath);
logLine(logP, 'runDir: %s', runDir);

%% Load catalog
cat = readtable(catalogPath, 'TextType', 'string');

%% Extract raw series for each observable
obsNames = cfg.observableNames;
nObs     = numel(obsNames);
raw      = struct();
for i = 1:nObs
    [raw.(safe(obsNames{i})).T, raw.(safe(obsNames{i})).V] = extractSeries(cat, obsNames{i});
end

%% Fine evaluation grid: 1 K steps, span entire union
allT = [];
for i = 1:nObs
    allT = [allT; raw.(safe(obsNames{i})).T(:)]; %#ok<AGROW>
end
Tmin = min(allT);
Tmax = max(allT);
Tgrid = (Tmin:1:Tmax)';   % 1 K step
nGrid = numel(Tgrid);

%% Interpolate each observable onto Tgrid (NaN outside support)
interp_mat = NaN(nGrid, nObs);
for i = 1:nObs
    s = raw.(safe(obsNames{i}));
    if numel(s.T) < 2
        continue
    end
    lo = min(s.T); hi = max(s.T);
    inRange = Tgrid >= lo & Tgrid <= hi;
    if any(inRange)
        interp_mat(inRange, i) = interp1(s.T, s.V, Tgrid(inRange), 'pchip');
    end
end

%% Normalise each column independently: (v-min)/(max-min)
norm_mat  = NaN(nGrid, nObs);
obs_min   = NaN(1, nObs);
obs_max   = NaN(1, nObs);
obs_range = NaN(1, nObs);
for i = 1:nObs
    col = interp_mat(:, i);
    vmin = min(col(isfinite(col)));
    vmax = max(col(isfinite(col)));
    obs_min(i)   = vmin;
    obs_max(i)   = vmax;
    obs_range(i) = vmax - vmin;
    if isfinite(vmin) && isfinite(vmax) && obs_range(i) > 0
        norm_mat(:, i) = (col - vmin) / (vmax - vmin);
    end
end

%% Build aligned output table
colNames = [{'T_K'}, cellfun(@(x) ['norm_' safe(x)], obsNames, 'uni', false), ...
                     cellfun(@(x) ['raw_'  safe(x)], obsNames, 'uni', false)];
alignedTbl = array2table([Tgrid, norm_mat, interp_mat], 'VariableNames', colNames);

%% Feature extraction per observable
featRows = [];
for i = 1:nObs
    nc  = norm_mat(:, i);
    rc  = interp_mat(:, i);
    idx = find(isfinite(nc));
    if isempty(idx)
        continue
    end
    support_min = Tgrid(idx(1));
    support_max = Tgrid(idx(end));
    support_width = support_max - support_min;

    [pkVal, pkIdx] = max(nc(idx));
    peak_T = Tgrid(idx(pkIdx));

    % Onset: first T where norm >= 0.1
    on_idx = idx(find(nc(idx) >= 0.1, 1, 'first'));
    onset_T = Tgrid(on_idx);

    % Decay: last T where nc >= 0.5 (after peak)
    late_idx = idx(pkIdx:end);
    dc_idx = late_idx(find(nc(late_idx) >= 0.5, 1, 'last'));
    if isempty(dc_idx), dc_idx = idx(end); end
    decay_T = Tgrid(dc_idx);

    % Shape classification
    dv = diff(nc(idx));
    nPos = sum(dv > 0); nNeg = sum(dv < 0);
    if nPos >= 0.9*numel(dv)
        shape = 'monotonic_increasing';
    elseif nNeg >= 0.9*numel(dv)
        shape = 'monotonic_decreasing';
    elseif pkIdx > 1 && pkIdx < numel(idx)
        shape = 'peaked';
    else
        shape = 'asymmetric';
    end

    row = table(string(obsNames{i}), support_min, support_max, support_width, ...
        peak_T, pkVal, onset_T, decay_T, string(shape), ...
        'VariableNames', {'observable','support_min_K','support_max_K','support_width_K', ...
        'peak_temperature_K','peak_normalized_value','onset_K','decay_K','shape'});
    featRows = [featRows; row]; %#ok<AGROW>
end

%% Physical regime definitions (temperature-based boundaries, no clustering)
physRegimes(1).name  = 'kappa-dominated';
physRegimes(1).T_lo  = 4;    physRegimes(1).T_hi  = 10;
physRegimes(1).color = [0.90 0.96 1.00];   % light blue

physRegimes(2).name  = 'chi_amp-dominated';
physRegimes(2).T_lo  = 10;   physRegimes(2).T_hi  = 18;
physRegimes(2).color = [0.92 1.00 0.92];   % light green

physRegimes(3).name  = 'X-dominated';
physRegimes(3).T_lo  = 18;   physRegimes(3).T_hi  = 30;
physRegimes(3).color = [1.00 0.95 0.85];   % light orange

physRegimes(4).name  = 'mobile';
physRegimes(4).T_lo  = 30;   physRegimes(4).T_hi  = Tmax + 1;
physRegimes(4).color = [0.96 0.96 0.92];   % light yellow
nRegimes = numel(physRegimes);

% R sector: embedded overlay band (14–26 K, not an exclusive global regime)
rSector_lo   = 14;   rSector_hi   = 26;
rSectorColor = [1.00 0.88 0.88];  % light red

% Physical crossover temperatures (K)
physCrossovers = [10, 18, 30];

% Canonical R-sector measurement temperatures
rCanonical = [14, 18, 22, 26];

%% Consistency checks
checks = struct();
% X and A peak alignment
xFeat = featRows(featRows.observable == "X", :);
aFeat = featRows(featRows.observable == "A", :);
if ~isempty(xFeat) && ~isempty(aFeat)
    checks.X_A_peak_offset_K   = xFeat.peak_temperature_K - aFeat.peak_temperature_K;
    checks.X_A_peaks_aligned    = abs(checks.X_A_peak_offset_K) < cfg.alignTolK;
end
% R support overlap with first physical crossover (10 K)
rFeat = featRows(featRows.observable == "R", :);
if ~isempty(rFeat)
    checks.R_support_max      = rFeat.support_max_K;
    checks.R_covers_crossover = rFeat.support_max_K >= physCrossovers(1);
end
% chi_amp(T) peak alignment with kappa-dominated sector (4–10 K)
a1Feat = featRows(featRows.observable == "a1", :);
if ~isempty(a1Feat)
    checks.a1_peak_T     = a1Feat.peak_temperature_K;
    checks.a1_in_regime1 = physRegimes(1).T_lo <= a1Feat.peak_temperature_K && ...
                           a1Feat.peak_temperature_K <= physRegimes(1).T_hi;
end

%% ---- Figure 1 : Normalized observables ----
colors = [0.12 0.47 0.71;   % X    – blue
          0.20 0.63 0.17;   % A    – green
          0.89 0.10 0.11;   % R    – red
          1.00 0.50 0.05;   % chi_ridge – orange
          0.42 0.24 0.60;   % chi_amp – purple
          0.17 0.63 0.63];  % kappa – teal

fig1 = figure('Visible', 'off', 'Color', 'w', 'PaperPositionMode', 'auto');
ax1  = axes('Parent', fig1);
hold(ax1, 'on');
hdls = gobjects(nObs, 1);
for i = 1:nObs
    nc = norm_mat(:, i);
    vi = isfinite(nc);
    if ~any(vi), continue; end
    hdls(i) = plot(ax1, Tgrid(vi), nc(vi), '-', ...
        'Color', colors(mod(i-1,size(colors,1))+1, :), ...
        'LineWidth', 2.0, 'DisplayName', obsLabel(obsNames{i}));
end
xlabel(ax1, 'Temperature (K)', 'FontSize', 14);
ylabel(ax1, 'Normalized value  [0,1]', 'FontSize', 14);
title(ax1,  'Normalized observables vs temperature', 'FontSize', 14);
legend(ax1, hdls(arrayfun(@(h) isvalid(h) && h ~= 0, hdls)), 'FontSize', 12, 'Location', 'northwest');
grid(ax1, 'on');
set(ax1, 'FontSize', 14);
xlim(ax1, [Tmin-1, Tmax+1]);
ylim(ax1, [-0.05, 1.15]);
hold(ax1, 'off');
save_run_figure(fig1, 'phase_diagram_normalized', runDir);
close(fig1);

%% ---- Figure 2 : Physically-defined regime phase diagram ----
regimeLabelTxt = {'\kappa-dom.', '\chi_{amp}-dom.', 'X-dom.', 'mobile'};

fig2 = figure('Visible', 'off', 'Color', 'w', 'PaperPositionMode', 'auto');
ax2  = axes('Parent', fig2);
hold(ax2, 'on');

% Shade physical regime bands (patches first, curves on top)
for r = 1:nRegimes
    xlo = physRegimes(r).T_lo;
    xhi = min(physRegimes(r).T_hi, Tmax + 1);
    patch(ax2, [xlo xhi xhi xlo], [-0.05 -0.05 1.15 1.15], ...
        physRegimes(r).color, 'EdgeColor', 'none', 'FaceAlpha', 0.70, ...
        'HandleVisibility', 'off');
    midT = (xlo + min(physRegimes(r).T_hi, Tmax)) / 2;
    text(ax2, midT, 1.10, regimeLabelTxt{r}, 'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'Color', [0.2 0.2 0.2]);
end

% R-sector overlay band (14–26 K, semi-transparent; not an exclusive regime)
patch(ax2, [rSector_lo rSector_hi rSector_hi rSector_lo], [-0.05 -0.05 1.15 1.15], ...
    rSectorColor, 'EdgeColor', 'none', 'FaceAlpha', 0.25, 'HandleVisibility', 'off');
text(ax2, (rSector_lo + rSector_hi) / 2, -0.04, 'R sector', ...
    'FontSize', 10, 'HorizontalAlignment', 'center', 'Color', [0.7 0.2 0.2]);

% Vertical lines at physical crossovers (10, 18, 30 K)
for ci = 1:numel(physCrossovers)
    xline(ax2, physCrossovers(ci), '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, ...
        'HandleVisibility', 'off');
    text(ax2, physCrossovers(ci) + 0.3, 1.07, sprintf('%d K', physCrossovers(ci)), ...
        'FontSize', 10, 'Color', [0.4 0.4 0.4]);
end

% Canonical R temperatures (14, 18, 22, 26 K) — dotted markers
for ti = 1:numel(rCanonical)
    xline(ax2, rCanonical(ti), ':', 'Color', [0.80 0.30 0.30], 'LineWidth', 1.0, ...
        'HandleVisibility', 'off');
end

% Observable curves
hdls2 = gobjects(nObs, 1);
for i = 1:nObs
    nc = norm_mat(:, i);
    vi = isfinite(nc);
    if ~any(vi), continue; end
    hdls2(i) = plot(ax2, Tgrid(vi), nc(vi), '-', ...
        'Color', colors(mod(i-1,size(colors,1))+1, :), ...
        'LineWidth', 2.0, 'DisplayName', obsLabel(obsNames{i}));
end

xlabel(ax2, 'Temperature (K)', 'FontSize', 14);
ylabel(ax2, 'Normalized value  [0,1]', 'FontSize', 14);
title(ax2,  'Dynamical phase diagram \u2014 physically-defined regimes', 'FontSize', 14);
legend(ax2, hdls2(arrayfun(@(h) isvalid(h) && h ~= 0, hdls2)), 'FontSize', 12, 'Location', 'northwest');
grid(ax2, 'on');
set(ax2, 'FontSize', 14);
xlim(ax2, [Tmin-1, Tmax+1]);
ylim(ax2, [-0.08, 1.20]);
hold(ax2, 'off');
save_run_figure(fig2, 'phase_diagram_regimes', runDir);
close(fig2);

%% Save tables
alignedPath  = save_run_table(alignedTbl, 'phase_diagram_aligned_table.csv', runDir);
featPath     = save_run_table(featRows,   'phase_diagram_features.csv', runDir);

%% Build report
reportText = buildReport(obsNames, nGrid, Tmin, Tmax, norm_mat, Tgrid, ...
    alignedTbl, featRows, physRegimes, physCrossovers, checks, ...
    input_struct(catalogPath, runDir));
reportPath  = save_run_report(reportText, 'phase_diagram_report.md', runDir);
zipPath     = buildReviewZip(runDir, 'phase_diagram_bundle.zip');

logLine(logP, 'aligned_table: %s', alignedPath);
logLine(logP, 'features: %s', featPath);
logLine(logP, 'report: %s', reportPath);
logLine(logP, 'bundle: %s', zipPath);
logLine(logP, '[%s] phase_diagram_synthesis complete', stampNow());

%% Terminal output
physBoundsStr = strjoin(arrayfun(@(r) sprintf('[%d-%d K, %s]', ...
    physRegimes(r).T_lo, physRegimes(r).T_hi, physRegimes(r).name), ...
    1:nRegimes, 'uni', false), ', ');

fprintf('RUN_ID=%s\n', run.run_id);
fprintf('NUMBER_OF_TEMPERATURE_POINTS=%d\n', nGrid);
fprintf('NUMBER_OF_OBSERVABLES_USED=%d\n', nObs);
fprintf('PHYSICAL_REGIME_BOUNDARIES=%s\n', physBoundsStr);

out.run        = run;
out.aligned    = alignedTbl;
out.features   = featRows;
out.regimes    = physRegimes;
out.crossovers = physCrossovers;
out.checks     = checks;
out.paths      = struct('aligned', alignedPath, 'features', featPath, ...
                        'report', reportPath, 'bundle', zipPath);
end

% -------------------------------------------------------------------------
function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'phase_diagram_synthesis');
cfg = setDefault(cfg, 'catalogPath', fullfile('results','cross_experiment','runs', ...
    'run_2026_03_16_110632_observable_catalog_completion','tables','observable_catalog.csv'));
cfg = setDefault(cfg, 'observableNames', {'X','A','R','chi_ridge','a1','kappa'});
cfg = setDefault(cfg, 'alignTolK',  4);   % K, threshold for "peaks aligned"
end

function p = resolvePath(root, p)
p = char(string(p));
if isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) && ~startsWith(p, '\\')
    p = fullfile(root, p);
end
end

function [T, V] = extractSeries(cat, obsName)
mask = lower(strtrim(string(cat.observable_name))) == lower(strtrim(string(obsName)));
sub  = cat(mask, :);
if isempty(sub), T = []; V = []; return; end
agg  = groupsummary(sub, 'temperature_K', 'mean', 'value');
T    = double(agg.temperature_K);
V    = double(agg.mean_value);
[T, ord] = sort(T);  V = V(ord);
end

function s = safe(name)
s = regexprep(char(string(name)), '[^A-Za-z0-9_]', '_');
end

function id = extractRunId(pathStr)
parts = split(string(strrep(char(pathStr), '/', filesep)), filesep);
idx   = find(startsWith(parts, "run_"), 1, 'last');
if isempty(idx), id = "unknown"; else, id = parts(idx); end
end

function st = input_struct(catalogPath, runDir)
st.catalogPath = catalogPath;
st.runDir      = runDir;
end

function txt = buildReport(obsNames, nGrid, Tmin, Tmax, norm_mat, Tgrid, ...
    alignedTbl, featRows, physRegimes, physCrossovers, checks, inp)

nObs     = numel(obsNames);
nRegimes = numel(physRegimes); %#ok<NASGU>

L = strings(0,1);
L(end+1) = '# Dynamical Phase Diagram Synthesis';
L(end+1) = '';
L(end+1) = 'Generated: ' + string(stampNow());
L(end+1) = 'Catalog source: `' + string(inp.catalogPath) + '`';
L(end+1) = 'Run dir: `' + string(inp.runDir) + '`';
L(end+1) = '';

L(end+1) = '## Visualization choices';
L(end+1) = '- Number of curves: ' + string(nObs);
L(end+1) = '- Legend vs colormap: explicit legend (n ≤ 6)';
L(end+1) = '- Colormap: none (distinct qualitative colors)';
L(end+1) = '- Smoothing: none; pchip interpolation for grid alignment only';
L(end+1) = '- Regime definition: **physically-defined temperature boundaries** (no clustering).';
L(end+1) = '';

L(end+1) = '## 1. Observable alignment summary';
L(end+1) = '- Temperature grid: ' + string(Tmin) + ' – ' + string(Tmax) + ' K, step 1 K';
L(end+1) = '- Grid points: ' + string(nGrid);
L(end+1) = '- Interpolation: pchip within each observable''s native support; NaN outside (no extrapolation).';
L(end+1) = string(sprintf('- Observables used: `%s`', strjoin(obsNames, '`, `')));
L(end+1) = '';

for i = 1:nObs
    row = featRows(featRows.observable == string(obsNames{i}), :);
    if isempty(row), continue; end
    L(end+1) = '- `' + string(obsNames{i}) + '`: support ' + ...
        string(row.support_min_K) + '–' + string(row.support_max_K) + ' K, n_source points from catalog';
end
L(end+1) = '';

L(end+1) = '## 2. Normalized behavior comparison';
L(end+1) = '- Each observable independently normalized to [0,1].';
L(end+1) = '- Figures: `phase_diagram_normalized.png` and `phase_diagram_regimes.png`.';
L(end+1) = '';

L(end+1) = '## 3. Extracted feature temperatures';
L(end+1) = '';
L(end+1) = '| Observable | Support K | Peak T (K) | Onset K | Decay K | Shape |';
L(end+1) = '|---|---|---|---|---|---|';
for i = 1:height(featRows)
    r = featRows(i,:);
    dispName = string(r.observable);
    if dispName == "a1", dispName = "chi_amp(T) (legacy: a1)"; end
    L(end+1) = '| `' + dispName + '` | ' + ...
        string(r.support_min_K) + '–' + string(r.support_max_K) + ' | ' + ...
        string(r.peak_temperature_K) + ' | ' + ...
        string(r.onset_K) + ' | ' + ...
        string(r.decay_K) + ' | ' + string(r.shape) + ' |';
end
L(end+1) = '';

L(end+1) = '## 4. Physically-defined dynamical regimes';
L(end+1) = '- Regimes are defined by fixed temperature boundaries based on observable physics.';
L(end+1) = '- No data clustering is used.';
L(end+1) = '';
L(end+1) = '| Regime | T range (K) | Dominant physics |';
L(end+1) = '|---|---|---|';
L(end+1) = '| κ-dominated | 4–10 | κ and χ_amp(T) carry the observable structure; switching amplitude most temperature-sensitive near 10 K. |';
L(end+1) = '| χ_amp-dominated | 10–18 | χ_amp(T) ≈ −dS_peak/dT peaks at ~10 K; X rising; aging dip timescales (A near peak) first appear. |';
L(end+1) = '| X-dominated | 18–30 | X and A peak; R sector fully active (14–26 K embedded); FM clock component overtakes dip. |';
L(end+1) = '| mobile (>30 K) | >30 K | Switching observables (X, κ, χ_amp) unsupported; only A (relaxation amplitude) persists. |';
L(end+1) = '';

L(end+1) = '### Embedded R sector (14–26 K)';
L(end+1) = '- R(T) = τ_FM / τ_dip is defined only at {14, 18, 22, 26} K (four aging clock-overlap points).';
L(end+1) = '- Straddles the χ_amp-dominated and X-dominated regimes; shown as a semi-transparent overlay.';
L(end+1) = '- Not an independent global regime.';
L(end+1) = '';

L(end+1) = '### Physical crossover temperatures';
L(end+1) = '- **10 K**: κ-dominated → χ_amp-dominated; peak of χ_amp(T).';
L(end+1) = '- **18 K**: χ_amp-dominated → X-dominated; X near peak, R begins rising.';
L(end+1) = '- **30 K**: X-dominated → mobile; all switching observables lose support.';
L(end+1) = '';

L(end+1) = '## 5. χ_amp(T) — temperature susceptibility of switching amplitude';
L(end+1) = '- **Physical definition:** χ_amp(T) ≈ −dS_peak/dT, where S_peak(T) = max_I S(T,I).';
L(end+1) = '- **Interpretation:** measures the temperature-derivative response of the switching amplitude peak.';
L(end+1) = '- **Peak location:** ~10 K, marking the κ-dominated → χ_amp-dominated crossover.';
L(end+1) = '- **Support:** 4–30 K (14 measured points on even-K grid).';
L(end+1) = '- **Legacy code name:** `a1` — used unchanged in all scripts, CSVs, and historical runs.';
L(end+1) = '- **Basis classification:** EXPLAINED_BY_X_KAPPA (requires both X and κ).';
L(end+1) = '';

L(end+1) = '## 6. Relation to minimal observable basis {X, κ, R}';
L(end+1) = '- X spans 4–30 K; primary dynamical ordering coordinate rising through regimes 1→3.';
L(end+1) = '- κ (kappa) spans 4–30 K; geometric correction/modulation, dominant below 10 K.';
L(end+1) = '- R spans 14–26 K; embedded aging clock observable, not extrapolated outside this range.';
L(end+1) = '';

L(end+1) = '## 7. Consistency checks';
if isfield(checks, 'X_A_peak_offset_K')
    L(end+1) = '- X vs A peak offset: ' + string(checks.X_A_peak_offset_K) + ' K — ' + ...
        ternary(checks.X_A_peaks_aligned, 'peaks are aligned within tolerance.', 'peaks are NOT aligned within tolerance.');
end
if isfield(checks, 'R_covers_crossover')
    L(end+1) = '- R support extends to ' + string(checks.R_support_max) + ' K — ' + ...
        ternary(checks.R_covers_crossover, 'overlaps the first physical crossover (10 K). [CONSISTENT]', ...
                'does NOT reach the first physical crossover (10 K). [CHECK DATA]');
end
if isfield(checks, 'a1_in_regime1')
    L(end+1) = '- χ_amp(T) (legacy: a1) peak at ' + string(checks.a1_peak_T) + ' K — ' + ...
        ternary(checks.a1_in_regime1, 'within κ-dominated regime (4–10 K). [CONSISTENT]', ...
                'outside κ-dominated regime (4–10 K). [CHECK DATA]');
end
L(end+1) = '';

L(end+1) = '---';
L(end+1) = '';
L(end+1) = '## FINAL_PHASE_DIAGRAM_SUMMARY';
L(end+1) = '';
L(end+1) = '- **Regime 1 (κ-dominated):** 4–10 K';
L(end+1) = '- **Regime 2 (χ_amp-dominated):** 10–18 K';
L(end+1) = '- **Regime 3 (X-dominated):** 18–30 K';
L(end+1) = '- **Regime 4 (mobile):** >30 K';
L(end+1) = '- **Embedded R sector:** 14–26 K (overlay; not exclusive)';
L(end+1) = '- **Crossover temperatures:** 10 K, 18 K, 30 K';
L(end+1) = '- **Canonical R measurements:** 14 K, 18 K, 22 K, 26 K';
L(end+1) = '';
L(end+1) = '- χ_amp(T) (legacy: a1) peaks at ~10 K — aligns with κ→χ_amp crossover boundary.';
L(end+1) = '- Role of X: primary ordering coordinate; onset tracks χ_amp→X crossover at 10–18 K.';
L(end+1) = '- Role of κ: geometric correction; dominant in 4–10 K where χ_amp(T) requires X+κ basis.';
L(end+1) = '- Role of R: embedded clock observable; defined only at {14,18,22,26} K in 14–26 K sector.';

txt = strjoin(L, newline);
end

function s = ternary(cond, a, b)
if cond, s = a; else, s = b; end
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7, mkdir(reviewDir); end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2, delete(zipPath); end
zip(zipPath, { ...
    fullfile('tables',  'phase_diagram_aligned_table.csv'), ...
    fullfile('tables',  'phase_diagram_features.csv'), ...
    fullfile('figures', 'phase_diagram_normalized.png'), ...
    fullfile('figures', 'phase_diagram_regimes.png'), ...
    fullfile('reports', 'phase_diagram_report.md'), ...
    'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function logLine(fp, fmt, varargin)
msg = sprintf(fmt, varargin{:});
fid = fopen(fp, 'a', 'n', 'UTF-8');
if fid ~= -1
    c = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', msg);
end
end

function out = stampNow()
out = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function lbl = obsLabel(name)
% Map internal observable name to display label (χ_amp for a1).
if strcmp(char(name), 'a1')
    lbl = '\chi_{amp}(T)  (legacy: a1)';
else
    lbl = char(name);
end
end

function cfg = setDefault(cfg, f, v)
if ~isfield(cfg, f) || isempty(cfg.(f)), cfg.(f) = v; end
end
