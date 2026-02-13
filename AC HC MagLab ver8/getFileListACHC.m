% getFileListACHC.m
function [fileList, legendStrings, colors] = getFileListACHC(directory)
    % List all non-directory files
    d = dir(directory);
    d = d(~[d.isdir]);
    names = {d.name};

    % Filter for sweep files: Asweep, Tsweep, Bsweep
    isSweep = ~cellfun(@isempty, regexp(names, '_(A|T|B)sweep_', 'once'));
    names = names(isSweep);

    n = numel(names);
    fixedOrder = cell(n,2);
    fixedValues = nan(n,2);

    % Define fixed variable order for each sweep axis
    orderMap.A = {'B','T'};  % Asweep: fixed B then T
    orderMap.T = {'A','B'};  % Tsweep: fixed A then B
    orderMap.B = {'T','A'};  % Bsweep: fixed T then A

    % Unit mapping
    unitMap.A = 'deg'; unitMap.T = 'K'; unitMap.B = 'T';

    for i = 1:n
        nm = names{i};
        % Determine sweep axis
        tk = regexp(nm, '_(A|T|B)sweep_', 'tokens', 'once');
        if isempty(tk)
            error('Filename "%s" does not contain a valid sweep axis.', nm);
        end
        sa = tk{1};  % 'A', 'T', or 'B'

        % Extract fixed variable assignments, allowing negative values
        toks = regexp(nm, '_(A|B|T)=(-?\d+\.?\d*)', 'tokens');
        valMap = struct();
        for j = 1:numel(toks)
            var = toks{j}{1};
            val = str2double(toks{j}{2});
            valMap.(var) = val;
        end

        % Store fixed values in defined order, with safety check
        fo = orderMap.(sa);
        for k = 1:2
            var = fo{k};
            fixedOrder{i,k} = var;
            if isfield(valMap, var)
                fixedValues(i,k) = valMap.(var);
            else
                warning('Missing %s in filename "%s"; setting to NaN.', var, nm);
                fixedValues(i,k) = NaN;
            end
        end
    end

    % Sort by fixedValues lexicographically
    [~, idx] = sortrows(fixedValues, [1,2]);
    fileList = names(idx);
    fixedOrder = fixedOrder(idx,:);
    fixedValues = fixedValues(idx,:);

    % Build legend strings using units
    legendStrings = cell(n,1);
    for i = 1:n
        f1 = fixedOrder{i,1}; v1 = fixedValues(i,1);
        f2 = fixedOrder{i,2}; v2 = fixedValues(i,2);
        legendStrings{i} = sprintf('%s=%.3g%s, %s=%.3g%s', ...
            f1, v1, unitMap.(f1), f2, v2, unitMap.(f2));
    end

    % Generate distinct colors
    colors = parula(n);
end