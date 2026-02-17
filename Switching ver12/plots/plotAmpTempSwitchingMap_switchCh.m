function plotAmpTempSwitchingMap_switchCh(parentDir, metricType, channelMode, plotAmpTempMode)
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
interpFactor = 7;   % היה 5 | מומלץ: 7–8 | לא לעבור 10

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

    hImg = imagesc(Tq(1,:), Aq(:,1), M_interp);
    set(ax,'YDir','normal');

    set(hImg, ...
        'AlphaData', double(~isnan(M_interp)), ...
        'AlphaDataMapping','none', ...
        'Interpolation','bilinear');

    % ---- axes typography ----
    xlabel(ax,'Temperature (K)','Interpreter','latex');
    ylabel(ax,'$\mathrm{Pulse\, amplitude\, (mA)}$','Interpreter','latex');

    ax.TickLabelInterpreter = 'tex';
    ax.TickDir = 'out';
    ax.Layer   = 'top';

    % ---- colorbar ----
    cb = colorbar(ax);
    switch metricType
        case "P2P_percent"
            xlabel(cb, physLabel('symbol','R','delta',true,'ratioTo','R','units','\%'),'Interpreter','latex');
        otherwise
            xlabel(cb, physLabel('symbol','R','delta',true,'ratioTo','R'),'Interpreter','latex');
    end
    cb.TickLabelInterpreter = 'tex';

    forceLatexFigure(fig);
end
end



% =====================================================================
% Helpers
% =====================================================================
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
cb.TickLabelInterpreter = 'tex';

xlabel(cb,'$\mathrm{Temperature\ (K)}$','Interpreter','latex','FontSize',fs);

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
