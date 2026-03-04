function opts = setDefault(opts, f, v)
% =========================================================
% setDefault
%
% PURPOSE:
%   Assign default value to a field in a struct if missing/empty.
%
% INPUTS:
%   opts    - struct to modify
%   f       - field name (char/string)
%   v       - default value
%
% OUTPUTS:
%   opts    - updated struct
%
% Physics meaning:
%   AFM = not used
%   FM  = not used
%
% =========================================================

if ~isfield(opts, f) || isempty(opts.(f))
    opts.(f) = v;
end
end
