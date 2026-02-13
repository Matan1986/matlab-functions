function data = importFilesRHC(directory, fileList)
    % importFilesRHC: read RHs and RHr from fixed columns in tab-delimited files
    n = numel(fileList);
    data = repmat(struct('Ts', [], 'Field', [], 'Angle', [], 'RHs', [], 'RHr', [], 'RHDiff', [], ...
                         'RHs_norm', [], 'RHr_norm', [], 'RHDiff_norm', []), n, 1);
    for i = 1:n
        fp = fullfile(directory, fileList{i});
        % Read numeric data, skip header line
        M = readmatrix(fp, 'FileType', 'text', 'Delimiter', '	', 'NumHeaderLines', 1);
        % Column mapping based on header row:
        Ts_col    = 52;   % Ts (K) 36
        Field_col = 51;   % H (T)
        Angle_col = 53;   % Polar angle (deg)
        RHs_col   = 57 ;   % RHs (ohm)  55 
        RHr_col   = 56;   % RHr (ohm)
        % Assign raw data
        data(i).Ts     = M(:, Ts_col);
        data(i).Field  = M(:, Field_col);
        data(i).Angle      = (M(:,Angle_col) + 3000)* (-45/(7*560.714)); % (-45/(7*500)) ,  (-45/(7*560.714))
        data(i).RHs    = M(:, RHs_col);
        data(i).RHr    = M(:, RHr_col);
        data(i).RHDiff = data(i).RHs - data(i).RHr;
        % Compute normalized values
        data(i).RHs_norm    = data(i).RHs  ./ data(i).Ts;
        data(i).RHr_norm    = data(i).RHr  ./ data(i).Ts;
        data(i).RHDiff_norm = data(i).RHDiff ./ data(i).Ts;
    end
end

