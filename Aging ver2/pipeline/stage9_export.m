function stage9_export(state, cfg)
% =========================================================
% stage9_export
%
% PURPOSE:
%   Export summary table and related figures (optional).
%
% INPUTS:
%   state - struct with pauseRuns data
%   cfg   - configuration struct
%
% OUTPUTS:
%   none (creates files/figures as configured)
%
% Physics meaning:
%   AFM = DeltaM dip metrics in table
%   FM  = not used
%
% =========================================================

if ~exist(cfg.outputFolder, 'dir')
    mkdir(cfg.outputFolder);
end

% Build summary table from pauseRuns
pauseK        = [state.pauseRuns.waitK]';
DeltaM_pause  = [state.pauseRuns.DeltaM_atPause]';
DeltaM_min    = [state.pauseRuns.DeltaM_localMin]';

T_min = nan(numel(state.pauseRuns),1);
for i = 1:numel(state.pauseRuns)
    if isfield(state.pauseRuns(i),'T_localMin') && ~isempty(state.pauseRuns(i).T_localMin)
        T_min(i) = state.pauseRuns(i).T_localMin;
    end
end

% Create clean ASCII table
summaryTbl = table(pauseK, DeltaM_pause, DeltaM_min, T_min, ...
    'VariableNames', {'Pause_K', 'DeltaM_atPause', 'DeltaM_localMin', 'T_localMin_K'});

% Round numbers
summaryTbl.Pause_K        = round(summaryTbl.Pause_K, 3);
summaryTbl.T_localMin_K   = round(summaryTbl.T_localMin_K, 3);

% Pretty column names for uitable (ASCII only)
prettyNames = {'Pause T (K)', ...
    'DeltaM at pause', ...
    'DeltaM local min', ...
    'T local min (K)'};

%% --- Always show summary table figure ---
tblData = table2cell(summaryTbl);

% Convert numeric columns to scientific notation
tblData(:,2) = convertToScientificStr(summaryTbl.DeltaM_atPause, 3);
tblData(:,3) = convertToScientificStr(summaryTbl.DeltaM_localMin, 3);
tblData(:,4) = convertToScientificStr(summaryTbl.T_localMin_K, 3);

% Create table figure (ALWAYS)
f_tbl = figure('Color','w','Name','DeltaM Summary Table');
t = uitable('Parent', f_tbl, ...
    'Data', tblData, ...
    'ColumnName', prettyNames, ...
    'Units','normalized', ...
    'Position',[0 0 1 1]);

set(t, 'FontSize', 14, ...
    'RowStriping', 'on', ...
    'ColumnWidth', {130,130,130,150});


switch lower(cfg.saveTableMode)
    case 'none'
        % do nothing (table already shown)

    case 'excel'
        outFile = fullfile(cfg.outputFolder, sprintf('%s_AgingSummary.xlsx', cfg.sample_name));
        writetable(summaryTbl, outFile);
        fprintf('Saved summary table to %s\n', outFile);

    case 'figure'
        outFig = fullfile(cfg.outputFolder, sprintf('%s_AgingSummary.fig', cfg.sample_name));
        savefig(f_tbl, outFig);
        fprintf('Saved table figure to %s\n', outFig);

    case 'both'
        outFile = fullfile(cfg.outputFolder, sprintf('%s_AgingSummary.xlsx', cfg.sample_name));
        writetable(summaryTbl, outFile);

        outFig = fullfile(cfg.outputFolder, sprintf('%s_AgingSummary.fig', cfg.sample_name));
        savefig(f_tbl, outFig);

        fprintf('Saved Excel + FIG in %s\n', cfg.outputFolder);

    otherwise
        warning('Unknown saveTableMode "%s". Use none|figure|excel|both.', cfg.saveTableMode);
end

end

function S = convertToScientificStr(x, digits)
if nargin < 2
    digits = 3;
end
S = cell(size(x));
for i = 1:numel(x)
    if isnan(x(i))
        S{i} = '';
    else
        S{i} = sprintf(['%0.', num2str(digits), 'e'], x(i));
    end
end
end
