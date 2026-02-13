function data = importOneFileRHC(fp)
    M = readmatrix(fp, 'FileType', 'text', 'Delimiter', '	', 'NumHeaderLines', 1);
    data.RHs         = M(:, 20);
    data.RHr         = M(:, 22);
    data.RHDiff      = M(:, 24);
    data.RHs_norm    = M(:, 30);
    data.RHr_norm    = M(:, 31);
    data.RHDiff_norm = M(:, 33);
    data.Ts          = M(:, 52); %36
    data.Field       = M(:, 51);
    data.Angle       = (M(:, 53) + 3000) * (-45/(7*560.714));
end