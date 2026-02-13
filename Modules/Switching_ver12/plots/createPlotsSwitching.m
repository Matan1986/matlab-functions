function createPlotsSwitching(stored_data, sortedValues, colors, A, dep_type, ...
    lineWidth, fontsize, labels, plotChannels, Resistivity,meta, varargin)
% --- optional plotting control ---
p = inputParser;
addParameter(p,'plotOnlyActiveChannel',false);
addParameter(p,'activeChannel',NaN);
parse(p,varargin{:});


plotOnlyActiveChannel = p.Results.plotOnlyActiveChannel;
activeChannel         = p.Results.activeChannel;

% ----- כמה ערוצים באמת יש בנתונים? -----
% --- determine available physical channels from stored_data ---
physIndex_first = stored_data{1,7};   % physical channel numbers actually present
availablePhysCh = unique(physIndex_first);

chNames = {'ch1','ch2','ch3','ch4'};
activeChannels = {};

for k = availablePhysCh
    chName = chNames{k};
    if isfield(plotChannels, chName) && plotChannels.(chName)
        activeChannels{end+1} = chName;
    end
end
%{
disp('DEBUG createPlotsSwitching:');
disp(['physIndex_first = ', mat2str(stored_data{1,7})]);
disp(['activeChannels  = ', strjoin(activeChannels, ', ')]);
%}
% -------------------------------------------------
% Figure name (window title) using dep_type + meta
% -------------------------------------------------
nameParts = {};
nameParts{end+1} = sprintf('%s dependence', dep_type);

if isfield(meta,'Temperature_K') && ~isnan(meta.Temperature_K)
    nameParts{end+1} = sprintf('T = %.3g K', meta.Temperature_K);
end
if isfield(meta,'Field_T') && ~isnan(meta.Field_T)
    nameParts{end+1} = sprintf('B = %.3g T', meta.Field_T);
end
if isfield(meta,'PulseWidth_ms') && ~isnan(meta.PulseWidth_ms)
    nameParts{end+1} = sprintf('τ = %.3g ms', meta.PulseWidth_ms);
end
if isfield(meta,'Current_mA') && ~isnan(meta.Current_mA)
    nameParts{end+1} = sprintf('I = %.3g mA', meta.Current_mA);
end

baseFigName = strjoin(nameParts, ' | ');

numActive = numel(activeChannels);
if numActive == 0
    warning('createPlotsSwitching: No active channels match the available data (numPhysCh = %d).', numPhysCh);
    return;
end


% precompute time offsets (so all files are concatenated in time)
N = size(stored_data,1);
dur = zeros(N,1);
for i = 1:N
    d = stored_data{i,1};
    dur(i) = d(end,1);
end
tOffset = [0; cumsum(dur(1:end-1))];

% ===== 1) Create figures for each channel & each type =====
fig_unf  = cell(1,numActive);
fig_filt = cell(1,numActive);
fig_fc   = cell(1,numActive);

if Resistivity
    unit_string = '[10^{-6} \Omega\cdotcm]';
else
    unit_string = '[m \Omega]';
end

for idx = 1:numActive
    chName  = activeChannels{idx};
    rawLabel   = labels.(chName);
    cleanLabel = cleanChannelLabel(rawLabel);


    % unfiltered
    fig_unf{idx} = figure('NumberTitle','off');
    fig_unf{idx}.Name = sprintf('%s | %s | unfiltered', baseFigName, rawLabel);

    hold on;
    if Resistivity
        ylab = sprintf('$\\mathrm{%s}\\,(\\mu\\Omega\\,\\mathrm{cm})$', cleanLabel);
    else
        ylab = sprintf('$\\mathrm{%s}\\,(\\mathrm{m}\\Omega)$', cleanLabel);
    end

    ylabel(ylab, 'Interpreter','latex', 'FontSize', fontsize);
    set(gca,'FontSize',fontsize);

    % filtered
    fig_filt{idx} = figure('NumberTitle','off');
    fig_filt{idx}.Name = sprintf('%s | %s | filtered', baseFigName, rawLabel);
    hold on;
    if Resistivity
        ylab = sprintf('$\\mathrm{%s}\\,(\\mu\\Omega\\,\\mathrm{cm})$', cleanLabel);
    else
        ylab = sprintf('$\\mathrm{%s}\\,(\\mathrm{m}\\Omega)$', cleanLabel);
    end

    ylabel(ylab, 'Interpreter','latex', 'FontSize', fontsize);
    set(gca,'FontSize',fontsize);

    % filtered & centered
    fig_fc{idx} = figure('NumberTitle','off');
    fig_fc{idx}.Name = sprintf('%s | %s | filtered & centered', baseFigName, rawLabel);
    hold on;
    if Resistivity
        ylab = sprintf('$\\mathrm{%s}\\,(\\mu\\Omega\\,\\mathrm{cm})$', cleanLabel);
    else
        ylab = sprintf('$\\mathrm{%s}\\,(\\mathrm{m}\\Omega)$', cleanLabel);
    end

    ylabel(ylab, 'Interpreter','latex', 'FontSize', fontsize);
    set(gca,'FontSize',fontsize);
end

% ===== 2) plot unfiltered / filtered / centered (multi-channel) =====
plotUnfilteredData( ...
    fig_unf, stored_data, sortedValues, colors, A, dep_type, ...
    lineWidth, fontsize, activeChannels, tOffset);

plotFilteredData( ...
    fig_filt, stored_data, sortedValues, colors, A, dep_type, ...
    lineWidth, fontsize, activeChannels, tOffset);

plotFilteredCenteredData( ...
    fig_fc, stored_data, sortedValues, colors, A, dep_type, ...
    lineWidth, fontsize, activeChannels, tOffset);

% אם dep_type מיוחד – אפשר להוסיף טיפול נוסף ב־legend דרך addLegends,
% אבל כרגע כל plot פונקציה כבר בונה legend משלה.
for idx = 1:numActive
    cellfun(@forceLatexFigure, ...
        {fig_unf{idx}, fig_filt{idx}, fig_fc{idx}});
end


end
