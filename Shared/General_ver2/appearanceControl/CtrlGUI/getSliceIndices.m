function idx = getSliceIndices(M, mode)
% GETSLICEINDICES
%   Flexible colormap slicing function with adjustable widths.
%
%   Modes (all have "-rev" versions):
%       ultra-narrow
%       narrow
%       medium
%       wide
%       ultra
%       full
%
%   Widths are controlled by constants at the top of this file.

%% ==============================================================
%  USER CONFIGURABLE WIDTHS  (fraction of full colormap)
%  These represent HALF-width spans around the center.
% ==============================================================

SPAN_ULTRA_NARROW = 0.20 * M;   % ~20% total width
SPAN_NARROW       = 0.30 * M;   % ~30%
SPAN_MEDIUM       = 0.35 * M;   % ~35%
SPAN_WIDE         = 0.40 * M;   % ~40%
SPAN_ULTRA        = 0.45 * M;   % ~45%

% NOTE:
% full = 100% → handled directly (no span needed)

%% ==============================================================
%  Logic
% ==============================================================

mode = lower(mode);
mid  = round(M/2);

switch mode

    % ==========================================================
    % FULL (100%)
    % ==========================================================
    case 'full'
        idx = 1:M;

    case 'full-rev'
        idx = M:-1:1;

    % ==========================================================
    % ULTRA-NARROW (new)
    % ==========================================================
    case 'ultra-narrow'
        lo = max(1, mid - round(SPAN_ULTRA_NARROW));
        hi = min(M, mid + round(SPAN_ULTRA_NARROW));
        idx = lo:hi;

    case 'ultra-narrow-rev'
        lo = max(1, mid - round(SPAN_ULTRA_NARROW));
        hi = min(M, mid + round(SPAN_ULTRA_NARROW));
        idx = hi:-1:lo;

    % ==========================================================
    % NARROW
    % ==========================================================
    case 'narrow'
        lo = max(1, mid - round(SPAN_NARROW));
        hi = min(M, mid + round(SPAN_NARROW));
        idx = lo:hi;

    case 'narrow-rev'
        lo = max(1, mid - round(SPAN_NARROW));
        hi = min(M, mid + round(SPAN_NARROW));
        idx = hi:-1:lo;

    % ==========================================================
    % MEDIUM
    % ==========================================================
    case 'medium'
        lo = max(1, mid - round(SPAN_MEDIUM));
        hi = min(M, mid + round(SPAN_MEDIUM));
        idx = lo:hi;

    case 'medium-rev'
        lo = max(1, mid - round(SPAN_MEDIUM));
        hi = min(M, mid + round(SPAN_MEDIUM));
        idx = hi:-1:lo;

    % ==========================================================
    % WIDE
    % ==========================================================
    case 'wide'
        lo = max(1, mid - round(SPAN_WIDE));
        hi = min(M, mid + round(SPAN_WIDE));
        idx = lo:hi;

    case 'wide-rev'
        lo = max(1, mid - round(SPAN_WIDE));
        hi = min(M, mid + round(SPAN_WIDE));
        idx = hi:-1:lo;

    % ==========================================================
    % ULTRA (widest non-full)
    % ==========================================================
    case 'ultra'
        lo = max(1, mid - round(SPAN_ULTRA));
        hi = min(M, mid + round(SPAN_ULTRA));
        idx = lo:hi;

    case 'ultra-rev'
        lo = max(1, mid - round(SPAN_ULTRA));
        hi = min(M, mid + round(SPAN_ULTRA));
        idx = hi:-1:lo;

    otherwise
        error('Unknown spreadMode "%s".', mode);
end
end
