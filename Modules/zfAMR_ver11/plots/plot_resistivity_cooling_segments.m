function plot_resistivity_cooling_segments( ...
    resistivity_cooling_tables, ...
    rounded_unique_field_max_values, ...
    plotChannels, ...
    plan_measured, showAngleUI)

% plot_resistivity_cooling_segments
% ---------------------------------------------------------
% Plot rho(T) during COOLING, per field and per enabled preset channel.
%
% UI (optional):
% - Angle selection via checkboxes in TWO columns
% - Legend shown only if <= 50 angles
% - If > 50 angles → colorbar instead of legend

if nargin < 5 || isempty(showAngleUI)
    showAngleUI = false;
end

labels = plotChannels.labels;

% ---- enabled preset channels ----
allKeys = fieldnames(plotChannels);
allKeys = allKeys(startsWith(allKeys,'ch'));

enabledKeys = {};
for i = 1:numel(allKeys)
    if plotChannels.(allKeys{i})
        enabledKeys{end+1} = allKeys{i}; %#ok<AGROW>
    end
end
if isempty(enabledKeys)
    warning('plot_resistivity_cooling_segments:NoChannels', ...
        'No enabled channels in plotChannels (preset). Nothing to plot.');
    return;
end

% ---- loop over fields ----
for f = 1:numel(resistivity_cooling_tables)

    field_table = resistivity_cooling_tables{f};
    Bval        = rounded_unique_field_max_values(f);

    anglesRaw = field_table.Angle(:);
    anglesKey = round(anglesRaw);   % integer degrees
    [anglesUnique, ~] = unique(anglesKey,'stable');
    num_angles_u = numel(anglesUnique);

    colors     = parula(max(num_angles_u,64));
    color_inds = round(linspace(1,size(colors,1),num_angles_u));

    % ---- loop over enabled channels ----
    for iC = 1:numel(enabledKeys)

        chKey   = enabledKeys{iC};
        chLabel = labels.(chKey);

        figName = sprintf('%s %s  Cooling  B = %.2f T', ...
            plan_measured, chLabel, Bval);

        figure('Name',figName,'Position',[100 100 1000 600]);
        hold on; grid on;

        ax = gca;
        ax.Position = [0.20 0.15 0.70 0.75];
        ax.FontSize = 10;

        hPlots     = gobjects(num_angles_u,1);
        checkBoxes = gobjects(num_angles_u,1);

        % ---- plot UNIQUE angles (merged segments) ----
        for ii = 1:num_angles_u

            angVal  = anglesUnique(ii);
            idxRows = find(anglesKey == angVal);

            Tall = [];
            Rall = [];

            for rr = idxRows(:)'
                Tdata = field_table.Temperature{rr};
                Rdata = field_table.(chKey){rr};

                if isempty(Tdata) || isempty(Rdata), continue; end

                Tdata = Tdata(:);
                Rdata = Rdata(:);
                good  = isfinite(Tdata) & isfinite(Rdata);

                Tdata = Tdata(good);
                Rdata = Rdata(good);

                if numel(Tdata) < 2, continue; end

                Tall = [Tall; Tdata]; %#ok<AGROW>
                Rall = [Rall; Rdata]; %#ok<AGROW>
            end

            if numel(Tall) < 2, continue; end

            % sort by temperature
            [Tall, idx] = sort(Tall);
            Rall = Rall(idx);

            hPlots(ii) = plot( ...
                Tall, Rall, '-', ...
                'Color', colors(color_inds(ii),:), ...
                'LineWidth', 1.2, ...
                'DisplayName', sprintf('%g°', angVal));
        end

        % ---- labels ----
        title(sprintf('%s %s  Cooling  B = %.2f T', ...
            plan_measured, chLabel, Bval),'FontSize',14);
        xlabel('Temperature [K]','FontSize',12);
        ylabel(sprintf('%s [\\Omega\\cdot cm]', chLabel),'FontSize',12);

        % ---- legend OR colorbar ----
        if num_angles_u <= 50
            lgd = legend('show');
            lgd.Location = 'eastoutside';
            lgd.FontSize = 7;
            lgd.ItemTokenSize = [8 6];
            lgd.NumColumns = 2;
        else
            legend('off');
            cb = colorbar;
            colormap(colors(color_inds,:));
            caxis([1 num_angles_u])
            cb.Ticks = linspace(1,num_angles_u,5);
            cb.TickLabels = round(linspace(min(anglesUnique), ...
                                           max(anglesUnique),5));
            cb.Label.String = 'Angle [deg]';
            cb.FontSize = 8;
        end

        % ---- optional UI ----
        if showAngleUI

            uicontrol('Style','text','Position',[10 560 80 14], ...
                'String','Angles','BackgroundColor','w','FontSize',6);

            nRows = ceil(num_angles_u/2);
            colX  = [5 60];
            rowY0 = 540;
            rowH  = 14;

            for ii = 1:num_angles_u
                if isgraphics(hPlots(ii))
                    col = (ii > nRows) + 1;
                    row = ii - (col-1)*nRows;

                    checkBoxes(ii) = uicontrol( ...
                        'Style','checkbox', ...
                        'String',sprintf('%g°', anglesUnique(ii)), ...
                        'Position',[colX(col) rowY0-rowH*row 50 rowH], ...
                        'Value',1, ...
                        'FontSize',6, ...
                        'Callback', @(src,~) toggleCurve(src,hPlots(ii)));
                end
            end

            uicontrol('Style','pushbutton','String','Uncheck', ...
                'Position',[10 585 70 22],'FontSize',8, ...
                'Callback', @(~,~) uncheckAll(hPlots, checkBoxes));

            uicontrol('Style','pushbutton','String','Check', ...
                'Position',[90 585 70 22],'FontSize',8, ...
                'Callback', @(~,~) checkAll(hPlots, checkBoxes));
        end

        hold off;
    end
end

% ================== helpers ==================

    function toggleCurve(src,h)
        if src.Value
            h.Visible = 'on';
        else
            h.Visible = 'off';
        end
    end
end

function uncheckAll(hPlots, checkBoxes)
    for k = 1:numel(hPlots)
        if isgraphics(hPlots(k))
            hPlots(k).Visible = 'off';
        end
        if isgraphics(checkBoxes(k))
            checkBoxes(k).Value = 0;
        end
    end
end

function checkAll(hPlots, checkBoxes)
    for k = 1:numel(hPlots)
        if isgraphics(hPlots(k))
            hPlots(k).Visible = 'on';
        end
        if isgraphics(checkBoxes(k))
            checkBoxes(k).Value = 1;
        end
    end
end
