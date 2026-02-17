% test_FCS_state_persistence_audit
% Programmatic behavioral audit for FigureControlStudio UI state persistence.

close all force;
clc;

stateFile = i_stateFilePath();
if exist(stateFile,'file') == 2
    delete(stateFile);
end

results = struct('name', {}, 'pass', {}, 'detail', {});

% ---------- Scenario 1: gridRows/gridCols persist ----------
try
    s = i_openStudio();
    c = i_findControls(s);
    c.nfRows.Value = 3;
    c.nfCols.Value = 5;
    i_persistNow(c);
    close(s);

    s2 = i_openStudio();
    c2 = i_findControls(s2);
    ok = (double(c2.nfRows.Value) == 3) && (double(c2.nfCols.Value) == 5);
    details = sprintf('rows=%g cols=%g', c2.nfRows.Value, c2.nfCols.Value);
    results(end+1) = struct('name','1) gridRows/gridCols persist','pass',ok,'detail',details); %#ok<AGROW>
    close(s2);
catch ME
    results(end+1) = struct('name','1) gridRows/gridCols persist','pass',false,'detail',ME.message); %#ok<AGROW>
end

% ---------- Scenario 2: widthPreset/customWidth persist ----------
try
    s = i_openStudio();
    c = i_findControls(s);
    c.ddWidthPreset.Value = 'Custom';
    i_fireValueChanged(c.ddWidthPreset);
    c.nfCustomWidth.Value = 14.3;
    i_persistNow(c);
    close(s);

    s2 = i_openStudio();
    c2 = i_findControls(s2);
    ok = strcmp(string(c2.ddWidthPreset.Value), "Custom") && abs(double(c2.nfCustomWidth.Value) - 14.3) < 1e-9;
    details = sprintf('widthPreset=%s customWidth=%g', string(c2.ddWidthPreset.Value), c2.nfCustomWidth.Value);
    results(end+1) = struct('name','2) widthPreset/customWidth persist','pass',ok,'detail',details); %#ok<AGROW>
    close(s2);
catch ME
    results(end+1) = struct('name','2) widthPreset/customWidth persist','pass',false,'detail',ME.message); %#ok<AGROW>
end

% ---------- Scenario 3: scopeMode persist without override ----------
try
    s = i_openStudio();
    c = i_findControls(s);
    c.ddScope.Value = 'By Name Contains';
    i_fireValueChanged(c.ddScope);
    close(s);

    s2 = i_openStudio();
    c2 = i_findControls(s2);
    ok = strcmp(string(c2.ddScope.Value), "By Name Contains");
    details = sprintf('scopeMode=%s', string(c2.ddScope.Value));
    results(end+1) = struct('name','3) scopeMode persist/no override','pass',ok,'detail',details); %#ok<AGROW>
    close(s2);
catch ME
    results(end+1) = struct('name','3) scopeMode persist/no override','pass',false,'detail',ME.message); %#ok<AGROW>
end

% ---------- Scenario 4: Reset to Defaults + delete file + reopen defaults ----------
try
    s = i_openStudio();
    c = i_findControls(s);

    c.ddScope.Value = 'By Name Contains';
    i_fireValueChanged(c.ddScope);
    c.nfRows.Value = 7;
    c.nfCols.Value = 8;
    c.ddWidthPreset.Value = 'Custom';
    i_fireValueChanged(c.ddWidthPreset);
    c.nfCustomWidth.Value = 19.2;
    c.cbAutoLabel.Value = false;
    i_persistNow(c);

    i_fireButton(c.btnResetDefaults);
    drawnow;

    defaultsNow = strcmp(string(c.ddScope.Value), "Explicit List") && ...
                  double(c.nfRows.Value) == 2 && ...
                  double(c.nfCols.Value) == 2 && ...
                  strcmp(string(c.ddWidthPreset.Value), "Single column") && ...
                  abs(double(c.nfCustomWidth.Value) - 12.0) < 1e-9 && ...
                  logical(c.cbAutoLabel.Value) == true;
    fileDeleted = exist(stateFile,'file') ~= 2;

    close(s);

    s2 = i_openStudio();
    c2 = i_findControls(s2);
    reopenDefaults = strcmp(string(c2.ddScope.Value), "Explicit List") && ...
                     double(c2.nfRows.Value) == 2 && ...
                     double(c2.nfCols.Value) == 2 && ...
                     strcmp(string(c2.ddWidthPreset.Value), "Single column") && ...
                     abs(double(c2.nfCustomWidth.Value) - 12.0) < 1e-9 && ...
                     logical(c2.cbAutoLabel.Value) == true;
    ok = defaultsNow && fileDeleted && reopenDefaults;
    details = sprintf('defaultsNow=%d fileDeleted=%d reopenDefaults=%d', defaultsNow, fileDeleted, reopenDefaults);
    results(end+1) = struct('name','4) reset defaults behavior','pass',ok,'detail',details); %#ok<AGROW>
    close(s2);
catch ME
    results(end+1) = struct('name','4) reset defaults behavior','pass',false,'detail',ME.message); %#ok<AGROW>
end

% ---------- Scenario 5: Corrupted/partial state file ----------
try
    uiState = struct('gridRows', 9, 'scopeMode', 42); %#ok<NASGU>
    save(stateFile, 'uiState');

    s = i_openStudio();
    c = i_findControls(s);
    ok = isvalid(s) && isgraphics(s,'figure') && isnumeric(c.nfRows.Value) && isfinite(c.nfRows.Value);
    details = sprintf('opened=1 gridRows=%g scopeMode=%s', c.nfRows.Value, string(c.ddScope.Value));
    results(end+1) = struct('name','5) corrupted/partial file fallback','pass',ok,'detail',details); %#ok<AGROW>
    close(s);
catch ME
    results(end+1) = struct('name','5) corrupted/partial file fallback','pass',false,'detail',ME.message); %#ok<AGROW>
end

% ---------- Scenario 6: no handle persistence + compose unaffected ----------
try
    s = i_openStudio();
    c = i_findControls(s);
    i_persistNow(c);

    S = load(stateFile, 'uiState');
    okNoCacheField = isstruct(S) && isfield(S,'uiState') && ~isfield(S.uiState, 'explicitHandleCache');

    fns = fieldnames(S.uiState);
    hasHandleLike = false;
    for i = 1:numel(fns)
        v = S.uiState.(fns{i});
        if isa(v, 'matlab.graphics.Graphics') || isa(v, 'handle') || (isnumeric(v) && any(isgraphics(v)))
            hasHandleLike = true;
            break;
        end
    end

    composeNoThrow = true;
    try
        i_fireButton(c.btnCompose); % may alert on no selection; should not throw
    catch
        composeNoThrow = false;
    end

    ok = okNoCacheField && ~hasHandleLike && composeNoThrow;
    details = sprintf('noCacheField=%d hasHandleLike=%d composeNoThrow=%d', okNoCacheField, hasHandleLike, composeNoThrow);
    results(end+1) = struct('name','6) no handle persistence + compose unaffected','pass',ok,'detail',details); %#ok<AGROW>
    close(s);
catch ME
    results(end+1) = struct('name','6) no handle persistence + compose unaffected','pass',false,'detail',ME.message); %#ok<AGROW>
end

%% Print summary
fprintf('\n=== FigureControlStudio Persistence Audit ===\n');
for i = 1:numel(results)
    status = 'FAIL';
    if results(i).pass
        status = 'PASS';
    end
    fprintf('%s | %s | %s\n', status, results(i).name, results(i).detail);
end

allPass = all([results.pass]);
fprintf('Overall: %s\n', string(allPass));

reportPath = fullfile(fileparts(mfilename('fullpath')), 'test_FCS_state_persistence_audit_report.txt');
fid = fopen(reportPath, 'w');
if fid ~= -1
    fprintf(fid, '=== FigureControlStudio Persistence Audit ===\n');
    for i = 1:numel(results)
        status = 'FAIL';
        if results(i).pass
            status = 'PASS';
        end
        fprintf(fid, '%s | %s | %s\n', status, results(i).name, results(i).detail);
    end
    fprintf(fid, 'Overall: %s\n', string(allPass));
    fclose(fid);
end


function studio = i_openStudio()
    FigureControlStudio;
    drawnow;
    figs = findall(groot, 'Type', 'figure', 'Name', 'FigureControlStudio');
    if isempty(figs)
        error('FigureControlStudio did not open.');
    end
    studio = figs(1);
end

function c = i_findControls(studio)
    c = struct();

    % Scope dropdown (unique by items containing By Name Contains)
    dds = findall(studio, 'Type', 'uidropdown');
    c.ddScope = [];
    for i = 1:numel(dds)
        try
            items = string(dds(i).Items);
            if any(items == "By Name Contains") && any(items == "Explicit List")
                c.ddScope = dds(i);
                break;
            end
        catch
        end
    end
    if isempty(c.ddScope)
        error('Scope dropdown not found.');
    end

    % Compose tab + controls
    tabs = findall(studio, 'Type', 'uitab');
    composeTab = [];
    for i = 1:numel(tabs)
        if strcmp(string(tabs(i).Title), "Compose")
            composeTab = tabs(i);
            break;
        end
    end
    if isempty(composeTab)
        error('Compose tab not found.');
    end

    nfs = findall(composeTab, 'Type', 'uieditfield', '-and', 'Style', 'numeric');
    c.nfRows = [];
    c.nfCols = [];
    c.nfCustomWidth = [];
    c.nfLabelFont = [];
    for i = 1:numel(nfs)
        r = [];
        try
            r = nfs(i).Layout.Row;
        catch
        end
        if isequal(r, 2)
            c.nfRows = nfs(i);
        elseif isequal(r, 4)
            c.nfCols = nfs(i);
        elseif isequal(r, 8)
            c.nfLabelFont = nfs(i);
        elseif isequal(r, 10)
            c.nfCustomWidth = nfs(i);
        end
    end
    if isempty(c.nfRows) || isempty(c.nfCols) || isempty(c.nfCustomWidth)
        error('Compose numeric controls not found.');
    end

    ddsCompose = findall(composeTab, 'Type', 'uidropdown');
    c.ddWidthPreset = [];
    for i = 1:numel(ddsCompose)
        try
            items = string(ddsCompose(i).Items);
            if any(items == "Single column") && any(items == "Custom")
                c.ddWidthPreset = ddsCompose(i);
                break;
            end
        catch
        end
    end
    if isempty(c.ddWidthPreset)
        error('Width preset dropdown not found.');
    end

    c.cbAutoLabel = [];
    cbs = findall(composeTab, 'Type', 'uicheckbox');
    for i = 1:numel(cbs)
        if strcmp(string(cbs(i).Text), "Auto label panels")
            c.cbAutoLabel = cbs(i);
            break;
        end
    end
    if isempty(c.cbAutoLabel)
        error('Auto label checkbox not found.');
    end

    c.btnCompose = [];
    btnsCompose = findall(composeTab, 'Type', 'uibutton');
    for i = 1:numel(btnsCompose)
        if strcmp(string(btnsCompose(i).Text), "Compose")
            c.btnCompose = btnsCompose(i);
            break;
        end
    end
    if isempty(c.btnCompose)
        error('Compose button not found.');
    end

    c.btnResetDefaults = [];
    btnsAll = findall(studio, 'Type', 'uibutton');
    for i = 1:numel(btnsAll)
        if strcmp(string(btnsAll(i).Text), "Reset to Defaults")
            c.btnResetDefaults = btnsAll(i);
            break;
        end
    end
    if isempty(c.btnResetDefaults)
        error('Reset to Defaults button not found.');
    end
end

function i_fireValueChanged(ctrl)
    try
        fcn = ctrl.ValueChangedFcn;
        if ~isempty(fcn)
            feval(fcn, ctrl, []);
        end
    catch
    end
    drawnow;
end

function i_fireButton(btn)
    fcn = btn.ButtonPushedFcn;
    if ~isempty(fcn)
        feval(fcn, btn, []);
    end
    drawnow;
end

function i_persistNow(c)
    % Triggers i_saveUIState without compose execution by using scope callback.
    i_fireValueChanged(c.ddScope);
end

function stateFile = i_stateFilePath()
    up = userpath;
    if isempty(up)
        stateRoot = pwd;
    else
        parts = strsplit(up, pathsep);
        parts = parts(~cellfun(@isempty, parts));
        if isempty(parts)
            stateRoot = pwd;
        else
            stateRoot = parts{1};
        end
    end
    stateFile = fullfile(stateRoot, 'FCS_ui_state.mat');
end
