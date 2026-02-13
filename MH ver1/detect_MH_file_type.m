function systemType = detect_MH_file_type(folderPath, filename)
% Detect whether MH file is from MPMS (SQUID) or PPMS/DynaCool VSM.
% Returns: "MPMS" or "PPMS"

    fullpath = fullfile(folderPath, filename);

    fid = fopen(fullpath, 'r');
    if fid == -1
        error("Could not open file: %s", fullpath);
    end

    % scan for [Data]
    line = '';
    while ischar(line)
        line = fgetl(fid);
        if contains(line, '[Data]')
            break;
        end
    end

    % header line
    header = fgetl(fid);
    fclose(fid);

    if ~ischar(header)
        error("Could not read header line in: %s", filename);
    end

    % tokenize header
    cols = strtrim(strsplit(header, ','));

    % =====================================================================
    %  1) Explicit folder name hints ("PPMS", "DynaCool", "VSM")
    % =====================================================================
    folderLower = lower(folderPath);
    if contains(folderLower, 'ppms') || ...
       contains(folderLower, 'dynacool') || ...
       contains(folderLower, 'vsm')
        systemType = "PPMS";
        return;
    end

    % =====================================================================
    %  2) PPMS / DynaCool header fingerprints
    % =====================================================================
    PPMS_keys = {
        'Transport Action'
        'Averaging Time (sec)'
        'Coil Signal'
        'Map 01'
        'Map 02'
        'Motor Lag'
    };

    for k = 1:numel(PPMS_keys)
        if any(contains(cols, PPMS_keys{k}, 'IgnoreCase', true))
            systemType = "PPMS";
            return;
        end
    end

    % =====================================================================
    %  3) MPMS SQUID fingerprints
    % =====================================================================
    MPMS_keys = {
        'DC Moment Free Ctr (emu)'
        'AC Moment'
    };

    for k = 1:numel(MPMS_keys)
        if any(strcmp(cols, MPMS_keys{k}))
            systemType = "MPMS";
            return;
        end
    end

    % =====================================================================
    %  4) Fallback: #columns
    % =====================================================================
    if numel(cols) > 20
        systemType = "PPMS";
    else
        systemType = "MPMS";
    end
end
