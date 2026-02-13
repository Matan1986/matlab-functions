function out = sanitizeFilename(in)

in = char(in);
% semantic shortening
in = regexprep(in,'Configuration[_\s]*dependence','Conf_Dep','ignorecase');
in = regexprep(in,'Configuration','Conf','ignorecase');
in = regexprep(in,'dependence','Dep','ignorecase');
% lower chaos
in = strtrim(in);

% greek tau → tau
in = strrep(in,'τ','tau');

% remove equals & commas
in = strrep(in,'=','');
in = strrep(in,',','');

% spaces → underscore
in = regexprep(in,'\s+','_');

% kill multiple underscores
in = regexprep(in,'_+','_');

% remove percent
in = strrep(in,'%','');

% remove brackets
in = regexprep(in,'[\(\)]','');

% keep only safe chars
in = regexprep(in,'[^a-zA-Z0-9_\.]','');

% trim _
in = regexprep(in,'^_+|_+$','');

out = string(in);
end
