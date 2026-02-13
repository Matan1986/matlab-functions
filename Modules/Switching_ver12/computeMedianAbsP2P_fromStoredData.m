function val_pct = computeMedianAbsP2P_fromStoredData( ...
    stored_data_i, phys2localIdx, refBase, opts)

% computeMedianAbsP2P_fromStoredData
% Robust median(|ΔR|)/R_ref [%] from plateau means
%
% stored_data_i : stored_data{i,:} for a single file
% phys2localIdx: local column index of the physical channel
% refBase      : reference baseline (same as tableData col 7)
% opts fields:
%   .skipFirstPlateaus (default = 1)
%   .madThresh         (default = 4)

if nargin < 4, opts = struct(); end
if ~isfield(opts,'skipFirstPlateaus'), opts.skipFirstPlateaus = 1; end
if ~isfield(opts,'madThresh'),         opts.madThresh = 4; end

% ---- plateau means from UNFILTERED data (exactly like your pipeline) ----
plate = stored_data_i{6}(:, phys2localIdx);   % intervel_avg_res(:,k)

plate = plate(:);
if numel(plate) < 3 || all(isnan(plate))
    val_pct = NaN;
    return;
end

% ---- ΔR between plateaus ----
dR = diff(plate);

% ---- skip conditioning steps ----
if opts.skipFirstPlateaus > 0 && numel(dR) > opts.skipFirstPlateaus
    dR(1:opts.skipFirstPlateaus) = NaN;
end

dRabs = abs(dR);
dRabs = dRabs(isfinite(dRabs));

if numel(dRabs) < 2
    val_pct = NaN;
    return;
end

% ---- MAD-based outlier rejection ----
med0 = median(dRabs);
mad0 = mad(dRabs,1);
if mad0 > 0
    thr = opts.madThresh * 1.4826 * mad0;
    dRabs = dRabs(abs(dRabs - med0) <= thr);
end

if isempty(dRabs) || ~isfinite(refBase) || refBase == 0
    val_pct = NaN;
    return;
end

% ---- final metric ----
val_pct = median(dRabs) / refBase * 100;

end
