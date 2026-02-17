% test_compose_annotation_zorder_direct
% Direct (non-UI) Z-order check for figure-level annotations through composeManuscriptFigure.

close all force;
clc;

%% 1) Source figure with overlapping figure-level annotations
srcFig = figure('Name', 'ZOrderDirect_Source', 'Color', 'w', ...
    'Units', 'pixels', 'Position', [100 100 800 550]);
ax = axes(srcFig); %#ok<LAXES>
plot(ax, 1:20, cumsum(randn(1,20)), 'k-', 'LineWidth', 1.2);
title(ax, 'Source for direct compose test');

hRect = annotation(srcFig, 'rectangle', [0.18 0.22 0.56 0.48], ...
    'FaceColor', [1 0.75 0.25], 'FaceAlpha', 0.60, 'Color', [0.85 0.45 0.10]);
hRect.Tag = 'ZRect';

hArrow = annotation(srcFig, 'arrow', [0.26 0.63], [0.30 0.62], ...
    'Color', [0.1 0.2 0.95], 'LineWidth', 2.4);
hArrow.Tag = 'ZArrow';

hText = annotation(srcFig, 'textbox', [0.34 0.45 0.22 0.13], ...
    'String', 'TOP TEXT', 'BackgroundColor', [1 1 1], ...
    'FitBoxToText', 'off', 'LineWidth', 1.4, 'Color', [0.8 0 0]);
hText.Tag = 'ZText';

drawnow;

%% 2) Print source annotation stacking order (findall + matlab.graphics.shape.*)
fprintf('\n=== Source annotation order (findall order) ===\n');
srcOrder = getShapeOrder(srcFig);
printShapeOrder(srcOrder);

%% 3) Direct composeManuscriptFigure call (1x1, deterministic size, no labels)
outFolder = fullfile(tempdir, 'compose_zorder_test');
if ~isfolder(outFolder)
    mkdir(outFolder);
end

spec = struct();
spec.manuscript = struct('type', 'single');
spec.grid = struct('rows', 1, 'cols', 1);
spec.layout = struct('gap', 0.1, 'margin', 0.2);
spec.panels = struct('autoLabels', false);
spec.export = struct('filename', 'compose_zorder_test_output.pdf', 'folder', outFolder);

destFig = composeManuscriptFigure(srcFig, spec);
drawnow;

%% 4) Print destination annotation stacking order (findall + matlab.graphics.shape.*)
fprintf('\n=== Destination annotation order (findall order) ===\n');
dstOrder = getShapeOrder(destFig);
printShapeOrder(dstOrder);

%% 5) Relative-order preservation summary: rectangle -> arrow -> textbox
keyTags = ["ZRect", "ZArrow", "ZText"];
[srcIdx, srcFound] = findTagIndices(srcOrder, keyTags);
[dstIdx, dstFound] = findTagIndices(dstOrder, keyTags);

fprintf('\n=== Relative-order summary ===\n');
if ~(srcFound && dstFound)
    fprintf('Could not locate all tagged annotations in both figures.\n');
    fprintf('sourceFound=%d, destFound=%d\n', srcFound, dstFound);
    fprintf('source idx [Rect Arrow Text]=[%s %s %s]\n', num2str(srcIdx(1)), num2str(srcIdx(2)), num2str(srcIdx(3)));
    fprintf('dest   idx [Rect Arrow Text]=[%s %s %s]\n', num2str(dstIdx(1)), num2str(dstIdx(2)), num2str(dstIdx(3)));
else
    srcRel = [srcIdx(1) < srcIdx(2), srcIdx(2) < srcIdx(3), srcIdx(1) < srcIdx(3)];
    dstRel = [dstIdx(1) < dstIdx(2), dstIdx(2) < dstIdx(3), dstIdx(1) < dstIdx(3)];
    preserved = isequal(srcRel, dstRel);

    fprintf('source idx [Rect Arrow Text]=[%d %d %d]\n', srcIdx(1), srcIdx(2), srcIdx(3));
    fprintf('dest   idx [Rect Arrow Text]=[%d %d %d]\n', dstIdx(1), dstIdx(2), dstIdx(3));
    fprintf('preserved(rect->arrow->text) = %s\n', string(preserved));
end


function order = getShapeOrder(fig)
objs = findall(fig);
order = struct('idx', {}, 'class', {}, 'tag', {});
outIdx = 0;
for i = 1:numel(objs)
    cls = string(class(objs(i)));
    if startsWith(cls, "matlab.graphics.shape.")
        outIdx = outIdx + 1;
        tg = "";
        try, tg = string(objs(i).Tag); catch, end
        order(outIdx).idx = i; %#ok<AGROW>
        order(outIdx).class = char(cls); %#ok<AGROW>
        order(outIdx).tag = char(tg); %#ok<AGROW>
    end
end
end

function printShapeOrder(order)
if isempty(order)
    fprintf('(no matlab.graphics.shape.* objects found)\n');
    return;
end
for i = 1:numel(order)
    fprintf('findallIdx=%d  class=%s  tag=%s\n', order(i).idx, order(i).class, order(i).tag);
end
end

function [idxs, foundAll] = findTagIndices(order, tags)
idxs = nan(1, numel(tags));
for k = 1:numel(tags)
    hit = find(arrayfun(@(s) strcmp(string(s.tag), tags(k)), order), 1, 'first');
    if ~isempty(hit)
        idxs(k) = order(hit).idx;
    end
end
foundAll = all(isfinite(idxs));
end
