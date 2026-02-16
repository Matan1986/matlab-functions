function FCS_export(figHandles, exportOpts)
% FCS_export Export only explicitly provided figures.
% Enforces explicit targeting by iterating only figHandles (no all-open scans).
% Assumes print/exportgraphics/savefig availability; optionally reuses sanitizeFilename.

    if nargin < 2
        exportOpts = struct();
    end
    opts = i_parseExportOpts(exportOpts);

    figs = FCS_resolveTargets(struct('mode', 'explicitList', 'explicitList', figHandles, 'excludeKnownGUIs', false));
    if isempty(figs)
        return;
    end

    if ~exist(opts.outDir, 'dir')
        mkdir(opts.outDir);
    end

    for idx = 1:numel(figs)
        fig = figs(idx);
        baseName = i_buildBaseName(fig, idx, opts);
        if opts.sanitize
            baseName = i_sanitizeName(baseName);
        end
        if strlength(baseName) == 0
            baseName = "Figure_" + string(idx);
        end

        for f = opts.formats
            fmt = lower(string(f));
            outFile = fullfile(opts.outDir, char(baseName + "." + fmt));
            if ~opts.overwrite
                outFile = i_uniqueFilename(outFile);
            end

            switch fmt
                case "pdf"
                    if opts.vectorMode
                        try
                            print(fig, outFile, '-dpdf', '-painters');
                        catch
                            exportgraphics(fig, outFile, 'ContentType', 'vector');
                        end
                    else
                        exportgraphics(fig, outFile, 'ContentType', 'image', 'Resolution', 300);
                    end

                case "png"
                    exportgraphics(fig, outFile, 'Resolution', 300);

                case "fig"
                    savefig(fig, outFile);

                otherwise
                    error('FCS_export:UnsupportedFormat', 'Unsupported format: %s', fmt);
            end
        end
    end
end

function opts = i_parseExportOpts(exportOpts)
    if ~isstruct(exportOpts)
        error('FCS_export:InvalidOpts', 'exportOpts must be a struct.');
    end

    opts = struct();
    opts.formats = i_parseFormats(exportOpts);
    opts.outDir = i_getStringField(exportOpts, 'outDir', string(pwd));
    opts.overwrite = i_getLogicalField(exportOpts, 'overwrite', false);
    opts.vectorMode = i_getLogicalField(exportOpts, 'vectorMode', true);
    opts.filenameFrom = lower(i_getStringField(exportOpts, 'filenameFrom', "Name"));
    opts.sanitize = i_getLogicalField(exportOpts, 'sanitize', true);
    opts.customPrefix = i_getStringField(exportOpts, 'customPrefix', "Figure");

    validNameModes = ["name", "number", "customprefix"];
    if ~any(opts.filenameFrom == validNameModes)
        error('FCS_export:InvalidFilenameFrom', 'filenameFrom must be one of: Name, Number, customPrefix.');
    end

    opts.outDir = char(opts.outDir);
end

function formats = i_parseFormats(exportOpts)
    raw = "pdf";
    if isfield(exportOpts, 'format') && ~isempty(exportOpts.format)
        raw = exportOpts.format;
    end

    if ischar(raw)
        formats = string({raw});
    elseif isstring(raw)
        formats = raw(:);
    elseif iscell(raw)
        formats = string(raw(:));
    else
        error('FCS_export:InvalidFormat', 'format must be char, string, or cellstr.');
    end

    formats = lower(strtrim(formats));
    valid = ["pdf", "png", "fig"];
    if any(~ismember(formats, valid))
        error('FCS_export:InvalidFormat', 'format supports only: pdf, png, fig.');
    end
    formats = unique(formats, 'stable');
end

function value = i_getStringField(s, name, defaultValue)
    value = defaultValue;
    if isfield(s, name) && ~isempty(s.(name))
        value = string(s.(name));
    end
end

function value = i_getLogicalField(s, name, defaultValue)
    value = defaultValue;
    if isfield(s, name) && ~isempty(s.(name))
        value = logical(s.(name));
    end
end

function out = i_buildBaseName(fig, idx, opts)
    switch opts.filenameFrom
        case "name"
            try
                out = string(fig.Name);
            catch
                out = "";
            end
            if strlength(strtrim(out)) == 0
                out = i_defaultFigureName(fig, idx);
            end

        case "number"
            out = i_defaultFigureName(fig, idx);

        case "customprefix"
            out = string(opts.customPrefix) + "_" + string(idx);

        otherwise
            out = i_defaultFigureName(fig, idx);
    end
end

function out = i_defaultFigureName(fig, idx)
    figNum = [];
    try
        figNum = fig.Number;
    catch
    end

    if ~isempty(figNum) && isnumeric(figNum) && isfinite(figNum)
        out = "Figure" + string(figNum);
    else
        out = "Figure_" + string(idx);
    end
end

function out = i_sanitizeName(nameIn)
    out = string(nameIn);
    try
        if exist('sanitizeFilename', 'file') == 2
            out = string(sanitizeFilename(char(out)));
            return;
        end
    catch
    end

    out = regexprep(out, '\\s+', '_');
    out = regexprep(out, '[^a-zA-Z0-9_\.-]', '');
    out = regexprep(out, '_+', '_');
    out = regexprep(out, '^_+|_+$', '');
end

function out = i_uniqueFilename(pathIn)
    out = pathIn;
    [p, n, e] = fileparts(pathIn);
    k = 1;
    while exist(out, 'file')
        out = fullfile(p, sprintf('%s_%d%s', n, k, e));
        k = k + 1;
    end
end
