function PlotsACHC(Temp_S, C_S, Temp_R, C_R, Cdiff, ...
    Cs_norm, Cr_norm, Cdiff_norm, ...
    Angle, Field, slowValsR, fastValsR, colors, temp_jump_threshold, Fontsize, legendStrings, ...
    Cs_Cr_plotMode, C_or_CoverT_plotType, CsCr_plotLayout, includeDiff, xVar, lineWidth, ...
    applyShift, shiftValue, addSuffix, SortMode, Mirror, xVarRef, ...
    showSlowVarInLegend, slowVarStr)

% Prefix
if Mirror
    figPrefix = 'Extended ';
else
    figPrefix = '';
end

% Legend strings cleanup (remove any previous LaTeX remnants)
n = numel(legendStrings);
if isstring(legendStrings) || ischar(legendStrings)
    legendStrings = cellstr(legendStrings);
end
for k = 1:n
    legendStrings{k} = strrep(legendStrings{k}, '\phi', 'phi');
    legendStrings{k} = strrep(legendStrings{k}, '^{0}', '°');
end

% ------------------- X SELECTOR ----------------------
switch xVar
    case 'Temp'
        xS = Temp_S;
        xR = Temp_R;
        isUp = cellfun(@(v) v(end) > v(1), xS);
        xlbl   = 'Temperature [K]';
        xplain = 'Temperature [K]';

    case 'Angle'
        xS = Angle;
        xR = Angle;
        isUp = cellfun(@(v) v(end) > v(1), xS);
        xlbl   = 'Angle °';
        xplain = 'Angle °';

    case 'Field'
        xS = Field;
        xR = Field;
        isUp = cellfun(@(v) v(end) > v(1), xS);
        xlbl   = 'Field [T]';
        xplain = 'Field [T]';

    otherwise
        error('Unknown xVar "%s".', xVar);
end

% Add suffix (up/down) if needed
if addSuffix
    for i = 1:n
        if isUp(i)
            legendStrings{i} = [legendStrings{i} ' (up)'];
        else
            legendStrings{i} = [legendStrings{i} ' (down)'];
        end
    end
end

% Compute shifts
off = zeros(n,1);
if applyShift
    for i = 2:n
        switch SortMode
            case 'fast'
                changed = round(fastValsR(i),1) ~= round(fastValsR(i-1),1);
            case 'slow'
                changed = round(slowValsR(i),1) ~= round(slowValsR(i-1),1);
            case 'both'
                changed = (round(fastValsR(i),1) ~= round(fastValsR(i-1),1)) || ...
                          (round(slowValsR(i),1) ~= round(slowValsR(i-1),1));
            otherwise
                error('Unknown SortMode "%s".', SortMode);
        end
        if changed
            off(i) = off(i-1) + shiftValue;
        else
            off(i) = off(i-1);
        end
    end
end

%% ===================== RAW C PLOTS ==========================
if any(strcmp(C_or_CoverT_plotType,{'raw','both'}))

    switch CsCr_plotLayout

        % ---------------- OVERLAY -----------------
        case 'overlay'

            if showSlowVarInLegend
                figName = sprintf('%sRaw C vs %s', figPrefix, xplain);
            else
                figName = sprintf('%sRaw C vs %s, %s', figPrefix, xplain, slowVarStr);
            end
            figure('Name',figName,'NumberTitle','off'); hold on;

            for i = 1:n
                base = off(i);

                if Cs_Cr_plotMode ~= 'R'
                    if applyShift, y = C_S{i}-mean(C_S{i})+base; else, y = C_S{i}; end
                    plot(xS{i}, y, 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end

                if Cs_Cr_plotMode ~= 'S'
                    if applyShift, y = C_R{i}-mean(C_R{i})+base; else, y = C_R{i}; end
                    plot(xR{i}, y, '--', 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end

                if includeDiff && strcmp(Cs_Cr_plotMode,'B')
                    if applyShift, y = Cdiff{i}-mean(Cdiff{i})+base; else, y = Cdiff{i}; end
                    plot(xS{i}, y, ':', 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end
            end

            xlabel(xlbl,'Interpreter','tex');
            ylabel('C  [J/K]','Interpreter','tex');
            legend('Location','southeast','Interpreter','tex');
            grid on; box on; set(gca,'FontSize',Fontsize);

            yl = ylim; dy = 0.05*(yl(2)-yl(1));
            ylim([yl(1)-dy, yl(2)+dy]);

            if Mirror
                xline(xVarRef,'k--','LineWidth',1,'DisplayName','x_{ref}');
            end

            if showSlowVarInLegend
                title([figPrefix 'Raw C vs ' xplain],'Interpreter','tex');
            else
                title([figPrefix 'Raw C vs ' xplain ', ' slowVarStr],'Interpreter','tex');
            end

        % --------------- SEPARATE -----------------
        case 'separate'

            % -------- Cs raw --------
            if ~strcmp(Cs_Cr_plotMode,'R')

                if showSlowVarInLegend
                    figName = sprintf('%sCs vs %s', figPrefix, xplain);
                else
                    figName = sprintf('%sCs vs %s, %s', figPrefix, xplain, slowVarStr);
                end
                figure('Name',figName,'NumberTitle','off'); hold on;

                for i = 1:n
                    if applyShift, y = C_S{i}-mean(C_S{i})+off(i); else, y = C_S{i}; end
                    plot(xS{i}, y, 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end
                xlabel(xlbl,'Interpreter','tex');
                ylabel('Cs  [J/K]','Interpreter','tex');
                legend('Location','southeast','Interpreter','tex');
                grid on; box on; set(gca,'FontSize',Fontsize);

                yl = ylim; dy = 0.05*(yl(2)-yl(1));
                ylim([yl(1)-dy, yl(2)+dy]);

                if Mirror
                    xline(xVarRef,'k--','LineWidth',1,'DisplayName','x_{ref}');
                end

                if showSlowVarInLegend
                    title([figPrefix 'Cs vs ' xplain],'Interpreter','tex');
                else
                    title([figPrefix 'Cs vs ' xplain ',' slowVarStr],'Interpreter','tex');
                end
            end

            % -------- Cr raw --------
            if ~strcmp(Cs_Cr_plotMode,'S')

                if showSlowVarInLegend
                    figName = sprintf('%sCr vs %s', figPrefix, xplain);
                else
                    figName = sprintf('%sCr vs %s, %s', figPrefix, xplain, slowVarStr);
                end
                figure('Name',figName,'NumberTitle','off'); hold on;

                for i = 1:n
                    if applyShift, y = C_R{i}-mean(C_R{i})+off(i); else, y = C_R{i}; end
                    plot(xR{i}, y, 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end
                xlabel(xlbl,'Interpreter','tex');
                ylabel('Cr  [J/K]','Interpreter','tex');
                legend('Location','southeast','Interpreter','tex');
                grid on; box on; set(gca,'FontSize',Fontsize);

                yl = ylim; dy = 0.05*(yl(2)-yl(1));
                ylim([yl(1)-dy, yl(2)+dy]);

                if Mirror
                    xline(xVarRef,'k--','LineWidth',1,'DisplayName','x_{ref}');
                end

                if showSlowVarInLegend
                    title([figPrefix 'Cr vs ' xplain],'Interpreter','tex');
                else
                    title([figPrefix 'Cr vs ' xplain ', ' slowVarStr],'Interpreter','tex');
                end
            end

            % -------- Cs - Cr raw --------
            if includeDiff && strcmp(Cs_Cr_plotMode,'B')

                if showSlowVarInLegend
                    figName = sprintf('%sCs - Cr vs %s', figPrefix, xplain);
                else
                    figName = sprintf('%sCs - Cr vs %s, %s', figPrefix, xplain, slowVarStr);
                end
                figure('Name',figName,'NumberTitle','off'); hold on;

                for i = 1:n
                    if applyShift, y = Cdiff{i}-mean(Cdiff{i})+off(i); else, y = Cdiff{i}; end
                    plot(xS{i}, y, 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end

                xlabel(xlbl,'Interpreter','tex');
                ylabel('Cs - Cr  [J/K]','Interpreter','tex');
                legend('Location','southeast','Interpreter','tex');
                grid on; box on; set(gca,'FontSize',Fontsize);

                yl = ylim; dy = 0.05*(yl(2)-yl(1));
                ylim([yl(1)-dy, yl(2)+dy]);

                if Mirror
                    xline(xVarRef,'k--','LineWidth',1,'DisplayName','x_{ref}');
                end

                if showSlowVarInLegend
                    title([figPrefix 'Cs - Cr vs ' xplain],'Interpreter','tex');
                else
                    title([figPrefix 'Cs - Cr vs ' xplain ', ' slowVarStr],'Interpreter','tex');
                end
            end
    end
end

%% ===================== NORMALIZED C/T ==========================
if any(strcmp(C_or_CoverT_plotType,{'norm','both'}))

    switch CsCr_plotLayout

        % ---------------- OVERLAY -----------------
        case 'overlay'

            if showSlowVarInLegend
                figName = sprintf('%sNormalized C/T vs %s', figPrefix, xplain);
            else
                figName = sprintf('%sNormalized C/T vs %s, %s', figPrefix, xplain, slowVarStr);
            end
            figure('Name',figName,'NumberTitle','off'); hold on;

            for i = 1:n
                base = off(i);

                if ~strcmp(Cs_Cr_plotMode,'R')
                    if applyShift, y = Cs_norm{i}-mean(Cs_norm{i})+base; else, y = Cs_norm{i}; end
                    plot(xS{i}, y, 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end

                if ~strcmp(Cs_Cr_plotMode,'S')
                    if applyShift, y = Cr_norm{i}-mean(Cr_norm{i})+base; else, y = Cr_norm{i}; end
                    plot(xR{i}, y, '--', 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end

                if includeDiff && strcmp(Cs_Cr_plotMode,'B')
                    if applyShift, y = Cdiff_norm{i}-mean(Cdiff_norm{i})+base; else, y = Cdiff_norm{i}; end
                    plot(xS{i}, y, ':', 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end
            end

            xlabel(xlbl,'Interpreter','tex');
            ylabel('C/T  [J/K^2]','Interpreter','tex');
            legend('Location','southeast','Interpreter','tex');
            grid on; box on; set(gca,'FontSize',Fontsize);

            yl = ylim; dy = 0.05*(yl(2)-yl(1));
            ylim([yl(1)-dy, yl(2)+dy]);

            if Mirror
                xline(xVarRef,'k--','LineWidth',1,'DisplayName','x_{ref}');
            end

            if showSlowVarInLegend
                title([figPrefix 'Normalized C/T vs ' xplain],'Interpreter','tex');
            else
                title([figPrefix 'Normalized C/T vs ' xplain ', ' slowVarStr],'Interpreter','tex');
            end

        % ---------------- SEPARATE -----------------
        case 'separate'

            % -------- Cs/T --------
            if ~strcmp(Cs_Cr_plotMode,'R')

                if showSlowVarInLegend
                    figName = sprintf('%sCs/T vs %s', figPrefix, xplain);
                else
                    figName = sprintf('%sCs/T vs %s, %s', figPrefix, xplain, slowVarStr);
                end
                figure('Name',figName,'NumberTitle','off'); hold on;

                for i = 1:n
                    if applyShift, y = Cs_norm{i}-mean(Cs_norm{i})+off(i); else, y = Cs_norm{i}; end
                    plot(xS{i}, y, 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end
                xlabel(xlbl,'Interpreter','tex');
                ylabel('Cs/T  [J/K^2]','Interpreter','tex');
                legend('Location','southeast','Interpreter','tex');
                grid on; box on; set(gca,'FontSize',Fontsize);

                yl = ylim; dy = 0.05*(yl(2)-yl(1));
                ylim([yl(1)-dy, yl(2)+dy]);

                if Mirror
                    xline(xVarRef,'k--','LineWidth',1,'DisplayName','x_{ref}');
                end

                if showSlowVarInLegend
                    title([figPrefix 'Cs/T vs ' xplain],'Interpreter','tex');
                else
                    title([figPrefix 'Cs/T vs ' xplain ', ' slowVarStr],'Interpreter','tex');
                end
            end

            % -------- Cr/T --------
            if ~strcmp(Cs_Cr_plotMode,'S')

                if showSlowVarInLegend
                    figName = sprintf('%sCr/T vs %s', figPrefix, xplain);
                else
                    figName = sprintf('%sCr/T vs %s, %s', figPrefix, xplain, slowVarStr);
                end
                figure('Name',figName,'NumberTitle','off'); hold on;

                for i = 1:n
                    if applyShift, y = Cr_norm{i}-mean(Cr_norm{i})+off(i); else, y = Cr_norm{i}; end
                    plot(xR{i}, y, 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end
                xlabel(xlbl,'Interpreter','tex');
                ylabel('Cr/T  [J/K^2]','Interpreter','tex');
                legend('Location','southeast','Interpreter','tex');
                grid on; box on; set(gca,'FontSize',Fontsize);

                yl = ylim; dy = 0.05*(yl(2)-yl(1));
                ylim([yl(1)-dy, yl(2)+dy]);

                if Mirror
                    xline(xVarRef,'k--','LineWidth',1,'DisplayName','x_{ref}');
                end

                if showSlowVarInLegend
                    title([figPrefix 'Cr/T vs ' xplain],'Interpreter','tex');
                else
                    title([figPrefix 'Cr/T vs ' xplain ', ' slowVarStr],'Interpreter','tex');
                end
            end

            % -------- (Cs-Cr)/T --------
            if includeDiff && strcmp(Cs_Cr_plotMode,'B')

                if showSlowVarInLegend
                    figName = sprintf('%s(Cs-Cr)/T vs %s', figPrefix, xplain);
                else
                    figName = sprintf('%s(Cs-Cr)/T vs %s, %s', figPrefix, xplain, slowVarStr);
                end
                figure('Name',figName,'NumberTitle','off'); hold on;

                for i = 1:n
                    if applyShift, y = Cdiff_norm{i}-mean(Cdiff_norm{i})+off(i); else, y = Cdiff_norm{i}; end
                    plot(xS{i}, y, 'Color', colors(i,:), 'LineWidth', lineWidth, ...
                        'DisplayName', legendStrings{i});
                end

                xlabel(xlbl,'Interpreter','tex');
                ylabel('(Cs - Cr) / T  [J/K^2]','Interpreter','tex');
                legend('Location','southeast','Interpreter','tex');
                grid on; box on; set(gca,'FontSize',Fontsize);

                yl = ylim; dy = 0.05*(yl(2)-yl(1));
                ylim([yl(1)-dy, yl(2)+dy]);

                if Mirror
                    xline(xVarRef,'k--','LineWidth',1,'DisplayName','x_{ref}');
                end

                if showSlowVarInLegend
                    title([figPrefix '(Cs - Cr)/T vs ' xplain],'Interpreter','tex');
                else
                    title([figPrefix '(Cs - Cr)/T vs ' xplain ', ' slowVarStr],'Interpreter','tex');
                end
            end
    end
end

end
