function [ang360, perm] = wrap_sort_angles(angles_deg)
% Map to [0,360) and sort ascending; return permutation to reorder Y accordingly.
    ang360 = mod(angles_deg, 360);
    [ang360, perm] = sort(ang360(:));  % column
end