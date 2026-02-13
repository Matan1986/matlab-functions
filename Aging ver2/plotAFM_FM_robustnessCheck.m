function [AFM_all, FM_all, diag] = plotAFM_FM_robustnessCheck( ...
    pauseRuns, dip_window_K, ...
    excludeLowT_FM, excludeLowT_K, excludeLowT_mode, ...
    paramSet, fontsize, plotOpts)
% plotAFM_FM_robustnessCheck
% ------------------------------------------------------------
% Robustness sanity-check of AFM / FM decomposition
% using MULTIPLE equivalent parameter sets.
%
% ✅ Plots MANY curves cleanly with a calm colormap (parula)
% ✅ Avoids giant legends (optional: show only a subset)
% ✅ Prints detailed diagnostics to Command Window:
%    - invalid (NaN/Inf) counts per parameter set
%    - invalid counts per Tp
%    - highlights "worst" parameter sets + worst Tp points
%
% Uses analyzeAFM_FM_components (NO fitting).
%
% paramSet : struct array with fields
%   .label
%   .smoothWindow_K
%   .FM_plateau_K
%   .FM_buffer_K
%
% OUTPUT:
%   AFM_all : [nSet x nTp]
%   FM_all  : [nSet x nTp]
%   diag    : struct with diagnostics
% ------------------------------------------------------------

if nargin < 7 || isempty(fontsize), fontsize = 16; end
if nargin < 8, plotOpts = struct(); end

% ---------------- defaults ----------------
plotOpts = setDefault(plotOpts,'colormap','parula');     % 'parula' | 'turbo' | 'gray'
plotOpts = setDefault(plotOpts,'cmapCompress',[0.15 0.85]); % avoid very bright ends
plotOpts = setDefault(plotOpts,'lineWidth',1.2);
plotOpts = setDefault(plotOpts,'markerSize',5);
plotOpts = setDefault(plotOpts,'alpha',0.35);           % if supported
plotOpts = setDefault(plotOpts,'showLegend',false);     % legend explodes for many curves
plotOpts = setDefault(plotOpts,'maxLegendItems',12);
plotOpts = setDefault(plotOpts,'printToCMD',true);
plotOpts = setDefault(plotOpts,'topK_worstSets',8);
plotOpts = setDefault(plotOpts,'topK_worstTp',8);
plotOpts = setDefault(plotOpts,'sampleCurvesToPlot',Inf); % Inf = plot all, or an integer
plotOpts = setDefault(plotOpts,'titlePrefix','AFM/FM robustness check');

% ---------------- init ----------------
nSet = numel(paramSet);
Tp   = [pauseRuns.waitK];
nTp  = numel(Tp);

AFM_all = NaN(nSet, nTp);
FM_all  = NaN(nSet, nTp);

% Keep per-set metadata for printing
smoothK = NaN(nSet,1);
plK     = NaN(nSet,1);
bufK    = NaN(nSet,1);
labels  = strings(nSet,1);
for s = 1:nSet
    labels(s)  = string(paramSet(s).label);
    smoothK(s) = paramSet(s).smoothWindow_K;
    plK(s)     = paramSet(s).FM_plateau_K;
    bufK(s)    = paramSet(s).FM_buffer_K;
end

% ---------------- Run decomposition for each parameter set ----------------
for s = 1:nSet
    pr = pauseRuns;  % copy — DO NOT TOUCH ORIGINAL
    pr = analyzeAFM_FM_components( ...
        pr, dip_window_K, paramSet(s).smoothWindow_K, ...
        excludeLowT_FM, excludeLowT_K, ...
        paramSet(s).FM_plateau_K, excludeLowT_mode, ...
        paramSet(s).FM_buffer_K);

    % NOTE: AFM_amp should exist; FM_step_mag can be NaN if windows are invalid
    AFM_all(s,:) = [pr.AFM_amp];
    FM_all(s,:)  = [pr.FM_step_mag];
end

xlim_common = [min(Tp) max(Tp)];

% ---------------- Diagnostics ----------------
AFM_valid = isfinite(AFM_all);
FM_valid  = isfinite(FM_all);

AFM_invalid_perSet = nTp - sum(AFM_valid, 2);
FM_invalid_perSet  = nTp - sum(FM_valid, 2);

AFM_invalid_perTp  = nSet - sum(AFM_valid, 1);
FM_invalid_perTp   = nSet - sum(FM_valid, 1);

diag = struct();
diag.nSet = nSet;
diag.nTp  = nTp;
diag.Tp   = Tp;
diag.labels = labels;
diag.smoothWindow_K = smoothK;
diag.FM_plateau_K   = plK;
diag.FM_buffer_K    = bufK;
diag.AFM_invalid_perSet = AFM_invalid_perSet;
diag.FM_invalid_perSet  = FM_invalid_perSet;
diag.AFM_invalid_perTp  = AFM_invalid_perTp;
diag.FM_invalid_perTp   = FM_invalid_perTp;

% Print summary
if plotOpts.printToCMD
    fprintf('\n============================================================\n');
    fprintf('%s — Diagnostics\n', plotOpts.titlePrefix);
    fprintf('nSet = %d | nTp = %d | dip_window_K = %.3g\n', nSet, nTp, dip_window_K);
    fprintf('excludeLowT_FM = %d | excludeLowT_K = %.3g | excludeLowT_mode = %s\n', ...
        logical(excludeLowT_FM), excludeLowT_K, string(excludeLowT_mode));
    fprintf('------------------------------------------------------------\n');

    fprintf('AFM invalid points: total = %d (of %d)\n', sum(~AFM_valid,'all'), nSet*nTp);
    fprintf(' FM invalid points: total = %d (of %d)\n', sum(~FM_valid,'all'),  nSet*nTp);

    % Worst parameter sets (by FM invalid count)
    [~, idxWorstFM] = sort(FM_invalid_perSet, 'descend');
    K = min(plotOpts.topK_worstSets, nSet);

    fprintf('\nWorst parameter sets by FM invalid count (top %d):\n', K);
    fprintf('  %-4s %-6s  %-9s %-10s %-10s  %-12s  %s\n', ...
        'Rank','Set#','FM_bad','smooth(K)','plateau(K)','buffer(K)','label');
    for r = 1:K
        s = idxWorstFM(r);
        fprintf('  %-4d %-6d  %-9d %-10.3g %-10.3g %-10.3g  %s\n', ...
            r, s, FM_invalid_perSet(s), smoothK(s), plK(s), bufK(s), labels(s));
    end

    % Worst Tp points (by FM invalid across sets)
    [~, idxWorstTp] = sort(FM_invalid_perTp(:), 'descend');
    Ktp = min(plotOpts.topK_worstTp, nTp);

    fprintf('\nWorst pause temperatures by FM invalid across sets (top %d):\n', Ktp);
    fprintf('  %-4s %-10s  %-12s\n', 'Rank','Tp(K)','FM_bad_sets');
    for r = 1:Ktp
        kTp = idxWorstTp(r);
        fprintf('  %-4d %-10.3g  %-12d\n', r, Tp(kTp), FM_invalid_perTp(kTp));
    end

    % Quick sanity: if AFM has invalids (unexpected), flag it
    if any(AFM_invalid_perSet > 0)
        fprintf('\nWARNING: AFM_amp had invalid entries in some sets.\n');
        [~, idxWorstAFM] = sort(AFM_invalid_perSet, 'descend');
        Kw = min(5, nSet);
        fprintf('Top sets with AFM invalid:\n');
        for r = 1:Kw
            s = idxWorstAFM(r);
            if AFM_invalid_perSet(s) == 0, break; end
            fprintf('  Set %d: AFM_bad=%d | %s\n', s, AFM_invalid_perSet(s), labels(s));
        end
    end

    fprintf('============================================================\n\n');
end

% ---------------- Plot styling (many curves) ----------------
switch lower(string(plotOpts.colormap))
    case "parula"
        cmap = parula(nSet);
    case "turbo"
        cmap = turbo(nSet);
    case "gray"
        cmap = gray(nSet);
    otherwise
        cmap = parula(nSet);
end

% Compress colormap range to avoid bright/yellow extremes
a = plotOpts.cmapCompress(1);
b = plotOpts.cmapCompress(2);
a = max(0,min(1,a)); b = max(0,min(1,b));
if b <= a, a = 0.15; b = 0.85; end
cmap = interp1(linspace(0,1,nSet), cmap, linspace(a,b,nSet));

lw   = plotOpts.lineWidth;
ms   = plotOpts.markerSize;
alp  = plotOpts.alpha;

% If too many curves, optionally subsample which sets to plot (still compute diagnostics on all)
plotIdx = 1:nSet;
if isfinite(plotOpts.sampleCurvesToPlot) && plotOpts.sampleCurvesToPlot < nSet
    plotIdx = unique(round(linspace(1, nSet, max(2, plotOpts.sampleCurvesToPlot))));
end

% ---------------- Plot ----------------
figure('Color','w','Name',plotOpts.titlePrefix,'NumberTitle','off');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

% === AFM panel ===
nexttile; hold on;
for s = plotIdx
    p = plot(Tp, AFM_all(s,:), 'o-', ...
        'Color', cmap(s,:), ...
        'LineWidth', lw, 'MarkerSize', ms);

    % alpha (only if MATLAB supports RGBA line colors)
    if numel(p.Color) == 4
        p.Color(4) = alp;
    end
end
xlim(xlim_common);
ylabel('AFM dip amplitude');

% === FM panel ===
nexttile; hold on;
for s = plotIdx
    valid = isfinite(FM_all(s,:));
    p = plot(Tp(valid), FM_all(s,valid), 's--', ...
        'Color', cmap(s,:), ...
        'LineWidth', lw, 'MarkerSize', ms);

    if numel(p.Color) == 4
        p.Color(4) = alp;
    end
end
xlim(xlim_common);
xlabel('Pause temperature T_p (K)');
ylabel('FM background step');

set(findall(gcf,'-property','FontSize'),'FontSize',fontsize);

% Optional: tiny legend only if few curves
if plotOpts.showLegend
    if numel(plotIdx) <= plotOpts.maxLegendItems
        legend(labels(plotIdx), 'Location','best', 'Interpreter','none');
    else
        legend(labels(plotIdx(1:plotOpts.maxLegendItems)), 'Location','best', 'Interpreter','none');
    end
end

% Tiny annotation: number of sets + plotted
axTop = findall(gcf,'Type','axes');
if ~isempty(axTop)
    try
        axes(axTop(end)); %#ok<LAXES>
        text(0.01, 0.93, sprintf('nSet=%d | plotted=%d', nSet, numel(plotIdx)), ...
            'Units','normalized','FontSize',max(10,fontsize-4), ...
            'BackgroundColor','w','EdgeColor',[0.85 0.85 0.85], 'Margin',4);
    catch
        % ignore
    end
end

end

% ===========================
function opts = setDefault(opts,f,v)
if ~isfield(opts,f) || isempty(opts.(f))
    opts.(f) = v;
end
end
