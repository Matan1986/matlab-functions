function writeSwitchingExecutionStatus(runDir, executionStatus, inputFound, errorMessage, nT, mainSummary, isFinal)
%WRITESWITCHINGEXECUTIONSTATUS Authoritative writer for runDir/execution_status.csv (see docs/execution_status_schema.md).
%
% Schema (exactly five columns, no extras): EXECUTION_STATUS, INPUT_FOUND, ERROR_MESSAGE, N_T, MAIN_RESULT_SUMMARY.
% EXECUTION_STATUS must be PARTIAL, SUCCESS, or FAILED.
% Non-final (isFinal=false): checkpoint only; must be PARTIAL; overwrites the file (not append).
% Final (isFinal=true): must be SUCCESS or FAILED; written atomically via temp file then move; SUCCESS requires empty ERROR_MESSAGE;
%   FAILED requires non-empty ERROR_MESSAGE (uses placeholder if the message is empty).

if nargin < 7
    error('writeSwitchingExecutionStatus:Args', 'Seven arguments required.');
end
if isempty(runDir) || exist(runDir, 'dir') ~= 7
    error('writeSwitchingExecutionStatus:RunDir', 'runDir must be an existing directory: %s', char(string(runDir)));
end

thisFile = mfilename('fullpath');
utilsDir = fileparts(thisFile);
switchingDir = fileparts(utilsDir);
repoRootWses = fileparts(switchingDir);
toolsDirWses = fullfile(repoRootWses, 'tools');
if exist(fullfile(toolsDirWses, 'atomic_commit_file.m'), 'file') == 2
    addpath(toolsDirWses);
end

statusCols = {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'};
es = wses_normExecStatus(executionStatus);
allowed = {'PARTIAL', 'SUCCESS', 'FAILED'};
if ~ismember(es, allowed)
    error('writeSwitchingExecutionStatus:InvalidExecutionStatus', ...
        'EXECUTION_STATUS must be PARTIAL, SUCCESS, or FAILED; got: %s', es);
end

errRaw = wses_normMsg(errorMessage);
if isFinal
    if strcmp(es, 'PARTIAL')
        error('writeSwitchingExecutionStatus:InvalidFinal', ...
            'Final write cannot use EXECUTION_STATUS=PARTIAL; use SUCCESS or FAILED.');
    end
    if strcmp(es, 'SUCCESS')
        if ~isempty(strtrim(errRaw))
            error('writeSwitchingExecutionStatus:SuccessNeedsEmptyError', ...
                'Final SUCCESS requires empty ERROR_MESSAGE.');
        end
        errStr = '';
    else
        if isempty(strtrim(errRaw))
            errStr = 'FAILED';
        else
            errStr = errRaw;
        end
    end
else
    if ~strcmp(es, 'PARTIAL')
        error('writeSwitchingExecutionStatus:CheckpointNotPartial', ...
            'Non-final writes must use EXECUTION_STATUS=PARTIAL; got: %s', es);
    end
    errStr = errRaw;
end

ifStr = wses_normYesNo(inputFound);
mainStr = wses_normSummary(mainSummary);
nTnum = wses_normNT(nT);

T = table({es}, {ifStr}, {errStr}, nTnum, {mainStr}, 'VariableNames', statusCols);

pathFinal = fullfile(runDir, 'execution_status.csv');
if isFinal
    tmpPath = fullfile(runDir, 'execution_status.tmp.csv');
    writetable(T, tmpPath);
    atomic_commit_file(tmpPath, pathFinal);
else
    tmpPath = fullfile(runDir, 'execution_status.partial.tmp.csv');
    writetable(T, tmpPath);
    atomic_commit_file(tmpPath, pathFinal);
end

end

function es = wses_normExecStatus(v)
if iscell(v)
    if isempty(v)
        error('writeSwitchingExecutionStatus:EmptyExecutionStatus', 'EXECUTION_STATUS is empty.');
    end
    raw = v{1};
else
    raw = v;
end
st = char(string(raw));
if isempty(strtrim(st))
    error('writeSwitchingExecutionStatus:EmptyExecutionStatus', 'EXECUTION_STATUS is empty.');
end
es = upper(strtrim(st));
end

function s = wses_normMsg(v)
if iscell(v) && ~isempty(v)
    s = char(string(v{1}));
elseif isempty(v)
    s = '';
else
    s = char(string(v));
end
end

function s = wses_normYesNo(v)
if iscell(v) && ~isempty(v)
    t = upper(strtrim(char(string(v{1}))));
else
    t = upper(strtrim(char(string(v))));
end
if ~ismember(t, {'YES', 'NO'})
    error('writeSwitchingExecutionStatus:InvalidInputFound', ...
        'INPUT_FOUND must be YES or NO; got: %s', t);
end
s = t;
end

function s = wses_normSummary(v)
if iscell(v) && ~isempty(v)
    s = char(string(v{1}));
else
    s = char(string(v));
end
s = strrep(strrep(s, sprintf('\n'), ' '), char(13), ' ');
end

function n = wses_normNT(v)
if isnumeric(v) && ~isempty(v)
    n = double(v(1));
elseif islogical(v) && ~isempty(v)
    n = double(v(1));
else
    tmp = str2double(char(string(v)));
    if isnan(tmp)
        n = NaN;
    else
        n = tmp;
    end
end
end
