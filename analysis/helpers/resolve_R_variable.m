function [R_relax, R_age, detected_type] = resolve_R_variable(T)

R_relax = [];
R_age   = [];
detected_type = "unknown";

vars = T.Properties.VariableNames;

if any(strcmp(vars, 'R_relax'))
    R_relax = T.R_relax;
    detected_type = "relax";
elseif any(strcmp(vars, 'R'))
    % heuristic: check if time column exists
    if any(contains(vars, 'logt')) || any(contains(vars, 'time'))
        R_relax = T.R;
        detected_type = "relax";
    else
        R_age = T.R;
        detected_type = "aging";
    end
end

if any(strcmp(vars, 'R_age'))
    R_age = T.R_age;
    detected_type = "aging";
end

end
