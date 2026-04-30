% Phase 4B_C02 - corrected-old collapse-like panel range lock
% Narrow QA slice only. No broad replay, no rename, no cross-module comparison.

clear;
clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

sourceTracePath = fullfile(repoRoot, 'tables', 'switching_phase4B_C02_collapse_like_panel_source_trace.csv');
rangeLockPath = fullfile(repoRoot, 'tables', 'switching_phase4B_C02_collapse_like_panel_range_lock.csv');
statusPath = fullfile(repoRoot, 'tables', 'switching_phase4B_C02_status.csv');
reportPath = fullfile(repoRoot, 'reports', 'switching_phase4B_C02_collapse_like_panel_range_lock.md');
pngPath = fullfile(repoRoot, 'figures', 'switching', 'phase4B_C02_collapse_like_panel_range_lock.png');
figPath = fullfile(repoRoot, 'figures', 'switching', 'phase4B_C02_collapse_like_panel_range_lock.fig');

% Authoritative corrected-old collapse-slice maps (artifact index roles).
sourceA = fullfile(repoRoot, 'tables', 'switching_corrected_old_authoritative_residual_after_mode1_map.csv');
sourceB = fullfile(repoRoot, 'tables', 'switching_corrected_old_authoritative_mode1_reconstruction_map.csv');
sourceC = fullfile(repoRoot, 'tables', 'switching_corrected_old_authoritative_artifact_index.csv');

sourceResolved = false;
outputsWritten = false;
pngWritten = false;
figWritten = false;
rangeLocked = false;
displayTransformDocumented = false;
sourceFamilyDocumented = false;

if ~exist(fileparts(pngPath), 'dir')
    mkdir(fileparts(pngPath));
end

traceRows = table();
traceRows.candidate_id = ["SRC_A"; "SRC_B"; "SRC_C"];
traceRows.candidate_path = string({sourceA; sourceB; sourceC});
traceRows.semantic_family = ["CORRECTED_CANONICAL_OLD_ANALYSIS"; ...
                             "CORRECTED_CANONICAL_OLD_ANALYSIS"; ...
                             "AUTHORITATIVE_INDEX_METADATA"];
traceRows.source_role = ["authoritative_residual_after_mode1_map"; ...
                         "authoritative_mode1_reconstruction_map"; ...
                         "authoritative_artifact_index"];
traceRows.exists_on_disk = [isfile(sourceA); isfile(sourceB); isfile(sourceC)];
traceRows.selected_for_panel = ["NO"; "NO"; "NO"];
traceRows.why_described_as_authoritative = strings(3, 1);
traceRows.ptcdf_or_diagnostic_columns_used = strings(3, 1);
traceRows.switching_canonical_S_long_used = repmat("NO", 3, 1);
traceRows.silent_family_mixing_risk = repmat("NO", 3, 1);
traceRows.selection_reason = strings(3, 1);

traceRows.why_described_as_authoritative(1) = "Listed as authoritative_residual_after_mode1_map in switching_corrected_old_authoritative_artifact_index.csv; gated corrected-old builder output.";
traceRows.why_described_as_authoritative(2) = "Authoritative mode1 reconstruction map from same builder package; retained as alternate candidate only.";
traceRows.why_described_as_authoritative(3) = "Artifact index proves lineage and allowed-use context; no plotting values consumed from index alone.";

traceRows.ptcdf_or_diagnostic_columns_used(1) = "NO; DeltaS_after_mode1 is authoritative corrected-old map column, not switching_canonical_S_long PT/CDF diagnostic bundle.";
traceRows.ptcdf_or_diagnostic_columns_used(2) = "NO for panel; mode1 reconstruction not selected as plotted Y.";
traceRows.ptcdf_or_diagnostic_columns_used(3) = "NO numeric columns used; metadata trace only.";

if isfile(sourceA)
    TA = readtable(sourceA);
    requiredA = {'x_aligned','DeltaS_after_mode1','T_K'};
    hasA = all(ismember(requiredA, TA.Properties.VariableNames));
else
    TA = table();
    hasA = false;
end

if hasA
    traceRows.selected_for_panel(1) = "YES";
    traceRows.selection_reason(1) = "Safest authoritative collapse-adjacent panel: residual after rank-one mode vs x_aligned under corrected-old package.";
    traceRows.selection_reason(2) = "Alternate rank-one reconstruction map not mixed into primary residual-after-mode1 collapse panel.";
    traceRows.selection_reason(3) = "Index/metadata only.";
    sourceResolved = true;
    sourceFamilyDocumented = true;
else
    traceRows.selection_reason(1) = "Primary source missing required columns or file missing.";
    traceRows.selection_reason(2) = "Alternate map not selected.";
    traceRows.selection_reason(3) = "Metadata source only.";
end

writetable(traceRows, sourceTracePath);

if sourceResolved
    x = TA.x_aligned;
    y = TA.DeltaS_after_mode1;
    T = TA.T_K;

    collapseVars = "x_aligned vs DeltaS_after_mode1 (residual after mode1)";
    oldIntendedRange = "finite grid over committed authoritative map; no separate legacy display contract";
    displayNote = "axis limits and percentile window are display-only; no write-back to source tables";

    displayMask = isfinite(x) & isfinite(y) & isfinite(T) & (T <= 30);
    xDisp = x(displayMask);
    yDisp = y(displayMask);

    if ~isempty(xDisp) && ~isempty(yDisp)
        xLow = prctile(xDisp, 1);
        xHigh = prctile(xDisp, 99);
        yLow = prctile(yDisp, 2);
        yHigh = prctile(yDisp, 98);
        xRangeChosen = sprintf('[%.4f, %.4f]', xLow, xHigh);
        yRangeChosen = sprintf('[%.6f, %.6f]', yLow, yHigh);
        outlierOrHighTExcluded = "YES";
        exclusionDisplayOnly = "YES";
        displayTransformUsed = "axis limits from prctile window; T_K<=30 row filter for inspection";
        displayTransformIsDisplayOnly = "YES";
        rangeLocked = true;
        displayTransformDocumented = true;

        f = figure('Visible', 'off');
        scatter(xDisp, yDisp, 22, T(displayMask), 'filled');
        xlabel('x\_aligned');
        ylabel('DeltaS\_after\_mode1');
        title('Phase 4B_C02 corrected-old collapse-like panel inspection (QA only)', 'Interpreter', 'none');
        cb = colorbar;
        cb.Label.String = 'T_K';
        grid on;
        xlim([xLow, xHigh]);
        ylim([yLow, yHigh]);
        exportgraphics(f, pngPath, 'Resolution', 180);
        savefig(f, figPath);
        close(f);
        pngWritten = isfile(pngPath);
        figWritten = isfile(figPath);
    else
        xRangeChosen = "N/A";
        yRangeChosen = "N/A";
        collapseVars = "N/A";
        oldIntendedRange = "N/A";
        outlierOrHighTExcluded = "N/A";
        exclusionDisplayOnly = "N/A";
        displayTransformUsed = "N/A";
        displayTransformIsDisplayOnly = "N/A";
        displayNote = "No finite rows after QA mask; no panel produced.";
    end

    R = table( ...
        "CORRECTED_CANONICAL_OLD_ANALYSIS", ...
        collapseVars, ...
        string(oldIntendedRange), ...
        strcat("x: ", string(xRangeChosen), "; y: ", string(yRangeChosen)), ...
        string(outlierOrHighTExcluded), ...
        string(exclusionDisplayOnly), ...
        string(displayTransformUsed), ...
        string(displayTransformIsDisplayOnly), ...
        string(displayNote), ...
        'VariableNames', { ...
            'selected_source_family', ...
            'collapse_like_variables_used', ...
            'old_intended_range_if_known', ...
            'chosen_display_range_xy', ...
            'clipping_or_outlier_exclusion_applied', ...
            'exclusion_is_display_only', ...
            'normalization_or_display_transform', ...
            'transform_is_display_only', ...
            'notes' ...
        });
    writetable(R, rangeLockPath);
    outputsWritten = true;
else
    R = table( ...
        "UNRESOLVED", ...
        "N/A", ...
        "N/A", ...
        "N/A", ...
        "N/A", ...
        "N/A", ...
        "N/A", ...
        "N/A", ...
        "SOURCE_RESOLVED=NO; no misleading collapse panel emitted.", ...
        'VariableNames', { ...
            'selected_source_family', ...
            'collapse_like_variables_used', ...
            'old_intended_range_if_known', ...
            'chosen_display_range_xy', ...
            'clipping_or_outlier_exclusion_applied', ...
            'exclusion_is_display_only', ...
            'normalization_or_display_transform', ...
            'transform_is_display_only', ...
            'notes' ...
        });
    writetable(R, rangeLockPath);
    outputsWritten = true;
end

if sourceResolved && rangeLocked && pngWritten && figWritten
    proceed = 'YES';
else
    proceed = 'NO';
end

if sourceResolved
    srcResolvedStr = 'YES';
else
    srcResolvedStr = 'NO';
end

if outputsWritten
    outWrStr = 'YES';
else
    outWrStr = 'NO';
end

if pngWritten
    pngStr = 'YES';
else
    pngStr = 'NO';
end

if figWritten
    figStr = 'YES';
else
    figStr = 'NO';
end

if rangeLocked
    rngStr = 'YES';
else
    rngStr = 'NO';
end

if displayTransformDocumented
    dtStr = 'YES';
else
    dtStr = 'NO';
end

if sourceFamilyDocumented
    sfStr = 'YES';
else
    sfStr = 'NO';
end

statusKeys = { ...
    'PHASE4B_C02_COMPLETE'; ...
    'SOURCE_RESOLVED'; ...
    'OUTPUTS_WRITTEN'; ...
    'PNG_WRITTEN'; ...
    'FIG_WRITTEN'; ...
    'FIGURE_QA_ONLY'; ...
    'FIGURE_CANONICAL_EVIDENCE'; ...
    'USES_COLLAPSE_CANON_NAME'; ...
    'USES_X_CANON_NAME'; ...
    'BROAD_REPLAY_RUN'; ...
    'RENAME_EXECUTED'; ...
    'RELAXATION_COMPARISON_RUN'; ...
    'AGING_COMPARISON_RUN'; ...
    'SAFE_TO_INTERPRET_PHYSICS'; ...
    'RANGE_LOCKED'; ...
    'DISPLAY_TRANSFORM_DOCUMENTED'; ...
    'SOURCE_FAMILY_DOCUMENTED'; ...
    'PTCDF_DIAGNOSTIC_PROMOTED'; ...
    'SILENT_FAMILY_MIXING'; ...
    'SAFE_TO_PROCEED_TO_NEXT_SLICE' ...
    };

statusValues = { ...
    'YES'; ...
    srcResolvedStr; ...
    outWrStr; ...
    pngStr; ...
    figStr; ...
    'YES'; ...
    'NO'; ...
    'NO'; ...
    'NO'; ...
    'NO'; ...
    'NO'; ...
    'NO'; ...
    'NO'; ...
    'NO'; ...
    rngStr; ...
    dtStr; ...
    sfStr; ...
    'NO'; ...
    'NO'; ...
    proceed ...
    };

S = table(string(statusKeys), string(statusValues), 'VariableNames', {'key', 'value'});
writetable(S, statusPath);

fid = fopen(reportPath, 'w');
fprintf(fid, '# Switching Phase 4B_C02 corrected-old collapse-like panel range lock\n\n');
fprintf(fid, 'Narrow QA inspection slice only. No broad replay, no rename, no Relaxation or Aging comparison.\n\n');
fprintf(fid, '## Source selection\n\n');
fprintf(fid, '- Candidate sources listed in `tables/switching_phase4B_C02_collapse_like_panel_source_trace.csv`.\n');
fprintf(fid, '- Selected panel numeric source when resolved: authoritative `tables/switching_corrected_old_authoritative_residual_after_mode1_map.csv` ');
fprintf(fid, '(CORRECTED_CANONICAL_OLD_ANALYSIS, residual after rank-one mode).\n');
fprintf(fid, '- `switching_canonical_S_long` was not used.\n');
fprintf(fid, '- PTCDF/CDF/backbone diagnostic columns were not promoted to corrected-old authority.\n\n');
fprintf(fid, '## Range lock and display policy\n\n');
fprintf(fid, '- Range lock table: `tables/switching_phase4B_C02_collapse_like_panel_range_lock.csv`.\n');
fprintf(fid, '- Display filters and axis limits are display-only; not written back to source CSVs.\n');
fprintf(fid, '- Forbidden tokens: `collapse_canon`, `X_canon` (not used).\n\n');
fprintf(fid, '## Figures (QA only)\n\n');
if pngWritten
    fprintf(fid, '- PNG: `figures/switching/phase4B_C02_collapse_like_panel_range_lock.png`\n');
else
    fprintf(fid, '- PNG not written (source unresolved or no finite QA rows).\n');
end
if figWritten
    fprintf(fid, '- FIG: `figures/switching/phase4B_C02_collapse_like_panel_range_lock.fig` (interactive inspection only)\n');
else
    fprintf(fid, '- FIG not written (source unresolved or no finite QA rows).\n');
end
fprintf(fid, '\n## Status\n\n');
fprintf(fid, '- Status CSV: `tables/switching_phase4B_C02_status.csv`\n');
fclose(fid);

disp('Phase4B_C02 completed.');
