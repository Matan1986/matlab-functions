
    % Main script for RH plotting based on slow & fast variables
    clc; clear; close all;
    disp('Running ACHC_RH_main');

    % 1) User options
    RHr_RHs_plotMode  = 'B';        % 'S'=RHs only, 'R'=RHr only, 'B'=both
    RHorRHT_plotType  = 'raw';      % 'raw','norm','both'
    RHrRHor_layout    = 'separate'; % 'overlay' or 'separate'
    includeDiff       = false;
    xVar              = 'Angle';    % 'Temp','Angle','Field'
    slowVar           = 'Field';
    fastVar           = 'Temp';

    applyShift        = false;
    shiftValue        = 0.015e-9;
    SortMode          = 'both';
    addSuffix         = true;
    Order_down_up     = true;
    temp_jump_thresh  = 3;
    Fontsize          = 14;
    lineWidth         = 1.5;

    % 2) Paths & file listing
    addpath(genpath('L:/My Drive/Quantum materials lab/Matlab functions'));
    directory = 'L:\My Drive\Quantum materials lab\AC Heat Capacity setup\Data\S=PSNO20_R=PSNO10 second\Angle sweep';
    [fileList, ~, colors] = getFileListRHC(directory);

    % 3) Import files
    data = importFilesRHC(directory, fileList);

    % 4) Extract slow/fast values
    switch slowVar
        case 'Temp',  slowVals = arrayfun(@(d) mean(d.Ts),    data);
        case 'Angle', slowVals = arrayfun(@(d) mean(d.Angle), data);
        case 'Field', slowVals = arrayfun(@(d) mean(d.Field), data);
        otherwise,    error('Unknown slowVar "%s".', slowVar);
    end
    switch fastVar
        case 'Temp',  fastVals = arrayfun(@(d) mean(d.Ts),    data);
        case 'Angle', fastVals = arrayfun(@(d) mean(d.Angle), data);
        case 'Field', fastVals = arrayfun(@(d) mean(d.Field), data);
        otherwise,    error('Unknown fastVar "%s".', fastVar);
    end
    slowValsR = round(slowVals*1e2)/1e2;
    fastValsR = round(fastVals*1e2)/1e2;

    % 5) Sort
    switch SortMode
        case 'fast'
            [~, idx] = sort(fastValsR);
        case 'slow'
            [~, idx] = sort(slowValsR);
        case 'both'
            M = [slowValsR(:), fastValsR(:)];
            [~, idx] = sortrows(M, [1,2]);
        otherwise
            error('Unknown SortMode "%s".', SortMode);
    end

    % Rebuild legendStrings based on slow/fast variables
    sv = slowValsR(idx);
    fv = fastValsR(idx);
    unitMap.Temp  = ' K';  labelMap.Temp  = 'T';
    unitMap.Angle = '°';   labelMap.Angle = 'φ';
    unitMap.Field = ' T';  labelMap.Field = 'B';
    legendStrings = arrayfun(@(s,f) ...
        sprintf('%s=%.2f%s, %s=%.2f%s', ...
            labelMap.(slowVar), s, unitMap.(slowVar), ...
            labelMap.(fastVar), f, unitMap.(fastVar)), ...
        sv, fv, 'Uni', false);

    % 6) Apply sorting and unpack
    fileList      = fileList(idx);
    data          = data(idx);
    colors        = colors(idx, :);
    Temp_S        = {data.Ts};
    RHs           = {data.RHs};
    RHr           = {data.RHr};
    RHdiff        = {data.RHDiff};
    RHs_norm      = {data.RHs_norm};
    RHr_norm      = {data.RHr_norm};
    RHd_norm      = {data.RHDiff_norm};
    Angle         = {data.Angle};
    Field         = {data.Field};

    % 7) Plot
    PlotsRHC(Temp_S, RHs, RHr, RHdiff, RHs_norm, RHr_norm, RHd_norm, ...
        Angle, Field, slowValsR(idx), fastValsR(idx), colors, temp_jump_thresh, ...
        Fontsize, legendStrings, RHr_RHs_plotMode, RHorRHT_plotType, ...
        RHrRHor_layout, includeDiff, xVar, lineWidth, ...
        applyShift, shiftValue, addSuffix, Order_down_up, SortMode);

