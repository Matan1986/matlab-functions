% F6N — Direct archived-source compatibility check (Aging only)
% diagnostic_only source_compatibility_only

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F6N_direct_archived_source_compatibility_check';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F6N_direct_archived_source_compatibility_check.m');

rp = @(rel) fullfile(repoRoot, strrep(rel, '/', filesep));
outTables = rp('tables/aging');
outReports = rp('reports/aging');
outFig = rp('figures');
if exist(outTables, 'dir') ~= 7, mkdir(outTables); end
if exist(outReports, 'dir') ~= 7, mkdir(outReports); end
if exist(outFig, 'dir') ~= 7, mkdir(outFig); end

arch26 = rp('results_old/aging/runs/run_2026_03_10_231719_tp_26_structured_export/tables/observable_matrix.csv');
f6l26 = rp('tables/aging/aging_F6L_26K_parity_diagnosis.csv');
f6m26 = rp('tables/aging/aging_F6M_26K_bridge_diagnosis.csv');
curAll = rp('tables/aging/aggregate_structured_export_aging_Tp_tw_2026_04_26_085033/tables/observable_matrix.csv');

runCtx = createRunContext('aging', cfg);
runTablesDir = fullfile(runCtx.run_dir, 'tables');
runReportsDir = fullfile(runCtx.run_dir, 'reports');
runFigDir = fullfile(runCtx.run_dir, 'figures');
if exist(runTablesDir, 'dir') ~= 7, mkdir(runTablesDir); end
if exist(runReportsDir, 'dir') ~= 7, mkdir(runReportsDir); end
if exist(runFigDir, 'dir') ~= 7, mkdir(runFigDir); end

assert(exist(arch26, 'file') == 2, 'F6N:MissingArchived26K');
assert(exist(f6l26, 'file') == 2, 'F6N:MissingF6L26K');
assert(exist(f6m26, 'file') == 2, 'F6N:MissingF6M26K');
assert(exist(curAll, 'file') == 2, 'F6N:MissingCurrentObservableMatrix');

% 1) direct archived source read
a = readtable(arch26, 'TextType', 'string', 'VariableNamingRule', 'preserve');
a.Tp_K = double(a.Tp_K);
a.tw_seconds = double(a.tw_seconds);
a.Dip_depth = double(a.Dip_depth);
a.FM_abs = double(a.FM_abs);
a26 = a(a.Tp_K == 26, :);
a26 = sortrows(a26, 'tw_seconds');
a26Read = table();
a26Read.Tp = a26.Tp_K;
a26Read.tw = a26.tw_seconds;
a26Read.sample = string(a26.sample);
a26Read.dataset = string(a26.dataset);
a26Read.Dip_depth_archived_source = a26.Dip_depth;
a26Read.FM_abs_archived_source = a26.FM_abs;
a26Read.source_run = repmat("run_2026_03_10_231719_tp_26_structured_export", height(a26), 1);

% 2) direct archived vs F6L replay parity
l = readtable(f6l26, 'TextType', 'string', 'VariableNamingRule', 'preserve');
l.Tp = double(l.Tp); l.tw = double(l.tw);
l.Dip_depth_archived_replay = double(l.Dip_depth_archived_replay);
l.FM_abs_archived_replay = double(l.FM_abs_archived_replay);
l26 = sortrows(l(l.Tp == 26, :), 'tw');

par = outerjoin(a26Read, l26(:, {'Tp','tw','Dip_depth_archived_replay','FM_abs_archived_replay','fast_dip_highR_reproduced'}), ...
    'Keys', {'Tp','tw'}, 'MergeKeys', true, 'Type', 'left');
par.Dip_abs_diff = abs(par.Dip_depth_archived_source - par.Dip_depth_archived_replay);
par.FM_abs_diff = abs(par.FM_abs_archived_source - par.FM_abs_archived_replay);
par.Dip_match = yesNo(par.Dip_abs_diff < 1e-12);
par.FM_match = yesNo(par.FM_abs_diff < 1e-12);
par.row_exact_match = yesNo((par.Dip_abs_diff < 1e-12) & (par.FM_abs_diff < 1e-12));

% 3) archived vs current 26K
c = readtable(curAll, 'TextType', 'string', 'VariableNamingRule', 'preserve');
c.Tp_K = double(c.Tp_K); c.tw_seconds = double(c.tw_seconds);
c.Dip_depth = double(c.Dip_depth); c.FM_abs = double(c.FM_abs);
c26 = sortrows(c(c.Tp_K == 26, :), 'tw_seconds');
c26s = table();
c26s.Tp = c26.Tp_K;
c26s.tw = c26.tw_seconds;
c26s.Dip_depth_current_source = c26.Dip_depth;
c26s.FM_abs_current_source = c26.FM_abs;
c26s.current_source_run = string(c26.source_run_dir);

cmp = outerjoin(par(:, {'Tp','tw','Dip_depth_archived_source','FM_abs_archived_source'}), c26s, ...
    'Keys', {'Tp','tw'}, 'MergeKeys', true, 'Type', 'left');
cmp.Dip_rel_diff_current_vs_archived = relDiffVec(cmp.Dip_depth_archived_source, cmp.Dip_depth_current_source);
cmp.FM_rel_diff_current_vs_archived = relDiffVec(cmp.FM_abs_archived_source, cmp.FM_abs_current_source);
cmp.Dip_differs = yesNo(abs(cmp.Dip_rel_diff_current_vs_archived) > 0.05);
cmp.FM_stable = yesNo(abs(cmp.FM_rel_diff_current_vs_archived) < 1e-12);
cmp.current_curve_note = repmat("Current 26K source shows late/high Dip at 3600s relative to early archived 3s minimum.", height(cmp), 1);

% Optional figure
fig = figure('Visible','off','Color','w','Position',[80 80 680 430]);
t = cmp.tw;
subplot(2,1,1);
plot(t, cmp.Dip_depth_archived_source, '-o', t, cmp.Dip_depth_current_source, '-s', 'LineWidth',1.2);
grid on; xlabel('tw (s)'); ylabel('Dip\_depth'); legend('Archived 26K','Current 26K','Location','best');
title('F6N direct archived vs current at 26K');
subplot(2,1,2);
plot(t, cmp.FM_abs_archived_source, '-o', t, cmp.FM_abs_current_source, '-s', 'LineWidth',1.2);
grid on; xlabel('tw (s)'); ylabel('FM\_abs');
exportgraphics(fig, fullfile(outFig, 'aging_F6N_26K_direct_archived_vs_current_DipFM.png'), 'Resolution', 130);
close(fig);

% 4) Verdicts
archReadOk = height(a26Read) > 0;
matchF6L = all((par.Dip_abs_diff < 1e-12) & (par.FM_abs_diff < 1e-12));
fastDipPresent = min(a26Read.Dip_depth_archived_source) == a26Read.Dip_depth_archived_source(a26Read.tw == 3);
curSlowDip = cmp.Dip_depth_current_source(cmp.tw==3600) > cmp.Dip_depth_current_source(cmp.tw==3);
fmStable = all(abs(cmp.FM_rel_diff_current_vs_archived) < 1e-12);

if archReadOk && matchF6L && fastDipPresent
    primaryNarrow = "ARCHIVED_SOURCE_DIRECTLY_CONTAINS_FAST_DIP";
elseif archReadOk
    primaryNarrow = "ARCHIVED_SOURCE_DOES_NOT_DIRECTLY_CONTAIN_FAST_DIP";
else
    primaryNarrow = "INSUFFICIENT_ARTIFACTS";
end

statusRows = {
    'F6N_DIRECT_ARCHIVED_SOURCE_CHECK_COMPLETED', 'YES';
    'ARCHIVED_26K_SOURCE_READ_SUCCESSFULLY', yesNo(archReadOk);
    'ARCHIVED_SOURCE_MATCHES_F6L_REPLAY', yesNo(matchF6L);
    'ARCHIVED_SOURCE_DIRECTLY_CONTAINS_FAST_DIP', yesNo(fastDipPresent);
    'CURRENT_SOURCE_CONTAINS_SLOW_DIP', yesNo(curSlowDip);
    'FM_STABLE_ARCHIVED_VS_CURRENT', yesNo(fmStable);
    'PRIMARY_CAUSAL_NARROWING', char(primaryNarrow);
    'READY_FOR_NEXT_STEP', 'YES';
    'READY_FOR_DIRECT_NON_RMS_METHOD_SEARCH', 'NO';
    'METHOD_SEARCH_PERFORMED', 'NO';
    'R_VS_X_ANALYSIS_PERFORMED', 'NO';
    'RELAXATION_TOUCHED', 'NO';
    'SWITCHING_TOUCHED', 'NO'
    };
statusTbl = cell2table(statusRows, 'VariableNames', {'verdict_key','verdict_value'});

% write outputs
writetable(a26Read, fullfile(outTables, 'aging_F6N_direct_archived_26K_source_read.csv'));
writetable(par, fullfile(outTables, 'aging_F6N_26K_source_vs_F6L_replay_parity.csv'));
writetable(cmp, fullfile(outTables, 'aging_F6N_26K_archived_vs_current_source_comparison.csv'));
writetable(statusTbl, fullfile(outTables, 'aging_F6N_status.csv'));

reportPath = fullfile(outReports, 'aging_F6N_direct_archived_source_compatibility_check.md');
writeReport(reportPath, a26Read, par, cmp, statusTbl, primaryNarrow);

copyfile(fullfile(outTables, 'aging_F6N_direct_archived_26K_source_read.csv'), fullfile(runTablesDir, 'aging_F6N_direct_archived_26K_source_read.csv'));
copyfile(fullfile(outTables, 'aging_F6N_26K_source_vs_F6L_replay_parity.csv'), fullfile(runTablesDir, 'aging_F6N_26K_source_vs_F6L_replay_parity.csv'));
copyfile(fullfile(outTables, 'aging_F6N_26K_archived_vs_current_source_comparison.csv'), fullfile(runTablesDir, 'aging_F6N_26K_archived_vs_current_source_comparison.csv'));
copyfile(fullfile(outTables, 'aging_F6N_status.csv'), fullfile(runTablesDir, 'aging_F6N_status.csv'));
copyfile(reportPath, fullfile(runReportsDir, 'aging_F6N_direct_archived_source_compatibility_check.md'));
copyfile(fullfile(outFig, 'aging_F6N_26K_direct_archived_vs_current_DipFM.png'), fullfile(runFigDir, 'aging_F6N_26K_direct_archived_vs_current_DipFM.png'));

executionStatus = table({'SUCCESS'}, {'YES'}, {''}, {'F6N direct archived source check completed'}, ...
    'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','MAIN_RESULT_SUMMARY'});
writetable(executionStatus, fullfile(runCtx.run_dir, 'execution_status.csv'));

function y = yesNo(tf)
if numel(tf) == 1
    if tf, y = "YES"; else, y = "NO"; end
else
    y = strings(size(tf));
    y(tf) = "YES";
    y(~tf) = "NO";
end
end

function r = relDiffVec(a,b)
r = NaN(size(a));
for k = 1:numel(a)
    if isfinite(a(k)) && isfinite(b(k)) && abs(a(k)) > eps
        r(k) = (b(k)-a(k))/abs(a(k));
    elseif isfinite(a(k)) && isfinite(b(k))
        r(k) = b(k)-a(k);
    end
end
end

function writeReport(path, a26Read, par, cmp, statusTbl, primaryNarrow)
fid = fopen(path, 'w');
fprintf(fid, '# F6N direct archived-source compatibility check\n\n');
fprintf(fid, 'Scope: Aging only. Source compatibility only.\n\n');
fprintf(fid, '## Direct archived 26K source read\n\n');
for i = 1:height(a26Read)
    fprintf(fid, '- tw=%.0f, Dip=%.12g, FM=%.12g\n', a26Read.tw(i), a26Read.Dip_depth_archived_source(i), a26Read.FM_abs_archived_source(i));
end
fprintf(fid, '\n## Archived source vs F6L replay parity\n\n');
fprintf(fid, '- All rows exact match: %s\n', char(yesNo(all(par.Dip_abs_diff<1e-12 & par.FM_abs_diff<1e-12))));
fprintf(fid, '\n## Archived vs current 26K source\n\n');
for i = 1:height(cmp)
    fprintf(fid, '- tw=%.0f, Dip archived=%.12g, Dip current=%.12g, FM archived=%.12g, FM current=%.12g\n', ...
        cmp.tw(i), cmp.Dip_depth_archived_source(i), cmp.Dip_depth_current_source(i), cmp.FM_abs_archived_source(i), cmp.FM_abs_current_source(i));
end
fprintf(fid, '\n## Primary causal narrowing\n\n');
fprintf(fid, '- %s\n\n', primaryNarrow);
fprintf(fid, '## Verdicts\n\n');
for i = 1:height(statusTbl)
    fprintf(fid, '- **%s**: %s\n', statusTbl.verdict_key{i}, statusTbl.verdict_value{i});
end
fclose(fid);
end
