function [fileList, sortedTemperatures, colors, mass, modeType] = getFileList_MH(directory)
    % Identify whether MH measurement is:
    %   (1) singleFile_multiTemp : one file containing several temperatures
    %   (2) multiFile_multiTemp  : multiple files, one temperature per file

    %% === Load DAT files (case-insensitive) ===
    files = dir(fullfile(directory, '*.*'));
    files = files(~[files.isdir]);
    files = files(endsWith(lower({files.name}), '.dat'));

    if isempty(files)
        error("No DAT files found in directory:\n%s", directory);
    end

    fileList = {files.name};
    N = numel(fileList);

    %% ==========================================================
    %  MODE 1 : single file containing multiple temperatures
    % ==========================================================
    if N == 1 && contains(lower(fileList{1}), 'difftemp')
        modeType = "singleFile_multiTemp";

        sortedTemperatures = nan;
        colors = parula(1);

        % Extract mass from file name
        massMatch = regexp(fileList{1}, '\d+[pP]\d+(?i)MG', 'match');
        if isempty(massMatch)
            error("Mass not found in filename: %s", fileList{1});
        end

        m = regexprep(regexprep(massMatch{1}, '(?i)MG',''), '[pP]', '.');
        mass = str2double(m);
        return;
    end

    %% ==========================================================
    %  MODE 2 : multiple files, each file has one temperature
    % ==========================================================
    modeType = "multiFile_multiTemp";  

    extractedTemps = nan(N,1);

    for i = 1:N
        Tmatch = regexp(fileList{i}, '\d+K', 'match');
        if isempty(Tmatch)
            error("Temperature not found in filename: %s", fileList{i});
        end
        extractedTemps(i) = str2double(regexprep(Tmatch{1}, 'K', ''));
    end

    % Sort files by temperature
    [sortedTemperatures, idx] = sort(extractedTemps);
    fileList = fileList(idx);

    colors = parula(numel(fileList));

    % Extract mass from first file
    massMatch = regexp(fileList{1}, '\d+[pP]\d+(?i)MG', 'match');
    if isempty(massMatch)
        error("Mass not found in filename: %s", fileList{1});
    end

    m = regexprep(regexprep(massMatch{1}, '(?i)MG',''), '[pP]', '.');
    mass = str2double(m);
end
