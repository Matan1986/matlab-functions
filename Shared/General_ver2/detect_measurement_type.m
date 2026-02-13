function type = detect_measurement_type(pathStr)
% Robust measurement-type detection based on folder/file name

str = lower(pathStr);

% === RELAXATION ===
if contains(str,"relax")
    type = "relaxation";

% === PS ===
elseif contains(str,"ps") || contains(str,"amr") || contains(str,"polar scan")
    type = "ps";

% === ZFAMR ===
elseif contains(str,"zfamr")
    type = "zfamr";

% === SWITCHING ===
elseif contains(str,"switching") || contains(str,"pulse")
    type = "switching";

% === FIELD SWEEP ===
elseif contains(str,"field sweep") || contains(str,"fieldsweep")
    type = "fieldsweep";

% === MH ===
elseif contains(str,"mh") || contains(str,"hysteresis")
    type = "mh";

% === MT ===
elseif contains(str,"mt") || contains(str,"temperature sweep")
    type = "mt";

% === AC HC ===
elseif contains(str,"achc") || contains(str,"ac hc")
    type = "achc";

% === DC HC ===
elseif contains(str,"_hc") || contains(str,"hc_") || contains(str," hc ") || ...
       contains(str,"field scan") || contains(str,"dc_hc")
    type = "hc";

% === AGING ===
elseif contains(str,"aging")
    type = "aging";

% === RESISTIVITY ===
elseif contains(str,"rhc") || contains(str,"resistivity")
    type = "resistivity";

% === UNKNOWN ===
else
    type = "unknown";
end

end
