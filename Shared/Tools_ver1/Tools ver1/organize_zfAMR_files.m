function organize_zfAMR_files()
% ORGANIZE_ZFAMR_FILES (FINAL, BUG-FREE VERSION)

base = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions\zfAMR ver10';

if ~isfolder(base)
    error('zfAMR folder not found.');
end

fprintf('\n=== Organizing zfAMR ver10 ===\n');
fprintf('Base folder: %s\n', base);

%% Create subfolders
folders = {'main','parsing','tables','plots','utils','old_internal'};
for k = 1:numel(folders)
    p = fullfile(base, folders{k});
    if ~exist(p,'dir')
        mkdir(p);
        fprintf('Created: %s\n', p);
    end
end

%% File list
S = dir(fullfile(base,'*.m'));

mainRule = 'zfAMR_main.m';

parsingPatterns = { ...
    'extract_', 'resolve_', 'find_', ...
    'mk_angle_mapper.m', 'select_angles.m', ...
    'dedup_by_round.m'};

tablePatterns = {'build_'};

plotPatterns = {'plot_', 'pretty_label.m'};

utilsPatterns = {'read_data.m','reindex_rows.m','wrap_sort_angles.m','ternary.m'};

oldPatterns = {'.asv'};


%% Move logic
for k = 1:numel(S)
    fn = S(k).name;
    src = fullfile(base, fn);

    % MAIN
    if strcmp(fn, mainRule)
        safe_move(src, fullfile(base,'main'));
        continue;
    end

    % PARSING
    if match_patterns(fn, parsingPatterns)
        safe_move(src, fullfile(base,'parsing'));
        continue;
    end

    % TABLES
    if match_patterns(fn, tablePatterns)
        safe_move(src, fullfile(base,'tables'));
        continue;
    end

    % PLOTS
    if match_patterns(fn, plotPatterns)
        safe_move(src, fullfile(base,'plots'));
        continue;
    end

    % UTILS
    if match_patterns(fn, utilsPatterns)
        safe_move(src, fullfile(base,'utils'));
        continue;
    end

    % OLD
    if match_patterns(fn, oldPatterns)
        safe_move(src, fullfile(base,'old_internal'));
        continue;
    end

    fprintf('Leaving file in place (no rule matched): %s\n', fn);
end

fprintf('\n=== DONE organizing zfAMR ver10 ===\n');
end


%% === helper: safe move ===
function safe_move(src, dstFolder)
    [~, name, ext] = fileparts(src);
    dst = fullfile(dstFolder, [name ext]);
    src = char(src);
    dst = char(dst);
    movefile(src, dst);
    fprintf('Moved: %s --> %s\n', name, dstFolder);
end


%% === helper: match patterns ===
function tf = match_patterns(filename, patternList)
    tf = false;
    for k = 1:numel(patternList)
        p = patternList{k};
        if contains(filename, p, 'IgnoreCase', true)
            tf = true;
            return;
        end
    end
end
