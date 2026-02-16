%% MH_main.m
clc; clear; close all;

% ==========================
% User options
% ==========================
fontsize      = 18;
linewidth     = 2.5;
DC            = true;
all_same_fig  = true;
Unfiltered    = true;
delta_T       = 0.2;
formatFigures = true;

% ==========================
% Cleaning parameters
% ==========================
filterParams.slopeFactor     = 3;
filterParams.minDentLength   = 2;
filterParams.maxInterpLength = 15;

% ==========================
% Paths
% ==========================
baseFolder = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions';
addpath(genpath(baseFolder));

dir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG119 VSM PPMS\MH different temperatures";

% ==========================
% Load file list (AUTO detect mode)
% ==========================
[fileList, sortedTemps, colors, mass, modeType] = getFileList_MH(dir);
fprintf("Detected MH mode: %s\n", modeType);

% ==========================
% Auto detect system (MPMS vs PPMS)
% ==========================
systemType = detect_MH_file_type(dir, fileList{1});
MPMS = strcmpi(systemType, 'MPMS');
fprintf("Detected system: %s\n", systemType);

% ==========================
% Import data according to mode
% ==========================
switch modeType

    case "singleFile_multiTemp"
        % --- Import single file with multiple temperatures ---
        fullpath = fullfile(dir, fileList{1});

        [TimeSec, TempK, Moment, FieldOe] = importOneFile_MH_diff_temps(fullpath);

        % Split into stable temperature groups
        [Temp_table, Time_table, VSM_table, MagneticField_table] = ...
            divideByStableTemperatures(TempK, TimeSec, Moment, FieldOe, delta_T);

        % Determine representative temperature per group
        finalTemps = zeros(numel(Temp_table), 1);
        for i = 1:numel(Temp_table)
            finalTemps(i) = round(mean(Temp_table{i}, 'omitnan'));
        end

    case "multiFile_multiTemp"
        % --- Import multiple files, one per temperature ---
        [Time_table, Temp_table, VSM_table, MagneticField_table] = ...
            importFiles_MH(dir, fileList, sortedTemps, MPMS, DC);

        finalTemps = sortedTemps;
end

% ==========================
% Growth / FIB
% ==========================
[growth_num, FIB_num] = extract_growth_FIB(dir, []);

% ==========================
% Units conversion to μB/Co
% ==========================
n_mols        = (mass*1e-3) / ( (1/3)*58.9332 + 180.948 + 2*32.066 );
Co_mols       = n_mols/3;
Co_atoms      = Co_mols * 6.022e23;
unitsRatio    = 1.078e20 / Co_atoms;

% ==========================
% Clean curves
% ==========================
for i = 1:numel(finalTemps)

    H = MagneticField_table{i};
    M = VSM_table{i};

    [Hraw, Mraw, Hclean, Mclean] = ...
        clean_MH_data(H, M, Unfiltered, filterParams);

    if Unfiltered
        MagneticField_table{i} = Hraw;
        VSM_table{i}           = Mraw;
    else
        MagneticField_table{i} = Hclean;
        VSM_table{i}           = Mclean;
    end
end

% ==========================
% Plot curves
% ==========================
Plots_MH(Temp_table, MagneticField_table, VSM_table, ...
         finalTemps, colors, unitsRatio, ...
         growth_num, fontsize, linewidth, all_same_fig);

% ==========================
% Format figures
% ==========================
if false
    formatAllFigures('pos',[0.1,0.1,0.7,0.6], ...
                     'clearTitles', false, ...
                     'showLegend', true, ...
                     'showGrid', true);
end
