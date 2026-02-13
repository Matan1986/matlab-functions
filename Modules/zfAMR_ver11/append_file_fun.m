function Timems = append_file_fun(appended_files, Timems, Angledeg)
% buildTimems - Construct the Timems vector according to input conditions.
%
% Syntax:
%   Timems = buildTimems(appended_files, Timems, Angledeg)
%
% Inputs:
%   appended_files - logical (true/false), indicates if files were appended
%   Timems         - numeric vector with at least 3 elements
%   Angledeg       - numeric vector of angles (used for length)
%
% Output:
%   Timems         - numeric column vector of time values

    if appended_files && (Timems(2) - Timems(1) > 0)
        step = Timems(2) - Timems(1);
        Timems = (Timems(1):step:length(Angledeg)*step)';
    else
        step = Timems(3) - Timems(2);
        Timems = (Timems(2):step:length(Angledeg)*step)';
    end
end
