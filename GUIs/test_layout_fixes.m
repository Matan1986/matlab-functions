function test_layout_fixes()
    close all;
    fprintf('=== CRITICAL LAYOUT FIX VALIDATION ===\n\n');
    
    % TEST 1: YLabel extent-based spacing (with varying tick precision)
    fprintf('[TEST 1] YLabel spacing with different tick label lengths\n');
    f1 = figure('Position',[50 50 1200 400]);
    
    % Panel A: Short tick labels (few decimals)
    subplot(1,3,1);
    plot(1:10, 1:10);
    ylim([0 10]);
    yticks(0:2:10);
    yticklabels({'0','2','4','6','8','10'});
    xlabel('X-axis');
    ylabel('Short ticks');
    title('Panel A');
    
    % Panel B: Medium tick labels
    subplot(1,3,2);
    plot(1:10, 100:10:190);
    ylim([100 200]);
    yticks(100:20:200);
    yticklabels({'100','120','140','160','180','200'});
    xlabel('X-axis');
    ylabel('Medium ticks');
    title('Panel B');
    
    % Panel C: Long tick labels (with decimals)
    subplot(1,3,3);
    plot(1:10, 0.001:0.0001:0.0019);
    ylim([0.001 0.002]);
    yticks(0.001:0.0002:0.002);
    yticklabels({'0.0010','0.0012','0.0014','0.0016','0.0018','0.0020'});
    xlabel('X-axis');
    ylabel('Long tick labels');
    title('Panel C');
    
    s1 = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 3, 1, 'PRL');
    s1.applyPreviewResize = false;
    SmartFigureEngine.applyFullSmart(f1, s1);
    
    % Check YLabel positions (should adapt to tick width)
    ax1 = findall(f1, 'Type', 'axes');
    yLabelPos = [];
    for k = 1:numel(ax1)
        try
            ax1(k).YLabel.Units = 'normalized';
            yp = ax1(k).YLabel.Position(1);
            yLabelPos(end+1) = yp;
        catch
        end
    end
    
    % YLabels should be more negative (further left) with longer tick labels
    adaptiveSpacing = max(abs(yLabelPos)) > min(abs(yLabelPos)) * 1.1;
    fprintf('  YLabel positions: %s\n', mat2str(yLabelPos, 3));
    fprintf('  Adaptive spacing: %s\n', iif(adaptiveSpacing, 'YES (adapts to tick width)', 'NO'));
    fprintf('  Result: %s\n\n', iif(adaptiveSpacing, 'PASS', 'WARNING - may need adjustment'));
    
    % TEST 2: XLabel closer to ticks
    fprintf('[TEST 2] XLabel vertical positioning (closer to ticks)\n');
    f2 = figure('Position',[100 100 600 450]);
    ax2 = axes(f2);
    plot(ax2, 1:10, rand(1,10));
    xlabel(ax2, 'X-axis label');
    ylabel(ax2, 'Y-axis label');
    title(ax2, 'XLabel Spacing Test');
    
    s2 = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 1, 1, 'PRL');
    s2.applyPreviewResize = false;
    SmartFigureEngine.applyFullSmart(f2, s2);
    
    ax2.XLabel.Units = 'normalized';
    xLabelYPos = ax2.XLabel.Position(2);
    isCloser = xLabelYPos > -0.08;  % Should be higher than -0.08 (closer to ticks)
    fprintf('  XLabel Y position: %.4f (target: > -0.08 for tight spacing)\n', xLabelYPos);
    fprintf('  Result: %s\n\n', iif(isCloser, 'PASS - Closer to ticks', 'FAIL - Too far'));
    
    % TEST 3: Manual legend/textbox typography
    fprintf('[TEST 3] Manual legend and textbox typography\n');
    f3 = figure('Position',[150 150 700 500]);
    ax3 = axes(f3);
    
    % Plot with data
    h1 = plot(ax3, 1:10, rand(1,10), 'r-', 'LineWidth', 2);
    hold on;
    h2 = plot(ax3, 1:10, rand(1,10), 'b-', 'LineWidth', 2);
    
    % Create manual legend using axes overlay
    legAx = axes('Position', [0.65 0.7 0.25 0.15], 'Visible', 'off');
    legAx.Tag = 'manual';  % Mark as overlay
    plot(legAx, [0.1 0.3], [0.7 0.7], 'r-', 'LineWidth', 2);
    hold(legAx, 'on');
    text(legAx, 0.35, 0.7, 'Series 1', 'FontSize', 8);
    plot(legAx, [0.1 0.3], [0.3 0.3], 'b-', 'LineWidth', 2);
    text(legAx, 0.35, 0.3, 'Series 2', 'FontSize', 8);
    xlim(legAx, [0 1]);
    ylim(legAx, [0 1]);
    
    % Add textbox annotation
    annotation(f3, 'textbox', [0.15 0.8 0.2 0.1], 'String', 'Annotation', ...
        'FontSize', 8, 'EdgeColor', 'none');
    
    % Get font sizes before formatting
    legText = findall(legAx, 'Type', 'text');
    preFontSize = [];
    for t = legText(:)'
        preFontSize(end+1) = t.FontSize;
    end
    
    s3 = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 1, 1, 'PRL');
    s3.applyPreviewResize = false;
    SmartFigureEngine.applyFullSmart(f3, s3);
    
    % Check if overlay typography was applied
    postFontSize = [];
    for t = legText(:)'
        postFontSize(end+1) = t.FontSize;
    end
    
    typographyApplied = any(postFontSize ~= preFontSize);
    avgFontChange = mean(postFontSize) - mean(preFontSize);
    
    fprintf('  Manual legend text count: %d\n', numel(legText));
    fprintf('  Font size before: %.1f pt (avg)\n', mean(preFontSize));
    fprintf('  Font size after: %.1f pt (avg)\n', mean(postFontSize));
    fprintf('  Typography applied: %s\n', iif(typographyApplied, 'YES', 'NO'));
    fprintf('  Result: %s\n\n', iif(typographyApplied, 'PASS', 'FAIL'));
    
    % TEST 4: Subplot XLabel alignment and positioning
    fprintf('[TEST 4] Subplot XLabel vertical positioning\n');
    f4 = figure('Position',[200 200 800 600]);
    for i = 1:4
        subplot(2,2,i);
        plot(1:10, rand(1,10));
        xlabel(sprintf('X-axis %d', i));
        ylabel(sprintf('Y%d', i));
        title(sprintf('Panel %d', i));
    end
    
    s4 = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 2, 2, 'PRL');
    s4.applyPreviewResize = false;
    SmartFigureEngine.applyFullSmart(f4, s4);
    
    % Check XLabel positions
    ax4 = findall(f4, 'Type', 'axes');
    pos4 = vertcat(ax4.Position);
    bottomRow = pos4(:,2) < median(pos4(:,2));
    
    xLabelYBottom = [];
    axBottomEdge = [];
    for k = 1:numel(ax4)
        if bottomRow(k)
            try
                ax4(k).XLabel.Units = 'normalized';
                xp = ax4(k).XLabel.Position;
                xLabelYBottom(end+1) = xp(2);
                axBottomEdge(end+1) = pos4(k,2);
            catch
            end
        end
    end
    
    aligned = std(xLabelYBottom) < 0.001;
    clearanceFromAxes = min(axBottomEdge) - max(xLabelYBottom);
    lowEnough = all(xLabelYBottom < -0.05);  % Should be well below axes
    
    fprintf('  Bottom row XLabel Y positions: %s\n', mat2str(xLabelYBottom, 4));
    fprintf('  Alignment std: %.6f\n', std(xLabelYBottom));
    fprintf('  Clearance from axes: %.4f\n', clearanceFromAxes);
    fprintf('  Low enough (< -0.05): %s\n', iif(lowEnough, 'YES', 'NO'));
    fprintf('  Aligned: %s\n', iif(aligned, 'YES', 'NO'));
    fprintf('  Result: %s\n\n', iif(aligned && lowEnough, 'PASS', 'FAIL'));
    
    % SUMMARY
    fprintf('=== SUMMARY ===\n');
    allPass = adaptiveSpacing && isCloser && typographyApplied && aligned && lowEnough;
    if allPass
        fprintf('✓✓✓ ALL CRITICAL FIXES VALIDATED ✓✓✓\n');
        fprintf('\n✓ YLabel extent-based spacing working\n');
        fprintf('✓ XLabel positioned closer to ticks\n');
        fprintf('✓ Overlay typography applied\n');
        fprintf('✓ Subplot XLabels properly positioned and aligned\n');
    else
        fprintf('❌ Some issues detected:\n');
        if ~adaptiveSpacing, fprintf('  - YLabel not adapting to tick width\n'); end
        if ~isCloser, fprintf('  - XLabel too far from ticks\n'); end
        if ~typographyApplied, fprintf('  - Overlay typography not applied\n'); end
        if ~aligned, fprintf('  - XLabels not aligned\n'); end
        if ~lowEnough, fprintf('  - XLabels not low enough\n'); end
    end
    
    pause(3);
end

function out = iif(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end
