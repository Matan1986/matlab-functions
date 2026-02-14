function ANALYZE_FIG_QUALITY()
baseDir = 'C:/Users/matan/My Drive (matanst@post.bgu.ac.il)/Quantum materials lab/Graphs for papers/Switching paper/Graphs for paper ver3/Fig2/Spin glass/Aging (out of plane) ver11';
outFile = fullfile(baseDir,'FIG_QUALITY_REPORT.txt');
localDir = fileparts(mfilename('fullpath'));
localOutFile = fullfile(localDir,'FIG_QUALITY_REPORT_LOCAL.txt');
summaryCsv = fullfile(localDir,'FIG_QUALITY_SUMMARY.csv');
figFiles = dir(fullfile(baseDir,'*.fig'));
fid = fopen(outFile,'w');
if fid<0
    error('Cannot open report file for writing: %s', outFile);
end
fidLocal = fopen(localOutFile,'w');
if fidLocal<0
    error('Cannot open local report file for writing: %s', localOutFile);
end
fidCsv = fopen(summaryCsv,'w');
if fidCsv<0
    error('Cannot open CSV summary file for writing: %s', summaryCsv);
end
fprintf(fidCsv,'file,axes,legends,colorbars,lines,texts,axes_font_min,axes_font_med,axes_font_max,line_width_min,line_width_med,line_width_max,interp_issues,underscore_issues,clipping_risk,pdf_ok,fig_ok,error\n');
fprintf(fid,'FIG Quality Diagnostic Report\n');
fprintf(fid,'Generated: %s\n\n', char(datetime('now')));
fprintf(fidLocal,'FIG Quality Diagnostic Report\n');
fprintf(fidLocal,'Generated: %s\n\n', char(datetime('now')));
if isempty(figFiles)
    fprintf(fid,'No .fig files found in folder.\n');
    fprintf(fidLocal,'No .fig files found in folder.\n');
    fclose(fid);
    fclose(fidLocal);
    fclose(fidCsv);
    return;
end

for i = 1:numel(figFiles)
    fpath = fullfile(figFiles(i).folder, figFiles(i).name);
    fprintf(fid,'============================================================\n');
    fprintf(fid,'File: %s\n', figFiles(i).name);
    fprintf(fid,'Path: %s\n', fpath);
    fprintf(fidLocal,'============================================================\n');
    fprintf(fidLocal,'File: %s\n', figFiles(i).name);
    fprintf(fidLocal,'Path: %s\n', fpath);
    try
        fig = openfig(fpath,'invisible');
        cleanup = onCleanup(@() closeSafe(fig));

        fprintf(fid,'Figure.Name: %s\n', toCharSafe(get(fig,'Name')));
        fprintf(fidLocal,'Figure.Name: %s\n', toCharSafe(get(fig,'Name')));
        pos = get(fig,'Position');
        if isnumeric(pos) && numel(pos)>=4
            fprintf(fid,'Figure.Position(px): [%.1f %.1f %.1f %.1f]\n', pos(1),pos(2),pos(3),pos(4));
            fprintf(fidLocal,'Figure.Position(px): [%.1f %.1f %.1f %.1f]\n', pos(1),pos(2),pos(3),pos(4));
        end

        ax = findall(fig,'Type','axes');
        ax = ax(~arrayfun(@(a) strcmpi(toCharSafe(get(a,'Tag')),'legend'), ax));
        lg = findall(fig,'Type','legend');
        cb = findall(fig,'Type','colorbar');
        ln = findall(fig,'Type','line');
        tx = findall(fig,'Type','text');

        fprintf(fid,'Counts: axes=%d, legends=%d, colorbars=%d, lines=%d, texts=%d\n', ...
            numel(ax), numel(lg), numel(cb), numel(ln), numel(tx));
        fprintf(fidLocal,'Counts: axes=%d, legends=%d, colorbars=%d, lines=%d, texts=%d\n', ...
            numel(ax), numel(lg), numel(cb), numel(ln), numel(tx));

        fsAxes = getPropVec(ax,'FontSize');
        lwAxes = getPropVec(ax,'LineWidth');
        fsLegend = getPropVec(lg,'FontSize');
        lwLine = getPropVec(ln,'LineWidth');
        msLine = getPropVec(ln,'MarkerSize');

        printStats(fid,'Axes.FontSize',fsAxes);
        printStats(fid,'Axes.LineWidth',lwAxes);
        printStats(fid,'Legend.FontSize',fsLegend);
        printStats(fid,'Line.LineWidth',lwLine);
        printStats(fid,'Line.MarkerSize',msLine);
        printStats(fidLocal,'Axes.FontSize',fsAxes);
        printStats(fidLocal,'Axes.LineWidth',lwAxes);
        printStats(fidLocal,'Legend.FontSize',fsLegend);
        printStats(fidLocal,'Line.LineWidth',lwLine);
        printStats(fidLocal,'Line.MarkerSize',msLine);

        interpIssues = 0;
        labelUnderscoreIssues = 0;
        for a = ax'
            try
                if isprop(a,'TickLabelInterpreter')
                    tli = toCharSafe(get(a,'TickLabelInterpreter'));
                    if ~strcmpi(tli,'latex')
                        interpIssues = interpIssues + 1;
                    end
                end
                xl = get(a,'XLabel'); yl = get(a,'YLabel'); tt = get(a,'Title');
                labelUnderscoreIssues = labelUnderscoreIssues + countUnderscoreIssue(xl);
                labelUnderscoreIssues = labelUnderscoreIssues + countUnderscoreIssue(yl);
                labelUnderscoreIssues = labelUnderscoreIssues + countUnderscoreIssue(tt);
            catch
            end
        end
        fprintf(fid,'Interpreter issues (axes ticklabel not latex): %d\n', interpIssues);
        fprintf(fid,'Potential underscore/latex label issues: %d\n', labelUnderscoreIssues);
        fprintf(fidLocal,'Interpreter issues (axes ticklabel not latex): %d\n', interpIssues);
        fprintf(fidLocal,'Potential underscore/latex label issues: %d\n', labelUnderscoreIssues);

        % Clipping risk heuristic
        clippingRisk = 0;
        for a = ax'
            try
                set(a,'Units','normalized');
                ti = get(a,'TightInset');
                p = get(a,'Position');
                if numel(ti)>=4 && numel(p)>=4
                    if p(1) < ti(1)-0.01 || p(2) < ti(2)-0.01 || (p(1)+p(3)) > (1-ti(3)+0.01) || (p(2)+p(4)) > (1-ti(4)+0.01)
                        clippingRisk = clippingRisk + 1;
                    end
                end
            catch
            end
        end
        fprintf(fid,'Axes with possible clipping risk: %d\n', clippingRisk);
        fprintf(fidLocal,'Axes with possible clipping risk: %d\n', clippingRisk);

        % Saveability smoke test paths
        tmpPdf = fullfile(tempdir, [figFiles(i).name '_smoke.pdf']);
        tmpFig = fullfile(tempdir, [figFiles(i).name '_smoke.fig']);
        pdfOk = true; figOk = true;
        pdfErr = ''; figErr = '';
        try
            exportgraphics(fig,tmpPdf,'ContentType','vector');
        catch ME
            pdfOk = false; pdfErr = ME.message;
        end
        try
            savefig(fig,tmpFig);
        catch ME
            figOk = false; figErr = ME.message;
        end
        fprintf(fid,'Smoke export: PDF=%s; FIG=%s\n', tfStr(pdfOk), tfStr(figOk));
        fprintf(fidLocal,'Smoke export: PDF=%s; FIG=%s\n', tfStr(pdfOk), tfStr(figOk));
        if ~pdfOk, fprintf(fid,'PDF error: %s\n', pdfErr); end
        if ~figOk, fprintf(fid,'FIG error: %s\n', figErr); end
        if ~pdfOk, fprintf(fidLocal,'PDF error: %s\n', pdfErr); end
        if ~figOk, fprintf(fidLocal,'FIG error: %s\n', figErr); end
        fprintf(fidCsv,'%s,%d,%d,%d,%d,%d,%s,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,""\n', ...
            csvEsc(figFiles(i).name), numel(ax), numel(lg), numel(cb), numel(ln), numel(tx), ...
            statVal(fsAxes,1), statVal(fsAxes,2), statVal(fsAxes,3), ...
            statVal(lwLine,1), statVal(lwLine,2), statVal(lwLine,3), ...
            interpIssues, labelUnderscoreIssues, clippingRisk, pdfOk, figOk);

        fprintf(fid,'\n');
        fprintf(fidLocal,'\n');
        clear cleanup;
    catch ME
        fprintf(fid,'ERROR opening/analyzing FIG: %s\n\n', ME.message);
        fprintf(fidLocal,'ERROR opening/analyzing FIG: %s\n\n', ME.message);
        fprintf(fidCsv,'%s,0,0,0,0,0,,,,,,,,,0,0,"%s"\n', csvEsc(figFiles(i).name), csvEsc(ME.message));
    end
end

fclose(fid);
fclose(fidLocal);
fclose(fidCsv);
fprintf('REPORT_OK|%s\n', localOutFile);
fprintf('CSV_OK|%s\n', summaryCsv);
end

function s = statVal(v, mode)
if isempty(v)
    s = '';
    return;
end
switch mode
    case 1
        s = sprintf('%.3f', min(v));
    case 2
        s = sprintf('%.3f', median(v));
    otherwise
        s = sprintf('%.3f', max(v));
end
end

function s = csvEsc(x)
if isstring(x), x = char(x); end
if ~ischar(x), x = toCharSafe(x); end
s = strrep(x, '"', '""');
end

function printStats(fid,name,v)
if isempty(v)
    fprintf(fid,'%s: [none]\n', name);
else
    fprintf(fid,'%s: min=%.3f, med=%.3f, max=%.3f\n', name, min(v), median(v), max(v));
end
end

function v = getPropVec(h, prop)
v = [];
for k = 1:numel(h)
    try
        if isprop(h(k),prop)
            x = get(h(k),prop);
            if isnumeric(x) && isscalar(x) && isfinite(x)
                v(end+1) = double(x); %#ok<AGROW>
            end
        end
    catch
    end
end
end

function n = countUnderscoreIssue(lbl)
n = 0;
try
    if isempty(lbl), return; end
    if ~isprop(lbl,'String') || ~isprop(lbl,'Interpreter'), return; end
    s = get(lbl,'String');
    itp = toCharSafe(get(lbl,'Interpreter'));
    ss = toCharSafe(s);
    if contains(ss,'_') && ~strcmpi(itp,'latex')
        n = 1;
    end
catch
end
end

function s = toCharSafe(x)
try
    if isstring(x), s = char(x); return; end
    if ischar(x), s = x; return; end
    if isnumeric(x), s = mat2str(x); return; end
    s = char(string(x));
catch
    s = '';
end
end

function s = tfStr(tf)
if tf, s='OK'; else, s='FAIL'; end
end

function closeSafe(fig)
try
    if ~isempty(fig) && isvalid(fig)
        close(fig);
    end
catch
end
end
