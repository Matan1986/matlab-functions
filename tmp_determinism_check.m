addpath(genpath(pwd));
SmartFigureEngine.setDebug(false);

function p = make_and_format()
    f = figure('Visible','off');
    t = tiledlayout(f,2,2);
    for k = 1:4
        ax = nexttile(t);
        x = linspace(0,1,100);
        plot(ax,x,sin(2*pi*(k)*x),'LineWidth',1.2);
        title(ax,sprintf('T%d',k));
        xlabel(ax,'X'); ylabel(ax,'Y');
    end
    style = SmartFigureEngine.computeSmartStyle(3.5,2.6,2,2,'PRL');
    style.safeMode = true;
    style.geometryMode = 'deterministic-grid';
    style.applyPreviewResize = false;
    style.enableAutoReflow = false;
    SmartFigureEngine.applyFullSmart(f, style);
    ax = SmartFigureEngine.getDataAxes(f);
    ax = SmartFigureEngine.orderAxesDeterministically(ax);
    p = vertcat(ax.Position);
    close(f);
end

p1 = make_and_format();
p2 = make_and_format();

d = max(abs(p1(:)-p2(:)));
fprintf('MAX_ABS_DIFF=%0.17g\n', d);
fprintf('BITWISE_EQUAL=%d\n', isequal(p1,p2));
disp('P1:'); disp(p1);
disp('P2:'); disp(p2);
