function plot_R_vs_temp_field_at_angle( ...
    target_angles, resistivity_deviation_percent_tables, angles, fields, specific_fields, ...
    temp_values, Normalize_to, plan_measured, fontsize, linewidth, plotChannels, titleStr, varargin)

% -------- parse options (kept for compatibility) --------
p = inputParser;
addParameter(p, 'PlotOnlyXX', true, @(x)islogical(x)||isnumeric(x));
addParameter(p, 'PivotFrac', 0.80);         % not used, kept for compat
addParameter(p, 'InterpFieldOnly', false);  % interpolate only along field axis
addParameter(p, 'InterpFactorField', 5);    % upsampling factor for field interpolation
addParameter(p, 'MaxRelDist', 1.2);         % max relative distance (Δfield units) for keeping interp points
addParameter(p, 'UseSmoothing', false);     % Gaussian smoothing before display
addParameter(p, 'GaussSigma', 0.5);         % Gaussian sigma
addParameter(p, 'ApplyGamma', false);       % γ-correction
addParameter(p, 'Gamma', 0.4);              % γ exponent
addParameter(p, 'NaNValueColor', 'black', @(x) any(strcmpi(x,{'white','black'}))); % NaN overlay color
addParameter(p, 'TickGranularity', 'integer', @(x) ismember(x,{'half','integer','auto'})); % preserved
addParameter(p, 'ColormapStyle', 'balance', @(x) ischar(x)||isstring(x));          % colormap base
parse(p, varargin{:});
opts = p.Results;

% -------- assign (names kept) --------
plot_only_xx        = logical(opts.PlotOnlyXX);
interp_field_only   = opts.InterpFieldOnly;
interp_factor_field = opts.InterpFactorField;
max_rel_dist        = opts.MaxRelDist;
use_smoothing       = opts.UseSmoothing;
gauss_sigma         = opts.GaussSigma;
apply_gamma         = opts.ApplyGamma;
gamma               = opts.Gamma;
nan_color           = lower(opts.NaNValueColor);
colormap_style      = lower(string(opts.ColormapStyle));

% -------- resolve channels --------
[keys_all, labels_all] = resolve_channels_generic(plotChannels);
if isempty(keys_all)
    warning('No channels selected in plotChannels.');
    return;
end

% -------- KEEP ONLY XX channels (by LABEL, so ch2 with label Rxx_{2} is kept) --------
if plot_only_xx
    m = contains(lower(labels_all), 'xx');
    keys_all   = keys_all(m);
    labels_all = labels_all(m);
    if isempty(keys_all)
        warning('No "xx" channels found to plot (filter removed all channels).');
        return;
    end
end

% -------- Normalize_to: scalar, vector, or key -> per-channel indices --------
if isnumeric(Normalize_to)
    idxVec = round(Normalize_to(:)');                    % row vector
elseif ischar(Normalize_to) || (isstring(Normalize_to) && isscalar(Normalize_to))
    k = find(strcmp(keys_all, char(Normalize_to)), 1);
    idxVec = ternary(~isempty(k), k, 1);
else
    idxVec = 1;
end
% flexible fit to number of channels (no warnings)
nC = numel(labels_all);
if isscalar(idxVec)
    idxVec = repmat(idxVec, 1, nC);
elseif numel(idxVec) > nC
    idxVec = idxVec(1:nC);
elseif numel(idxVec) < nC
    idxVec = [idxVec repmat(idxVec(end), 1, nC - numel(idxVec))];
end
idxVec = max(1, min(nC, idxVec));  % clamp

% -------- color scale & colormap --------
clim_low = -8; clim_high = 2.5;
base = make_diverging_cmap(colormap_style,1024);
cmap = pivot_cmap(base,clim_low,clim_high);

% -------- plotting --------
for a = 1:numel(target_angles)
    t_ang = target_angles(a);
    for c = 1:numel(keys_all)
        comp       = keys_all{c};
        comp_str   = labels_all{c};
        denom_str  = labels_all{ idxVec(c) };   % per-channel denominator label

        % ---- assemble matrix over specific_fields × temp_values ----
        D = nan(numel(specific_fields), numel(temp_values));
        for fi = 1:numel(specific_fields)
            sf = specific_fields(fi);
            [~,fidx] = min(abs(fields - sf));
            tbl = resistivity_deviation_percent_tables{fidx};

            if ~ismember(comp, tbl.Properties.VariableNames)
                continue;
            end

            % nearest angle row
            [~,r] = min(abs(tbl.Angle - t_ang));

            % row across temps
            sl = tbl.(comp)(r,:);
            if numel(sl) ~= numel(temp_values)
                sl = interp1(1:numel(sl), sl, linspace(1,numel(sl),numel(temp_values)), 'linear', NaN);
            end
            D(fi,:) = sl;
        end

        % ---- interpolate along field, if requested ----
        if interp_field_only
            [Fq, Z_disp] = interpolate_along_field_only(specific_fields, D, interp_factor_field, max_rel_dist);
        else
            Fq     = specific_fields(:);
            Z_disp = D;
        end
        Tq = temp_values(:).';

        % ---- optional smoothing ----
        if use_smoothing
            if exist('imgaussfilt','file')
                Z_disp = imgaussfilt(Z_disp, gauss_sigma);
            else
                Z_disp = smoothdata(Z_disp,1,'movmean',3);
                Z_disp = smoothdata(Z_disp,2,'movmean',3);
            end
        end

        % ---- optional gamma correction ----
        if apply_gamma && abs(gamma-1)>eps
            M = max(abs(Z_disp(:)),[], 'omitnan');
            if M>0
                Z_disp = sign(Z_disp) .* (abs(Z_disp)/M).^gamma * M;
            end
        end

        % ---- draw ----
        figure('Name',sprintf('%s %s Δ%s at %.2f°', ...
                plan_measured, titleStr, comp_str, denom_str, t_ang), ...
                'Position',[150,150,900,600],'Color',[1 1 1]);

        imagesc(Tq, Fq, Z_disp); hold on;
        colormap(cmap); caxis([clim_low clim_high]);

        % overlay NaNs in chosen color (don’t modify data)
        Zmask = (Z_disp<clim_low | Z_disp>clim_high);
        Znan = Z_disp; Znan(Zmask) = NaN;
        nm = isnan(Znan);
        if any(nm(:))
            rgb = strcmp(nan_color,'white')*[1 1 1] + strcmp(nan_color,'black')*[0 0 0];
            ov  = repmat(reshape(rgb,1,1,3), size(Znan));
            image('XData',Tq,'YData',Fq,'CData',ov,'AlphaData',double(nm));
        end
        hold off;

        % axes & ticks
        ticks = unique(specific_fields(:));
        ticks(ticks == 0.01) = [];
        ax = gca;
        ax.YDir       = 'normal';
        ax.YLim       = [0 13];
        ax.YTick      = ticks;
        ax.YTickLabel = arrayfun(@(v) sprintf('%.3g',v), ticks, 'UniformOutput', false);
        ax.XAxis.Exponent = 0;
        ax.YAxis.Exponent = 0;

        % colorbar & labels
        cb = colorbar;
        ylabel(cb, sprintf('Δ%s/%s[%%]', comp_str, denom_str));
        xlabel('Temperature[K]', 'FontSize', fontsize);
        ylabel('Field[T]',      'FontSize', fontsize);
        title(sprintf('%s %s Δ%s/%s at %.2f°', ...
              plan_measured, titleStr, comp_str, denom_str, t_ang), ...
              'FontSize', fontsize);
        ax.FontSize = fontsize;
        grid off;
    end
end
end

%% ===== helpers =====

function [keys, labels] = resolve_channels_generic(plotChannels)
% struct of logicals (+ optional .labels), list of keys, or {key,label} Nx2
    keys = {}; labels = {};

    if isstruct(plotChannels)
        label_map = [];
        if isfield(plotChannels,'labels') && isstruct(plotChannels.labels)
            label_map = plotChannels.labels;
        end
        fns = fieldnames(plotChannels);
        for i = 1:numel(fns)
            fn = fns{i};
            if strcmp(fn,'labels'), continue; end
            val = plotChannels.(fn);
            is_flag = (islogical(val) || isnumeric(val)) && isscalar(val);
            if is_flag && logical(val)
                keys{end+1} = fn; %#ok<AGROW>
                if ~isempty(label_map) && isfield(label_map, fn)
                    lbl = label_map.(fn);
                    if isstring(lbl), lbl = char(lbl); end
                    labels{end+1} = lbl; %#ok<AGROW>
                else
                    labels{end+1} = pretty_label(fn); %#ok<AGROW>
                end
            end
        end
        return
    end

    if isstring(plotChannels) || iscellstr(plotChannels)
        keys = cellstr(plotChannels);
        labels = cellfun(@pretty_label, keys, 'UniformOutput', false);
        return
    end

    if iscell(plotChannels) && size(plotChannels,2) == 2
        keys   = plotChannels(:,1);
        labels = plotChannels(:,2);
        if isstring(keys),   keys   = cellstr(keys);   end
        if isstring(labels), labels = cellstr(labels); end
        return
    end
end

function s = pretty_label(k)
% 'Rxx4' -> 'Rxx_{4}', 'Rxy1' -> 'Rxy_{1}', 'rho_xx' -> 'rho\_xx', 'ch3' -> 'ch_{3}'
    k = char(k);
    k = strrep(k, '_', '\_');
    tokens = regexp(k, '^([A-Za-z\\]+)(\d+)$', 'tokens', 'once');
    if ~isempty(tokens)
        s = sprintf('%s_{%s}', tokens{1}, tokens{2});
    else
        s = k;
    end
end

function cmap = make_diverging_cmap(style,n)
switch lower(string(style))
    case 'balance'
        if exist('cmocean','file'), cmap = cmocean('balance',n);
        else, cmap = make_blue_white_red_colormap(n); end
    case 'redblue'
        neg=[linspace(0,1,n/2)',linspace(0.2,1,n/2)',linspace(0.6,1,n/2)'];
        pos=[linspace(1,0.8,n/2)',linspace(1,0,n/2)',linspace(1,0,n/2)'];
        cmap=[neg;pos];
    case 'parula', cmap = parula(n);
    case 'gray',   cmap = gray(n);
    otherwise
        try, cmap=feval(style,n); catch, cmap=make_blue_white_red_colormap(n); end
end
end

function pivmap = pivot_cmap(base,low,high)
N = size(base,1);
pf = (0-low)/(high-low);
nneg = max(1,round(pf*N)); npos = N - nneg;
mid  = round(N/2);
negb = base(1:mid,:); posb = base(mid+1:end,:);
nr=interp1(linspace(0,1,size(negb,1)),negb,linspace(0,1,nneg));
pr=interp1(linspace(0,1,size(posb,1)),posb,linspace(0,1,npos));
nr(end,:)=1; pr(1,:)=1;
pivmap=[nr;pr];
end

function [Fq,Zq]=interpolate_along_field_only(F,Z,factor,maxd)
Fq=linspace(min(F),max(F),max(1,factor)*numel(F));
Zq=nan(numel(Fq),size(Z,2));
dF=mean(diff(F));
for ti=1:size(Z,2)
    v=interp1(F,Z(:,ti),Fq,'linear',NaN);
    d=abs(bsxfun(@minus,Fq(:),F(:)'))/dF;
    v(min(d,[],2)>maxd)=NaN;
    Zq(:,ti)=v;
end
end

function cmap = make_blue_white_red_colormap(n)
half=floor(n/2);
l=[linspace(0,1,half)',linspace(0.2,1,half)',linspace(0.6,1,half)'];
r=[linspace(1,0.8,n-half)',linspace(1,0,n-half)',linspace(1,0,n-half)'];
cmap=[l;r];
if size(cmap,1)<n, cmap(end+1:n,:)=repmat([1,0,0],n-size(cmap,1),1);
elseif size(cmap,1)>n, cmap=cmap(1:n,:); end
end

function out = ternary(c,a,b)
if c, out=a; else, out=b; end
end
