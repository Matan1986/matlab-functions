function [T, M] = importFiles_aging(filePath, normalizeByMass, debugMode)
% importFiles_aging — Import Temperature & Moment from MPMS .dat
% Normalizes by sample mass (if found) to emu/g.

mass = NaN;

fid = fopen(filePath,'r');
if fid < 0, error('Cannot open %s', filePath); end
while true
    L = fgetl(fid);
    if ~ischar(L), break; end
    if contains(L,'SAMPLE_MASS','IgnoreCase',true)
        p = split(L,',');
        if numel(p)>=2
            val = str2double(p{2});
            if ~isnan(val), mass = val; end
        end
    end
    if contains(L,'[Data]'), break; end
end
fclose(fid);

opts = detectImportOptions(filePath,'Delimiter',',','VariableNamingRule','preserve');
opts = setvartype(opts,'double');
tbl  = readtable(filePath,opts);

names = lower(string(tbl.Properties.VariableNames));
iT = find(contains(names, {'temperature_k','temperature (k)'}), 1);
iM = find(contains(names, {'moment_emu','moment (emu)'}), 1);

if isempty(iT) || isempty(iM)
    if debugMode
        disp(tbl.Properties.VariableNames);
    end
    error('Temperature/Moment columns not found in %s', filePath);
end

T = tbl{:,iT};
M = tbl{:,iM};

if normalizeByMass && ~isnan(mass)
    M = M ./ (mass * 1e-3); % mg → g
end

ok = isfinite(T) & isfinite(M);
T = T(ok); M = M(ok);
[T, idx] = sort(T);
M = M(idx);
end
