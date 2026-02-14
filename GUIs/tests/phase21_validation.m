function results = phase21_validation()
% Phase 2.1 behavioral regression validation for FinalFigureFormatterUI + SmartFigureEngine

clc;
results = struct();
results.passed = true;
results.failures = {};

rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(rootDir));

cleanupObj = onCleanup(@() closeAllSafely()); %#ok<NASGU>
closeAllSafely();

try
    % Launch UI
    FinalFigureFormatterUI();
    pause(0.4);
    uiFig = findall(0,'Type','figure','Name','Final Figure Formatter');
    assert(~isempty(uiFig), 'UI did not launch');
    uiFig = uiFig(1);

    % ---------- 1) SMART Layout ----------
    [testFig, ax] = createRichTestFigure('P2.1_SMART_Test');
    lastwarn('');

    setStyleMode(uiFig, 'PRL');
    pressButton(uiFig, 'Apply SMART');
    pause(0.2);

    % Verify axes resized and typography applied
    pos1 = ax.Position;
    assert(pos1(3) > 0.4 && pos1(4) > 0.35, 'SMART axes sizing failed');
    assert(ax.FontSize >= 8, 'SMART font application failed');

    lg = findall(testFig,'Type','legend');
    assert(~isempty(lg) && isvalid(lg(1)), 'Legend not preserved after SMART');

    [warnMsg, ~] = lastwarn;
    assert(isempty(warnMsg), sprintf('Warnings after SMART: %s', warnMsg));

    % ---------- 2) Appearance open-fig mode ----------
    setAppearanceOpenMode(uiFig);
    setAppearanceFields(uiFig, struct( ...
        'mapName','parula', ...
        'spreadMode','medium', ...
        'fitColor','black', ...
        'dataWidth','2.5', ...
        'fitWidth','1.7', ...
        'markerSize','8', ...
        'reverseOrder',true, ...
        'reverseLegend',true, ...
        'noMapChange',false));

    beforeChildren = ax.Children;
    pressButton(uiFig, 'Apply Appearance');
    pause(0.3);

    afterChildren = ax.Children;
    assert(numel(afterChildren) == numel(beforeChildren), 'Children count changed unexpectedly');

    lines = findall(ax,'Type','line');
    assert(~isempty(lines), 'No lines found after appearance apply');
    assert(any(abs([lines.LineWidth] - 2.5) < 1e-6 | abs([lines.LineWidth] - 1.7) < 1e-6), ...
        'Line width change not applied');
    assert(any(abs([lines.MarkerSize] - 8) < 1e-6), 'Marker size change not applied');

    lg = findall(testFig,'Type','legend');
    assert(~isempty(lg) && isvalid(lg(1)), 'Legend missing after reverse legend');

    % ---------- 3) Folder mode ----------
    folderPath = fullfile(tempdir, ['phase21_figs_' char(java.util.UUID.randomUUID)]);
    mkdir(folderPath);
    makeFolderModeFixtures(folderPath);

    close(testFig);  % reduce dependence on currently open figure
    close all force;
    FinalFigureFormatterUI();
    pause(0.4);
    uiFig = findall(0,'Type','figure','Name','Final Figure Formatter');
    uiFig = uiFig(1);

    setAppearanceFolderMode(uiFig, folderPath);
    setAppearanceFields(uiFig, struct( ...
        'mapName','parula', ...
        'spreadMode','medium-rev', ...
        'fitColor','red', ...
        'dataWidth','2.1', ...
        'fitWidth','1.2', ...
        'markerSize','7', ...
        'reverseOrder',true, ...
        'reverseLegend',false, ...
        'noMapChange',false));

    pressButton(uiFig, 'Apply Appearance');
    pause(0.3);

    figs = dir(fullfile(folderPath,'*.fig'));
    assert(numel(figs) >= 2, 'Folder fixtures missing');
    for k = 1:numel(figs)
        f = openfig(fullfile(folderPath,figs(k).name),'invisible');
        axk = findall(f,'Type','axes');
        assert(~isempty(axk), 'Corrupted fig after folder mode apply');
        close(f);
    end

    % ---------- 4) Export consistency ----------
    [testFig, ax] = createRichTestFigure('P2.1_Export_Test');
    setPathAndPdfMode(uiFig, folderPath, 'Vector (Recommended)');
    setStyleMode(uiFig, 'PRL');
    pressButton(uiFig, 'Apply SMART');
    pause(0.2);

    fsBefore = ax.FontSize;
    tiBefore = ax.TickLabelInterpreter;

    pressButton(uiFig, 'Save PDF');
    pause(0.4);

    pdfs = dir(fullfile(folderPath, '*.pdf'));
    assert(~isempty(pdfs), 'PDF export failed');

    assert(abs(ax.FontSize - fsBefore) < 1e-9, 'Font scaling changed after export');
    assert(strcmp(ax.TickLabelInterpreter, tiBefore), 'Interpreter changed after export');

    % ---------- 5) Style mode switch ----------
    modes = {'PRL','Nature','Compact','Presentation'};
    styles = cell(size(modes));
    axesPos = zeros(numel(modes),4);

    for i = 1:numel(modes)
        setStyleMode(uiFig, modes{i});
        pressButton(uiFig, 'Apply SMART');
        pause(0.2);
        styles{i} = getappdata(testFig, 'SmartFigureEngine_LastStyle');
        axesPos(i,:) = ax.Position;
        assert(strcmpi(styles{i}.mode, modes{i}), 'Style mode did not update in engine state');
    end

    tickFonts = cellfun(@(s) s.tickFont, styles);
    leftMargins = cellfun(@(s) s.leftMargin, styles);
    assert(numel(unique(tickFonts)) > 1, 'Font hierarchy did not change across style modes');
    assert(numel(unique(round(leftMargins,4))) > 1, 'Margins did not change across style modes');
    assert(size(unique(round(axesPos,4), 'rows'),1) > 1, 'Axes geometry did not change across style modes');

    % ---------- 6) Resize window / autoReflow ----------
    p = testFig.Position;
    testFig.Position = [p(1) p(2) p(3)+220 p(4)+120];
    pause(0.3);
    p2 = testFig.Position;
    testFig.Position = [p2(1) p2(2) max(420,p2(3)-180) max(320,p2(4)-90)];
    pause(0.3);

    hasListener = isappdata(testFig,'SmartFigureEngine_SizeListener');
    assert(hasListener, 'autoReflow listener not attached');

    isApplying = false;
    if isappdata(testFig,'SmartFigureEngine_IsApplying')
        isApplying = getappdata(testFig,'SmartFigureEngine_IsApplying');
    end
    assert(~isApplying, 'Possible recursive resize loop (engine stuck applying)');

    % ---------- 7) Engine integrity ----------
    s = SmartFigureEngine.computeSmartStyle(max(1,testFig.Position(3)/96), max(1,testFig.Position(4)/96), 1, 1, 'PRL');
    s.applyPreviewResize = false;
    SmartFigureEngine.applyFullSmart(testFig, s);
    SmartFigureEngine.validateEngine(testFig);

catch ME
    results.passed = false;
    results.failures{end+1} = sprintf('%s | %s', ME.identifier, ME.message);
end

reportsDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'reports');
if ~isfolder(reportsDir), mkdir(reportsDir); end
reportPath = fullfile(reportsDir, 'phase21_validation_report.txt');
fid = fopen(reportPath, 'w');
if fid > 0
    fprintf(fid, 'passed=%d\n', results.passed);
    if isfield(results,'failures') && ~isempty(results.failures)
        for i = 1:numel(results.failures)
            fprintf(fid, 'failure_%d=%s\n', i, results.failures{i});
        end
    end
    fclose(fid);
end

if results.passed
    fprintf('\n[PHASE 2.1 VALIDATION] PASSED\n');
else
    fprintf('\n[PHASE 2.1 VALIDATION] FAILED\n');
    for i = 1:numel(results.failures)
        fprintf(' - %s\n', results.failures{i});
    end
end

end

function [f, ax] = createRichTestFigure(name)
f = figure('Name',name,'Color','w','Position',[120 120 780 560]);
ax = axes('Parent',f);
hold(ax,'on');

imagesc(ax, linspace(0,1,60));
colormap(ax, parula(256));
colorbar(ax);

x = linspace(0, 2*pi, 220);
for k = 1:4
    y = sin(x + 0.4*k) + 0.08*k;
    plot(ax, x, y, '-o', 'MarkerSize', 5, 'LineWidth', 1.2, 'DisplayName', sprintf('Data %d',k));
end
plot(ax, x, cos(x), 'k--', 'LineWidth', 1.3, 'DisplayName','Fit');
legend(ax,'Location','northeast');
xlabel(ax,'X'); ylabel(ax,'Y'); title(ax,'Validation Test');
end

function makeFolderModeFixtures(folderPath)
for i = 1:3
    f = figure('Visible','off','Color','w','Position',[100 100 620 420]);
    ax = axes('Parent',f); hold(ax,'on');
    x = linspace(0,1,140);
    plot(ax,x,sin(2*pi*x*i),'DisplayName',sprintf('Data %d',i),'LineWidth',1.1);
    plot(ax,x,cos(2*pi*x*i),'LineWidth',1.0);
    legend(ax,'show');
    colorbar(ax);
    savefig(f, fullfile(folderPath, sprintf('fixture_%d.fig', i)));
    close(f);
end
end

function setStyleMode(uiFig, mode)
d = findall(uiFig,'Type','uidropdown');
for k = 1:numel(d)
    items = cellstr(d(k).Items);
    if all(ismember({'PRL','Nature','Compact','Presentation'}, items))
        d(k).Value = mode;
        return;
    end
end
error('Style mode dropdown not found');
end

function setAppearanceOpenMode(uiFig)
c = findall(uiFig,'Type','uicheckbox');
for k = 1:numel(c)
    if strcmp(c(k).Text, 'Open figs')
        c(k).Value = true;
        invokeValueChanged(c(k));
    elseif strcmp(c(k).Text, 'Folder:')
        c(k).Value = false;
        invokeValueChanged(c(k));
    end
end
end

function setAppearanceFolderMode(uiFig, folderPath)
c = findall(uiFig,'Type','uicheckbox');
for k = 1:numel(c)
    if strcmp(c(k).Text, 'Open figs')
        c(k).Value = false;
        invokeValueChanged(c(k));
    elseif strcmp(c(k).Text, 'Folder:')
        c(k).Value = true;
        invokeValueChanged(c(k));
    end
end

edits = findall(uiFig,'Type','uieditfield');
for k = 1:numel(edits)
    if isa(edits(k),'matlab.ui.control.EditField')
        if strcmp(edits(k).Type, 'text') && strcmp(edits(k).Enable,'on')
            edits(k).Value = folderPath;
            return;
        end
    end
end
error('Folder path edit field not found');
end

function setAppearanceFields(uiFig, cfg)
d = findall(uiFig,'Type','uidropdown');
for k = 1:numel(d)
    items = cellstr(d(k).Items);
    if any(strcmp(items,'(no change)')) && any(strcmp(items,'parula'))
        d(k).Value = cfg.mapName;
    elseif any(strcmp(items,'ultra-narrow')) && any(strcmp(items,'full-rev'))
        d(k).Value = cfg.spreadMode;
    elseif any(strcmp(items,'black')) && any(strcmp(items,'(no change)'))
        d(k).Value = cfg.fitColor;
    elseif numel(items)==6 && any(strcmp(items,'none'))
        % data/fit style dropdowns, keep defaults
    end
end

c = findall(uiFig,'Type','uicheckbox');
for k = 1:numel(c)
    switch c(k).Text
        case 'Reverse Plot'
            c(k).Value = cfg.reverseOrder;
        case 'Reverse Legend'
            c(k).Value = cfg.reverseLegend;
        case 'No map change'
            c(k).Value = cfg.noMapChange;
    end
end

% set text edit fields in appearance panel by best-effort row/column
p = findall(uiFig,'Type','uipanel','Title','Appearance / Colormap Control');
if isempty(p), error('Appearance panel not found'); end
children = findall(p(1));
for k = 1:numel(children)
    if ~isa(children(k),'matlab.ui.control.EditField'), continue; end
    if ~strcmp(children(k).Type,'text'), continue; end
    if ~isprop(children(k),'Layout'), continue; end
    try
        r = children(k).Layout.Row;
        ccol = children(k).Layout.Column;
    catch
        continue;
    end
    if isequal(r,3) && isequal(ccol,2)
        children(k).Value = cfg.dataWidth;
    elseif isequal(r,3) && isequal(ccol,6)
        children(k).Value = cfg.markerSize;
    elseif isequal(r,4) && isequal(ccol,2)
        children(k).Value = cfg.fitWidth;
    end
end
end

function setPathAndPdfMode(uiFig, pathValue, pdfMode)
% Save folder text field (first text edit in Save panel row 1 col 1)
p = findall(uiFig,'Type','uipanel','Title','Save & Export');
if isempty(p), error('Save panel not found'); end
children = findall(p(1));

for k = 1:numel(children)
    if isa(children(k),'matlab.ui.control.EditField') && strcmp(children(k).Type,'text')
        try
            if isequal(children(k).Layout.Row,1)
                children(k).Value = pathValue;
                break;
            end
        catch
        end
    end
end

d = findall(uiFig,'Type','uidropdown');
for k = 1:numel(d)
    items = cellstr(d(k).Items);
    if any(strcmp(items,'Vector (Recommended)')) && any(strcmp(items,'WYSIWYG (Match FIG)'))
        d(k).Value = pdfMode;
        return;
    end
end
error('PDF mode dropdown not found');
end

function pressButton(uiFig, txt)
b = findall(uiFig,'Type','uibutton');
for k = 1:numel(b)
    if strcmp(b(k).Text, txt)
        cb = b(k).ButtonPushedFcn;
        if isa(cb,'function_handle')
            cb(b(k), struct());
        elseif iscell(cb)
            feval(cb{1}, b(k), struct(), cb{2:end});
        else
            error('Unsupported callback type for button %s', txt);
        end
        drawnow;
        return;
    end
end
error('Button "%s" not found', txt);
end

function invokeValueChanged(ctrl)
try
    cb = ctrl.ValueChangedFcn;
    if isa(cb,'function_handle')
        cb(ctrl, struct());
    elseif iscell(cb)
        feval(cb{1}, ctrl, struct(), cb{2:end});
    end
catch
end
end

function closeAllSafely()
try
    close all force;
catch
end
end
