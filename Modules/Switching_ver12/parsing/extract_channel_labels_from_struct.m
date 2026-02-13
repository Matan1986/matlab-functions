function [chan1_label, chan2_label] = extract_channel_labels_from_struct(labels)
% EXTRACT_CHANNEL_LABELS_FROM_STRUCT
% Automatically choose unique channel labels (chan1_label, chan2_label)
% from a "labels" struct, ignoring duplicates.
%
% Example:
%   labels = struct('ch1','ρ_{xy1}','ch2','ρ_{xx2}','ch3','ρ_{xx3}','ch4','');
%   → chan1_label = 'ρ_{xy1}', chan2_label = 'ρ_{xx2}'
%
% Selection logic:
%   • Prefers first 'ρ_{xy}' (or 'R_{xy}') → chan1_label
%   • Prefers first 'ρ_{xx}' (or 'R_{xx}') → chan2_label
%   • Ignores duplicate 'xx' or 'xy' channels
%   • Falls back to first two non-empty labels if no match found.

    if nargin < 1 || isempty(labels)
        error('extract_channel_labels_from_struct:MissingInput', ...
            'Input struct "labels" is required.');
    end

    fields = fieldnames(labels);
    vals = struct2cell(labels);
    vals = vals(:);

    % Normalize to lowercase for pattern detection
    vals_lower = lower(string(vals));

    % --- Find first occurrences of xy and xx ---
    idx_xy_all = find(contains(vals_lower, 'xy'));
    idx_xx_all = find(contains(vals_lower, 'xx'));

    if ~isempty(idx_xy_all)
        idx_xy = idx_xy_all(1);  % only first xy
        chan1_label = vals{idx_xy};
    else
        % fallback: first non-empty
        nonempty_idx = find(~cellfun(@isempty, vals));
        chan1_label = '';
        if ~isempty(nonempty_idx)
            chan1_label = vals{nonempty_idx(1)};
        end
    end

    if ~isempty(idx_xx_all)
        idx_xx = idx_xx_all(1);  % only first xx
        chan2_label = vals{idx_xx};
    else
        % fallback: second non-empty (different from first)
        nonempty_idx = find(~cellfun(@isempty, vals));
        chan2_label = '';
        if numel(nonempty_idx) >= 2
            chan2_label = vals{nonempty_idx(2)};
        end
    end

    % Final safety fallbacks
    if isempty(chan1_label), chan1_label = 'R_{xy}'; end
    if isempty(chan2_label), chan2_label = 'R_{xx}'; end

  %  fprintf('[extract_channel_labels_from_struct] chan1 = %s | chan2 = %s\n', ...
  %      chan1_label, chan2_label);
end
