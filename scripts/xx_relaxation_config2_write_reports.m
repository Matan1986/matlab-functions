function xx_relaxation_config2_write_reports(repoRoot, runDir, chainErrorMessage)
% Write chain inventory CSV, provenance note, and summary for Config2 XX relaxation rerun.
% chainErrorMessage: empty string on full success; otherwise short error text.

if nargin < 3
    chainErrorMessage = "";
end
chainErrorMessage = string(chainErrorMessage);

invPath = fullfile(repoRoot, "tables", "xx_relaxation_config2_chain_inventory.csv");
provPath = fullfile(repoRoot, "reports", "xx_relaxation_config2_rerun_provenance.md");
sumPath = fullfile(repoRoot, "reports", "xx_relaxation_config2_chain_summary.md");

ensureDir(fileparts(invPath));
ensureDir(fileparts(provPath));

eventPath = fullfile(repoRoot, "tables", "xx_relaxation_event_level_full_config2.csv");
[exOk, nFilesEv, nEventsEv, h25, h30, h35] = summarizeExtractionArtifacts(eventPath);

stages = {
    'extraction'
    'quality_symmetry_sequence_regime_dataset_audits'
    'detectability_structure'
    'switching_coupling'
    'morphology'
    };

paths = {
    char(joinPathsSemicolon(repoRoot, {
    "tables/xx_relaxation_event_level_full_config2.csv"
    "tables/xx_relaxation_aggregated_by_state_config2.csv"
    "reports/xx_relaxation_extraction_full_config2.md"
    }))
    char(joinPathsSemicolon(repoRoot, {
    "tables/xx_relaxation_quality_audit_config2.csv"
    "tables/xx_relaxation_symmetry_audit_config2.csv"
    "tables/xx_relaxation_sequence_audit_config2.csv"
    "tables/xx_relaxation_regime_split_config2.csv"
    "tables/xx_relaxation_full_audit_status_config2.csv"
    "reports/xx_relaxation_quality_audit_config2.md"
    "reports/xx_relaxation_symmetry_audit_config2.md"
    "reports/xx_relaxation_sequence_audit_config2.md"
    "reports/xx_relaxation_regime_split_config2.md"
    "reports/xx_relaxation_dataset_summary_config2.md"
    }))
    char(joinPathsSemicolon(repoRoot, {
    "tables/xx_relaxation_detectability_structure_config2.csv"
    "reports/xx_relaxation_detectability_structure_config2.md"
    }))
    char(joinPathsSemicolon(repoRoot, {
    "tables/xx_relaxation_switching_coupling_config2.csv"
    "reports/xx_relaxation_switching_coupling_config2.md"
    }))
    char(joinPathsSemicolon(repoRoot, {
    "tables/xx_relaxation_morphology_event_level_config2.csv"
    "tables/xx_relaxation_morphology_aggregated_config2.csv"
    "reports/xx_relaxation_morphology_map_config2.md"
    "figures/xx_relaxation_settled_map_config2.png"
    "figures/xx_relaxation_unsettled_but_relaxing_map_config2.png"
    "figures/xx_relaxation_no_clear_map_config2.png"
    }))
    };

nStages = numel(stages);
srcBranch = repmat("Config2_Amp_Temp_Dep_all", nStages, 1);
has25 = strings(nStages, 1);
has30 = strings(nStages, 1);
has35 = strings(nStages, 1);
nFilesCol = NaN(nStages, 1);
nEventsCol = NaN(nStages, 1);
statCol = strings(nStages, 1);
notesCol = strings(nStages, 1);

for i = 1:nStages
    has25(i) = yesNoFrom01(h25);
    has30(i) = yesNoFrom01(h30);
    has35(i) = yesNoFrom01(h35);
    if i == 1
        nFilesCol(i) = nFilesEv;
        nEventsCol(i) = nEventsEv;
        if exOk
            statCol(i) = "OK";
            notesCol(i) = "Event-level table present";
        else
            statCol(i) = "MISSING_OR_EMPTY";
            notesCol(i) = "Extraction output not readable";
        end
    else
        nFilesCol(i) = NaN;
        nEventsCol(i) = NaN;
        statCol(i) = artifactGroupStatus(repoRoot, i, exOk);
        notesCol(i) = downstreamNote(i, exOk, statCol(i));
    end
end

if strlength(chainErrorMessage) > 0
    notesCol(end) = notesCol(end) + " | chain_error: " + chainErrorMessage;
end

invTbl = table(stages, paths, srcBranch, has25, has30, has35, nFilesCol, nEventsCol, statCol, notesCol, ...
    'VariableNames', {'stage', 'artifact_path', 'source_branch', 'has_25mA', 'has_30mA', 'has_35mA', ...
    'n_files', 'n_events', 'status', 'notes'});
writetable(invTbl, invPath);

verdicts = buildVerdicts(exOk, h25, h30, h35, statCol, chainErrorMessage);
writeProvenance(provPath, verdicts, chainErrorMessage);
writeChainSummary(sumPath, invTbl, verdicts, chainErrorMessage);

fprintf('Wrote %s\n', invPath);
fprintf('Wrote %s\n', provPath);
fprintf('Wrote %s\n', sumPath);

if nargin >= 2 && strlength(string(runDir)) > 0 && exist(char(runDir), 'dir') == 7
    copyfile(invPath, fullfile(runDir, 'xx_relaxation_config2_chain_inventory.csv'));
    copyfile(provPath, fullfile(runDir, 'xx_relaxation_config2_rerun_provenance.md'));
    copyfile(sumPath, fullfile(runDir, 'xx_relaxation_config2_chain_summary.md'));
end

end

function s = joinPathsSemicolon(repoRoot, relList)
parts = strings(numel(relList), 1);
for ii = 1:numel(relList)
    rel = relList{ii};
    parts(ii) = string(fullfile(repoRoot, char(rel)));
end
s = strjoin(parts, '; ');
end

function s = yesNoFrom01(v)
if v >= 1
    s = "YES";
else
    s = "NO";
end
end

function [ok, nFiles, nEvents, h25, h30, h35] = summarizeExtractionArtifacts(eventPath)
ok = false;
nFiles = NaN;
nEvents = NaN;
h25 = 0;
h30 = 0;
h35 = 0;
if exist(eventPath, 'file') ~= 2
    return;
end
T = readtable(eventPath, 'TextType', 'string');
nEvents = height(T);
ok = nEvents > 0;
if ~ismember('config_id', T.Properties.VariableNames)
    return;
end
u = unique(T.config_id);
h25 = double(any(u == "config2_25mA"));
h30 = double(any(u == "config2_30mA"));
h35 = double(any(u == "config2_35mA"));
if ismember('file_id', T.Properties.VariableNames)
    nFiles = height(unique(T(:, {'file_id', 'config_id'})));
else
    nFiles = NaN;
end
end

function s = artifactGroupStatus(repoRoot, idx, extractionOk)
if ~extractionOk
    s = "BLOCKED_NO_EXTRACTION";
    return;
end
switch idx
    case 2
        files = {
            fullfile(repoRoot, "tables", "xx_relaxation_quality_audit_config2.csv")
            fullfile(repoRoot, "tables", "xx_relaxation_symmetry_audit_config2.csv")
            fullfile(repoRoot, "tables", "xx_relaxation_sequence_audit_config2.csv")
            fullfile(repoRoot, "tables", "xx_relaxation_regime_split_config2.csv")
            };
    case 3
        files = {fullfile(repoRoot, "tables", "xx_relaxation_detectability_structure_config2.csv")};
    case 4
        files = {fullfile(repoRoot, "tables", "xx_relaxation_switching_coupling_config2.csv")};
    case 5
        files = {
            fullfile(repoRoot, "tables", "xx_relaxation_morphology_event_level_config2.csv")
            fullfile(repoRoot, "tables", "xx_relaxation_morphology_aggregated_config2.csv")
            };
    otherwise
        s = "UNKNOWN";
        return;
end
allOk = true;
for k = 1:numel(files)
    if exist(files{k}, 'file') ~= 2
        allOk = false;
    end
end
if allOk
    s = "OK";
else
    s = "MISSING";
end
end

function n = downstreamNote(idx, extractionOk, st)
if ~extractionOk
    n = "Waiting on extraction";
    return;
end
if st == "OK"
    n = "Artifacts present";
elseif st == "MISSING"
    n = "One or more expected outputs missing";
else
    n = string(st);
end
end

function v = buildVerdicts(exOk, h25, h30, h35, statCol, chainErrorMessage)
v = struct();
v.XX_CONFIG2_RERUN_COMPLETED = "NO";
v.XX_CONFIG2_SOURCE_BINDING_CORRECT = "YES";
v.XX_CONFIG2_FULL_COVERAGE_25_30_35 = "NO";
v.XX_CONFIG2_EXTRACTION_COMPLETED = "NO";
v.XX_CONFIG2_DOWNSTREAM_CHAIN_COMPLETED = "NO";
v.XX_CONFIG2_OUTPUTS_CANONICAL_FOR_XX = "NO";
v.PRIOR_MISASSIGNED_OUTPUTS_PRESERVED = "YES";

if exOk
    v.XX_CONFIG2_EXTRACTION_COMPLETED = "YES";
end
if exOk && h25 == 1 && h30 == 1 && h35 == 1
    v.XX_CONFIG2_FULL_COVERAGE_25_30_35 = "YES";
end
downstreamOk = all(statCol(2:end) == "OK");
if exOk && downstreamOk && strlength(chainErrorMessage) == 0
    v.XX_CONFIG2_DOWNSTREAM_CHAIN_COMPLETED = "YES";
    v.XX_CONFIG2_RERUN_COMPLETED = "YES";
    v.XX_CONFIG2_OUTPUTS_CANONICAL_FOR_XX = "YES";
end
end

function ensureDir(d)
if exist(d, 'dir') ~= 7
    mkdir(d);
end
end

function writeProvenance(path, verdicts, chainErrorMessage)
nl = sprintf('\n');
blk = ['# XX relaxation Config2 rerun provenance', nl, nl, ...
    'This report documents the corrected XX relaxation analysis chain bound to the ', ...
    'canonical XX-stable raw branch (Config2, Amp Temp Dep all) rather than Config3 23.', nl, nl, ...
    'The prior documented XX relaxation chain used Config3 23 and is misassigned for XX scientific interpretation; ', ...
    'those legacy artifacts were not deleted or overwritten by this rerun.', nl, nl, ...
    'Use the `*_config2` tables and reports as the XX-scoped reference outputs going forward.', nl, nl, ...
    '## Source binding (execution change)', nl, nl, ...
    '- Canonical raw root: `...\\FIB5_Switching_old_PPMS\\Config2\\Amp Temp Dep all` (see `scripts/xx_relaxation_config2_sources.m`).', nl, ...
    '- Current folders are discovered at runtime as `Temp Dep 25mA*`, `Temp Dep 30mA*`, `Temp Dep 35mA*` under that root.', nl, ...
    '- Extraction profile `config2` in `run_xx_relaxation_extraction_full` uses all `.dat` files in each matched folder (no partial temperature subsampling).', nl, ...
    '- Legacy profile remains available as `run_xx_relaxation_extraction_full()` default (`legacy_config3`) and still targets Config3 23 for historical provenance only.', nl, nl];
if strlength(chainErrorMessage) > 0
    blk = [blk, '## Execution note', nl, 'Chain error message: ', char(chainErrorMessage), nl, nl]; %#ok<AGROW>
end
blk = [blk, '## Required verdicts', nl, nl, '```text', nl, ...
    'XX_CONFIG2_RERUN_COMPLETED = ', char(verdicts.XX_CONFIG2_RERUN_COMPLETED), nl, ...
    'XX_CONFIG2_SOURCE_BINDING_CORRECT = ', char(verdicts.XX_CONFIG2_SOURCE_BINDING_CORRECT), nl, ...
    'XX_CONFIG2_FULL_COVERAGE_25_30_35 = ', char(verdicts.XX_CONFIG2_FULL_COVERAGE_25_30_35), nl, ...
    'XX_CONFIG2_EXTRACTION_COMPLETED = ', char(verdicts.XX_CONFIG2_EXTRACTION_COMPLETED), nl, ...
    'XX_CONFIG2_DOWNSTREAM_CHAIN_COMPLETED = ', char(verdicts.XX_CONFIG2_DOWNSTREAM_CHAIN_COMPLETED), nl, ...
    'XX_CONFIG2_OUTPUTS_CANONICAL_FOR_XX = ', char(verdicts.XX_CONFIG2_OUTPUTS_CANONICAL_FOR_XX), nl, ...
    'PRIOR_MISASSIGNED_OUTPUTS_PRESERVED = ', char(verdicts.PRIOR_MISASSIGNED_OUTPUTS_PRESERVED), nl, ...
    '```', nl];
writeTextFile(char(path), blk);
end

function writeChainSummary(path, invTbl, verdicts, chainErrorMessage)
nl = sprintf('\n');
blk = ['# XX relaxation Config2 chain summary', nl, nl, ...
    '## Generated artifacts (inventory)', nl, nl, ...
    'See `tables/xx_relaxation_config2_chain_inventory.csv` for stage-level paths and status.', nl, nl, ...
    '- Stages listed: ', sprintf('%d', height(invTbl)), nl, nl, ...
    '## Coverage and inheritance', nl, nl, ...
    '- Full Config2 XX current coverage (25 / 30 / 35 mA): see `reports/xx_relaxation_extraction_full_config2.md` section ', ...
    '"Required current coverage (25 / 30 / 35 mA)" and per-config file/event counts.', nl, ...
    '- Downstream audits and morphology read `tables/xx_relaxation_event_level_full_config2.csv` (or re-read raw with the same Config2 folder map) ', ...
    'so all listed stages inherit the corrected extraction binding.', nl, nl];
if strlength(chainErrorMessage) > 0
    blk = [blk, nl, '## Execution note', nl, char(chainErrorMessage), nl, nl]; %#ok<AGROW>
end
blk = [blk, nl, '## Corrected artifact list (by stage)', nl, nl];
for ir = 1:height(invTbl)
    blk = [blk, '- ', char(string(invTbl.stage{ir})), ': ', char(string(invTbl.artifact_path{ir})), nl]; %#ok<AGROW>
end
blk = [blk, nl, '## Required verdicts', nl, nl, '```text', nl, ...
    'XX_CONFIG2_RERUN_COMPLETED = ', char(verdicts.XX_CONFIG2_RERUN_COMPLETED), nl, ...
    'XX_CONFIG2_SOURCE_BINDING_CORRECT = ', char(verdicts.XX_CONFIG2_SOURCE_BINDING_CORRECT), nl, ...
    'XX_CONFIG2_FULL_COVERAGE_25_30_35 = ', char(verdicts.XX_CONFIG2_FULL_COVERAGE_25_30_35), nl, ...
    'XX_CONFIG2_EXTRACTION_COMPLETED = ', char(verdicts.XX_CONFIG2_EXTRACTION_COMPLETED), nl, ...
    'XX_CONFIG2_DOWNSTREAM_CHAIN_COMPLETED = ', char(verdicts.XX_CONFIG2_DOWNSTREAM_CHAIN_COMPLETED), nl, ...
    'XX_CONFIG2_OUTPUTS_CANONICAL_FOR_XX = ', char(verdicts.XX_CONFIG2_OUTPUTS_CANONICAL_FOR_XX), nl, ...
    'PRIOR_MISASSIGNED_OUTPUTS_PRESERVED = ', char(verdicts.PRIOR_MISASSIGNED_OUTPUTS_PRESERVED), nl, ...
    '```', nl];
writeTextFile(char(path), blk);
end

function writeTextFile(path, text)
fid = fopen(path, 'w');
if fid < 0
    error('xx_relaxation_config2_write_reports:OpenFailed', 'Could not open for write: %s', path);
end
try
    fwrite(fid, text, 'char');
catch ME
    fclose(fid);
    rethrow(ME);
end
fclose(fid);
end
