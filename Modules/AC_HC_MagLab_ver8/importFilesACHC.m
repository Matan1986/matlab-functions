function data = importFilesACHC(directory, fileList)
    % Import raw and normalized heat capacity, field, and angle from data files
    n = numel(fileList);
    data = struct(...
        'Ts',         cell(n,1), 'Tr',         cell(n,1), ...
        'Cs',         cell(n,1), 'Cr',         cell(n,1), 'Cdiff',      cell(n,1), ...
        'Cs_norm',    cell(n,1), 'Cr_norm',    cell(n,1), 'Cdiff_norm', cell(n,1), ...
        'Field',      cell(n,1), 'Angle',      cell(n,1)...
    );
    for i = 1:n
        fp = fullfile(directory, fileList{i});
        % Read tab-delimited data, skipping header line
        M = readmatrix(fp, 'FileType', 'text', 'Delimiter', '\t', 'NumHeaderLines', 1);
        if size(M,2) < 53
            warning('File "%s" skipped: unexpected number of columns.', fileList{i});
            continue;
        end
        % Assign columns
        data(i).Cs         = M(:,20);
        data(i).Cr         = M(:,22);
        data(i).Cdiff      = M(:,24);
        data(i).Cs_norm    = M(:,30);
        data(i).Cr_norm    = M(:,31);
        data(i).Cdiff_norm = M(:,33);
        data(i).Ts         = M(:,36);
        data(i).Tr         = M(:,37);
        data(i).Field      = M(:,51);
        data(i).Angle      = (M(:,53) + 3000)* (-45/(7*560.714)); % (-45/(7*500)) ,  (-45/(7*560.714))
        end
    
end