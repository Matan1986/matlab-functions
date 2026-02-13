function print_AMR_spectra(results, opts)
% Print and plot harmonic spectra from AMR symmetry analysis
%
% results : output struct from analyze_AMR_symmetry
%
% opts fields (all optional):
%   .channels   : cellstr of internal keys, e.g. {'ch2','ch4'}
%   .fields     : indices or 'all'
%   .temps      : indices or 'all'
%   .plot       : true/false (default true)
%   .print      : true/false (default true)

if ~isfield(opts,'channels'), opts.channels = fieldnames(results); end
if ~isfield(opts,'fields'),   opts.fields   = 'all'; end
if ~isfield(opts,'temps'),    opts.temps    = 'all'; end
if ~isfield(opts,'plot'),     opts.plot     = true; end
if ~isfield(opts,'print'),    opts.print    = true; end

for ic = 1:numel(opts.channels)
    key = opts.channels{ic};

    if ~isfield(results, key), continue; end
    R = results.(key);

    data = R.data;   % [field x temp] struct array

    nF = size(data,1);
    nT = size(data,2);

    fList = resolve_indices(opts.fields, nF);
    tList = resolve_indices(opts.temps,  nT);

    for f = fList
        for t = tList
            out = data(f,t);
            if isempty(out) || isempty(out.n), continue; end

            % ---------- PRINT ----------
            if opts.print
                fprintf('%s | field #%d | temp #%d\n', key, f, t);
                fprintf('  n : ');
                fprintf('%3d ', out.n);
                fprintf('\n  A : ');
                fprintf('%6.3g ', out.Amp);
                fprintf('\n\n');
            end

            % ---------- PLOT ----------
            if opts.plot
                figure('Color','w');
                stem(out.n, out.Amp, 'filled','LineWidth',1.5);
                grid on;
                xlabel('Harmonic n');
                ylabel('Amplitude');
                title(sprintf('Spectrum | %s | f=%d | t=%d', key, f, t));
                set(gca,'FontSize',14);
            end
        end
    end
end
end

% ===== helper =====
function idx = resolve_indices(sel, N)
    if ischar(sel) || isstring(sel)
        if strcmpi(sel,'all')
            idx = 1:N;
        else
            error('Unknown selector');
        end
    else
        idx = sel(sel>=1 & sel<=N);
    end
end
