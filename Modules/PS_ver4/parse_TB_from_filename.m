function [temp_values, field_values] = parse_TB_from_filename(filename_dat, debug)
%PARSE_TB_FROM_FILENAME  Fully robust parser for temperature & field info from filename.
%
% Handles ALL formats:
%   "..._PS_4K_diff_fields_1Tto13T_at_2T_steps"
%   "...temps_4_8_12K_fields_1_3_5T"
%   "...diff_temps_4Kto40K_at_8K_steps"
%   "..._diff_fields_2T_5T_14T"
%   "Temp_4K"                   <-- NEW
%   "Field_1T"                  <-- NEW

    if nargin < 2, debug = false; end
    temp_values  = [];
    field_values = [];

    %% ============================================================
    %                       TEMPERATURE PARSING
    %% ============================================================
    tokT = regexp(filename_dat,'temps?_([0-9p_]+)K','tokens','once');
    if ~isempty(tokT)
        % list form: temps_4_8_12K
        temp_values = parse_number_list(tokT{1});

    else
        % range form: temps_4Kto40K_at_8K_steps
        tokTRange = regexp(filename_dat,'temps?_([0-9p]+)Kto([0-9p]+)K','tokens','once');
        if ~isempty(tokTRange)
            T1 = str2double(strrep(tokTRange{1},'p','.'));
            T2 = str2double(strrep(tokTRange{2},'p','.'));

            tokTstep = regexp(filename_dat,'at_([0-9p]+)K_steps','tokens','once');
            if ~isempty(tokTstep)
                stepT = str2double(strrep(tokTstep{1},'p','.'));
            else
                stepT = 1;
            end
            temp_values = T1:stepT:T2;

        else
            % simple single: "_4K"
            tokT = regexp(filename_dat,'[_\-]([0-9]+)K','tokens','once');
            if ~isempty(tokT)
                temp_values = str2double(tokT{1});
            end
        end
    end

    % ==== NEW: detect "Temp_4K"
    if isempty(temp_values)
        tokTsingle = regexp(filename_dat,'Temp_([0-9p]+)K','tokens','once');
        if ~isempty(tokTsingle)
            temp_values = str2double(strrep(tokTsingle{1},'p','.'));
        end
    end

    %% ============================================================
    %                        FIELD PARSING
    %% ============================================================
    tokBRange = regexp(filename_dat,'(?:diff_)?fields?_([0-9p]+)Tto([0-9p]+)T','tokens','once');
    if ~isempty(tokBRange)
        B1 = str2double(strrep(tokBRange{1},'p','.'));
        B2 = str2double(strrep(tokBRange{2},'p','.'));

        tokBstep = regexp(filename_dat,'at_([0-9p]+)T_steps','tokens','once');
        if ~isempty(tokBstep)
            stepB = str2double(strrep(tokBstep{1},'p','.'));
        else
            stepB = 1;
        end
        field_values = B1:stepB:B2;

    else
        % list form: fields_1T_3T_5T or diff_fields_2T_5T_14T
        tokB = regexp(filename_dat,'(?:diff_)?fields?_([0-9pT_]+)','tokens','once');
        if ~isempty(tokB)
            raw = regexprep(tokB{1},'T','_');
            field_values = parse_number_list(raw);
        end
    end

    % ==== NEW: detect "Field_1T"
    if isempty(field_values)
        tokBsingle = regexp(filename_dat,'Field_([0-9p]+)T','tokens','once');
        if ~isempty(tokBsingle)
            field_values = str2double(strrep(tokBsingle{1},'p','.'));
        end
    end

    %% ============================================================
    %                          VALIDATION
    %% ============================================================
    if isempty(temp_values)
        warning('⚠️ Missing temperature info in filename.');
    end
    if isempty(field_values)
        warning('⚠️ Missing field info in filename.');
    end

    %% ============================================================
    %                          DEBUG PRINT
    %% ============================================================
    if debug
        fprintf('[DEBUG] Temp array:  %s\n', mat2str(temp_values));
        fprintf('[DEBUG] Field array: %s\n', mat2str(field_values));
    end
end
