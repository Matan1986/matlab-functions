function figs = plot_T_by_B( ...
    temp_values, field_values, ...
    FieldT, TempK, AngleDeg, ...
    chans_raw, chans_filt, ...
    labels, plotChannels, Normalize_to, ...
    plan_measured_title, ...
    varargin)

%% ------------ Name-value parser ------------
p = inputParser;

addParameter(p, 'NormalizeData',     true);
addParameter(p, 'SubtractMean',      true);
addParameter(p, 'TempTol',           0.25);
addParameter(p, 'FieldTol',          0.15);
addParameter(p, 'XTickStep',         45);
addParameter(p, 'MakePolar',         false);
addParameter(p, 'FontSize',          18);
addParameter(p, 'LineWidth',         3);
addParameter(p, 'LegendLocation',    'best');
addParameter(p, 'CloseLoop',         true);

% POST outlier removal (after normalization)
addParameter(p, 'ApplyPostOutlierFilter',   true);
addParameter(p, 'PostOutlierJumpPercent',   800);
addParameter(p, 'PostOutlierMedianFactor',  7);

% Final smoothing
addParameter(p, 'FinalSmoothWindow',        7);

parse(p, varargin{:});
o = p.Results;

%% Setup
[field_values, ~] = sort(field_values(:).');
nF = numel(field_values);

if nF < 4
    cmap = lines(nF);
    cind = 1:nF;
else
    cmap = parula(max(64,nF));
    cind = round(linspace(1,size(cmap,1),nF));
end

figs = gobjects(0);
temp_values = temp_values(:).';


%% ============================================================
%%                    MAIN LOOP
%% ============================================================
for tVal = temp_values
    for k = 1:4
        keyk = sprintf('ch%d', k);
        if ~isfield(plotChannels,keyk) || ~plotChannels.(keyk)
            continue;
        end

        pseudoPC.labels = labels;
        numLabel = resolveLabelForKey(keyk, labels, pseudoPC);

        knorm = normalize_index_for_channel(Normalize_to, k, 2);
        denKey = sprintf('ch%d', knorm);
        denLabel = resolveLabelForKey(denKey, labels, pseudoPC);

        drew_cart = false;
        drew_pol  = false;

        hMainCart = gobjects(1,nF);
        hMainPol  = gobjects(1,nF);

        for iF = 1:nF
            B0 = field_values(iF);

            idx = abs(TempK - tVal) <= o.TempTol & abs(FieldT - B0) <= o.FieldTol;
            if ~any(idx)
                continue;
            end

            %% ----- Angle sorting -----
            ang = AngleDeg(idx);
            [angS, si] = sort(ang);
            [angU, ia] = unique(angS,'stable');

            d_f = chans_filt.(keyk)(idx);
            d_f = d_f(si); d_f = d_f(ia);

            denom = chans_filt.(denKey)(idx);
            denom = denom(si); denom = denom(ia);
            denom = mean(denom,'omitnan');
            if ~isfinite(denom) || denom==0, denom = 1; end

            %% ---- Mean subtract ----
            if o.SubtractMean
                d_f = d_f - mean(d_f,'omitnan');
            end

            %% ---- Normalize ----
            if o.NormalizeData
                d_f = d_f ./ denom * 100;
            end

            %% ---- POST OUTLIERS (מלא + fill) ----
            if o.ApplyPostOutlierFilter
                d_f = clean_after_normalization(d_f, ...
                    o.PostOutlierJumpPercent, ...
                    o.PostOutlierMedianFactor);
            end

            %% ---- Final smoothing ----
            if numel(d_f) >= o.FinalSmoothWindow
                d_f = sgolayfilt(d_f, 3, o.FinalSmoothWindow);
            end


            %% =====================================================
            %%                   CARTESIAN PLOT
            %% =====================================================
            if ~drew_cart
                figName = sprintf('%s AMR Δ%s/%s[%%] at %.2f[K]', ...
                    char(plan_measured_title), numLabel, denLabel, tVal);

                f = figure('Name', figName, 'Position', [100,100,1000,600]);
                ax = axes('Parent', f);
                hold(ax,'on'); grid(ax,'on');
                xlabel(ax,'Angle [deg]');
                ylabel(ax,sprintf('\\Delta%s/%s[%%]', numLabel, denLabel));
                title(ax, figName, 'Interpreter','tex');
                xlim(ax,[0,360]);
                ax.XTick = 0:o.XTickStep:360;
                ax.FontSize = o.FontSize;
                drew_cart = true;
            end

            col = cmap(cind(iF),:);
            labelB = sprintf('%g[T]', B0);

            ang_uniform = linspace(0,360,360);
            d_plot = interp1(angU, d_f, ang_uniform, 'pchip');

            hMainCart(iF) = plot(ax, ang_uniform, d_plot, '-', ...
                'Color',col,'LineWidth',o.LineWidth, ...
                'DisplayName',labelB);


            %% =====================================================
            %%                   POLAR PLOT
            %% =====================================================
            if o.MakePolar
                angP = mod(angU, 360);
                dP = abs(d_f);

                if o.CloseLoop && angP(end) < 359
                    angP(end+1)=360;
                    dP(end+1)=dP(1);
                end

                if ~drew_pol
                    figNameP = sprintf('%s AMR Δ%s/%s[%%] at %.2f[K] polar', ...
                        char(plan_measured_title), numLabel, denLabel, tVal);

                    fp = figure('Name', figNameP, 'Position',[100,100,1000,600]);
                    pax = polaraxes('Parent', fp);
                    pax.NextPlot = 'add';
                    pax.ThetaZeroLocation = 'top';
                    pax.ThetaDir = 'clockwise';
                    pax.ThetaAxisUnits = 'degrees';
                    pax.ThetaTick = 0:o.XTickStep:360;
                    pax.FontSize = o.FontSize;
                    drew_pol = true;
                end

                hMainPol(iF) = polarplot(pax, angP*pi/180, dP, ...
                    'Color',col,'LineWidth',o.LineWidth, ...
                    'DisplayName',labelB);
            end

        end

        %% Finalize
        if drew_cart
            legend(ax, hMainCart, 'Location', o.LegendLocation);
            figs(end+1) = f;
        end

        if o.MakePolar && drew_pol
            legend(pax, hMainPol, 'Location','bestoutside');
            figs(end+1) = fp;
        end

    end
end

end
