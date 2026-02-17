function out = physLabel(varargin)
% PHYSLABEL Research-Stable v1.1
% Symbol-level LaTeX constructor for one physical label expression only.
% Always returns a single math-mode string wrapped in $...$.
%
% Examples:
%   physLabel('symbol','M','sub','z','units','\mu_B / \mathrm{Co}^{2+}')
%   physLabel('symbol','rho','sub','xx','delta',true,'ratioTo','rho_0','units','\%')

p = inputParser;
p.FunctionName = 'physLabel';

addParameter(p, 'symbol', [], @isTextScalar);
addParameter(p, 'sub', [], @isOptionalTextScalar);
addParameter(p, 'delta', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'ratioTo', [], @isOptionalTextScalar);
addParameter(p, 'power', [], @isOptionalScalarOrText);
addParameter(p, 'units', [], @isOptionalTextScalar);

parse(p, varargin{:});
r = p.Results;

if isempty(r.symbol)
    error('physLabel:MissingRequiredSymbol', 'The ''symbol'' parameter is required.');
end

assertNoDollar(r.symbol, 'symbol');
assertNoDollar(r.sub, 'sub');
assertNoDollar(r.ratioTo, 'ratioTo');
assertNoDollar(r.units, 'units');
assertNoDollar(r.power, 'power');

expr = formatToken(r.symbol);
expr = [expr wrapSub(r.sub) wrapSup(r.power)];

if r.delta
    expr = ['\Delta ' expr];
end

if ~isempty(r.ratioTo)
    expr = [expr '/' formatToken(r.ratioTo)];
end

if ~isempty(r.units)
    unitsText = char(string(r.units));
    expr = [expr '\ (' unitsText ')'];
end

out = ['$' expr '$'];
end

function tf = isTextScalar(x)
tf = ischar(x) || (isstring(x) && isscalar(x));
end

function tf = isOptionalTextScalar(x)
tf = isempty(x) || isTextScalar(x);
end

function tf = isOptionalScalarOrText(x)
tf = isempty(x) || (isnumeric(x) && isscalar(x)) || isTextScalar(x);
end

function assertNoDollar(value, paramName)
if isempty(value)
    return;
end

if isnumeric(value)
    return;
end

txt = char(string(value));
if contains(txt, '$')
    error('physLabel:InvalidDollarInput', ...
        'Parameter ''%s'' contains ''$''. Inputs must be raw LaTeX fragments without $...$.', ...
        paramName);
end
end

function outTok = formatToken(token)
tokenText = char(string(token));
if startsWith(tokenText, '\\')
    outTok = tokenText;
    return;
end

mapped = mapGreekName(tokenText);
if isempty(mapped)
    outTok = tokenText;
else
    outTok = mapped;
end
end

function outSub = wrapSub(sub)
if isempty(sub)
    outSub = '';
    return;
end
subText = char(string(sub));
outSub = ['_{' subText '}'];
end

function outSup = wrapSup(power)
if isempty(power)
    outSup = '';
    return;
end

if isnumeric(power)
    pText = num2str(power);
else
    pText = char(string(power));
end

outSup = ['^{' pText '}'];
end

function mapped = mapGreekName(token)
switch lower(token)
    case 'alpha'
        mapped = '\alpha';
    case 'beta'
        mapped = '\beta';
    case 'gamma'
        mapped = '\gamma';
    case 'delta'
        mapped = '\delta';
    case 'epsilon'
        mapped = '\epsilon';
    case 'zeta'
        mapped = '\zeta';
    case 'eta'
        mapped = '\eta';
    case 'theta'
        mapped = '\theta';
    case 'kappa'
        mapped = '\kappa';
    case 'lambda'
        mapped = '\lambda';
    case 'mu'
        mapped = '\mu';
    case 'nu'
        mapped = '\nu';
    case 'xi'
        mapped = '\xi';
    case 'pi'
        mapped = '\pi';
    case 'rho'
        mapped = '\rho';
    case 'sigma'
        mapped = '\sigma';
    case 'tau'
        mapped = '\tau';
    case 'phi'
        mapped = '\phi';
    case 'chi'
        mapped = '\chi';
    case 'psi'
        mapped = '\psi';
    case 'omega'
        mapped = '\omega';
    otherwise
        mapped = '';
end
end