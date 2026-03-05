function dbgSummaryTable(cfg, varargin)
% =========================================================
% dbgSummaryTable — Save structured diagnostic summary table
% =========================================================
%
% PURPOSE:
%   Save pipeline results as formatted text for easy inspection.
%   Can be called at end of pipeline to bundle key metrics
%   including physical reconstruction context.
%
% INPUTS:
%   cfg    - configuration struct
%   varargin - name-value pairs of diagnostic data
%            - Use empty string as key to create section break
%            - Use empty string as value to skip line
%
% EXAMPLES:
%   dbgSummaryTable(cfg, ...
%       '=== SECTION 1 ===', '', ...
%       'metric1', value1, ...
%       'metric2', value2, ...
%       '', '', ...
%       '=== SECTION 2 ===', '', ...
%       'metric3', value3);
%
% =========================================================

if isfield(cfg, 'outFolder') && ~isempty(cfg.outFolder)
    baseFolder = cfg.outFolder;
elseif isfield(cfg, 'outputFolder') && ~isempty(cfg.outputFolder)
    baseFolder = cfg.outputFolder;
else
    return;  % Silent skip if no output folder
end

% Diagnostics subdirectory
diagDir = fullfile(baseFolder, 'diagnostics');
if ~isfolder(diagDir)
    mkdir(diagDir);
end

% Create table from name-value pairs
summaryFile = fullfile(diagDir, 'diagnostic_summary.txt');

fid = fopen(summaryFile, 'w');
if fid <= 0
    return;  % Silent fail
end

fprintf(fid, '╔══════════════════════════════════════════════════════════╗\n');
fprintf(fid, '║        AGING PIPELINE DIAGNOSTIC SUMMARY              ║\n');
fprintf(fid, '╠══════════════════════════════════════════════════════════╣\n');
fprintf(fid, '\n');

fprintf(fid, 'Generated: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
fprintf(fid, '\n');

% Write key-value pairs
for i = 1:2:length(varargin)
    key = varargin{i};
    val = varargin{i+1};
    
    % Section headers (key starts with '=')
    if isstring(key) || ischar(key)
        key_str = char(key);
        if startsWith(key_str, '===')
            fprintf(fid, '\n%s\n', key_str);
            fprintf(fid, '─────────────────────────────────────────────────────────\n\n');
            continue;
        end
    end
    
    % Skip empty lines
    if (isstring(val) && strlength(val) == 0) || (ischar(val) && isempty(val))
        fprintf(fid, '\n');
        continue;
    end
    
    % Format and print
    if isnumeric(val)
        if isscalar(val)
            if isnan(val)
                fprintf(fid, '  %-40s: N/A\n', key);
            else
                % Auto-select precision based on magnitude
                if abs(val) < 0.001 && val ~= 0
                    fprintf(fid, '  %-40s: %.3e\n', key, val);
                elseif abs(val) > 1000
                    fprintf(fid, '  %-40s: %.1f\n', key, val);
                else
                    fprintf(fid, '  %-40s: %.4f\n', key, val);
                end
            end
        else
            fprintf(fid, '  %-40s: [%s]\n', key, mat2str(val(:).', 3));
        end
    elseif isstring(val) || ischar(val)
        val_str = char(val);
        if ~isempty(val_str)
            fprintf(fid, '  %-40s: %s\n', key, val_str);
        end
    else
        fprintf(fid, '  %-40s: (complex type)\n', key);
    end
end

fprintf(fid, '\n');
fprintf(fid, '╚══════════════════════════════════════════════════════════╝\n');

fclose(fid);

dbg(cfg, "summary", "Summary table saved to %s", summaryFile);

end
