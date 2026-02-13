function CHECK_COLORMAP_FUNCTIONALITY()
% CHECK_COLORMAP_FUNCTIONALITY - Verify which colormaps actually work

fprintf('\n===== COLORMAP AVAILABILITY CHECK =====\n\n');

% Test built-in colormaps
fprintf('Built-in MATLAB colormaps:\n');
builtin_maps = {'parula', 'jet', 'hot', 'cool', 'gray'};
for k = 1:numel(builtin_maps)
    try
        cmap = feval(builtin_maps{k}, 32);
        fprintf('  ✓ %s\n', builtin_maps{k});
    catch
        fprintf('  ✗ %s\n', builtin_maps{k});
    end
end

% Test cmocean colormaps (if toolbox installed)
fprintf('\ncmocean colormaps:\n');
try
    cmap = cmocean('thermal');
    fprintf('  ✓ cmocean() works\n');
catch
    fprintf('  ✗ cmocean() not available\n');
end

% Test ScientificColourMaps8
fprintf('\nScientificColourMaps8 colormaps:\n');
scm8_candidates = {'davos', 'batlow', 'roma', 'turku', 'oslo', 'nuuk', 'batlowS'};
found_any = false;
for k = 1:numel(scm8_candidates)
    try
        cmap = feval(scm8_candidates{k}, 32);
        fprintf('  ✓ %s\n', scm8_candidates{k});
        found_any = true;
    catch
    end
end

if ~found_any
    fprintf('  ✗ None of the SCM8 maps are callable\n');
end

% Try to get info about which toolboxes are installed
fprintf('\nInstalled toolboxes:\n');
licensing_info = version('-all');
if contains(licensing_info, 'Image')
    fprintf('  Image Processing Toolbox: INSTALLED\n');
end

end
