function BATCH_FIX_AGING_FIGURES()
% Batch polish for figure files in Fig2/Spin glass/Aging folder

targetDir = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Graphs for papers\Switching paper\Graphs for paper ver3\Fig2\Spin glass\Aging (out of plane) ver11';

if ~isfolder(targetDir)
    error('Target folder not found: %s', targetDir);
end

files = dir(fullfile(targetDir, '*.fig'));
fprintf('[BATCH] Found %d FIG files in %s\n', numel(files), targetDir);

if isempty(files)
    return;
end

for k = 1:numel(files)
    inPath = fullfile(files(k).folder, files(k).name);
    [~, baseName] = fileparts(files(k).name);
    outFig = fullfile(files(k).folder, [baseName '_fixed.fig']);
    outPdf = fullfile(files(k).folder, [baseName '_fixed.pdf']);
    outPng = fullfile(files(k).folder, [baseName '_fixed.png']);

    fprintf('\n[BATCH] Processing %s\n', files(k).name);

    fig = [];
    try
        fig = openfig(inPath, 'invisible');

        % Figure-level defaults
        try, fig.Color = 'white'; catch, end
        try, fig.Renderer = 'painters'; catch, end

        ax = findall(fig, 'Type', 'axes');
        for a = ax'
            try
                if isprop(a,'Tag') && strcmpi(a.Tag,'legend')
                    continue;
                end
                a.FontSize = 16;
                a.LineWidth = 1.0;
                a.TickDir = 'out';
                a.Box = 'on';
                if isprop(a,'TickLabelInterpreter'), a.TickLabelInterpreter = 'latex'; end

                if ~isempty(a.XLabel) && isprop(a.XLabel,'FontSize')
                    a.XLabel.FontSize = 18;
                    if isprop(a.XLabel,'Interpreter'), a.XLabel.Interpreter = 'latex'; end
                end
                if ~isempty(a.YLabel) && isprop(a.YLabel,'FontSize')
                    a.YLabel.FontSize = 18;
                    if isprop(a.YLabel,'Interpreter'), a.YLabel.Interpreter = 'latex'; end
                end
                if ~isempty(a.Title) && isprop(a.Title,'FontSize')
                    a.Title.FontSize = 18;
                    if isprop(a.Title,'Interpreter'), a.Title.Interpreter = 'latex'; end
                end
            catch
            end
        end

        ln = findall(fig, 'Type', 'line');
        for L = ln'
            try
                if isprop(L,'LineWidth'), L.LineWidth = max(1.8, L.LineWidth); end
                if isprop(L,'MarkerSize') && ~strcmp(L.Marker,'none'), L.MarkerSize = max(7, L.MarkerSize); end
            catch
            end
        end

        lg = findall(fig, 'Type', 'legend');
        for L = lg'
            try
                L.FontSize = 14;
                L.Box = 'off';
                L.Color = 'none';
                if isprop(L,'Interpreter'), L.Interpreter = 'latex'; end
            catch
            end
        end

        % Export
        savefig(fig, outFig);
        try
            exportgraphics(fig, outPdf, 'ContentType', 'vector');
        catch
            print(fig, '-dpdf', outPdf);
        end
        try
            exportgraphics(fig, outPng, 'Resolution', 300);
        catch
            print(fig, '-dpng', outPng, '-r300');
        end

        fprintf('[BATCH] Saved: %s\n', outFig);
        fprintf('[BATCH] Saved: %s\n', outPdf);
        fprintf('[BATCH] Saved: %s\n', outPng);

    catch ME
        fprintf('[BATCH][ERROR] %s\n', ME.message);
    end

    if ~isempty(fig) && isvalid(fig)
        close(fig);
    end
end

fprintf('\n[BATCH] Done.\n');
end
