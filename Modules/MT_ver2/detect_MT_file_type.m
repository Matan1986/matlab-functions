function systemType = detect_MT_file_type(folderPath, filename)

    fullpath = fullfile(folderPath, filename);
    fid = fopen(fullpath, 'r');
    if fid == -1
        error("Could not open file: %s", fullpath);
    end

    % Skip to [Data]
    line = '';
    while ischar(line)
        line = fgetl(fid);
        if contains(line, '[Data]')
            break;
        end
    end

    header = fgetl(fid);
    fclose(fid);

    cols = strtrim(strsplit(header, ','));

    %% ======== 1) MPMS SQUID DEFINITIVE KEYS ========
    MPMS_unique = {
        'DC Moment Free Ctr (emu)'
        'DC Moment Fixed Ctr (emu)'
        'DC Number of Points'
        'DC Scan Length (mm)'
        'DC Scan Time (s)'
    };

    for k = 1:numel(MPMS_unique)
        if any(strcmp(cols, MPMS_unique{k}))
            systemType = "MPMS";
            return;
        end
    end

    %% ======== 2) PPMS DEFINITIVE KEYS (transport only) ========
    PPMS_unique = {
        'Resistance (Ohms)'
        'Heater Range'
        'Bridge Reading'
        'Source Current (A)'
    };

    for k = 1:numel(PPMS_unique)
        if any(strcmpi(cols, PPMS_unique{k}))
            systemType = "PPMS";
            return;
        end
    end

    %% ======== 3) Fallback by column count ========
    if numel(cols) > 30
        % MPMS VSM has A LOT of columns
        systemType = "MPMS";
    else
        systemType = "PPMS";
    end
end
