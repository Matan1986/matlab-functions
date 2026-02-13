function pulseScheme = extractPulseSchemeFromFolder(dir)
% extractPulseSchemeFromFolder
% Determines pulse scheme (alternating / repeated) and geometry
% from folder name.
%
% alternating  -> single cycle
% repeated     -> multiple cycles possible

dirStr = lower(string(dir));

pulseScheme = struct();

% --- mode ---
if contains(dirStr,"repeated")
    pulseScheme.mode = "repeated";
else
    pulseScheme.mode = "alternating";
end

% --- pulses per block (e.g. "10pulses") ---
pulseScheme.pulsesPerBlock = extract_num_of_pulses_from_name(dir);

% --- cycles ---
if pulseScheme.mode == "alternating"
    % IMPORTANT: alternating => exactly one cycle
    pulseScheme.cycles = 1;
else
    % repeated pulses: try to extract cycles, default to 1
    cycles = NaN;
    tok = regexp(dirStr,'(\d+)\s*cycles','tokens','once');
    if ~isempty(tok)
        cycles = str2double(tok{1});
    end
    if isnan(cycles) || cycles <= 0
        cycles = 1;
    end
    pulseScheme.cycles = cycles;
end

% --- total pulses per dep ---
% A-block + B-block per cycle
pulseScheme.totalPulses = 2 * pulseScheme.pulsesPerBlock * pulseScheme.cycles;

end
