%% AC susceptibility module for Co1/3TaS2
clc; clear; close all;
%% --- Add MATLAB paths ---
baseFolder = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions';
addpath(genpath(baseFolder));
% --- SETTINGS ---
dir = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Susceptibility';
color_scheme = 'parula';
normalizeByMass = true;
fontsize = 16;
[growth_num, FIB_num] = extract_growth_FIB(dir, []);
sample_name = sprintf('MG %d', growth_num);
formatFigures=true;

% --- 1. File list & mass ---
[fileList, sortedFreqs, colors, mass] = getFileList_Susceptibility(dir, color_scheme);

% --- 2. Import ---
[Temp_table, chiP_table, chiPP_table, freq_table, massHeader] = ...
    importFiles_Susceptibility(dir, fileList, normalizeByMass);

if isnan(mass) && ~isnan(massHeader)
    mass = massHeader;
end

% fprintf('Sample mass: %.3f mg\n', mass);

[chiP_corr, chiPP_corr, info] = fix_phase_and_baseline( ...
    Temp_table, chiP_table, chiPP_table, freq_table, 0.2);  % top 20% => baseline

% Add back a common baseline so high-T values coincide at a nonzero level
c0 = mean([info.baselineP], 'omitnan');   % common χ′ baseline after rotation
for i = 1:numel(chiP_corr)
    chiP_corr{i} = chiP_corr{i} + c0;
end

Plots_Susceptibility(Temp_table, chiP_corr, chiPP_corr, freq_table, ...
    colors, normalizeByMass, [sample_name ' (phase-corrected, common baseline)'], fontsize);

if formatFigures
    formatAllFigures('pos',[0.1,0.1,0.7,0.6], 'clearTitles',false, ...
        'showLegend',true, 'showGrid',true);
end