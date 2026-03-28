function plotAmpTempSwitchingMap_switchCh( ...
    parentDir, metricType, channelMode, plotAmpTempMode, FC_amp_subset, ...
    swapAxes, useMathLabels, showOverlay,ridge_vis_mode)
% Amp–Temp switching map with TEMPERATURE BINNING
% Figure Name = META ONLY (preset-based labels)
% No title, no LaTeX in Name

% ---------------- input defaults ----------------
if nargin < 3 || isempty(channelMode)
    channelMode = "switchCh";
end
if nargin < 4 || isempty(plotAmpTempMode)
    plotAmpTempMode = "map";
end
if nargin < 5 || isempty(FC_amp_subset)
    FC_amp_subset = [];
end
if nargin < 6 || isempty(swapAxes)
    swapAxes = false;
end
if nargin < 7 || isempty(useMathLabels)
    useMathLabels = false;
end
if nargin < 8 || isempty(showOverlay)
    showOverlay = false;
end

if nargin < 9 || isempty(ridge_vis_mode)
    ridge_vis_mode = 'smooth_map';
end

% options:
% 'raw'          -> raw argmax ridge (staircase)
% 'smooth_map'   -> argmax on smoothed map (recommended)
% 'refined'      -> parabolic sub-pixel refinement

validModes = ["raw","smooth_map","refined"];
ridge_vis_mode = string(ridge_vis_mode);

if ~ismember(ridge_vis_mode, validModes)
    ridge_vis_mode = "smooth_map";
end

doFCstack = (plotAmpTempMode == "map+fc");

% ---------------- defaults ----------------
Resistivity = false;
swap_Rxy_direction = false;

RemovePulseOutliers = true;
PulseOutlierPercent = 1.5;
safety_margin_for_outlier_clean_in_percent = 50;

hample_filter_window_size = 4000;
HampelGlobalPercent = 4;
med_filter_window_size = 16;
SG_filter_poly_order = 2;
SG_filter_frame_size = 11;

safety_margin_for_average_between_pulses_in_percent = 15;

force_manual_preset = true;
manual_preset_name  = '1xy_3xx';

NegP2P = resolveNegP2P(parentDir,"auto");
debugMode = false;

% ---------------- find Temp Dep subfolders ----------------
d = dir(parentDir);
names = string({d.name});
isSub  = [d.isdir] & ~startsWith(names,'.');
isTemp = contains(names,"Temp Dep",'IgnoreCase',true);
subDirs = d(isSub & isTemp);

assert(~isempty(subDirs),'No "Temp Dep ..." folders found');

% ---------------- containers ----------------
if doFCstack
    FCpack = struct('stored',{},'amp',{},'meta',{},'plotChannels',{});
end

Vpack = struct('amp',{},'T',{},'V',{},'ch',{});
amps_all = [];
T_all    = [];

% -------- channel → label map (preset identity) --------
chLabelMap = containers.Map('KeyType','int32','ValueType','char');
interpFactor = 9;   % היה 5 | מומלץ: 7–8 | לא לעבור 10
fs       = 18;

% ================= MAIN LOOP =================
for iDir = 1:numel(subDirs)

    thisDir = fullfile(parentDir,subDirs(iDir).name);

    dep_type = extract_dep_type_from_folder(thisDir);
    [fileList, sortedValues, colors, meta] = getFileListSwitching(thisDir,dep_type);
    if isempty(fileList), continue; end

    amp = meta.Current_mA;
    if ~isfinite(amp), continue; end

    pulseScheme = extractPulseSchemeFromFolder(thisDir);
    delay_between_pulses_in_msec = ...
        extract_delay_between_pulses_from_name(thisDir)*1e3;

    num_of_pulses_with_same_dep = pulseScheme.totalPulses;

    preset_name = resolve_preset(fileList(1).name, ...
        force_manual_preset, manual_preset_name);

    [~, plotChannels, labels, Normalize_to] = select_preset(preset_name);

    % ---- build channel identity map ONCE ----
    if isempty(chLabelMap)
        for k = 1:4
            chKey = sprintf('ch%d',k);
            if isfield(labels,chKey) && ~isempty(labels.(chKey))
                chLabelMap(k) = labels.(chKey);
            end
        end
    end

    [growth_num, FIB_num] = extract_growth_FIB(thisDir,fileList(1).name);
    I = extract_current_I(thisDir,fileList(1).name,NaN);

    [Scaling_factor, ~] = getScalingFactor(growth_num,FIB_num);
    if ~Resistivity, Scaling_factor = 1e3; end

    [stored_data, tableData] = processFilesSwitching( ...
        thisDir, fileList, sortedValues, I, Scaling_factor, ...
        hample_filter_window_size, med_filter_window_size, HampelGlobalPercent, ...
        SG_filter_poly_order, SG_filter_frame_size, ...
        swap_Rxy_direction, delay_between_pulses_in_msec, ...
        num_of_pulses_with_same_dep, safety_margin_for_average_between_pulses_in_percent, ...
        NaN, NaN, Normalize_to, ...
        RemovePulseOutliers, PulseOutlierPercent, ...
        safety_margin_for_outlier_clean_in_percent, debugMode, pulseScheme);




    stbOpts = struct();
    stbOpts.useFiltered = true;
    stbOpts.useCentered = false;
    stbOpts.stateMethod = pulseScheme.mode;
    stbOpts.skipFirstPlateaus = 1;
    stbOpts.skipLastPlateaus  = 0;
    stbOpts.pulseScheme = pulseScheme;

    stability = analyzeSwitchingStability( ...
        stored_data, sortedValues, ...
        delay_between_pulses_in_msec, ...
        safety_margin_for_average_between_pulses_in_percent, stbOpts);
    % ---- store FC for stacked plot (ONLY if requested) ----
    if doFCstack
        folderSwitchCh = stability.switching.globalChannel;  % scalar usually

        FCpack(end+1).stored = stored_data;
        FCpack(end).amp = amp;
        FCpack(end).meta = meta;
        FCpack(end).plotChannels = plotChannels;
        FCpack(end).Tvals = sortedValues(:);
        FCpack(end).switchCh = folderSwitchCh;
    end

    switch channelMode
        case "switchCh"
            chList = stability.switching.globalChannel;
        case "all"
            chList = find([plotChannels.ch1,plotChannels.ch2,...
                plotChannels.ch3,plotChannels.ch4]);
        otherwise
            error('plotAmpTempSwitchingMap_switchCh:BadChannelMode', ...
                'channelMode must be "switchCh" or "all".');
    end

    for ch = chList
        [Tvec,Vvec] = extractMetric_switchCh_tableData( ...
            tableData,ch,metricType,NegP2P);
        if isempty(Tvec), continue; end

        entry.amp = amp;
        entry.T   = Tvec(:);
        entry.V   = Vvec(:);
        entry.ch  = ch;

        Vpack(end+1) = entry; %#ok<AGROW>
        amps_all(end+1) = amp; %#ok<AGROW>
        T_all = [T_all; Tvec(:)]; %#ok<AGROW>
    end
end

% ---- optional stacked FC figure ----
if doFCstack && exist('FCpack','var') && ~isempty(FCpack)

    if ~isempty(FC_amp_subset)
        keep = ismember([FCpack.amp], FC_amp_subset);
        FCpack = FCpack(keep);
    end

    plotAmpTemp_FilteredCenteredStacked(FCpack, chLabelMap, Resistivity);
end


assert(~isempty(Vpack),'No valid data collected');

% ================= TEMPERATURE BINNING =================
T_bins = unique(round(T_all));
amps   = sort(unique(amps_all));

channelsPlotted = unique([Vpack.ch]);

% ================= BUILD & PLOT =================
for ch = channelsPlotted

    M = NaN(numel(amps),numel(T_bins));

    for i = 1:numel(Vpack)
        if Vpack(i).ch ~= ch, continue; end
        ia = find(amps == Vpack(i).amp,1);

        for k = 1:numel(Vpack(i).T)
            [~,it] = min(abs(T_bins - Vpack(i).T(k)));
            if ~isnan(Vpack(i).V(k))
                M(ia,it) = Vpack(i).V(k);
            end
        end
    end

    % ---- fill missing bins (1D nearest) ----
    M_filled = M;
    for ia = 1:size(M,1)
        row = M_filled(ia,:);
        for it = 1:numel(row)
            if ~isnan(row(it)), continue; end
            L = find(~isnan(row(1:it-1)),1,'last');
            R = find(~isnan(row(it+1:end)),1,'first');
            if ~isempty(R), R = R + it; end
            if ~isempty(L) && ~isempty(R)
                row(it) = 0.5*(row(L)+row(R));
            elseif ~isempty(L)
                row(it) = row(L);
            elseif ~isempty(R)
                row(it) = row(R);
            end
        end
        M_filled(ia,:) = row;
    end

    % ================= FIGURE =================
    if isKey(chLabelMap,ch)
        chDisp = chLabelMap(ch);
    else
        chDisp = sprintf('ch%d',ch);
    end

    figName = sprintf('Amp-Temp switching map | %s | %s', ...
        metricType, chDisp);

    fig = figure( ...
        'Name', figName, ...
        'NumberTitle','off', ...
        'Color','w');

    ax = axes(fig);

    % ---- interpolation ----
    [Tm, Am] = meshgrid(T_bins, amps);
    [Tq, Aq] = meshgrid( ...
        linspace(min(T_bins), max(T_bins), interpFactor*numel(T_bins)), ...
        linspace(min(amps),   max(amps),   interpFactor*numel(amps)));

    M_interp = interp2(Tm, Am, M_filled, Tq, Aq, 'linear');
    M_interp = imgaussfilt(M_interp,0.5);
    M_interp = sign(M_interp) .* abs(M_interp).^0.8;
    if ~isreal(M_interp)
        warning('M_interp contains complex values — taking real part');
        M_interp = real(M_interp);
    end

    % ---- draw image ----
    if swapAxes
        hImg = imagesc(ax, Aq(:,1), Tq(1,:), M_interp');  % <-- TRANSPOSE!!!
    else
        hImg = imagesc(ax, Tq(1,:), Aq(:,1), M_interp);
    end

    % --- Try to use Oslo scientific colormap ---
    cmap = [];

    % Option A: function exists
    if exist('loadScientificColourMaps','file') == 2
        try
            maps = loadScientificColourMaps();
            if isfield(maps,'oslo')
                cmap = maps.oslo;
            end
        catch
        end
    end

    % Option B: local folder fallback
    if isempty(cmap)
        try
            basePath = fileparts(mfilename('fullpath'));
            cmapPath = fullfile(basePath,'ScientificColourMaps8','oslo.mat');
            if exist(cmapPath,'file')
                s = load(cmapPath);
                fn = fieldnames(s);
                cmap = s.(fn{1});
            end
        catch
        end
    end

    % Option C: fallback
    if isempty(cmap)
        cmap = parula(256);
    end

    colormap(ax, cmap);

    set(ax,'YDir','normal');

    if swapAxes
        alphaMask = double(~isnan(M_interp')) ;
    else
        alphaMask = double(~isnan(M_interp));
    end

    set(hImg, ...
        'AlphaData', alphaMask, ...
        'AlphaDataMapping','none', ...
        'Interpolation','bilinear');

    % ---- contours ----
    hold(ax,'on')

    % --- smooth ridge via weighted center of mass ---

    Z = M_interp;
    Z = Z - min(Z(:),[],'omitnan');
    Z = Z ./ max(Z(:),[],'omitnan');

    p = 3;                 % sharpening exponent (2–4 טוב)
    W = Z.^p;

    num = sum(Aq .* W, 1, 'omitnan');
    den = sum(W,       1, 'omitnan');
    Ir  = num ./ max(den, eps);

    % final smoothing
    Ir = smoothdata(Ir,'gaussian',21);

    % Overlay defaults (legacy ridge/width from map itself).
    I_overlay = Ir;
    width_overlay = NaN(size(Ir));
    S_peak_overlay = NaN(size(Ir));
    useCanonicalOverlay = false;
    if showOverlay
        obsOverlay = loadCollapseOverlayObservables(Tq(1,:));
        if obsOverlay.loaded
            I_overlay = obsOverlay.I_peak(:).';
            width_overlay = obsOverlay.width(:).';
            S_peak_overlay = obsOverlay.S_peak(:).';
            useCanonicalOverlay = true;
            fprintf('[OVERLAY] using canonical observables (collapse)\n');
        else
            % fallback to legacy overlay computation
            fprintf('[OVERLAY] using legacy overlay (fallback)\n');
        end
    end

    Tcut = 32;

    if showOverlay
        % ================= COLOR =================
        overlayColor = [1 0.8 0.2];   % strong visibility on Oslo
        widthMarkerColor = [0.9 0.9 0.9];

        I_axis = Aq(:,1);
        T_axis = Tq(1,:);

        % ridge_method is kept for extensibility.
        % current visualization uses smoothed-map ridge only.
        ridge_method = 'argmax';

        switch ridge_method
            case 'argmax'
                [~, idx_ridge] = max(M_interp, [], 1);
                idx_ridge = idx_ridge(:);
                I_ridge = I_axis(idx_ridge);

            case 'parabolic'
                I_ridge = nan(size(T_axis));
                for j = 1:numel(T_axis)
                    idx = idx_ridge(j);
                    if idx > 1 && idx < size(M_interp,1)
                        y1 = M_interp(idx-1,j);
                        y2 = M_interp(idx,  j);
                        y3 = M_interp(idx+1,j);

                        denom = (y1 - 2*y2 + y3);

                        if abs(denom) > eps
                            delta = 0.5 * (y1 - y3) / denom;
                        else
                            delta = 0;
                        end

                        dI = I_axis(2) - I_axis(1);
                        I_ridge(j) = I_axis(idx) + delta * dI;
                    else
                        I_ridge(j) = I_axis(idx);
                    end
                end

            case 'centroid'
                I_ridge = nan(size(T_axis));
                for j = 1:numel(T_axis)
                    idx = idx_ridge(j);

                    i1 = max(1, idx-2);
                    i2 = min(size(M_interp,1), idx+2);

                    I_loc = I_axis(i1:i2);
                    W_loc = M_interp(i1:i2, j);

                    valid_loc = isfinite(I_loc) & isfinite(W_loc);
                    I_loc = I_loc(valid_loc);
                    W_loc = W_loc(valid_loc);

                    if isempty(W_loc) || sum(W_loc) <= 0
                        I_ridge(j) = I_axis(idx);
                    else
                        I_ridge(j) = sum(I_loc .* W_loc) / sum(W_loc);
                    end
                end

            case 'weighted'
                I_ridge = Ir;

            otherwise
                [~, idx_ridge] = max(M_interp, [], 1);
                idx_ridge = idx_ridge(:);
                I_ridge = I_axis(idx_ridge);
        end

        I_ridge = I_ridge(:);

        % --- Alternative visual ridge methods (optional, not used) ---
        % % Parabolic sub-pixel refinement
        % % (kept for future use, currently disabled)
        %
        % % Local centroid method
        % % (kept for future use, currently disabled)
        %
        % % Interpolation-based smoothing
        % % (kept for future use, currently disabled)

        T_axis_vis = T_axis(:);

        % NOTE:
        % Ridge is interpolated along temperature for visualization only.
        % All quantitative analysis uses the raw ridge (I_ridge).
        T_dense = linspace(min(T_axis), max(T_axis), 600);
        I_dense = linspace(min(I_axis), max(I_axis), 600);

        [Tq_dense, Iq_dense] = meshgrid(T_dense, I_dense);

        M_dense = interp2(T_bins, amps, M_filled, Tq_dense, Iq_dense, 'spline');
        M_dense = imgaussfilt(M_dense, 0.8);

        I_ridge_vis = nan(1, size(M_dense,2));
        I_ridge_vis = nan(1, size(M_dense,2));

        for j = 1:size(M_dense,2)
            col = M_dense(:,j);

            % remove NaNs
            valid = isfinite(col);

            if ~any(valid)
                continue;
            end

            col_valid = col(valid);
            I_valid   = I_dense(valid);

            [mx, ~] = max(col_valid);

            % threshold around peak
            mask = col_valid > 0.7 * mx;

            if ~any(mask)
                % fallback → argmax
                [~, idx] = max(col_valid);
                I_ridge_vis(j) = I_valid(idx);
            else
                w = col_valid(mask);
                x = I_valid(mask);

                w = w(:);
                x = x(:);

                I_ridge_vis(j) = sum(x .* w) / sum(w);
            end
        end
        T_axis_vis = T_dense(:);
        I_ridge_vis = I_ridge_vis(:);

        valid_vis = isfinite(T_axis_vis) & isfinite(I_ridge_vis) & (T_axis_vis <= Tcut);
        valid_vis = valid_vis(:);

        assert(numel(T_axis) == numel(I_ridge), 'Ridge size mismatch');

        if swapAxes
            plot(ax, I_ridge_vis(valid_vis), T_axis_vis(valid_vis), ...
                '--','Color', overlayColor, 'LineWidth', 1.2);
        else
            plot(ax, T_axis_vis(valid_vis), I_ridge_vis(valid_vis), ...
                '--','Color', overlayColor, 'LineWidth', 1.2);
        end

        % NOTE:
        % Label indicates that the visual ridge approximates I_peak(T).
        % It is a guide only and not used in analysis.
        % --- Ridge label (visual guide) ---
        midIdx = round(numel(T_axis_vis) * 0.7);   % place away from center/W
        x_text = I_ridge_vis(midIdx);
        y_text = T_axis_vis(midIdx);

        text(ax, x_text, y_text, '$\sim I_{peak}$', ...
            'Color', overlayColor, ...
            'FontSize', 14, ...
            'FontWeight', 'bold', ...
            'Interpreter', 'latex');

        % ===== WIDTH =====
        T_target = 20;
        [~, it] = min(abs(Tq(1,:) - T_target));

        I = Aq(:,it);
        S = M_interp(:,it);
        S = S - min(S);

        if any(diff(I) <= 0)
            [I, sortIdx] = sort(I);
            S = S(sortIdx);
        end

        hasLeft = false;
        hasRight = false;
        I_left = NaN;
        I_right = NaN;
        if useCanonicalOverlay && isfinite(I_overlay(it)) && isfinite(width_overlay(it)) && width_overlay(it) > eps
            S_peak = S_peak_overlay(it);
            halfMax = 0.5 * S_peak; %#ok<NASGU>
            I_left = I_overlay(it) - 0.5 * width_overlay(it);
            I_right = I_overlay(it) + 0.5 * width_overlay(it);
            hasLeft = isfinite(I_left);
            hasRight = isfinite(I_right);
        else
            [~, iPeak] = min(abs(I - I_overlay(it)));
            S_peak = S(iPeak);
            halfMax = 0.5 * S_peak;

            iL = find(S(1:iPeak) <= halfMax, 1, 'last');
            if ~isempty(iL) && iL < iPeak
                s1 = S(iL);
                s2 = S(iL+1);
                ds = s2 - s1;
                if abs(ds) > eps
                    I_left = I(iL) + (halfMax - s1) * (I(iL+1) - I(iL)) / ds;
                    hasLeft = true;
                end
            end

            iRrel = find(S(iPeak:end) <= halfMax, 1, 'first');
            if ~isempty(iRrel) && iRrel > 1
                iR = iPeak + iRrel - 1;
                s1 = S(iR-1);
                s2 = S(iR);
                ds = s2 - s1;
                if abs(ds) > eps
                    I_right = I(iR-1) + (halfMax - s1) * (I(iR) - I(iR-1)) / ds;
                    hasRight = true;
                end
            end
        end

        if ~(hasLeft && hasRight && isfinite(I_left) && isfinite(I_right) && I_right > I_left)
            fprintf('[WIDTH] fallback used at T=%.1f K\n', Tq(1,it));
            col = M_interp(:,it);
            col = col - min(col);
            col = col ./ (max(col) + eps);

            Wloc = col.^3;

            num = sum(Aq(:,it) .* Wloc, 'omitnan');
            den = sum(Wloc, 'omitnan');
            Icm = num / max(den,eps);

            var = sum(Wloc .* (Aq(:,it)-Icm).^2, 'omitnan') / max(den,eps);
            w = sqrt(var);

            I_left  = Icm - w;
            I_right = Icm + w;
        else
            fprintf('[WIDTH] FWHM used at T=%.1f K\n', Tq(1,it));
        end

        dt = 0.2;

        if swapAxes
            plot(ax, [I_left I_right], [Tq(1,it) Tq(1,it)], ...
                 '--','Color', widthMarkerColor, 'LineWidth',1.2);

            plot(ax, [I_left I_left], [Tq(1,it)-dt Tq(1,it)+dt], ...
                 '--','Color', widthMarkerColor, 'LineWidth',1.2);

            plot(ax, [I_right I_right], [Tq(1,it)-dt Tq(1,it)+dt], ...
                 '--','Color', widthMarkerColor, 'LineWidth',1.2);

            text(ax, I_right, Tq(1,it)+0.5, '$w$', ...
                'Color', widthMarkerColor, ...
                'FontSize',14, 'Interpreter','latex');

        else
            plot(ax, [Tq(1,it) Tq(1,it)], [I_left I_right], ...
                'Color', widthMarkerColor, 'LineWidth',1.2);

            plot(ax, [Tq(1,it)-dt Tq(1,it)+dt], [I_left I_left], ...
                'Color', widthMarkerColor, 'LineWidth',1.2);

            plot(ax, [Tq(1,it)-dt Tq(1,it)+dt], [I_right I_right], ...
                'Color', widthMarkerColor, 'LineWidth',1.2);

            text(ax, Tq(1,it)+0.5, I_right, 'w', ...
                'Color', widthMarkerColor, ...
                'FontSize',14,'Interpreter','latex');
        end

    end

    % ---- axes typography ----
    if useMathLabels
        if swapAxes
            xlabel(ax,'I (mA)','Interpreter','latex','FontSize',fs);
            ylabel(ax,'T (K)','Interpreter','latex','FontSize',fs);
        else
            xlabel(ax,'T (K)','Interpreter','latex','FontSize',fs);
            ylabel(ax,'I (mA)','Interpreter','latex','FontSize',fs);
        end
    else
        if swapAxes
            xlabel(ax,'Current (mA)','Interpreter','latex','FontSize',fs);
            ylabel(ax,'Temperature (K)','Interpreter','latex','FontSize',fs);
        else
            xlabel(ax,'Temperature (K)','Interpreter','latex','FontSize',fs);
            ylabel(ax,'Current (mA)','Interpreter','latex','FontSize',fs);
        end
    end

    ax.TickLabelInterpreter = 'latex';
    ax.TickDir = 'out';
    ax.Layer   = 'top';
    ax.FontSize = fs;

    % ---- colorbar ----
    cb = colorbar(ax);
    if useMathLabels
        ylabel(cb,'$S\ (\%)$','Interpreter','latex','FontSize',fs);
    else
        switch metricType
            case "P2P_percent"
                ylabel(cb,'\DeltaR/R (%)','Interpreter','latex','FontSize',fs);
            otherwise
                ylabel(cb,'\DeltaR/R','Interpreter','latex','FontSize',fs);
        end
    end
    cb.TickLabelInterpreter = 'latex';
    cb.FontSize = fs;
    forceLatexFigure(fig);
end
end



% =====================================================================
% Helpers
% =====================================================================
function obs = loadCollapseOverlayObservables(Tquery)
obs = struct( ...
    'loaded', false, ...
    'sourcePath', "", ...
    'message', "", ...
    'I_peak', NaN(size(Tquery)), ...
    'width', NaN(size(Tquery)), ...
    'S_peak', NaN(size(Tquery)));

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');
if exist(runsRoot, 'dir') ~= 7
    obs.message = sprintf('missing runs root: %s', runsRoot);
    return;
end

paramsPath = "";
if exist('getLatestRun', 'file') == 2
    try
        runId = string(getLatestRun('switching'));
        paramsCandidate = fullfile(runsRoot, char(runId), 'tables', 'switching_full_scaling_parameters.csv');
        if exist(paramsCandidate, 'file') == 2
            paramsPath = string(paramsCandidate);
        end
    catch
    end
end

if strlength(paramsPath) == 0
    runDirs = dir(fullfile(runsRoot, 'run_*'));
    runDirs = runDirs([runDirs.isdir]);
    if isempty(runDirs)
        obs.message = 'no switching run_* directories';
        return;
    end
    [~, order] = sort([runDirs.datenum], 'descend');
    runDirs = runDirs(order);
    for k = 1:numel(runDirs)
        paramsCandidate = fullfile(runDirs(k).folder, runDirs(k).name, 'tables', 'switching_full_scaling_parameters.csv');
        if exist(paramsCandidate, 'file') == 2
            paramsPath = string(paramsCandidate);
            break;
        end
    end
end

if strlength(paramsPath) == 0
    obs.message = 'switching_full_scaling_parameters.csv not found';
    return;
end

tbl = readtable(char(paramsPath));
required = {'T_K','Ipeak_mA','width_chosen_mA','S_peak'};
if ~all(ismember(required, tbl.Properties.VariableNames))
    obs.message = sprintf('missing required columns in %s', paramsPath);
    return;
end

Tobs = double(tbl.T_K(:));
Iobs = double(tbl.Ipeak_mA(:));
Wobs = double(tbl.width_chosen_mA(:));
Sobs = double(tbl.S_peak(:));
validRows = isfinite(Tobs) & isfinite(Iobs);
if ~any(validRows)
    obs.message = 'no finite T/I_peak rows in collapse observables';
    return;
end

Tobs = Tobs(validRows);
Iobs = Iobs(validRows);
Wobs = Wobs(validRows);
Sobs = Sobs(validRows);

Iout = NaN(size(Tquery));
Wout = NaN(size(Tquery));
Sout = NaN(size(Tquery));
for it = 1:numel(Tquery)
    [~, idx] = min(abs(Tobs - Tquery(it)));
    Iout(it) = Iobs(idx);
    Wout(it) = Wobs(idx);
    Sout(it) = Sobs(idx);
end

obs.loaded = true;
obs.sourcePath = paramsPath;
obs.I_peak = Iout;
obs.width = Wout;
obs.S_peak = Sout;
end

function [T, V] = extractMetric_switchCh_tableData(tableData, ch, metricType, NegP2P)

chName = sprintf('ch%d', ch);

if ~isfield(tableData, chName) || isempty(tableData.(chName))
    T = [];
    V = [];
    return;
end

tbl = tableData.(chName);

T = tbl(:,1);   % Temperature (dep)

switch metricType
    case "P2P_percent"
        V = tbl(:,4);   % ΔR/R [%]  <<< בדיוק כמו createP2PSwitching
        if NegP2P
            V = -V;
        end

    case "meanP2P"
        V = tbl(:,2);   % avg_p2p (יחידות פנימיות)
        if NegP2P
            V = -V;
        end
    case "medianAbs"
        V = abs(tbl(:,4));   % |ΔR/R| [%]

    otherwise
        error('Unknown metricType: %s', string(metricType));
end
end





function plotAmpTemp_FilteredCenteredStacked(FCpack, chLabelMap, Resistivity)

% ========= USER KNOBS =========
Ttol     = 0.15;
fs       = 18;
useCmoceanThermal = true;

Ymin = -7;
Ymax =  7;

topMargin    = 0.04;
colorbarZone = 0.15;   % <<< זה המקום לבר (הפרמטר הקריטי)
gap          = 0.01;
% ==============================

Nblocks = numel(FCpack);
if Nblocks == 0
    warning('plotAmpTemp_FilteredCenteredStacked: empty FCpack');
    return;
end

% ---------- sort blocks by amplitude (max on top) ----------
ampsVec = [FCpack.amp];
[~, sortIdx] = sort(ampsVec,'descend');
FCpack = FCpack(sortIdx);

% ---------- channel per block ----------
chPerBlock = zeros(Nblocks,1);
for b = 1:Nblocks
    if isfield(FCpack(b),'switchCh') && ~isempty(FCpack(b).switchCh)
        chPerBlock(b) = FCpack(b).switchCh(1);
    else
        pc = FCpack(b).plotChannels;
        chMask = [pc.ch1 pc.ch2 pc.ch3 pc.ch4];
        chPerBlock(b) = find(chMask,1,'first');
    end
end

% ---------- temperature bins ----------
Tall_raw = vertcat(FCpack.Tvals);
Tall_raw = sort(Tall_raw(:));

Tall = Tall_raw(1);
for k = 2:numel(Tall_raw)
    if abs(Tall_raw(k)-Tall(end)) > Ttol
        Tall(end+1,1) = Tall_raw(k); %#ok<AGROW>
    end
end

Tmin = min(Tall);
Tmax = max(Tall);
Nt   = numel(Tall);

% ---------- colormap ----------
if useCmoceanThermal && exist('cmocean','file') == 2
    cmap = cmocean('thermal',256);
else
    cmap = parula(256);
end

% ---------- ylabel ----------
chRef = chPerBlock(1);
if isKey(chLabelMap,chRef)
    rawLabel = chLabelMap(chRef);
else
    rawLabel = sprintf('ch%d',chRef);
end
cleanLabel = cleanChannelLabel(rawLabel);

% --- normalize greek symbols ---
cleanLabel = strrep(cleanLabel,'ρ','\rho');
cleanLabel = strrep(cleanLabel,'Δ','\Delta');
cleanLabel = strrep(cleanLabel,'μ','\mu');

if Resistivity
    ylab = sprintf('$\\mathrm{%s\\ (\\mu\\Omega\\,cm)}$', cleanLabel);
else
    % --- HARD REPLACEMENT: rho -> R (no backslash survives) ---
    cleanLabel = regexprep(cleanLabel,'\\rho','R');

    % --- SAFETY NET: kill illegal \R if it already slipped in ---
    cleanLabel = regexprep(cleanLabel,'\\R','R');

    ylab = sprintf('$\\mathrm{%s\\ (m\\Omega)}$', cleanLabel);
end


% ================= FIGURE =================
fig = figure('Color','w',...
    'Name','Amp–Temp | filtered & centered (by TempDep)',...
    'NumberTitle','off');

ax = gobjects(Nblocks,1);

% ---------- draw panels ----------
for b = 1:Nblocks
    ax(b) = subplot(Nblocks,1,b);
    hold(ax(b),'on');
    box(ax(b),'on');
    grid(ax(b),'off');
    set(ax(b),'FontSize',fs-4);
    xlim(ax(b),[1 Nt+1]);
    ylim(ax(b),[Ymin Ymax]);
    set(ax(b),'XTick',[]);

    sd     = FCpack(b).stored;
    Tlocal = FCpack(b).Tvals(:);
    ch     = chPerBlock(b);

    for i = 1:size(sd,1)
        ctr = sd{i,3};
        y   = ctr(:,1+ch);
        y(y<Ymin | y>Ymax) = NaN;

        Ti = Tlocal(i);
        [dmin,idx] = min(abs(Tall-Ti));
        if dmin > Ttol, continue; end

        x = idx + linspace(0,1,numel(y));

        Tnorm = (Ti-Tmin)/max(eps,Tmax-Tmin);
        color = interp1(linspace(0,1,size(cmap,1)),cmap,Tnorm);

        plot(ax(b),x,y,'Color',color,'LineWidth',1);
    end

    if b == ceil(Nblocks/2)
        ylabel(ax(b),ylab,'Interpreter','latex','FontSize',fs);
    end
    % ---- current amplitude annotation (top-right of each panel) ----
    amp = FCpack(b).amp;

    txt = sprintf('$\\mathrm{I = %.3g\\ mA}$', amp);

    text(ax(b), ...
        0.98, 0.90, txt, ...
        'Units','normalized', ...
        'HorizontalAlignment','right', ...
        'VerticalAlignment','top', ...
        'Interpreter','latex', ...
        'FontSize', fs-4, ...
        'BackgroundColor','none', ...   % <-- שקוף
        'Margin',2);

end

% ================= PACK PANELS (FIRST!) =================
drawnow;

pos1  = ax(1).Position;
left  = pos1(1);
width = pos1(3);

usableH = 1 - topMargin - colorbarZone;
h = (usableH - gap*(Nblocks-1)) / Nblocks;

for b = 1:Nblocks
    y = 1 - topMargin - b*h;
    ax(b).Units = 'normalized';
    ax(b).Position = [left y width h];
end




%{
% ================= COLORBAR (SECOND!) =================
axCB = axes(fig,'Units','normalized',...
    'Position',[0.10 0.13 0.80 0.06],...
    'Visible','off');
set(axCB,'CLim',[Tmin Tmax]);

cb = colorbar(axCB,'southoutside');

% ---- centered bins WITH integer ticks ----
ticks = Tall(:);

% force true integer bin-centers (keeps ordering)
ticksInt = round(ticks);
ticksInt = unique(ticksInt,'stable');

% edges are half-integers => integers sit exactly at bin centers
edges = [ticksInt(1)-0.5; (ticksInt(1:end-1)+ticksInt(2:end))/2; ticksInt(end)+0.5];

cb.Limits = [edges(1) edges(end)];

% ticks at integer centers (perfectly centered)
cb.Ticks = ticksInt;

% labels are integers (no decimals ever)
cb.TickLabels = arrayfun(@(x) sprintf('%d',x), ticksInt, 'UniformOutput', false);


% ---- style ----
cb.AxisLocation  = 'out';
cb.TickDirection = 'out';
cb.TickLength    = 0;
cb.FontSize      = fs-4;
cb.LineWidth     = 0.5;
cb.TickLabelInterpreter = 'latex';

xlabel(cb,'$\mathrm{Temperature\ (K)}$','Interpreter','latex','FontSize',fs);
%}
% ================= EDITABLE ARROW COLORBAR =================

% ================= THIN ARROW COLORBAR =================

cbHeight = 0.02;      % <<< דק
cbY = 0.105;
cbX = 0.10;
cbW = 0.78;

axCB = axes(fig,...
    'Units','normalized',...
    'Position',[cbX cbY cbW cbHeight],...
    'Tag','ArrowColorbarAxes');

N = 400;
grad = linspace(Tmin,Tmax,N);

hGrad = imagesc(axCB,[Tmin Tmax],[0 1],grad);
set(hGrad,'Tag','ArrowColorbarImage');

colormap(axCB,cmap);

set(axCB,...
    'XTick',[],...
    'YTick',[],...
    'Box','off',...
    'TickDir','out',...
    'FontSize',fs-4,...
    'LineWidth',0.8);

axCB.XColor = 'none';
axCB.YColor = 'none';
% ---- allow space for arrow tip ----
tipFrac = 0.05;   % fraction of bar width
tipWidth = tipFrac*(Tmax-Tmin);

xlim(axCB,[Tmin-1.25 Tmax+tipWidth-1.25]);
ylim(axCB,[0 1]);

hold(axCB,'on')

% ================= ARROW HEAD =================
lw = 0.15;

tipFrac = 0.04;
arrowHalfHeight = 1;

dx = tipFrac*(Tmax-Tmin);
tipX = Tmax + dx;

y0 = 0.5;

% ===== arrow head =====
hArrowHead = patch(axCB,...
    [Tmax tipX Tmax],...
    [y0-arrowHalfHeight y0 y0+arrowHalfHeight],...
    cmap(end,:),...
    'EdgeColor','none',...
    'LineWidth',lw,...
    'Clipping','off',...
    'Tag','ArrowColorbarHead');

text(axCB, Tmin+1, 2, sprintf('%g K',Tmin), ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','top', ...
    'FontSize',fs-4);

text(axCB, Tmax-1, 2, sprintf('%g K',Tmax), ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','top', ...
    'FontSize',fs-4);

% ================= OUTLINE =================
% plot(axCB,[Tmin Tmax],[0 0],'k','LineWidth',0.3)
% plot(axCB,[Tmin Tmax],[1 1],'k','LineWidth',0.3)

axCB.XAxisLocation = 'bottom';
axCB.TickLabelInterpreter = 'latex';

xlabel(axCB,'$\mathrm{Temperature\ (K)}$',...
    'Interpreter','latex','FontSize',fs);


colormap(fig,cmap);
forceLatexFigure(fig);

end

% ================= helper =================
function s = localPrettyTempTick(T)
if abs(T-round(T)) < 0.03
    s = sprintf('%d',round(T));
else
    s = sprintf('%.3g',T);
end
end
