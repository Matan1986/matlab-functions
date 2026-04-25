clear; clc;

% run_aging_observable_dataset_consolidation
% Stage E: thin consolidation of structured Aging export tables into
% tables/aging/aging_observable_dataset.csv per Stage D contract.
% Pure script (no local functions). ASCII only.
% Location: Aging/analysis/ alongside other aging_* analysis entrypoints.

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

signalDir = fullfile(repoRoot, 'tables', 'aging', 'observable_dataset_consolidation_last');
if exist(signalDir, 'dir') ~= 7
    mkdir(signalDir);
end
fidProbe = fopen(fullfile(signalDir, 'execution_probe_top.txt'), 'w');
if fidProbe >= 0
    fprintf(fidProbe, 'SCRIPT_ENTERED run_aging_observable_dataset_consolidation\n');
    fclose(fidProbe);
end

addpath(fullfile(repoRoot, 'tools'));

outCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_observable_dataset.csv');
sidecarCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_observable_dataset_sidecar.csv');
statusCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_observable_dataset_consolidation_status.csv');
reportMd = fullfile(repoRoot, 'reports', 'aging', 'aging_observable_dataset_consolidation.md');
contractCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_observable_dataset_contract.csv');
mappingCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_dataset_mapping_from_structured_outputs.csv');
unblockCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_analysis_unblock_matrix.csv');
inputPointerFile = fullfile(repoRoot, 'tables', 'aging', 'consolidation_structured_run_dir.txt');

ver = struct();
ver.CONSOLIDATION_SCRIPT_CREATED = 'YES';
ver.USED_STAGE_D_CONTRACT = 'NO';
ver.INPUT_STRUCTURED_TABLE_FOUND = 'NO';
ver.FIVE_COLUMN_DATASET_WRITTEN = 'NO';
ver.FIVE_COLUMN_ORDER_VALID = 'NO';
ver.FM_STEP_MAG_EXCLUDED = 'YES';
ver.SOURCE_RUN_POPULATED = 'NO';
ver.ROWS_DROPPED = 'NO';
ver.DUPLICATES_FOUND = 'NO';
ver.SIDE_CAR_WRITTEN = 'NO';
ver.OLD_ANALYSIS_READERS_UNBLOCKED = 'NO';
ver.READY_FOR_READER_SMOKE_TEST = 'NO';
errMsg = '';
cmdNote = 'tools/run_matlab_safe.bat with absolute path to this script';

n0 = 0;
inPath = '';
usedName = '';
droppedIdx = [];
outTbl = table();
execStatus = 'FAILED';
MEsave = [];

try
    if exist(contractCsv, 'file') ~= 2
        error('Consolidation:MissingContract', 'Missing Stage D contract: %s', contractCsv);
    end
    if exist(mappingCsv, 'file') ~= 2
        error('Consolidation:MissingMapping', 'Missing Stage D mapping: %s', mappingCsv);
    end
    ct = readtable(contractCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    reqCols = ["Tp", "tw", "Dip_depth", "FM_abs", "source_run"];
    if ~ismember('contract_column', ct.Properties.VariableNames)
        error('Consolidation:ContractSchema', 'Contract CSV missing contract_column.');
    end
    for ii = 1:numel(reqCols)
        if ~any(ct.contract_column == reqCols(ii))
            error('Consolidation:ContractRowMissing', 'Contract CSV missing row for %s.', reqCols(ii));
        end
    end
    ver.USED_STAGE_D_CONTRACT = 'YES';

    if exist(inputPointerFile, 'file') ~= 2
        error('Consolidation:MissingInputPointer', ...
            'Create %s with one line: absolute or repo-relative path to structured export run dir containing tables/observable_matrix.csv (or observables.csv).', ...
            inputPointerFile);
    end
    rawPointer = strtrim(fileread(inputPointerFile));
    if isempty(rawPointer)
        error('Consolidation:EmptyInputPointer', 'Input pointer file is empty: %s', inputPointerFile);
    end
    if ~isempty(rawPointer) && (rawPointer(1) == '/' || (length(rawPointer) > 2 && rawPointer(2) == ':'))
        structuredRunDir = rawPointer;
    else
        structuredRunDir = fullfile(repoRoot, strrep(rawPointer, '/', filesep));
    end
    structuredRunDir = char(string(structuredRunDir));

    matrixPath = fullfile(structuredRunDir, 'tables', 'observable_matrix.csv');
    obsPath = fullfile(structuredRunDir, 'tables', 'observables.csv');
    if exist(matrixPath, 'file') == 2
        inPath = matrixPath;
        usedName = 'observable_matrix.csv';
    elseif exist(obsPath, 'file') == 2
        inPath = obsPath;
        usedName = 'observables.csv';
    else
        error('Consolidation:NoStructuredTable', ...
            'Neither %s nor %s exists.', matrixPath, obsPath);
    end
    ver.INPUT_STRUCTURED_TABLE_FOUND = 'YES';

    inTbl = readtable(inPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    vnames = string(inTbl.Properties.VariableNames);
    reqA = ["Tp_K", "tw_seconds", "Dip_depth", "FM_abs", "sample", "dataset"];
    miss = strings(0, 1);
    for k = 1:numel(reqA)
        if ~any(vnames == reqA(k))
            miss(end + 1, 1) = reqA(k); %#ok<AGROW>
        end
    end
    if ~isempty(miss)
        error('Consolidation:MissingColumns', 'Input table missing columns: %s', strjoin(miss, ', '));
    end

    if any(vnames == "FM_step_mag")
        fmMagCol = inTbl.FM_step_mag;
    else
        fmMagCol = NaN(height(inTbl), 1);
    end

    n0 = height(inTbl);
    Tp = double(inTbl.Tp_K);
    tw = double(inTbl.tw_seconds);
    dd = double(inTbl.Dip_depth);
    fa = double(inTbl.FM_abs);

    manifestRunId = '';
    manPath = fullfile(structuredRunDir, 'run_manifest.json');
    if exist(manPath, 'file') == 2
        try
            manifest = load_run_manifest(structuredRunDir);
            if isfield(manifest, 'run_id')
                manifestRunId = char(string(manifest.run_id));
            elseif isfield(manifest, 'runId')
                manifestRunId = char(string(manifest.runId));
            end
        catch
            manifestRunId = '';
        end
    end
    if isempty(manifestRunId)
        manifestRunId = char(string(structuredRunDir));
        ix = strfind(manifestRunId, filesep);
        if ~isempty(ix)
            manifestRunId = manifestRunId(ix(end) + 1:end);
        end
    end

    src = strings(n0, 1);
    for r = 1:n0
        src(r) = sprintf('%s|%s|%s', manifestRunId, char(string(inTbl.sample(r))), char(string(inTbl.dataset(r))));
    end

    ok = isfinite(Tp) & isfinite(tw) & isfinite(dd) & isfinite(fa) & (tw > 0) & (strlength(strtrim(src)) > 0);
    droppedIdx = find(~ok);
    if ~isempty(droppedIdx)
        ver.ROWS_DROPPED = 'YES';
    end

    outTbl = table();
    outTbl.Tp = Tp(ok);
    outTbl.tw = tw(ok);
    outTbl.Dip_depth = dd(ok);
    outTbl.FM_abs = fa(ok);
    outTbl.source_run = src(ok);

    keyStr = strings(height(outTbl), 1);
    for r = 1:height(outTbl)
        keyStr(r) = sprintf('%.12g|%.12g|%s', outTbl.Tp(r), outTbl.tw(r), char(outTbl.source_run(r)));
    end
    [uq, ~] = unique(keyStr, 'stable');
    if numel(uq) < numel(keyStr)
        ver.DUPLICATES_FOUND = 'YES';
        error('Consolidation:DuplicateKeys', ...
            'Duplicate (Tp, tw, source_run) rows after filtering: %d unique of %d rows.', numel(uq), numel(keyStr));
    end
    ver.DUPLICATES_FOUND = 'NO';

    if height(outTbl) < 1
        error('Consolidation:NoValidRows', 'No rows passed finite-value and source_run checks after filter.');
    end

    vn = outTbl.Properties.VariableNames;
    expOrder = {'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'};
    if numel(vn) ~= 5 || any(~strcmp(vn(:), expOrder(:)))
        error('Consolidation:ColumnOrder', 'Output column order mismatch.');
    end
    if any(strcmp(vn, 'FM_step_mag'))
        error('Consolidation:FMStepMagLeak', 'FM_step_mag must not appear in five-column output.');
    end
    ver.FM_STEP_MAG_EXCLUDED = 'YES';
    ver.FIVE_COLUMN_ORDER_VALID = 'YES';
    ver.SOURCE_RUN_POPULATED = 'YES';

    if exist(fullfile(repoRoot, 'reports', 'aging'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'reports', 'aging'));
    end
    writetable(outTbl, outCsv, 'QuoteStrings', true);
    ver.FIVE_COLUMN_DATASET_WRITTEN = 'YES';

    sc = table((1:n0)', char(string(inTbl.sample)), char(string(inTbl.dataset)), ...
        char(string(inTbl.wait_time)), repmat(string(manifestRunId), n0, 1), ...
        repmat(string(inPath), n0, 1), ok, ...
        'VariableNames', {'orig_row_index', 'sample', 'dataset', 'wait_time', 'manifest_run_id', 'input_table', 'included_in_five_column'});
    if any(isfinite(fmMagCol(:)))
        sc.fm_step_mag_audit_signed_per_input_only = fmMagCol;
    end
    writetable(sc, sidecarCsv);
    ver.SIDE_CAR_WRITTEN = 'YES';

    rt = readtable(outCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve', 'Delimiter', ',');
    assert(height(rt) == height(outTbl), 'readtable height mismatch');
    assert(all(ismember({'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'}, rt.Properties.VariableNames)), ...
        'readtable missing contract columns');

    ver.READY_FOR_READER_SMOKE_TEST = 'YES';
    ver.OLD_ANALYSIS_READERS_UNBLOCKED = 'PARTIAL';
    execStatus = 'SUCCESS';
catch ME
    MEsave = ME;
    errMsg = char(string(ME.message));
    execStatus = 'FAILED';
    ver.FIVE_COLUMN_DATASET_WRITTEN = 'NO';
    ver.FIVE_COLUMN_ORDER_VALID = 'NO';
    ver.READY_FOR_READER_SMOKE_TEST = 'NO';
    ver.SIDE_CAR_WRITTEN = 'NO';
    ver.SOURCE_RUN_POPULATED = 'NO';
    emptyTbl = table('Size', [0, 5], ...
        'VariableTypes', {'double', 'double', 'double', 'double', 'string'}, ...
        'VariableNames', {'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'});
    if exist(fullfile(repoRoot, 'reports', 'aging'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'reports', 'aging'));
    end
    writetable(emptyTbl, outCsv);
    failSide = table(string(errMsg), 'VariableNames', {'failure_message'});
    writetable(failSide, sidecarCsv);
    ver.SIDE_CAR_WRITTEN = 'YES';
end

keys = fieldnames(ver);
vals = cell(size(keys));
for i = 1:numel(keys)
    vals{i} = ver.(keys{i});
end
st = table(string(keys), string(vals), 'VariableNames', {'metric', 'value'});
st(end + 1, :) = {string('EXECUTION_STATUS'), string(execStatus)};
st(end + 1, :) = {string('ERROR_MESSAGE'), string(errMsg)};
st(end + 1, :) = {string('COMMAND_NOTE'), string(cmdNote)};
writetable(st, statusCsv);

fidStatus = fopen(fullfile(signalDir, 'execution_status.csv'), 'w');
if fidStatus >= 0
    fprintf(fidStatus, 'EXECUTION_STATUS,%s\n', execStatus);
    fclose(fidStatus);
end

lines = strings(0, 1);
lines(end + 1) = '# aging_observable_dataset consolidation';
lines(end + 1) = '';
lines(end + 1) = sprintf('Generated: %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = '';
lines(end + 1) = '## Summary';
lines(end + 1) = 'This run builds a consolidation artifact from existing structured Aging tables.';
lines(end + 1) = 'It does not recompute AFM/FM from raw traces and does not change physics definitions.';
lines(end + 1) = 'Track A summary observables (AFM_like/FM_like) remain distinct from this Track B-style five-column contract.';
lines(end + 1) = '';
lines(end + 1) = '## Input';
lines(end + 1) = sprintf('- Pointer file: `%s`', strrep(inputPointerFile, '\', '/'));
if ~isempty(inPath)
    lines(end + 1) = sprintf('- Table used: `%s`', strrep(char(inPath), '\', '/'));
    lines(end + 1) = sprintf('- Table name: %s', char(string(usedName)));
end
lines(end + 1) = sprintf('- Stage D contract: `%s`', strrep(contractCsv, '\', '/'));
lines(end + 1) = sprintf('- Stage D mapping: `%s`', strrep(mappingCsv, '\', '/'));
lines(end + 1) = '';
lines(end + 1) = '## Mapping applied';
lines(end + 1) = '- Tp_K -> Tp (identity numeric rename)';
lines(end + 1) = '- tw_seconds -> tw (identity numeric rename)';
lines(end + 1) = '- Dip_depth -> Dip_depth (identity copy)';
lines(end + 1) = '- FM_abs -> FM_abs (identity copy)';
lines(end + 1) = '- source_run = sprintf(''%s|%s|%s'', manifest_run_id, sample, dataset) per Stage D doc';
lines(end + 1) = '- FM_step_mag excluded from five-column output; optional audit copy in sidecar only if column existed';
lines(end + 1) = '';
lines(end + 1) = '## Row counts';
lines(end + 1) = sprintf('- Input rows: %d', n0);
lines(end + 1) = sprintf('- Output rows after validity filter: %d', height(outTbl));
if ~isempty(droppedIdx)
    lines(end + 1) = sprintf('- Dropped row count: %d (non-finite Tp/tw/Dip_depth/FM_abs or empty source_run or tw<=0)', numel(droppedIdx));
    lines(end + 1) = sprintf('- Dropped orig_row_index (1-based input): %s', mat2str(droppedIdx'));
else
    lines(end + 1) = '- Dropped row count: 0';
end
lines(end + 1) = sprintf('- DUPLICATES_FOUND verdict: %s', ver.DUPLICATES_FOUND);
lines(end + 1) = '';
lines(end + 1) = '## Validation';
lines(end + 1) = sprintf('- FIVE_COLUMN_ORDER_VALID: %s', ver.FIVE_COLUMN_ORDER_VALID);
lines(end + 1) = sprintf('- FM_STEP_MAG_EXCLUDED: %s', ver.FM_STEP_MAG_EXCLUDED);
lines(end + 1) = sprintf('- SOURCE_RUN_POPULATED: %s', ver.SOURCE_RUN_POPULATED);
lines(end + 1) = '- Units: Tp in K, tw in s; Dip_depth and FM_abs carry same numeric units as structured export (DeltaM family unless scaled upstream).';
lines(end + 1) = '';
if ~isempty(errMsg)
    lines(end + 1) = '## Error';
    lines(end + 1) = string(errMsg);
    lines(end + 1) = '';
end
lines(end + 1) = '## Old analyses (uses_aging_observable_dataset = YES)';
if exist(unblockCsv, 'file') == 2
    ut = readtable(unblockCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    if ismember('uses_aging_observable_dataset', ut.Properties.VariableNames) && ...
            ismember('analysis_or_script', ut.Properties.VariableNames)
        mask = ut.uses_aging_observable_dataset == "YES";
        subs = ut.analysis_or_script(mask);
        for j = 1:height(subs)
            lines(end + 1) = sprintf('- %s', subs(j));
        end
    end
end
lines(end + 1) = '';
lines(end + 1) = '## Verdicts';
fn = fieldnames(ver);
for i = 1:numel(fn)
    lines(end + 1) = sprintf('- %s = %s', fn{i}, ver.(fn{i}));
end
lines(end + 1) = sprintf('- EXECUTION_STATUS = %s', execStatus);

fidR = fopen(reportMd, 'w');
if fidR >= 0
    for i = 1:numel(lines)
        fprintf(fidR, '%s\n', char(lines(i)));
    end
    fclose(fidR);
end

if ~isempty(MEsave)
    rethrow(MEsave);
end
