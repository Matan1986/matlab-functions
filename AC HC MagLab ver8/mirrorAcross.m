function [x_out, y_out] = mirrorAcross(x, y, xref, n)
% mirrorAcross  Mirror data for x> xref by reflecting x< xref values
%               and always expanding the output range.
% Inputs:
%   x, y – cell arrays of numeric vectors (length ≥ n)
%   xref – scalar reference value
%   n    – number of cells to process
% Outputs:
%   x_out, y_out – cell arrays containing original x<xref and
%                  their reflected points for x>xref

    x_out = cell(size(x));
    y_out = cell(size(y));

    for i = 1:n
        xi = x{i}(:);   % ensure column vector
        yi = y{i}(:);

        % select points below reference
        idx_low = xi < xref;
        x_low   = xi(idx_low);
        y_low   = yi(idx_low);

        % reflect those points across xref
        x_mirror = 2*xref - x_low;
        y_mirror = y_low;

        % combine original lower side with mirrored upper side
        x_comb = [x_low; x_mirror];
        y_comb = [y_low; y_mirror];

        % sort by x to maintain order
        [x_sorted, sort_idx] = sort(x_comb);
        y_sorted = y_comb(sort_idx);

        x_out{i} = x_sorted;
        y_out{i} = y_sorted;
    end
end
