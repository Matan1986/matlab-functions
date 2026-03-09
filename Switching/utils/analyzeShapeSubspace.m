function sh = analyzeShapeSubspace(M, rankK)
mask = isfinite(M);
M0 = M;
M0(~mask) = 0;
[U, S, V] = svd(M0, 'econ');
sv = diag(S);
k = min([rankK, numel(sv), size(U, 2), size(V, 2)]);
C = U(:, 1:k) * S(1:k, 1:k);
V2 = V(:, 1:k);
M_native = C * V2';
sh = struct('M', M, 'U', U, 'S', S, 'V', V, 'C', C, 'V2', V2, 'M_native', M_native, 'rank', k);
end