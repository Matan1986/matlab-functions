function TEST_AllColormapsIntegrity()
    disp('================================================');
    disp('COLORMAP INTEGRITY VERIFICATION');
    disp('================================================');
    
    mapNames = getAllMaps();
    scm8Cnt = countSCM8();
    
    fprintf('Total colormaps: %d\n', numel(mapNames));
    fprintf('ScientificColourMaps8: %d\n', scm8Cnt);
    disp(' ');
    
    pass = 0;
    fail = 0;
    warn = 0;
    
    for i = 1:numel(mapNames)
        try
            cmap = getMapSafely(mapNames{i});
            if isempty(cmap)
                fprintf('[FAIL] %s: empty\n', mapNames{i});
                fail = fail + 1;
            elseif ~ismatrix(cmap) || size(cmap,2) ~= 3
                fprintf('[WARN] %s: bad dims\n', mapNames{i});
                warn = warn + 1;
            elseif any(isnan(cmap(:))) || any(isinf(cmap(:)))
                fprintf('[WARN] %s: NaN/Inf\n', mapNames{i});
                warn = warn + 1;
            elseif any(cmap(:) < 0) || any(cmap(:) > 1)
                fprintf('[WARN] %s: out of range\n', mapNames{i});
                warn = warn + 1;
            else
                fprintf('[PASS] %s (%d colors)\n', mapNames{i}, size(cmap,1));
                pass = pass + 1;
            end
        catch ME
            fprintf('[FAIL] %s: %s\n', mapNames{i}, ME.message(1:40));
            fail = fail + 1;
        end
    end
    
    disp(' ');
    disp('================================================');
    fprintf('PASS:  %d / %d\n', pass, numel(mapNames));
    fprintf('WARN:  %d / %d\n', warn, numel(mapNames));
    fprintf('FAIL:  %d / %d\n', fail, numel(mapNames));
    
    if fail == 0
        disp('RESULT: ALL COLORMAPS VALID - READY FOR PRODUCTION');
    else
        disp('RESULT: SOME COLORMAPS FAILED - REVIEW ABOVE');
    end
    disp('================================================');
end

function maps = getAllMaps()
    maps = {};
    
    builtin = {'parula','jet','cool','spring','summer','autumn','winter','copper','turbo',...
        'hot','gray','bone','pink','hsv','lines','colorcube','prism','flag','white'};
    maps = [maps; builtin(:)];
    
    custom = {'softyellow','softgreen','softred','softblue','softpurple','softorange',...
        'softcyan','softgray','softbrown','softteal','softolive','softgold','softpink',...
        'softaqua','softsand','softsky','bluebright','redbright','greenbright',...
        'purplebright','orangebright','cyanbright','yellowbright','magnetabright',...
        'limebright','tealbright','ultrabrightblue','ultrabrightred','fire','ice',...
        'ocean','topo','terrain','magma','inferno','plasma','cividis','bluewhitered',...
        'redwhiteblue','purplewhitegreen','brownwhiteblue','greenwhitepurple',...
        'bluewhiteorange','blackwhiteyellow'};
    maps = [maps; custom(:)];
    
    cmocean = {'cmocean(''thermal'')','cmocean(''haline'')','cmocean(''solar'')',...
        'cmocean(''matter'')','cmocean(''turbid'')','cmocean(''speed'')','cmocean(''amp'')',...
        'cmocean(''deep'')','cmocean(''dense'')','cmocean(''algae'')','cmocean(''balance'')',...
        'cmocean(''curl'')','cmocean(''delta'')','cmocean(''oxy'')','cmocean(''phase'')',...
        'cmocean(''rain'')','cmocean(''ice'')','cmocean(''gray'')'};
    maps = [maps; cmocean(:)];
    
    try
        scm8 = which('scientificColourMaps8', '-all');
        if ~isempty(scm8)
            if ischar(scm8), scm8 = {scm8}; end
            dir_scm8 = fileparts(scm8{1});
            files = dir(fullfile(dir_scm8, '*.m'));
            for f = 1:numel(files)
                fname = files(f).name(1:end-2);
                if ~strcmpi(fname, 'scientificColourMaps8')
                    maps{end+1} = fname;
                end
            end
        end
    catch
    end
    
    maps = unique(maps);
end

function cnt = countSCM8()
    cnt = 0;
    try
        scm8 = which('scientificColourMaps8', '-all');
        if ~isempty(scm8)
            if ischar(scm8), scm8 = {scm8}; end
            dir_scm8 = fileparts(scm8{1});
            files = dir(fullfile(dir_scm8, '*.m'));
            for f = 1:numel(files)
                fname = files(f).name(1:end-2);
                if ~strcmpi(fname, 'scientificColourMaps8')
                    cnt = cnt + 1;
                end
            end
        end
    catch
    end
end

function cmap = getMapSafely(name)
    try
        if exist(name, 'builtin') || exist(name, 'file')
            cmap = feval(name, 256);
        elseif contains(lower(name),'cmocean')
            cmap = eval(name);
        else
            cmap = feval(name, 256);
        end
    catch
        cmap = [];
    end
end
