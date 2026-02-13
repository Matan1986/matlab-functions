function ppt_path = quickSaveFigsPPT_simple(targetFolder)
% Save all open figures into a PPTX, one per slide.
% Makes a hidden full-copy of each figure, removes its title (original untouched),
% exports the image, and inserts it with a big title. Does NOT reapply or change colormaps.

    if nargin < 1 || isempty(targetFolder)
        targetFolder = pwd;
    end
    if ~isfolder(targetFolder)
        error('Target folder "%s" does not exist.', targetFolder);
    end

    figs = findall(0,'Type','figure');
    if isempty(figs)
        warning('No open figures to save.');
        ppt_path = '';
        return;
    end

    try
        import mlreportgen.ppt.*;
    catch
        error('MATLAB Report Generator toolbox is required but not available.');
    end

    % sort for deterministic order
    [~, order] = sort(arrayfun(@(h)get(h,'Number'), figs));
    figs = figs(order);

    % prepare output
    timestamp = datestr(now,'yyyy-mm-dd_HHMMSS');
    pptname = sprintf('all_open_figures_%s.pptx', timestamp);
    ppt_path = fullfile(targetFolder, pptname);
    ppt = Presentation(ppt_path);
    open(ppt);

    figSizeCM = [15,10];
    dpi = 150;

    for idx = 1:numel(figs)
        origF = figs(idx);
        figNum = get(origF,'Number');
        origTitle = get(origF,'Name');
        if isempty(origTitle)
            origTitle = sprintf('Figure %d', figNum);
        end
        fprintf('Processing %s...\n', origTitle);

        % === make full hidden copy of the figure ===
        tempFig = copyobj(origF, 0);  % copy to root (creates a new figure)
        set(tempFig, 'Visible', 'off');
        % strip titles on all axes inside the copy (so the image in PPT has no title)
        axesInCopy = findall(tempFig, 'Type', 'axes');
        for a = 1:numel(axesInCopy)
            title(axesInCopy(a), '');
        end

        % export the copied figure
        tmpfile = fullfile(tempdir, sprintf('fig_%03d.png', idx));
        try
            set(tempFig, 'Units','centimeters', 'Position', [1 1 figSizeCM]); drawnow;
            exportgraphics(tempFig, tmpfile, 'Resolution', dpi);
        catch e
            warning('Failed to export figure copy %d: %s', figNum, e.message);
            close(tempFig);
            continue;
        end
        close(tempFig);

        if ~isfile(tmpfile)
            warning('Exported image missing for figure %d', figNum);
            continue;
        end

        % === Add slide ===
        slide = add(ppt, 'Blank');

        % Simplify title: extract angle if present
        angleMatch = regexp(origTitle, 'at\s*(?:angle\s*)?([0-9]+(?:\.[0-9]+)?)°', 'tokens', 'once');
        if ~isempty(angleMatch)
            angleStr = angleMatch{1};
        else
            angleStr = '?';
        end
        simpleTitle = sprintf('zfAMR: In plane, at angle %.2f°', str2double(angleStr));

        % Title box
        titleBox = TextBox();
        titlePara = mlreportgen.ppt.Paragraph(simpleTitle);
        titlePara.Style = {Bold(true), FontSize('36pt')};
        add(titleBox, titlePara);
        titleBox.X = '1cm';
        titleBox.Y = '0.5cm';
        titleBox.Width = '24cm';
        titleBox.Height = '2.5cm';
        add(slide, titleBox);

        % Picture
        pic = Picture(tmpfile);
        pic.X = '1cm';
        pic.Y = '3cm';
        pic.Width = '24cm';
        add(slide, pic);
    end

    % finalize
    close(ppt);
    try
        save(ppt);
    catch
        % some versions auto-save
    end
    fprintf('Saved %d figures into %s\n', numel(figs), ppt_path);

    if ispc()
        try
            winopen(ppt_path);
        catch
        end
    end
end
