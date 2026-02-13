function loadAllColormaps()

%% ---------- cmocean ----------
mapNames = { ...
    'thermal','haline','solar','ice','gray', ...
    'oxy','deep','dense','algae','matter','turbid', ...
    'speed','amp','tempo','rain','phase','topo', ...
    'balance','delta','curl','diff','tarn'};

for k = 1:numel(mapNames)

    name = char(mapNames{k});   % FORCE CHAR

    try
        cmap = cmocean(name,256);
        assignin('base',['cmap_' name],cmap);
    catch ME
        warning('Failed loading cmocean map: %s', name);
        disp(ME.message)
    end
end

%% ---------- ScientificColourMaps (.mat) ----------

baseDir = 'C:\Users\User\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions\github_repo\ScientificColourMaps8';

if exist(baseDir,'dir') ~= 7
    error('ScientificColourMaps directory not found');
end

d = dir(baseDir);
d = d([d.isdir]);
d = d(~ismember({d.name},{'.','..'}));

for k = 1:numel(d)

    folderName = char(d(k).name);

    matFile = fullfile(baseDir, folderName, [folderName '.mat']);
    if exist(matFile,'file') ~= 2
        continue
    end

    S = load(matFile);
    fn = fieldnames(S);

    if isempty(fn)
        continue
    end

    cmap = S.(fn{1});

    if size(cmap,2) ~= 3
        continue
    end

    if size(cmap,1) ~= 256
        x = linspace(1,size(cmap,1),256);
        cmap = interp1(1:size(cmap,1),cmap,x);
    end

    assignin('base',['cmap_' folderName],cmap);
end

disp('✔ All colormaps loaded successfully');

end
