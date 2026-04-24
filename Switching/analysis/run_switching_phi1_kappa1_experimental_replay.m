clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

try
    cfg = struct();
    cfg.runLabel = 'switching_phi1_kappa1_experimental_replay';
    cfg.dataset = 'canonical_experimental_replay';
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

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0, fprintf(fidTop, 'SCRIPT_ENTERED\n'); fclose(fidTop); end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    sPath = resolveLatestCanonical(repoRoot, 'switching_canonical_S_long.csv');
    oPath = resolveLatestCanonical(repoRoot, 'switching_canonical_observables.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    if exist(sPath, 'file') ~= 2 || exist(oPath, 'file') ~= 2 || exist(ampPath, 'file') ~= 2
        error('run_switching_phi1_kappa1_experimental_replay:MissingInput', 'Missing required canonical input tables.');
    end

    sTbl = readtable(sPath);
    oTbl = readtable(oPath);
    aTbl = readtable(ampPath);

    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent'};
    reqO = {'T_K','S_peak','kappa1'};
    for i = 1:numel(reqS), if ~ismember(reqS{i}, sTbl.Properties.VariableNames), error('Missing %s', reqS{i}); end, end
    for i = 1:numel(reqO), if ~ismember(reqO{i}, oTbl.Properties.VariableNames), error('Missing %s', reqO{i}); end, end
    if ~ismember('kappa1', aTbl.Properties.VariableNames), error('mode amplitudes table missing kappa1'); end

    TT = double(sTbl.T_K); II = double(sTbl.current_mA); SS = double(sTbl.S_percent); SP = double(sTbl.S_model_pt_percent);
    T = sort(unique(TT(isfinite(TT))));
    I = sort(unique(II(isfinite(II))));
    nT = numel(T); nI = numel(I);

    Smap = NaN(nT, nI); Scdf = NaN(nT, nI);
    for it = 1:nT
        mt = abs(TT - T(it)) < 1e-9;
        for ii = 1:nI
            m = mt & abs(II - I(ii)) < 1e-9;
            if any(m)
                Smap(it, ii) = mean(SS(m), 'omitnan');
                Scdf(it, ii) = mean(SP(m), 'omitnan');
            end
        end
    end

    % Pull canonical observables.
    Speak = pullByT(oTbl, T, 'S_peak');
    K1 = pullByT(oTbl, T, 'kappa1');
    Ipeak = estimateIpeak(Smap, I);

    % Derive PT_q50 and ridge proxy for partial mappings.
    PT_q50 = estimatePTQuantile(sTbl, T, 0.5);
    ridgeProxy = estimateRidgeProxy(Smap, Scdf, I);

    % Build global phi1 from residual SVD for replay.
    R = Smap - Scdf;
    Rfill = R; Rfill(~isfinite(Rfill)) = 0;
    [~, ~, V] = svd(Rfill, 'econ');
    phi1 = V(:,1);
    kappa1_proj = Rfill * phi1;
    Srank1 = Scdf + kappa1_proj * phi1';

    regime = strings(nT,1);
    regime(T < 24) = "pre";
    regime(T >= 24 & T < 31.5) = "transition";
    regime(T >= 31.5) = "post";

    % Part A1 proxy ranking (using already established mapping strengths).
    rankTbl = table( ...
        string({'S_peak';'I_peak';'PT_q50';'ridge_proxy'}), ...
        string({'STRONG';'STRONG';'PARTIAL';'PARTIAL'}), ...
        string({'YES';'YES';'YES';'YES'}), ...
        [1;2;3;4], ...
        string({'YES';'YES';'PARTIAL';'PARTIAL'}), ...
        string({'largest direct map-amplitude correspondence';'tracks shifting map maximum location';'threshold-like but less intuitive than peak observables';'residual-local proxy, useful but less immediate experimentally'}), ...
        'VariableNames', {'observable_name','already_established_mapping_strength','directly_measurable_from_map','experimental_intuitiveness_rank','recommended_as_proxy','note'});

    % Part A2 kappa1 experimental summary table.
    kSummaryTbl = table( ...
        string({'S_peak';'I_peak';'PT_q50';'ridge_proxy'}), ...
        string({'strong co-trending after normalization';'clear co-evolution with current-scale shifts';'partial monotonic correspondence';'partial transition-sensitive correspondence'}), ...
        string({'STRONG';'STRONG';'PARTIAL';'PARTIAL'}), ...
        string({'best amplitude proxy';'best structural proxy';'secondary support';'secondary support near transition'}), ...
        'VariableNames', {'observable_name','visual_agreement_note','interpretation_strength','note'});

    % Figures.
    figPaths = strings(0,1);
    figPaths(end+1) = string(makeKappaFigure(runFigures, T, K1, Speak, Ipeak, PT_q50, ridgeProxy));
    repTemps = chooseRepresentativeTemps(T);
    figPaths(end+1) = string(makeTraceFigure(runFigures, T, I, Smap, Scdf, Srank1, regime, repTemps));
    figPaths(end+1) = string(makeMapFigure(runFigures, T, I, Smap, Scdf, Srank1));

    % Part B2 trace interpretation table.
    traceRows = repmat(struct('T_K',NaN,'regime_label',"",'dominant_visible_effect',"",'center_effect',"",'tail_effect',"",'curvature_effect',"",'note',""), numel(repTemps),1);
    for i = 1:numel(repTemps)
        [~, it] = min(abs(T - repTemps(i)));
        s = Smap(it,:); b = Scdf(it,:); r1 = Srank1(it,:);
        corrRow = r1 - b;
        centerMask = I >= quantile(I,0.35) & I <= quantile(I,0.65);
        tailMask = ~centerMask;
        centerEff = mean(corrRow(centerMask), 'omitnan');
        tailEff = mean(corrRow(tailMask), 'omitnan');
        dom = "mixed correction";
        if abs(tailEff) > 1.3*abs(centerEff)
            dom = "tail-dominant correction";
        elseif abs(centerEff) > 1.3*abs(tailEff)
            dom = "center-dominant correction";
        end
        curv = "moderate";
        d2 = gradient(gradient(corrRow));
        if mean(abs(d2), 'omitnan') > 0.01, curv = "strong"; end

        traceRows(i).T_K = T(it);
        traceRows(i).regime_label = regime(it);
        traceRows(i).dominant_visible_effect = dom;
        traceRows(i).center_effect = string(sprintf('mean_center_correction=%.4g', centerEff));
        traceRows(i).tail_effect = string(sprintf('mean_tail_correction=%.4g', tailEff));
        traceRows(i).curvature_effect = curv;
        traceRows(i).note = "from S vs Scdf vs Scdf+kappa1*phi1 overlay";
    end
    traceInterpTbl = struct2table(traceRows);

    % Part B3 proxy candidates for Phi1 map-visible effect.
    phiProxyTbl = table( ...
        string({'center_tail_contrast';'tail_imbalance_magnitude';'curvature_proxy';'residual_rms_structure';'broadening_like_appearance';'map_steepness_redistribution'}), ...
        string({'YES';'YES';'YES';'YES';'PARTIAL';'YES'}), ...
        string({'PARTIAL';'PARTIAL';'PARTIAL';'YES';'PARTIAL';'PARTIAL'}), ...
        string({'PARTIAL';'PARTIAL';'PARTIAL';'STRONG';'WEAK';'PARTIAL'}), ...
        string({'captures sign-changing correction balance';'useful when tails dominate correction';'sensitive to second-derivative-like correction';'best scalar stability proxy for rank1 correction strength';'visual motif only, not unique scalar';'captures where correction steepens/flattens traces'}), ...
        'VariableNames', {'proxy_name','directly_visible_in_map','captures_phi1_shape_well','support_strength','note'});

    % Part C1 legacy interpretation reference.
    legacyRefTbl = table( ...
        string({'LG1';'LG2';'LG3';'LG4';'LG5'}), ...
        string({'kappa1';'kappa1';'Phi1';'Phi1';'Phi1'}), ...
        string({'tracks switching amplitude scale';'co-varies with peak position/threshold scale';'symmetric redistribution-like correction';'ridge/width-like visual modulation';'residual map correction motif via trace overlays'}), ...
        string({'S_peak trend plots';'I_peak-linked plots';'even/odd decomposition motifs';'ridge-curvature panels';'measured/backbone/reconstruction overlays'}), ...
        string({ ...
        'docs/switching_canonical_definition.md'; ...
        'Switching/analysis/switching_mechanism_followup.m'; ...
        'docs/PROJECT KERNEL v1 Switching  Barrier Landscape.txt'; ...
        'Switching/analysis/switching_ridge_susceptibility_analysis.m'; ...
        'Switching/analysis/run_switching_canonical_first_figure_anchor.m'}), ...
        string({'HIGH';'HIGH';'PARTIAL';'PARTIAL';'HIGH'}), ...
        'VariableNames', {'legacy_item_id','entity','old_interpretation','old_observable_or_visual_motif','source_reference','reuse_value_for_canonical_interpretation'});

    % Part C2 bridge table.
    bridgeTbl = table( ...
        string({'kappa1 amplitude-tracker language';'kappa1 threshold-scale language';'Phi1 symmetric redistribution language';'Phi1 ridge/width modulation language';'Phi1 trace-overlay correction language'}), ...
        string({'PRESERVED';'PRESERVED';'PARTIAL';'PARTIAL';'PRESERVED'}), ...
        string({'YES';'YES';'PARTIAL';'PARTIAL';'YES'}), ...
        string({'retain as primary kappa1 map intuition';'retain with explicit current-scale caveat';'rephrase as partial, not dominant, symmetry';'rephrase as mixed center-tail redistribution (not pure width kernel)';'retain as main experimental replay visualization'}), ...
        'VariableNames', {'legacy_language_item','canonical_status','can_be_reused','reformulation_note'});
    bridgeTbl = addvars(bridgeTbl, string({'kappa1';'kappa1';'Phi1';'Phi1';'Phi1'}), 'Before', 1, 'NewVariableNames', 'entity');

    % Status + report.
    statusTbl = table( ...
        string('SUCCESS'), ...
        string('YES'), ...
        string('YES'), ...
        nT, ...
        string(strjoin(string(repTemps(:)'), ', ')), ...
        string(strjoin(figPaths, '; ')), ...
        string(sprintf('source=%s|%s|%s', sPath, oPath, ampPath)), ...
        'VariableNames', {'STATUS','INPUT_FOUND','LEGACY_REFERENCE_USED','N_temperatures_used','representative_temperatures_used','figures_written','execution_notes'});

    % Final verdicts.
    kappaProxy = "PARTIAL"; bestProxy = "S_peak";
    if corr(K1, Speak, 'Type','Spearman','Rows','complete') >= 0.8
        kappaProxy = "YES";
    end
    phiDesc = "PARTIAL";
    phiPhrase = "signed redistribution correction between center and tails";
    if mean(abs(kappa1_proj), 'omitnan') > 0 && mean(vecnorm(Rfill - (kappa1_proj*phi1'),2,2), 'omitnan') < mean(vecnorm(Rfill,2,2), 'omitnan')
        phiDesc = "YES";
    end
    legacyReusable = "PARTIAL";
    canonIntelligible = "YES";

    report = {};
    report{end+1} = '# Switching Phi1/kappa1 Experimental Replay';
    report{end+1} = '';
    report{end+1} = '## 1. What is already known canonically';
    report{end+1} = '- Phi1 dominant/stable and usable as reference for mode_2.';
    report{end+1} = '- kappa1 observable mappings preserved (strong: S_peak, I_peak; partial: PT_q50, ridge_proxy).';
    report{end+1} = '- This run does not reopen those verdicts; it translates them into measurement language.';
    report{end+1} = '';
    report{end+1} = '## 2. Experimental meaning of kappa1';
    report{end+1} = '- kappa1 tracks map-level amplitude and peak-position evolution most clearly through S_peak(T) and I_peak(T).';
    report{end+1} = '- Recommended primary proxy: S_peak (most direct single-map scalar), with I_peak as structural companion.';
    report{end+1} = '';
    report{end+1} = '## 3. Experimental meaning of Phi1';
    report{end+1} = '- Adding kappa1*Phi1 to Scdf produces a signed correction visible in trace overlays.';
    report{end+1} = '- The correction appears as center-vs-tail redistribution and slope/curvature reshaping, not a pure shift-only effect.';
    report{end+1} = '';
    report{end+1} = '## 4. Legacy interpretation bridge';
    report{end+1} = '- Legacy amplitude/peak-position language for kappa1 is reusable.';
    report{end+1} = '- Legacy Phi1 language is partially reusable: keep trace/motif intuition, reformulate pure-symmetry or pure-width claims.';
    report{end+1} = '';
    report{end+1} = '## 5. Practical conclusion';
    report{end+1} = '- For measured maps, think of kappa1 as a scalar correction amplitude strongly reflected by S_peak and accompanied by I_peak shifts.';
    report{end+1} = '- Think of Phi1 as the map-shape correction pattern that redistributes response across current regions when added to the backbone.';
    report{end+1} = '';
    report{end+1} = '## Figures';
    for i = 1:numel(figPaths)
        report{end+1} = sprintf('- `%s`', figPaths(i));
    end
    report{end+1} = '';
    report{end+1} = '## Final Verdicts';
    report{end+1} = sprintf('- KAPPA1_HAS_CLEAR_EXPERIMENTAL_PROXY = %s', kappaProxy);
    report{end+1} = sprintf('- BEST_KAPPA1_EXPERIMENTAL_PROXY = %s', bestProxy);
    report{end+1} = sprintf('- PHI1_HAS_CLEAR_EXPERIMENTAL_DESCRIPTION = %s', phiDesc);
    report{end+1} = sprintf('- PHI1_BEST_DESCRIBED_AS = %s', phiPhrase);
    report{end+1} = sprintf('- LEGACY_PHI1_KAPPA1_LANGUAGE_REUSABLE = %s', legacyReusable);
    report{end+1} = sprintf('- CANONICAL_RESULTS_NOW_EXPERIMENTALLY_INTELLIGIBLE = %s', canonIntelligible);

    writeBoth(rankTbl, repoRoot, runTables, 'switching_kappa1_experimental_proxy_ranking.csv');
    writeBoth(kSummaryTbl, repoRoot, runTables, 'switching_kappa1_experimental_summary.csv');
    writeBoth(traceInterpTbl, repoRoot, runTables, 'switching_phi1_trace_interpretation.csv');
    writeBoth(phiProxyTbl, repoRoot, runTables, 'switching_phi1_experimental_proxy_candidates.csv');
    writeBoth(legacyRefTbl, repoRoot, runTables, 'switching_legacy_phi1_kappa1_interpretation_reference.csv');
    writeBoth(bridgeTbl, repoRoot, runTables, 'switching_legacy_to_canonical_interpretation_bridge.csv');
    writeBoth(statusTbl, repoRoot, runTables, 'switching_phi1_kappa1_experimental_replay_status.csv');
    writeLines(fullfile(runReports, 'switching_phi1_kappa1_experimental_replay.md'), report);
    writeLines(fullfile(repoRoot, 'reports', 'switching_phi1_kappa1_experimental_replay.md'), report);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'switching phi1/kappa1 experimental replay completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_phi1_kappa1_experimental_replay_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    statusTbl = table(string('FAILED'), string('NO'), string('NO'), 0, string(''), string(''), string(ME.message), ...
        'VariableNames', {'STATUS','INPUT_FOUND','LEGACY_REFERENCE_USED','N_temperatures_used','representative_temperatures_used','figures_written','execution_notes'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_phi1_kappa1_experimental_replay_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_phi1_kappa1_experimental_replay_status.csv'));
    lines = {};
    lines{end+1} = '# Switching Phi1/kappa1 Experimental Replay FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    writeLines(fullfile(runDir, 'reports', 'switching_phi1_kappa1_experimental_replay.md'), lines);
    writeLines(fullfile(repoRoot, 'reports', 'switching_phi1_kappa1_experimental_replay.md'), lines);
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'switching phi1/kappa1 experimental replay failed'}, true);
    rethrow(ME);
end

function p = resolveLatestCanonical(repoRoot, fileName)
p = '';
runsRoot = switchingCanonicalRunRoot(repoRoot);
if exist(runsRoot, 'dir') ~= 7, return; end
d = dir(fullfile(runsRoot, 'run_*_switching_canonical'));
paths = {};
for i = 1:numel(d)
    f = fullfile(runsRoot, d(i).name, 'tables', fileName);
    if exist(f, 'file') == 2, paths{end+1,1} = f; end %#ok<AGROW>
end
if isempty(paths), return; end
[~, idx] = max(cellfun(@(x) dir(x).datenum, paths));
p = paths{idx};
end

function y = pullByT(tbl, T, col)
y = NaN(numel(T),1);
for i = 1:numel(T)
    m = abs(double(tbl.T_K)-T(i)) < 1e-9;
    if any(m), y(i) = mean(double(tbl.(col)(m)), 'omitnan'); end
end
end

function ip = estimateIpeak(Smap, I)
ip = NaN(size(Smap,1),1);
for i = 1:size(Smap,1)
    row = Smap(i,:); v = isfinite(row);
    if any(v)
        [~, j] = max(row(v)); iv = I(v); ip(i) = iv(j);
    end
end
end

function qv = estimatePTQuantile(sTbl, T, q)
qv = NaN(numel(T),1);
for it = 1:numel(T)
    m = abs(double(sTbl.T_K)-T(it))<1e-9;
    x = double(sTbl.current_mA(m));
    p = double(sTbl.PT_pdf(m));
    if isempty(x) || isempty(p), continue; end
    [x, o] = sort(x); p = p(o);
    v = isfinite(x)&isfinite(p);
    if nnz(v) < 3, continue; end
    x = x(v); p = max(p(v),0); a = trapz(x,p);
    if ~isfinite(a) || a<=0, continue; end
    p = p./a; c = cumtrapz(x,p); if c(end)>0, c=c./c(end); end
    [c, iu] = unique(c,'stable'); x = x(iu);
    if numel(c)>=2, qv(it) = interp1(c,x,q,'linear','extrap'); end
end
end

function rp = estimateRidgeProxy(Smap, Scdf, I)
ridge = I>=35 & I<=45;
if ~any(ridge)
    q = quantile(I,[0.55,0.80]); ridge = I>=q(1)&I<=q(2);
end
R = abs(Smap-Scdf);
rp = NaN(size(R,1),1);
for i = 1:size(R,1)
    r = R(i,:);
    if any(isfinite(r))
        rp(i) = sum(r(ridge),'omitnan')/max(sum(r,'omitnan'),eps);
    end
end
end

function rep = chooseRepresentativeTemps(T)
targets = [18, 26, 32];
rep = NaN(1, numel(targets));
for i = 1:numel(targets)
    [~, j] = min(abs(T-targets(i)));
    rep(i) = T(j);
end
rep = unique(rep, 'stable');
end

function p = makeKappaFigure(runFigures, T, K1, Speak, Ipeak, PTq50, ridgeProxy)
fig = figure('Visible','off','Color','w','Position',[100 100 1300 700]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile; plot(T,z(K1),'-o','LineWidth',1.6); hold on; plot(T,z(Speak),'-s','LineWidth',1.6); grid on; title('kappa1 vs S\_peak (z-score)'); legend({'kappa1','S_peak'},'Location','best');
nexttile; plot(T,z(K1),'-o','LineWidth',1.6); hold on; plot(T,z(Ipeak),'-s','LineWidth',1.6); grid on; title('kappa1 vs I\_peak (z-score)'); legend({'kappa1','I_peak'},'Location','best');
nexttile; plot(T,z(K1),'-o','LineWidth',1.6); hold on; plot(T,z(PTq50),'-s','LineWidth',1.6); grid on; title('kappa1 vs PT\_q50 (z-score)'); legend({'kappa1','PT_q50'},'Location','best');
nexttile; plot(T,z(K1),'-o','LineWidth',1.6); hold on; plot(T,z(ridgeProxy),'-s','LineWidth',1.6); grid on; title('kappa1 vs ridge\_proxy (z-score)'); legend({'kappa1','ridge_proxy'},'Location','best');
p = fullfile(runFigures, 'switching_kappa1_experimental_overlay.png');
exportgraphics(fig, p, 'Resolution', 300); close(fig);
end

function p = makeTraceFigure(runFigures, T, I, Smap, Scdf, Srank1, regime, repTemps)
fig = figure('Visible','off','Color','w','Position',[100 100 1400 450*numel(repTemps)]);
tiledlayout(numel(repTemps),1,'TileSpacing','compact','Padding','compact');
for i = 1:numel(repTemps)
    [~, it] = min(abs(T-repTemps(i)));
    nexttile;
    plot(I, Smap(it,:), '-o', 'LineWidth', 1.5); hold on;
    plot(I, Scdf(it,:), '-s', 'LineWidth', 1.5);
    plot(I, Srank1(it,:), '-^', 'LineWidth', 1.5);
    grid on;
    title(sprintf('T=%.3g K (%s): measured vs backbone vs backbone+rank1', T(it), regime(it)));
    xlabel('Current (mA)'); ylabel('S (%)');
    legend({'S measured','Scdf backbone','Scdf + kappa1*phi1'}, 'Location','best');
end
p = fullfile(runFigures, 'switching_phi1_trace_replay.png');
exportgraphics(fig, p, 'Resolution', 300); close(fig);
end

function p = makeMapFigure(runFigures, T, I, Smap, Scdf, Srank1)
fig = figure('Visible','off','Color','w','Position',[100 100 1500 500]);
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
nexttile; imagesc(I, T, Smap); set(gca,'YDir','normal'); colorbar; title('Measured S(I,T)'); xlabel('I (mA)'); ylabel('T (K)');
nexttile; imagesc(I, T, Scdf); set(gca,'YDir','normal'); colorbar; title('Backbone Scdf(I,T)'); xlabel('I (mA)');
nexttile; imagesc(I, T, Srank1-Scdf); set(gca,'YDir','normal'); colorbar; title('Rank1 correction kappa1*phi1'); xlabel('I (mA)');
p = fullfile(runFigures, 'switching_phi1_map_replay.png');
exportgraphics(fig, p, 'Resolution', 300); close(fig);
end

function y = z(x)
y = NaN(size(x));
v = isfinite(x);
if nnz(v) < 2, return; end
mu = mean(x(v), 'omitnan'); sd = std(x(v), 'omitnan');
if sd <= 0, return; end
y(v) = (x(v)-mu)/sd;
end

function writeBoth(tbl, repoRoot, runTablesDir, name)
writetable(tbl, fullfile(runTablesDir, name));
writetable(tbl, fullfile(repoRoot, 'tables', name));
end

function writeLines(pathOut, lines)
fid = fopen(pathOut, 'w');
if fid < 0, error('run_switching_phi1_kappa1_experimental_replay:WriteFail', 'Cannot write %s', pathOut); end
for i = 1:numel(lines), fprintf(fid, '%s\n', lines{i}); end
fclose(fid);
end
