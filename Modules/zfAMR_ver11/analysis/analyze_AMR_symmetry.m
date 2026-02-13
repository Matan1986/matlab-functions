function results = analyze_AMR_symmetry(tables, angles, fields, temps, channelTags, opts, symMode)
% ------------------------------------------------------------
% Build harmonic amplitude & phase maps for AMR
% Phase masking includes:
%   (1) absolute temperature-level threshold
%   (2) relative-to-dominant harmonic (per T)
%   (3) relative-to-harmonic max across T  (NEW, critical)
% ------------------------------------------------------------

%% ---------- defaults ----------
if nargin < 6, opts = struct(); end
if ~isfield(opts,'maxHarm'),        opts.maxHarm = 12; end
if ~isfield(opts,'removeMean'),     opts.removeMean = true; end
if ~isfield(opts,'doDetrend'),      opts.doDetrend  = false; end
if ~isfield(opts,'verbose'),        opts.verbose    = false; end
if ~isfield(opts,'plotMaps'),       opts.plotMaps   = true; end
if ~isfield(opts,'pickFieldIdx'),   opts.pickFieldIdx = []; end
if ~isfield(opts,'pickTempIdx'),    opts.pickTempIdx  = []; end

% ---- phase masking thresholds ----
if ~isfield(opts,'specWeightMin'),  opts.specWeightMin = 0; end
if ~isfield(opts,'phaseRelFrac'),   opts.phaseRelFrac  = 0.1; end
if ~isfield(opts,'harmRelFrac'),    opts.harmRelFrac   = 0.1; end   % NEW

angles = angles(:);
nH = opts.maxHarm;
nVec = (1:nH).';

keys = tags_to_channel_keys(channelTags);
nF = numel(tables);
nT = numel(temps);

fieldIdxList = 1:nF;
tempIdxList  = 1:nT;
if ~isempty(opts.pickFieldIdx), fieldIdxList = opts.pickFieldIdx(:).'; end
if ~isempty(opts.pickTempIdx),  tempIdxList  = opts.pickTempIdx(:).';  end

%% ---------- allocate ----------
results.meta.fields = fields;
results.meta.temps  = temps;

results.channels = repmat(struct( ...
    'tag','', 'key','', 'n',nVec, ...
    'Amp',[], 'Phi',[], 'Acos',[], 'Bsin',[]), 1, numel(keys));

%% ================= loop channels =================
for ic = 1:numel(keys)

    key = keys{ic};
    tag = channelTags{ic};

    Amp  = nan(nH,nT,nF);
    Phi  = nan(nH,nT,nF);
    Acos = nan(nH,nT,nF);
    Bsin = nan(nH,nT,nF);

    %% ----- Fourier per (T,B) -----
    for f = fieldIdxList
        tbl = tables{f};
        if ~istable(tbl) || ~ismember(key,tbl.Properties.VariableNames), continue; end

        Y = tbl.(key);
        for t = tempIdxList
            if t > size(Y,2), continue; end
            out = analyze_AMR_fourier(angles, Y(:,t), opts);

            Amp(:,t,f)  = out.Amp(:);
            Phi(:,t,f)  = out.Phi(:);
            Acos(:,t,f) = out.Acos(:);
            Bsin(:,t,f) = out.Bsin(:);
        end
    end

    %% ================== PHASE MASKING ==================
    for f = fieldIdxList

        % --- per-harmonic max across T ---
        AmaxH = max(Amp(:,:,f),[],2,'omitnan');  % [nH x 1]

        for t = tempIdxList

            Acol  = Amp(:,t,f);
            AmaxT = max(Acol,[],'omitnan');

            % (1) no AMR at all → no phase
            if ~isfinite(AmaxT) || AmaxT < opts.specWeightMin
                Phi(:,t,f) = NaN;
                continue;
            end

            % (2) relative-to-dominant harmonic
            maskT = Acol >= opts.phaseRelFrac * AmaxT;

            % (3) relative-to-harmonic lifetime (NEW)
            maskH = Acol >= opts.harmRelFrac * AmaxH;

            Phi(~(maskT & maskH), t, f) = NaN;
        end
    end

    %% ---------- store ----------
    results.channels(ic).tag  = tag;
    results.channels(ic).key  = key;
    results.channels(ic).n    = nVec;
    results.channels(ic).Amp  = Amp;
    results.channels(ic).Phi  = Phi;
    results.channels(ic).Acos = Acos;
    results.channels(ic).Bsin = Bsin;

    if opts.plotMaps
        plot_AMR_maps_one_channel(results.channels(ic), fields, temps, opts, symMode);
    end
end
end
