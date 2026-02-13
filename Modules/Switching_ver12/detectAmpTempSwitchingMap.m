function tf = detectAmpTempSwitchingMap(dirPath)
% Returns true if dirPath is a parent folder for Amp–Temp switching maps

% 1) If there are .dat files here → Single Dep
if ~isempty(dir(fullfile(dirPath, '*.dat')))
    tf = false;
    return;
end

% 2) Look for subfolders named like "Temp Dep ... mA ..."
d = dir(dirPath);
sub = d([d.isdir] & ~startsWith({d.name}, '.'));

if isempty(sub)
    tf = false;
    return;
end

names = string({sub.name});

isTempDep = contains(names, "Temp Dep", 'IgnoreCase', true);
hasmA     = contains(names, "mA",       'IgnoreCase', true);

tf = any(isTempDep & hasmA);
end
