% test_compose_annotation_zorder
% Minimal manual harness for Compose v1 annotation Z-order verification.

close all force;
clc;

%% 1) Build source figure with overlapping figure-level annotations
srcFig = figure('Name','ZOrderSource', 'Color','w', 'Units','pixels', 'Position',[100 100 700 500]);
ax = axes(srcFig); %#ok<LAXES>
plot(rand(1,20), '-k');
title('Z-order source');

hRect = annotation(srcFig, 'rectangle', [0.15 0.20 0.55 0.45], ...
    'FaceColor',[1 0.7 0.2], 'FaceAlpha',0.6, 'Color',[0.9 0.4 0]);
hRect.Tag = 'ZRect';

hArrow = annotation(srcFig, 'arrow', [0.22 0.62], [0.28 0.58], ...
    'Color',[0.1 0.2 0.9], 'LineWidth',2.5);
hArrow.Tag = 'ZArrow';

hText = annotation(srcFig, 'textbox', [0.32 0.44 0.20 0.12], ...
    'String','TOP TEXT', 'FitBoxToText','off', 'Color',[0.8 0 0], ...
    'LineWidth',1.5, 'BackgroundColor',[1 1 1]);
hText.Tag = 'ZText';

drawnow;

%% 2) Print source stacking order
fprintf('\n=== Source figure annotation order (fig.Children index) ===\n');
srcOrder = printShapeOrder(srcFig);

%% 3) Launch FigureControlStudio and trigger the existing Compose callback path
FigureControlStudio;
drawnow;

studio = findall(groot, 'Type','figure', 'Name','FigureControlStudio');
assert(~isempty(studio), 'FigureControlStudio window not found.');
studio = studio(1);

% Set scope mode to Explicit List
allDD = findall(studio, 'Type', 'uidropdown');
ddScope = [];
for k = 1:numel(allDD)
    items = string(allDD(k).Items);
    if any(items == "Explicit List")
        ddScope = allDD(k);
        break;
    end
end
assert(~isempty(ddScope), 'Scope dropdown not found.');
ddScope.Value = 'Explicit List';
try
    feval(ddScope.ValueChangedFcn, ddScope, []);
catch
end

% Refresh explicit list
btnRefresh = findButtonByText(studio, 'Refresh Explicit List');
assert(~isempty(btnRefresh), 'Refresh Explicit List button not found.');
feval(btnRefresh.ButtonPushedFcn, btnRefresh, []);
drawnow;

lb = findall(studio, 'Type', 'uilistbox');
assert(~isempty(lb), 'Explicit listbox not found.');
lb = lb(1);

srcRow = find(contains(string(lb.Items), "ZOrderSource"), 1, 'first');
assert(~isempty(srcRow), 'ZOrderSource not found in explicit list.');
lb.Value = lb.ItemsData(srcRow);

% Configure compose tab controls (single tile, no auto panel labels)
composeTab = findall(studio, 'Type','uitab', 'Title','Compose');
assert(~isempty(composeTab), 'Compose tab not found.');
composeTab = composeTab(1);

composeNFs = findall(composeTab, 'Type', 'uieditfield', '-and', 'Style', 'numeric');
assert(numel(composeNFs) >= 2, 'Compose numeric controls not found.');
% Created in order: Rows, Columns, Label font size, Custom width
composeNFs(end).Value = 1; % Rows
composeNFs(end-1).Value = 1; % Columns

cbAutoLabel = findCheckboxByText(composeTab, 'Auto label panels');
assert(~isempty(cbAutoLabel), 'Auto label checkbox not found.');
cbAutoLabel.Value = false;

btnCompose = findButtonByText(composeTab, 'Compose');
assert(~isempty(btnCompose), 'Compose button not found.');
feval(btnCompose.ButtonPushedFcn, btnCompose, []);
drawnow;

%% 4) Inspect destination figure stacking order
destAll = findall(groot, 'Type','figure', 'Name','Composed Figure');
assert(~isempty(destAll), 'Composed Figure not created.');
destFig = destAll(1);

fprintf('\n=== Destination figure annotation order (fig.Children index) ===\n');
destOrder = printShapeOrder(destFig);

%% 5) Comparison summary
names = ["ZRect","ZArrow","ZText"];
[srcIdx, srcOk] = indicesByTag(srcOrder, names);
[dstIdx, dstOk] = indicesByTag(destOrder, names);

fprintf('\n=== Comparison summary ===\n');
if ~(srcOk && dstOk)
    fprintf('Could not locate all required tags in source/destination.\n');
    fprintf('Source found: %d, Destination found: %d\n', srcOk, dstOk);
else
    srcRel = [srcIdx(1) < srcIdx(2), srcIdx(2) < srcIdx(3), srcIdx(1) < srcIdx(3)];
    dstRel = [dstIdx(1) < dstIdx(2), dstIdx(2) < dstIdx(3), dstIdx(1) < dstIdx(3)];
    preserved = isequal(srcRel, dstRel);

    fprintf('Source indices   [Rect Arrow Text]: [%d %d %d]\n', srcIdx(1), srcIdx(2), srcIdx(3));
    fprintf('Destination idxs [Rect Arrow Text]: [%d %d %d]\n', dstIdx(1), dstIdx(2), dstIdx(3));
    fprintf('Relative order preserved: %s\n', string(preserved));
end


function order = printShapeOrder(fig)
children = fig.Children;
order = struct('idx', {}, 'class', {}, 'tag', {});
for i = 1:numel(children)
    ch = children(i);
    cls = string(class(ch));
    if startsWith(cls, "matlab.graphics.shape.")
        tg = "";
        try, tg = string(ch.Tag); catch, end
        order(end+1) = struct('idx', i, 'class', char(cls), 'tag', char(tg)); %#ok<AGROW>
        fprintf('idx=%d  class=%s  tag=%s\n', i, char(cls), char(tg));
    end
end
if isempty(order)
    fprintf('(no figure-level matlab.graphics.shape.* children found)\n');
end
end

function [idxs, ok] = indicesByTag(order, names)
idxs = nan(1, numel(names));
for k = 1:numel(names)
    hit = find(arrayfun(@(s) strcmp(string(s.tag), names(k)), order), 1, 'first');
    if ~isempty(hit)
        idxs(k) = order(hit).idx;
    end
end
ok = all(isfinite(idxs));
end

function btn = findButtonByText(parent, txt)
btn = [];
allBtns = findall(parent, 'Type', 'uibutton');
for k = 1:numel(allBtns)
    if strcmp(string(allBtns(k).Text), string(txt))
        btn = allBtns(k);
        return;
    end
end
end

function cb = findCheckboxByText(parent, txt)
cb = [];
allCb = findall(parent, 'Type', 'uicheckbox');
for k = 1:numel(allCb)
    if strcmp(string(allCb(k).Text), string(txt))
        cb = allCb(k);
        return;
    end
end
end
