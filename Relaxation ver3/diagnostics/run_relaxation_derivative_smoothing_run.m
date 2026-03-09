function out = run_relaxation_derivative_smoothing_run(dataDir, cfg)
% run_relaxation_derivative_smoothing_run
% Execute full Relaxation derivative smoothing diagnostics in a run-scoped context.

if nargin < 1 || isempty(dataDir)
    dataDir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM";
end
if nargin < 2 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(diagDir);

runLabel = getDef(cfg, 'runLabel', 'derivative_smoothing');
runCfg = struct();
runCfg.runLabel = runLabel;
runCfg.dataset = char(string(dataDir));
run = createRunContext('relaxation', runCfg);

fprintf('Relaxation run directory:\n%s\n', run.run_dir);

sub = ensureRunSubfolders(run.run_dir);
appendLog(run.log_path, sprintf('[%s] Starting derivative smoothing run orchestration\n', stampNow()));
appendLog(run.log_path, sprintf('Data directory: %s\n', char(string(dataDir))));

analysisCfg = getDef(cfg, 'analysisCfg', struct());
renderCfg = getDef(cfg, 'renderCfg', struct());

analysisOut = analyze_relaxation_derivative_smoothing(dataDir, analysisCfg);
renderOut = render_relaxation_derivative_interpretable(char(analysisOut.outDir), renderCfg);

analysisDir = char(renderOut.outDir);
appendLog(run.log_path, sprintf('Analysis output directory: %s\n', analysisDir));

stageInfo = stageRunArtifacts(analysisDir, sub);

archiveName = sprintf('relaxation_derivative_smoothing_%s.zip', run.run_id);
zipPath = fullfile(sub.archives, archiveName);
if exist(zipPath, 'file')
    delete(zipPath);
end
zipInputs = {'figures', 'csv', 'reports', 'artifacts', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'};
zip(zipPath, zipInputs, run.run_dir);

notes = {
    sprintf('Run ID: %s', run.run_id)
    sprintf('Timestamp: %s', stampNow())
    sprintf('Executed scripts: analyze_relaxation_derivative_smoothing.m, render_relaxation_derivative_interpretable.m')
    sprintf('Primary analysis directory: %s', analysisDir)
    sprintf('Staged figures: %d', stageInfo.nFigures)
    sprintf('Staged csv files: %d', stageInfo.nCsv)
    sprintf('Staged reports: %d', stageInfo.nReports)
    sprintf('Staged artifacts: %d', stageInfo.nArtifacts)
    sprintf('Archive: %s', zipPath)
    ''
};
writecell(notes, run.notes_path, 'FileType', 'text');

appendLog(run.log_path, sprintf('Archive created: %s\n', zipPath));
appendLog(run.log_path, sprintf('[%s] Run complete\n', stampNow()));

out = struct();
out.run = run;
out.runDir = string(run.run_dir);
out.analysisDir = string(analysisDir);
out.archivePath = string(zipPath);
out.figuresDir = string(sub.figures);
out.csvDir = string(sub.csv);
out.reportsDir = string(sub.reports);
out.artifactsDir = string(sub.artifacts);
out.stageInfo = stageInfo;

fprintf('\n=== Relaxation derivative smoothing run complete ===\n');
fprintf('Run dir: %s\n', run.run_dir);
fprintf('Archive: %s\n\n', zipPath);
end

function sub = ensureRunSubfolders(runDir)
sub = struct();
sub.figures = fullfile(runDir, 'figures');
sub.csv = fullfile(runDir, 'csv');
sub.reports = fullfile(runDir, 'reports');
sub.archives = fullfile(runDir, 'archives');
sub.artifacts = fullfile(runDir, 'artifacts');

names = fieldnames(sub);
for i = 1:numel(names)
    p = sub.(names{i});
    if exist(p, 'dir') ~= 7
        mkdir(p);
    end
end
end

function info = stageRunArtifacts(srcDir, sub)
items = dir(fullfile(srcDir, '*'));

nFig = 0;
nCsv = 0;
nRep = 0;
nArt = 0;

for i = 1:numel(items)
    it = items(i);
    if it.isdir
        continue;
    end

    src = fullfile(it.folder, it.name);
    [~, base, ext] = fileparts(it.name);
    extL = lower(ext);

    if any(strcmp(extL, {'.png', '.pdf', '.fig'}))
        copyfile(src, fullfile(sub.figures, it.name));
        nFig = nFig + 1;
    elseif strcmp(extL, '.csv')
        copyfile(src, fullfile(sub.csv, it.name));
        nCsv = nCsv + 1;
    elseif any(strcmp(extL, {'.md', '.txt'}))
        copyfile(src, fullfile(sub.reports, it.name));
        nRep = nRep + 1;
    elseif strcmp(extL, '.zip')
        % Keep source zip in analysis folder; run archive is created separately.
    else
        safeName = [base extL];
        copyfile(src, fullfile(sub.artifacts, safeName));
        nArt = nArt + 1;
    end
end

info = struct('nFigures', nFig, 'nCsv', nCsv, 'nReports', nRep, 'nArtifacts', nArt);
end

function appendLog(logPath, txt)
fid = fopen(logPath, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function val = getDef(s, f, d)
if isfield(s, f)
    val = s.(f);
else
    val = d;
end
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
