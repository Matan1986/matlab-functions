function [stableTemps, stableTimes, stableVSM, stableMagneticField] = ...
    divideByStableTemperatures(Temp_table, Time_table, VSM_table, MagneticFieldOe_table, delta_T)
    % Divide the input tables into stable temperature segments
    %
    % Inputs:
    %   Temp_table           - Cell array containing temperature data
    %   Time_table           - Cell array containing time data
    %   VSM_table            - Cell array containing VSM data
    %   MagneticFieldOe_table- Cell array containing magnetic field data
    %   delta_T              - Tolerance for stable temperature
    %
    % Outputs:
    %   stableTemps          - Column cell array of stable temperature segments (n x 1 vectors)
    %   stableTimes          - Column cell array of stable time segments (n x 1 vectors)
    %   stableVSM            - Column cell array of stable VSM segments (n x 1 vectors)
    %   stableMagneticField  - Column cell array of stable magnetic field segments (n x 1 vectors)

    % Extract the data from the input cell arrays
    Temp_data = Temp_table{1};
    Time_data = Time_table{1};
    VSM_data = VSM_table{1};
    MagneticField_data = MagneticFieldOe_table{1};

    % Initialize outputs as empty column cell arrays
    stableTemps = {}; % Cell array for stable temperatures
    stableTimes = {}; % Cell array for corresponding time segments
    stableVSM = {};   % Cell array for corresponding VSM segments
    stableMagneticField = {}; % Cell array for corresponding magnetic field segments

    % Initialize current segment
    currentSegmentTemp = [];
    currentSegmentTime = [];
    currentSegmentVSM = [];
    currentSegmentMagField = [];

    % Loop through the data
    for i = 1:length(Temp_data)
        if isempty(currentSegmentTemp)
            % Start a new segment
            currentSegmentTemp = Temp_data(i);
            currentSegmentTime = Time_data(i);
            currentSegmentVSM = VSM_data(i);
            currentSegmentMagField = MagneticField_data(i);
        else
            % Check if the temperature is within the tolerance of the current segment
            if abs(Temp_data(i) - mean(currentSegmentTemp)) <= delta_T
                % Add to the current segment
                currentSegmentTemp(end + 1) = Temp_data(i);
                currentSegmentTime(end + 1) = Time_data(i);
                currentSegmentVSM(end + 1) = VSM_data(i);
                currentSegmentMagField(end + 1) = MagneticField_data(i);
            else
                % Save the completed segment as column vectors
                stableTemps{end + 1, 1} = currentSegmentTemp(:); %#ok<AGROW>
                stableTimes{end + 1, 1} = currentSegmentTime(:); %#ok<AGROW>
                stableVSM{end + 1, 1} = currentSegmentVSM(:); %#ok<AGROW>
                stableMagneticField{end + 1, 1} = currentSegmentMagField(:); %#ok<AGROW>

                % Start a new segment
                currentSegmentTemp = Temp_data(i);
                currentSegmentTime = Time_data(i);
                currentSegmentVSM = VSM_data(i);
                currentSegmentMagField = MagneticField_data(i);
            end
        end
    end

    % Add the last segment as column vectors
    if ~isempty(currentSegmentTemp)
        stableTemps{end + 1, 1} = currentSegmentTemp(:); %#ok<AGROW>
        stableTimes{end + 1, 1} = currentSegmentTime(:); %#ok<AGROW>
        stableVSM{end + 1, 1} = currentSegmentVSM(:); %#ok<AGROW>
        stableMagneticField{end + 1, 1} = currentSegmentMagField(:); %#ok<AGROW>
    end
end
