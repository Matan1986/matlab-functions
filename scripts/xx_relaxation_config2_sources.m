function cfg = xx_relaxation_config2_sources()
% Return raw-directory config rows for XX relaxation on Config2 (XX-stable branch).
% Discovers Temp Dep *mA* subfolders under the canonical Config2 Amp Temp Dep root.

baseDir = "L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\FIB5_Switching_old_PPMS\Config2\Amp Temp Dep all";

req_mA = [25, 30, 35];
cfg = struct([]);

for k = 1:numel(req_mA)
    am = req_mA(k);
    pat = fullfile(baseDir, sprintf('Temp Dep %dmA*', am));
    d = dir(pat);
    d = d([d.isdir]);
    if isempty(d)
        error('xx_relaxation_config2_sources:MissingFolder', ...
            'No subdirectory matching Temp Dep %dmA* under %s', am, baseDir);
    end
    if numel(d) > 1
        names = string({d.name});
        [sortedNames, ord] = sort(names);
        d = d(ord(1));
        warning('xx_relaxation_config2_sources:AmbiguousFolder', ...
            'Multiple folders for %d mA; using %s (candidates: %s)', ...
            am, d(1).name, strjoin(sortedNames, ', '));
    end
    cfg(end + 1).config_id = "config2_" + am + "mA"; %#ok<AGROW>
    cfg(end).baseDir = baseDir;
    cfg(end).tempDepFolder = string(d(1).name);
end

end
