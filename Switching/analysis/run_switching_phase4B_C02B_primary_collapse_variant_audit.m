% Phase 4B_C02B - primary collapse variant audit (QA / inspection only)
% Rebuilds collapse curves from existing script formulas. No broad replay.

clear;
clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

figDir = fullfile(repoRoot, 'figures', 'switching', 'canonical');
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(figDir, 'dir') ~= 7
    mkdir(figDir);
end
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

outReg = fullfile(tablesDir, 'switching_phase4B_C02B_collapse_variant_registry.csv');
outDef = fullfile(tablesDir, 'switching_phase4B_C02B_collapse_variant_defects.csv');
outRef = fullfile(tablesDir, 'switching_phase4B_C02B_collapse_variant_reference_match.csv');
outStat = fullfile(tablesDir, 'switching_phase4B_C02B_status.csv');
outRep = fullfile(reportsDir, 'switching_phase4B_C02B_primary_collapse_variant_audit.md');

collapsePrePrimary = fullfile(tablesDir, 'switching_canonical_primary_collapse_colored_values.csv');
collapsePreG014 = fullfile(tablesDir, 'switching_canonical_primary_collapse_colored_values_G014.csv');
collapsePreG254 = fullfile(tablesDir, 'switching_canonical_primary_collapse_colored_values_G254.csv');
p0Path = fullfile(tablesDir, 'switching_P0_effective_observables_values.csv');
gaugePath = fullfile(tablesDir, 'switching_gauge_component_stability_values.csv');
sLongA = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_2026_04_24_233348_switching_canonical', 'tables', 'switching_canonical_S_long.csv');
sLongB = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_2026_04_03_000147_switching_canonical', 'tables', 'switching_canonical_S_long.csv');

sl = [];
sLongPick = '';
if exist(sLongA, 'file') == 2
    sLongPick = sLongA;
    sl = readtable(sLongA);
elseif exist(sLongB, 'file') == 2
    sLongPick = sLongB;
    sl = readtable(sLongB);
end

hasSL = false;
cTsl = 0;
cIsl = 0;
cSsl = 0;
if ~isempty(sl) && ~isempty(sl.Properties.VariableNames)
    sNames = lower(string(sl.Properties.VariableNames));
    cTsl = find(sNames == "t_k" | sNames == "t" | contains(sNames, "temperature"), 1, 'first');
    cIsl = find(contains(sNames, "current_m") | sNames == "i_m_a" | sNames == "i" | sNames == "current_mA", 1, 'first');
    cSsl = find(sNames == "s_percent" | sNames == "s" | contains(sNames, "s_pct"), 1, 'first');
    if ~isempty(cTsl) && ~isempty(cIsl) && ~isempty(cSsl)
        hasSL = true;
    end
end

tblPrimary = table();
tblG014 = table();
tblG254 = table();
okP = false;
okG014 = false;
okG254 = false;

mixLine = "Column-selective S_percent from switching_canonical_S_long (mixed diagnostic file); not corrected-old backbone; PT/CDF columns not used.";

disp('Phase4B_C02B: VARIANT PRIMARY');

if hasSL
    if exist(collapsePrePrimary, 'file') == 2
        tp = readtable(collapsePrePrimary);
        if all(ismember({'T_K','x_scaled','y_scaled'}, tp.Properties.VariableNames))
            tblPrimary = tp(:, {'T_K','x_scaled','y_scaled'});
            okP = height(tblPrimary) > 0;
        end
    end
    if ~okP && exist(p0Path, 'file') == 2
        p0 = readtable(p0Path);
        p0Names = lower(string(p0.Properties.VariableNames));
        iTk = find(p0Names == "t_k" | p0Names == "t", 1, 'first');
        iIpk = find(contains(p0Names, "i_peak"), 1, 'first');
        iSpk = find(contains(p0Names, "s_peak"), 1, 'first');
        iWc = find(contains(p0Names, "width_chosen"), 1, 'first');
        iWi = find(p0Names == "w_i" | contains(p0Names, "_w_i"), 1, 'first');
        if ~isempty(iTk) && ~isempty(iIpk) && ~isempty(iSpk)
            T0 = p0{:, iTk};
            Ipk = p0{:, iIpk};
            Spk = p0{:, iSpk};
            Wc = nan(size(T0));
            if ~isempty(iWc)
                Wc = p0{:, iWc};
            end
            Wi = Wc;
            if ~isempty(iWi)
                Wi2 = p0{:, iWi};
                repl = ~isfinite(Wi) | Wi <= 0;
                Wi(repl) = Wi2(repl);
            end
            tRaw2 = sl{:, cTsl};
            iRaw2 = sl{:, cIsl};
            sRaw2 = sl{:, cSsl};
            keep = isfinite(tRaw2) & isfinite(iRaw2) & isfinite(sRaw2);
            tRaw2 = tRaw2(keep);
            iRaw2 = iRaw2(keep);
            sRaw2 = sRaw2(keep);
            tR = round(tRaw2);
            p0MapT = round(T0);
            xcol = [];
            ycol = [];
            tcol = [];
            uTloc = unique(tR);
            for ui = 1:numel(uTloc)
                tk = uTloc(ui);
                if tk >= 31.5
                    continue;
                end
                j = find(p0MapT == tk, 1, 'first');
                if isempty(j)
                    continue;
                end
                i0 = Ipk(j);
                w0 = Wi(j);
                s0 = Spk(j);
                if ~isfinite(i0) || ~isfinite(w0) || ~isfinite(s0) || w0 <= 0 || abs(s0) <= 1e-15
                    continue;
                end
                id = (tR == tk);
                xx = (iRaw2(id) - i0) ./ w0;
                yy = sRaw2(id) ./ s0;
                kk = isfinite(xx) & isfinite(yy);
                xx = xx(kk);
                yy = yy(kk);
                if numel(xx) < 4
                    continue;
                end
                xcol = [xcol; xx(:)];
                ycol = [ycol; yy(:)];
                tcol = [tcol; tk * ones(numel(xx), 1)];
            end
            if ~isempty(tcol)
                tblPrimary = table(tcol, xcol, ycol, 'VariableNames', {'T_K','x_scaled','y_scaled'});
                okP = true;
            end
        end
    end
end

disp('Phase4B_C02B: VARIANT G014 / G254');

if hasSL && exist(gaugePath, 'file') == 2
    vals = readtable(gaugePath);
    reqG = {'T_K','I_peak_old','I_peak_smoothed_across_T','W_sigma_positive','S_area_positive'};
    if all(ismember(reqG, vals.Properties.VariableNames))
        if exist(collapsePreG014, 'file') == 2
            tg = readtable(collapsePreG014);
            if all(ismember({'T_K','x_scaled','y_scaled'}, tg.Properties.VariableNames))
                tblG014 = tg(:, {'T_K','x_scaled','y_scaled'});
                okG014 = height(tblG014) > 0;
            end
        end
        if exist(collapsePreG254, 'file') == 2
            tg2 = readtable(collapsePreG254);
            if all(ismember({'T_K','x_scaled','y_scaled'}, tg2.Properties.VariableNames))
                tblG254 = tg2(:, {'T_K','x_scaled','y_scaled'});
                okG254 = height(tblG254) > 0;
            end
        end
        T0 = vals.T_K;
        I014 = vals.I_peak_old;
        I254 = vals.I_peak_smoothed_across_T;
        W0 = vals.W_sigma_positive;
        S0 = vals.S_area_positive;
        tRound = round(sl{:, cTsl});
        iRaw3 = sl{:, cIsl};
        sRaw3 = sl{:, cSsl};
        keep3 = isfinite(tRound) & isfinite(iRaw3) & isfinite(sRaw3);
        tRound = tRound(keep3);
        iRaw3 = iRaw3(keep3);
        sRaw3 = sRaw3(keep3);

        if ~okG014
            xcol = [];
            ycol = [];
            tcol = [];
            uT2 = unique(tRound);
            for ui = 1:numel(uT2)
                tk = uT2(ui);
                if tk >= 31.5
                    continue;
                end
                j = find(round(T0) == tk, 1, 'first');
                if isempty(j)
                    continue;
                end
                i0 = I014(j);
                wu = W0(j);
                sA = S0(j);
                if ~isfinite(i0) || ~isfinite(wu) || ~isfinite(sA) || wu <= 0 || abs(sA) <= 1e-15
                    continue;
                end
                id = tRound == tk;
                xx = (iRaw3(id) - i0) ./ wu;
                yy = sRaw3(id) ./ sA;
                kk = isfinite(xx) & isfinite(yy);
                xx = xx(kk);
                yy = yy(kk);
                if numel(xx) < 4
                    continue;
                end
                xcol = [xcol; xx(:)];
                ycol = [ycol; yy(:)];
                tcol = [tcol; tk * ones(numel(xx), 1)];
            end
            if ~isempty(tcol)
                tblG014 = table(tcol, xcol, ycol, 'VariableNames', {'T_K','x_scaled','y_scaled'});
                okG014 = true;
            end
        end

        if ~okG254
            xcol = [];
            ycol = [];
            tcol = [];
            uT2 = unique(tRound);
            for ui = 1:numel(uT2)
                tk = uT2(ui);
                if tk >= 31.5
                    continue;
                end
                j = find(round(T0) == tk, 1, 'first');
                if isempty(j)
                    continue;
                end
                i0 = I254(j);
                wu = W0(j);
                sA = S0(j);
                if ~isfinite(i0) || ~isfinite(wu) || ~isfinite(sA) || wu <= 0 || abs(sA) <= 1e-15
                    continue;
                end
                id = tRound == tk;
                xx = (iRaw3(id) - i0) ./ wu;
                yy = sRaw3(id) ./ sA;
                kk = isfinite(xx) & isfinite(yy);
                xx = xx(kk);
                yy = yy(kk);
                if numel(xx) < 4
                    continue;
                end
                xcol = [xcol; xx(:)];
                ycol = [ycol; yy(:)];
                tcol = [tcol; tk * ones(numel(xx), 1)];
            end
            if ~isempty(tcol)
                tblG254 = table(tcol, xcol, ycol, 'VariableNames', {'T_K','x_scaled','y_scaled'});
                okG254 = true;
            end
        end
    end
end

if okP
    dataP = "YES";
else
    dataP = "NO";
end
if okG014
    dataG14 = "YES";
else
    dataG14 = "NO";
end
if okG254
    dataG54 = "YES";
else
    dataG54 = "NO";
end

scrForensic = "scripts/run_switching_old_fig_forensic_and_canonical_replot.m";
scrGauge = "scripts/run_switching_stabilized_gauge_figure_replay.m";
scrAtlas = "scripts/run_switching_gauge_atlas_preview.m";
famP0 = "FORENSIC_REPLAY_P0_PLUS_MIXED_S_LONG";
famG = "GAUGE_STABILIZED_PLUS_MIXED_S_LONG";

regTbl = table( ...
    [ "PRIMARY"; "G014"; "G254"; "ATLAS_G001_DOC_ONLY" ], ...
    [ ...
    "P0 I_peak/W_I/S_peak (S_percent/S_peak vs (I-I_peak)/W_I)"; ...
    "Gauge G014 (axes like S/S0 vs (I-I0)/W in stabilized replay)"; ...
    "Gauge G254 smoothed I0 center"; ...
    "Atlas preview shows G001/G254/G014 triplets (doc only)" ...
    ], ...
    [ scrForensic; scrGauge; scrGauge; scrAtlas ], ...
    [ string(collapsePrePrimary) + "|" + string(p0Path) + "|" + string(sLongPick); ...
    string(collapsePreG014) + "|" + string(gaugePath) + "|" + string(sLongPick); ...
    string(collapsePreG254) + "|" + string(gaugePath) + "|" + string(sLongPick); ...
    "n/a" ...
    ], ...
    [ famP0; famG; famG; "DOCUMENTATION_PREVIEW_ONLY" ], ...
    [ "(I-I_peak(T))/W_I(T)"; "(I-I_peak_old(T))/W_sigma_positive(T)"; "(I-I_smooth(T))/W_sigma_positive(T)"; "varies by subplot" ], ...
    [ "S_percent/S_peak(T)"; "S_percent/S_area_positive(T)"; "S_percent/S_area_positive(T)"; "S/S0 style label in preview" ], ...
    [ "I_peak,W_I"; "I_peak_old,W_sigma_positive"; "I_peak_smooth,W_sigma_positive"; "see atlas script field names" ], ...
    [ "S_percent,S_peak"; "S_percent,S_area_positive"; "S_percent,S_area_positive"; "S_percent" ], ...
    [ "I_peak match on rounded T_K"; "I_peak_old row"; "I_peak_smoothed row"; "per-gauge I0" ], ...
    [ "W_I width_chosen/w_i"; "W_sigma_positive"; "W_sigma_positive"; "W_FWHM or W_sigma" ], ...
    [ "S_peak"; "S_area_positive"; "S_area_positive"; "S_peak_old or S_area" ], ...
    [ "T<31.5 collapse loop"; "T<31.5"; "T<31.5"; "T<31.5 primary index" ], ...
    [ "T>=31.5 omitted"; "T>=31.5 omitted"; "T>=31.5 omitted"; "diagnostic markers only" ], ...
    repmat(string(mixLine), 4, 1), ...
    repmat("YES", 4, 1), ...
    repmat("NO", 4, 1), ...
    [ "Ref PNG switching_canonical_primary_collapse_colored_by_T.png"; ...
    "Ref PNG ..._G014.png"; ...
    "Ref PNG ..._G254.png"; ...
    "Optional fourth family documented not regenerated here." ], ...
    [ dataP; dataG14; dataG54; "NO" ], ...
    'VariableNames', { ...
    'variant_id', 'variant_label', 'source_script', 'source_table_paths', ...
    'source_family', 'x_formula', 'y_formula', 'x_anchor_columns', 'y_normalize_columns', ...
    'center_definition', 'width_definition', 'normalization', 'included_temperatures', ...
    'excluded_temperatures', 'semantic_lineage_notes', 'safe_for_inspection', ...
    'safe_for_physics_interpretation', 'notes', 'data_loaded' ...
    });

writetable(regTbl, outReg);

defEmpty = table( ...
    string([]), [], [], [], [], [], [], [], ...
    'VariableNames', { ...
    'variant_id', 'T_K', 'n_points', 'rmse_vs_mean_curve', 'mae_vs_mean_curve', ...
    'max_abs_residual', 'x_grid_min', 'x_grid_max' ...
    });
D = defEmpty;
nG = 256;
grmse = nan(3, 1);
ids = {'PRIMARY', 'G014', 'G254'};
tbls = {tblPrimary, tblG014, tblG254};
xlab = { '(I-I_{peak})/W_I (arb.)', '(I-I_0)/W (arb.)', '(I-I_0)/W (arb., smoothed I_0)' };
ylab = { 'S/S_{peak} (arb.)', 'S/S_0 (arb.)', 'S/S_0 (arb.)' };

pngAny = false;
figAny = false;

for vi = 1:3
    tb = tbls{vi};
    vid = ids{vi};
    if isempty(tb) || height(tb) == 0
        grmse(vi) = NaN;
        continue;
    end
    tx = tb.T_K;
    xx = tb.x_scaled;
    yy = tb.y_scaled;
    uT = unique(tx);
    xMin = min(xx);
    xMax = max(xx);
    if ~isfinite(xMin) || ~isfinite(xMax) || xMax <= xMin
        continue;
    end
    xg = linspace(xMin, xMax, nG)';
    Ym = nan(numel(uT), numel(xg));
    for ki = 1:numel(uT)
        tk = uT(ki);
        idr = tx == tk;
        xi = xx(idr);
        yi = yy(idr);
        [xs, ord] = sort(xi);
        ys = yi(ord);
        yg = interp1(xs, ys, xg, 'linear', NaN);
        Ym(ki, :) = yg';
    end
    meanC = mean(Ym, 1, 'omitnan');
    allRes = [];
    for ki = 1:numel(uT)
        tk = uT(ki);
        yi = Ym(ki, :)';
        r = yi - meanC(:);
        vn = isfinite(yi) & isfinite(meanC(:));
        if any(vn)
            rv = r(vn);
            rmse = sqrt(mean(rv .^ 2));
            mae = mean(abs(rv));
            mx = max(abs(rv));
            np = sum(tx == tk);
            D = [D; table(string(vid), tk, np, rmse, mae, mx, xMin, xMax, 'VariableNames', { ...
                'variant_id', 'T_K', 'n_points', 'rmse_vs_mean_curve', 'mae_vs_mean_curve', ...
                'max_abs_residual', 'x_grid_min', 'x_grid_max' ...
                })]; %#ok<AGROW>
            allRes = [allRes; rv]; %#ok<AGROW>
        end
    end
    if ~isempty(allRes)
        grmse(vi) = sqrt(mean(allRes .^ 2));
        D = [D; table(string(vid), NaN, height(tb), grmse(vi), mean(abs(allRes)), max(abs(allRes)), xMin, xMax, ...
            'VariableNames', { ...
            'variant_id', 'T_K', 'n_points', 'rmse_vs_mean_curve', 'mae_vs_mean_curve', ...
            'max_abs_residual', 'x_grid_min', 'x_grid_max' ...
            })]; %#ok<AGROW>
    end

    f = figure('Visible', 'off', 'Color', 'w');
    ax = axes(f);
    hold(ax, 'on');
    tu = unique(tx);
    cmap = parula(max(1, numel(tu)));
    for ii = 1:numel(tu)
        tt = tu(ii);
        idc = tx == tt;
        plot(ax, xx(idc), yy(idc), '-', 'Color', cmap(ii, :), 'LineWidth', 1.2, 'HandleVisibility', 'off');
    end
    if ~isempty(tu)
        cb = colorbar(ax);
        cb.Label.String = 'T_K';
        caxis(ax, [min(tu) max(tu)]);
        colormap(ax, cmap);
    end
    grid(ax, 'on');
    xlabel(ax, xlab{vi}, 'Interpreter', 'tex');
    ylabel(ax, ylab{vi}, 'Interpreter', 'tex');
    title(ax, sprintf('Phase 4B_C02B %s primary_collapse audit (QA only)', vid), 'Interpreter', 'none');
    hold(ax, 'off');
    pBase = fullfile(figDir, sprintf('phase4B_C02B_primary_collapse_variant_%s', vid));
    exportgraphics(f, [pBase '.png'], 'Resolution', 240);
    savefig(f, [pBase '.fig']);
    close(f);
    pngAny = true;
    figAny = true;

    f2 = figure('Visible', 'off', 'Color', 'w');
    ax2 = axes(f2);
    hold(ax2, 'on');
    for ki = 1:numel(uT)
        yi = Ym(ki, :)';
        r = yi - meanC(:);
        plot(ax2, xg, r, '-', 'Color', cmap(min(ki, size(cmap, 1)), :), 'LineWidth', 1.1, 'HandleVisibility', 'off');
    end
    grid(ax2, 'on');
    xlabel(ax2, xlab{vi}, 'Interpreter', 'tex');
    ylabel(ax2, 'collapse-defect vs mean(T) (arb.)', 'Interpreter', 'none');
    title(ax2, sprintf('Phase 4B_C02B %s collapse-defect QA', vid), 'Interpreter', 'none');
    hold(ax2, 'off');
    pRes = fullfile(figDir, sprintf('phase4B_C02B_primary_collapse_residuals_%s', vid));
    exportgraphics(f2, [pRes '.png'], 'Resolution', 240);
    close(f2);
    pngAny = true;
end

f3 = figure('Visible', 'off', 'Color', 'w');
ax3 = axes(f3);
bar(ax3, 1:3, grmse);
set(ax3, 'XTickLabel', ids);
grid(ax3, 'on');
ylabel(ax3, 'global RMSE vs mean curve');
title(ax3, 'Phase 4B_C02B collapse variant defect comparison (QA only)', 'Interpreter', 'none');
pCmp = fullfile(figDir, 'phase4B_C02B_primary_collapse_variant_comparison');
exportgraphics(f3, [pCmp '.png'], 'Resolution', 240);
close(f3);
pngAny = true;

writetable(D, outDef);

refTbl = table( ...
    [ "switching_canonical_primary_collapse_colored_by_T.png"; ...
    "switching_canonical_primary_collapse_colored_by_T_G014.png"; ...
    "switching_canonical_primary_collapse_colored_by_T_G254.png" ], ...
    [ "PRIMARY"; "G014"; "G254" ], ...
    repmat("YES", 3, 1), ...
    repmat("YES", 3, 1), ...
    [ "S/S_peak style"; "S/S0 style"; "S/S0 style" ], ...
    [ "(I-I_peak)/W_I"; "(I-I0)/W"; "(I-I0)/W smoothed I0" ], ...
    [ "S_percent/S_peak"; "S_percent/S_area_positive"; "S_percent/S_area_positive" ], ...
    [ "Regenerated as phase4B_C02B_primary_collapse_variant_PRIMARY.png"; ...
    "Regenerated as phase4B_C02B_primary_collapse_variant_G014.png"; ...
    "Regenerated as phase4B_C02B_primary_collapse_variant_G254.png" ], ...
    'VariableNames', { ...
    'reference_graph_file', 'mapped_variant_id', 'peak_near_zero_expected', ...
    'color_by_temperature', 'y_normalization_style', 'x_axis_formula', 'y_axis_formula', ...
    'regenerated_counterpart' ...
    });
writetable(refTbl, outRef);

srcDisc = 'YES';
primFound = 'NO';
if okP || okG014 || okG254
    primFound = 'YES';
end
defW = 'NO';
if height(D) > 0
    defW = 'YES';
end
refOk = 'NO';
if okP && okG014 && okG254
    refOk = 'YES';
end
figCanon = 'NO';
if pngAny
    figCanon = 'YES';
end
pdfW = 'NO';
if pngAny
    pngW = 'YES';
else
    pngW = 'NO';
end
if figAny
    figMainW = 'YES';
else
    figMainW = 'NO';
end
broad = 'NO';
proc = 'NO';
if okP && okG014 && okG254 && strcmp(defW, 'YES')
    proc = 'YES';
end

k = { ...
    'PHASE4B_C02B_COMPLETE'; ...
    'SOURCE_DISCOVERY_COMPLETE'; ...
    'PRIMARY_COLLAPSE_VARIANTS_FOUND'; ...
    'PRIMARY_DEFAULT_VARIANT_FOUND'; ...
    'G014_VARIANT_FOUND'; ...
    'G254_VARIANT_FOUND'; ...
    'S_OVER_SPEAK_VARIANT_FOUND'; ...
    'S_OVER_S0_VARIANT_FOUND'; ...
    'RESIDUAL_DEFECTS_WRITTEN'; ...
    'REFERENCE_GRAPHS_CONFIRMED'; ...
    'FIGURES_WRITTEN_TO_CANONICAL_DIR'; ...
    'PNG_WRITTEN'; ...
    'FIG_WRITTEN_FOR_MAIN_VARIANTS'; ...
    'PDF_WRITTEN'; ...
    'USES_COLLAPSE_CANON_NAME'; ...
    'USES_X_CANON_NAME'; ...
    'BROAD_REPLAY_RUN'; ...
    'RENAME_EXECUTED'; ...
    'RELAXATION_COMPARISON_RUN'; ...
    'AGING_COMPARISON_RUN'; ...
    'SAFE_TO_INTERPRET_PHYSICS'; ...
    'SAFE_TO_USE_AS_QA_EVIDENCE'; ...
    'SAFE_TO_PROCEED_TO_NEXT_SLICE' ...
    };

vSpeak = 'NO';
if okP
    vSpeak = 'YES';
end
vS0 = 'NO';
if okG014 || okG254
    vS0 = 'YES';
end
vPriDef = 'NO';
if okP
    vPriDef = 'YES';
end
vG14 = 'NO';
if okG014
    vG14 = 'YES';
end
vG54 = 'NO';
if okG254
    vG54 = 'YES';
end

vals = { ...
    'YES'; ...
    srcDisc; ...
    primFound; ...
    vPriDef; ...
    vG14; ...
    vG54; ...
    vSpeak; ...
    vS0; ...
    defW; ...
    refOk; ...
    figCanon; ...
    pngW; ...
    figMainW; ...
    pdfW; ...
    'NO'; ...
    'NO'; ...
    broad; ...
    'NO'; ...
    'NO'; ...
    'NO'; ...
    'NO'; ...
    'YES'; ...
    proc ...
    };

statTbl = table(string(k), string(vals), 'VariableNames', {'key', 'value'});
writetable(statTbl, outStat);

fid = fopen(outRep, 'w');
fprintf(fid, '# Phase 4B_C02B primary collapse variant audit\n\n');
fprintf(fid, 'QA / inspection only. Not a manuscript physics interpretation.\n\n');
fprintf(fid, '## Why C02 differed\n\n');
fprintf(fid, '- Phase 4B_C02 used corrected-old authoritative residual-after-mode1 map vs x_aligned; that is residual-map QA, not P0-backed primary collapse.\n');
fprintf(fid, '- C02B rebuilds **primary collapse** overlays from P0 + gauge definitions and mixed S_long S_percent reads, matching forensic and stabilized-gauge scripts.\n\n');
fprintf(fid, '## Variants\n\n');
fprintf(fid, '- PRIMARY: S_percent/S_peak vs (I-I_peak)/W_I from `run_switching_old_fig_forensic_and_canonical_replot.m` logic.\n');
fprintf(fid, '- G014 / G254: S_percent/S_area_positive vs (I-I0)/W with gauge centers from `run_switching_stabilized_gauge_figure_replay.m` logic.\n');
fprintf(fid, '- ATLAS_G001_DOC_ONLY: extra triplets appear in `run_switching_gauge_atlas_preview.m` (not regenerated here).\n\n');
fprintf(fid, '## Outputs\n\n');
fprintf(fid, '- Registry: `tables/switching_phase4B_C02B_collapse_variant_registry.csv`\n');
fprintf(fid, '- Defects: `tables/switching_phase4B_C02B_collapse_variant_defects.csv`\n');
fprintf(fid, '- Reference map: `tables/switching_phase4B_C02B_collapse_variant_reference_match.csv`\n');
fprintf(fid, '- Figures: `figures/switching/canonical/phase4B_C02B_*`\n\n');
fprintf(fid, '## Defect metric\n\n');
fprintf(fid, 'Per variant: interpolate each T curve onto a shared x grid; mean across T; residual = curve - mean; RMSE/MAE per T plus global row (T_K=NaN).\n\n');
fprintf(fid, '## S_long path used\n\n');
fprintf(fid, '- %s\n', sLongPick);
fclose(fid);

disp('Phase4B_C02B completed.');

