function varargout = phi2_shape_helpers(action, varargin)
% Shared helper routines for run_phi2_shape_physics_test.m
switch action
    case 'apply_defaults'
        varargout{1} = localApplyDefaults(varargin{1});
    case 'even_part'
        [varargout{1}, varargout{2}] = localEvenPart(varargin{1}, varargin{2});
    case 'odd_part'
        varargout{1} = localOddPart(varargin{1}, varargin{2});
    case 'odd_fraction'
        varargout{1} = localOddFraction(varargin{1}, varargin{2});
    case 'zero_mean_unit_l2'
        varargout{1} = localZeroMeanUnitL2(varargin{1});
    case 'safe_corr'
        varargout{1} = localSafeCorr(varargin{1}, varargin{2});
    case 'rmse'
        varargout{1} = localRmse(varargin{1}, varargin{2});
    case 'cosine_sim'
        varargout{1} = localCosineSim(varargin{1}, varargin{2});
    case 'mean_abs'
        varargout{1} = localMeanAbs(varargin{1}, varargin{2});
    case 'zero_crossings'
        varargout{1} = localZeroCrossings(varargin{1}, varargin{2});
    case 'loo_phi2_cosine'
        varargout{1} = localLooPhi2Cosine(varargin{1}, varargin{2});
    case 'phi2_from_r'
        varargout{1} = localPhi2FromR(varargin{1});
    case 'yes_no'
        varargout{1} = localYesNo(varargin{1});
    otherwise
        error('phi2_shape_helpers:UnknownAction', 'Unknown action: %s', string(action));
end
end

function cfg = localApplyDefaults(cfg)
cfg = localSetDef(cfg, 'runLabel', 'phi2_shape_physics');
cfg = localSetDef(cfg, 'alignmentRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = localSetDef(cfg, 'fullScalingRunId', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = localSetDef(cfg, 'ptRunId', 'run_2026_03_24_212033_switching_barrier_distribution_from_map');
cfg = localSetDef(cfg, 'canonicalMaxTemperatureK', 30);
cfg = localSetDef(cfg, 'nXGrid', 220);
cfg = localSetDef(cfg, 'fallbackSmoothWindow', 5);
cfg = localSetDef(cfg, 'gaussianSigmaX', 0.22);
cfg = localSetDef(cfg, 'localizationRadiusX', 1.0);
cfg = localSetDef(cfg, 'localizationRadiusTightX', 0.5);
cfg = localSetDef(cfg, 'tailRadiusX', 0.35);
cfg = localSetDef(cfg, 'minRowsForPhi2', 5);
cfg = localSetDef(cfg, 'symmEvenThreshold', 0.55);
cfg = localSetDef(cfg, 'localizeEnergyThreshold', 0.45);
cfg = localSetDef(cfg, 'localizeRmsXThreshold', 0.55);
cfg = localSetDef(cfg, 'kernelCorrThreshold', 0.72);
cfg = localSetDef(cfg, 'stabilityCosThreshold', 0.88);
cfg = localSetDef(cfg, 'outputRepoRoot', 'C:/Dev/matlab-functions');
end

function cfg = localSetDef(cfg, name, val)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = val;
end
end

function [evenFrac, evenVec] = localEvenPart(xg, phi)
p = phi(:);
xn = xg(:);
pneg = interp1(xn, p, -xn, 'linear', NaN);
m = isfinite(p) & isfinite(pneg);
evenVec = NaN(size(p));
evenVec(m) = 0.5 * (p(m) + pneg(m));
evenFrac = sum(evenVec(m) .^ 2, 'omitnan') / sum(p(m) .^ 2, 'omitnan');
end

function oddVec = localOddPart(xg, phi)
p = phi(:);
xn = xg(:);
pneg = interp1(xn, p, -xn, 'linear', NaN);
m = isfinite(p) & isfinite(pneg);
oddVec = NaN(size(p));
oddVec(m) = 0.5 * (p(m) - pneg(m));
end

function f = localOddFraction(phi, oddVec)
p = phi(:);
m = isfinite(p) & isfinite(oddVec);
f = sum(oddVec(m) .^ 2, 'omitnan') / sum(p(m) .^ 2, 'omitnan');
end

function y = localZeroMeanUnitL2(y)
y = y(:);
m = isfinite(y);
if nnz(m) < 5
    y(:) = NaN;
    return
end
w = y(m) - mean(y(m), 'omitnan');
nrm = norm(w);
if ~(isfinite(nrm) && nrm > eps)
    y(:) = NaN;
    return
end
y(:) = 0;
y(m) = w ./ nrm;
end

function c = localSafeCorr(a, b)
m = isfinite(a(:)) & isfinite(b(:));
if nnz(m) < 5
    c = NaN;
    return
end
c = corr(a(m), b(m));
end

function r = localRmse(a, b)
m = isfinite(a(:)) & isfinite(b(:));
if nnz(m) < 5
    r = NaN;
    return
end
d = a(m) - b(m);
r = sqrt(mean(d .^ 2, 'omitnan'));
end

function c = localCosineSim(a, b)
m = isfinite(a(:)) & isfinite(b(:));
if nnz(m) < 5
    c = NaN;
    return
end
p = a(m);
q = b(m);
c = dot(p, q) / (norm(p) * norm(q) + eps);
end

function v = localMeanAbs(phi, mask)
m = mask(:) & isfinite(phi(:));
if nnz(m) == 0
    v = NaN;
    return
end
v = mean(abs(phi(m)), 'omitnan');
end

function n = localZeroCrossings(y, x)
y = y(:);
x = x(:);
m = isfinite(y);
y = y(m);
x = x(m);
if numel(y) < 3
    n = 0;
    return
end
s = sign(y);
s(s == 0) = NaN;
ds = diff(s);
n = sum(ds ~= 0 & isfinite(ds));
end

function cosVec = localLooPhi2Cosine(Rlow, phi2Ref)
n = size(Rlow, 1);
cosVec = NaN(n, 1);
ref = localZeroMeanUnitL2(phi2Ref);
for i = 1:n
    if n - 1 < 2
        break
    end
    Rm = Rlow;
    Rm(i, :) = [];
    v2 = localPhi2FromR(Rm);
    if isempty(v2)
        continue
    end
    vn = localZeroMeanUnitL2(v2);
    if dot(vn, ref) < 0
        vn = -vn;
    end
    cosVec(i) = dot(vn, ref);
end
end

function v2 = localPhi2FromR(Rlow)
R0 = Rlow;
R0(~isfinite(R0)) = 0;
if size(R0, 1) < 2
    v2 = [];
    return
end
[~, ~, V] = svd(R0, 'econ');
if size(V, 2) < 2
    v2 = [];
    return
end
v2 = V(:, 2);
end

function s = localYesNo(tf)
if tf
    s = 'YES';
else
    s = 'NO';
end
end
