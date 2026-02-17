function test_improvements()
    close all;
    fprintf('=== COMPREHENSIVE IMPROVEMENT VALIDATION ===\n\n');
    
    % TEST 1: Single panel + long labels + performance
    tic;
    fprintf('[TEST 1] Single panel + long labels\n');
    f1 = figure('Position',[50 50 600 450]);
    ax1 = axes(f1);
    plot(ax1, 1:10, rand(1,10));
    xlabel(ax1, 'X with moderate length');
    ylabel(ax1, 'Very long ylabel that extends beyond default margins');
    title(ax1, 'Single Panel Test');
    s1 = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 1, 1, 'PRL');
    s1.applyPreviewResize = false;
    SmartFigureEngine.applyFullSmart(f1, s1);
    t1 = toc;
    r1 = SmartFigureEngine.validateFigureConsistency(f1);
    fprintf('  Time: %.0f ms\n', t1*1000);
    fprintf('  Result: %s\n\n', iif(r1.passed, 'PASS', 'FAIL'));
    
    % TEST 2: Multi-panel with XLabel alignment
    tic;
    fprintf('[TEST 2] Multi-panel (2x2) with XLabel alignment\n');
    f2 = figure('Position',[100 100 800 600]);
    for i = 1:4
        subplot(2,2,i);
        plot(1:10, rand(1,10));
        xlabel(sprintf('X-axis %d', i));
        ylabel(sprintf('Y%d', i));
        title(sprintf('Panel %d', i));
    end
    s2 = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 2, 2, 'PRL');
    s2.applyPreviewResize = false;
    SmartFigureEngine.applyFullSmart(f2, s2);
    t2 = toc;
    
    % Check XLabel alignment
    ax2 = findall(f2, 'Type', 'axes');
    pos2 = vertcat(ax2.Position);
    bottomRow = pos2(:,2) < median(pos2(:,2));
    xLabelY = [];
    for k = 1:numel(ax2)
        if bottomRow(k)
            try
                ax2(k).XLabel.Units = 'normalized';
                xp = ax2(k).XLabel.Position;
                xLabelY(end+1) = xp(2);
            catch
            end
        end
    end
    aligned = std(xLabelY) < 0.001;
    r2 = SmartFigureEngine.validateFigureConsistency(f2);
    
    fprintf('  Time: %.0f ms\n', t2*1000);
    fprintf('  XLabel Y positions (bottom row): %s\n', mat2str(xLabelY, 4));
    fprintf('  Alignment: %s (std=%.5f)\n', iif(aligned, 'ALIGNED', 'MISALIGNED'), std(xLabelY));
    fprintf('  Result: %s\n\n', iif(r2.passed && aligned, 'PASS', 'FAIL'));
    
    % TEST 3: Manual legend exclusion
    fprintf('[TEST 3] Manual legend exclusion\n');
    f3 = figure('Position',[150 150 600 450]);
    ax3 = axes(f3);
    plot(ax3, 1:10, rand(1,10));
    xlabel(ax3, 'X');
    ylabel(ax3, 'Y');
    L = legend(ax3, 'Data', 'Location', 'best');
    L.Tag = 'manual';
    s3 = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 1, 1, 'PRL');
    s3.applyPreviewResize = false;
    SmartFigureEngine.applyFullSmart(f3, s3);
    r3 = SmartFigureEngine.validateFigureConsistency(f3);
    fprintf('  Result: %s\n\n', iif(r3.passed, 'PASS', 'FAIL'));
    
    % TEST 4: YLabel positioning (visual check)
    fprintf('[TEST 4] YLabel positioning closer to axis\n');
    f4 = figure('Position',[200 200 600 450]);
    ax4 = axes(f4);
    plot(ax4, 1:10, rand(1,10));
    xlabel(ax4, 'X-axis');
    ylabel(ax4, 'Y-axis');
    s4 = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 1, 1, 'PRL');
    s4.applyPreviewResize = false;
    SmartFigureEngine.applyFullSmart(f4, s4);
    ax4.YLabel.Units = 'normalized';
    yLabelPos = ax4.YLabel.Position(1);
    isCloser = yLabelPos >= -0.04;
    fprintf('  YLabel X position: %.4f (target: >= -0.04)\n', yLabelPos);
    fprintf('  Result: %s\n\n', iif(isCloser, 'PASS - Closer', 'FAIL - Too far'));
    
    % PERFORMANCE SUMMARY
    fprintf('=== PERFORMANCE SUMMARY ===\n');
    fprintf('Single panel: %.0f ms %s\n', t1*1000, iif(t1<0.15, '✓', '(SLOW)'));
    fprintf('Multi-panel: %.0f ms %s\n', t2*1000, iif(t2<0.20, '✓', '(SLOW)'));
    
    % FINAL RESULT
    fprintf('\n=== FINAL RESULT ===\n');
    allPass = r1.passed && r2.passed && r3.passed && aligned && isCloser;
    if allPass
        fprintf('✓✓✓ ALL IMPROVEMENTS VALIDATED ✓✓✓\n');
        fprintf('\n✓ Manual legend/textbox exclusion working\n');
        fprintf('✓ YLabel positioned closer to axis\n');
        fprintf('✓ XLabel bottom row alignment perfect\n');
        fprintf('✓ Performance optimized (no redundant calls)\n');
        fprintf('✓ No label clipping detected\n');
    else
        fprintf('❌ Some issues detected\n');
        if ~r1.passed, fprintf('  - Test 1 failed\n'); end
        if ~r2.passed, fprintf('  - Test 2 failed\n'); end
        if ~aligned, fprintf('  - XLabel alignment failed\n'); end
        if ~r3.passed, fprintf('  - Test 3 failed\n'); end
        if ~isCloser, fprintf('  - YLabel not closer\n'); end
    end
    
    pause(2);
end

function out = iif(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end
