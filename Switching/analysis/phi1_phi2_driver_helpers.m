function varargout = phi1_phi2_driver_helpers(action, varargin)
% Shared helper routines for run_phi1_observable_phi2_driver_test.m
switch action
    case 'apply_defaults'
        varargout{1} = localApplyDefaults(varargin{1});
    case 'numeric_column'
        varargout{1} = localNumericColumn(varargin{1}, varargin{2});
    case 'outer_join'
        varargout{1} = localOuterJoin(varargin{1}, varargin{2}, varargin{3});
    case 'yes_no'
        varargout{1} = localYesNo(varargin{1});
    otherwise
        error('phi1_phi2_driver_helpers:UnknownAction', 'Unknown action: %s', string(action));
end
end

function cfg = localApplyDefaults(cfg)
cfg = localSetDefault(cfg, 'runLabel', 'phi1_observable_phi2_driver_test');
cfg = localSetDefault(cfg, 'alphaTableName', 'alpha_structure.csv');
cfg = localSetDefault(cfg, 'errorColumnName', 'reconstruction_rmse_M2');
cfg = localSetDefault(cfg, 'corrPhi2Threshold', 0.45);
cfg = localSetDefault(cfg, 'errorRatioThreshold', 1.15);
cfg = localSetDefault(cfg, 'minCorrFloor', 0.20);
end

function cfg = localSetDefault(cfg, name, value)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = value;
end
end

function col = localNumericColumn(tbl, candidates)
names = string(tbl.Properties.VariableNames);
col = NaN(height(tbl), 1);
for i = 1:numel(candidates)
    idx = find(names == candidates(i), 1, 'first');
    if ~isempty(idx)
        raw = tbl.(names(idx));
        if isnumeric(raw)
            col = double(raw(:));
        else
            col = str2double(string(raw(:)));
        end
        return
    end
end
end

function T = localOuterJoin(A, B, keyName)
T = outerjoin(A, B, 'Keys', keyName, 'MergeKeys', true, 'Type', 'left');
end

function s = localYesNo(tf)
if tf
    s = 'YES';
else
    s = 'NO';
end
end
