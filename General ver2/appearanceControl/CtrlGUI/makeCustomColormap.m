function C = makeCustomColormap(name)

n = 256;

switch lower(name)

%% =========================
%       SOFT MAPS
%% =========================
case 'softyellow'
    C = [linspace(0.4,0.9,n)', linspace(0.4,0.9,n)', linspace(0.1,0.2,n)'];

case 'softgreen'
    C = [linspace(0.1,0.4,n)', linspace(0.3,0.7,n)', linspace(0.1,0.3,n)'];

case 'softred'
    C = [linspace(0.4,0.9,n)', linspace(0.1,0.3,n)', linspace(0.1,0.3,n)'];

case 'softblue'
    C = [linspace(0.1,0.3,n)', linspace(0.1,0.3,n)', linspace(0.4,0.9,n)'];

case 'softpurple'
    C = [linspace(0.4,0.7,n)', linspace(0.2,0.3,n)', linspace(0.5,0.8,n)'];

case 'softorange'
    C = [linspace(0.7,0.95,n)', linspace(0.4,0.6,n)', linspace(0.1,0.2,n)'];

case 'softcyan'
    C = [linspace(0.1,0.2,n)', linspace(0.5,0.9,n)', linspace(0.8,0.95,n)'];

case 'softgray'
    C = repmat(linspace(0.3,0.9,n)',1,3);

case 'softbrown'
    C = [linspace(0.3,0.6,n)', linspace(0.2,0.3,n)', linspace(0.1,0.1,n)'];

case 'softteal'
    C = [linspace(0.1,0.2,n)', linspace(0.6,0.8,n)', linspace(0.7,0.9,n)'];

case 'softolive'
    C = [linspace(0.3,0.5,n)', linspace(0.4,0.5,n)', linspace(0.1,0.2,n)'];

case 'softgold'
    C = [linspace(0.8,1,n)', linspace(0.7,0.9,n)', linspace(0.2,0.3,n)'];

case 'softpink'
    C = [linspace(0.9,1,n)', linspace(0.7,0.8,n)', linspace(0.7,0.9,n)'];

case 'softaqua'
    C = [linspace(0.3,0.5,n)', linspace(0.8,1,n)', linspace(0.9,1,n)'];

case 'softsand'
    C = [linspace(0.7,0.9,n)', linspace(0.6,0.7,n)', linspace(0.4,0.5,n)'];

case 'softsky'
    C = [linspace(0.4,0.6,n)', linspace(0.6,0.8,n)', linspace(0.9,1,n)'];



%% =========================
%      BRIGHT MAPS
%% =========================
case 'bluebright'
    C = [zeros(n,1), zeros(n,1), linspace(0.2,1,n)'];

case 'redbright'
    C = [linspace(0.2,1,n)', zeros(n,1), zeros(n,1)];

case 'greenbright'
    C = [zeros(n,1), linspace(0.2,1,n)', zeros(n,1)];

case 'purplebright'
    C = [linspace(0.3,1,n)', linspace(0,0.3,n)', linspace(0.3,1,n)'];

case 'orangebright'
    C = [ones(n,1), linspace(0.5,0.1,n)', zeros(n,1)];

case 'cyanbright'
    C = [zeros(n,1), linspace(0.5,1,n)', ones(n,1)];

case 'yellowbright'
    C = [ones(n,1), ones(n,1), linspace(0.2,0,n)'];

case 'magnetabright'
    C = [ones(n,1), linspace(0,0.2,n)', ones(n,1)];

case 'limebright'
    C = [linspace(0.6,1,n)', ones(n,1), linspace(0.2,0.3,n)'];

case 'tealbright'
    C = [zeros(n,1), linspace(0.7,1,n)', linspace(0.7,1,n)'];

case 'ultrabrightblue'
    C = [zeros(n,1), zeros(n,1), linspace(0.5,1,n)'];

case 'ultrabrightred'
    C = [linspace(0.5,1,n)', zeros(n,1), zeros(n,1)];



%% =========================
%     SCIENTIFIC MAPS
%% =========================
case 'fire'
    C = [linspace(0,1,n)', linspace(0,0.8,n)', zeros(n,1)];

case 'ice'
    C = [linspace(0.8,0,n)', linspace(1,0.4,n)', ones(n,1)];

case 'ocean'
    C = [zeros(n,1), linspace(0.2,0.7,n)', linspace(0.5,1,n)'];

case 'topo'
    C = [linspace(0.1,0.8,n)', linspace(0.4,0.8,n)', linspace(0.2,0.4,n)'];

case 'terrain'
    C = [linspace(0.2,0.6,n)', linspace(0.4,1,n)', ones(n,1)*0.2];

case 'magma'
    C = magma(n);

case 'inferno'
    C = inferno(n);

case 'plasma'
    C = plasma(n);

case 'cividis'
    C = cividis(n);



%% =========================
%     DIVERGING MAPS
%% =========================
case 'bluewhitered'
    C1 = [0 0 1];
    C2 = [1 1 1];
    C3 = [1 0 0];
    C = interp1([0 0.5 1],[C1;C2;C3],linspace(0,1,n));

case 'redwhiteblue'
    C = flipud(makeCustomColormap('bluewhitered'));

case 'purplewhitegreen'
    C = interp1([0 0.5 1],[0.6 0 0.6; 1 1 1; 0 0.6 0], linspace(0,1,n));

case 'brownwhiteblue'
    C = interp1([0 0.5 1],[0.5 0.2 0; 1 1 1; 0 0.4 1], linspace(0,1,n));

case 'greenwhitepurple'
    C = interp1([0 0.5 1],[0 1 0; 1 1 1; 0.5 0 0.5], linspace(0,1,n));

case 'bluewhiteorange'
    C = interp1([0 0.5 1],[0 0 1; 1 1 1; 1 0.5 0], linspace(0,1,n));

case 'blackwhiteyellow'
    C = interp1([0 0.5 1],[0 0 0; 1 1 1; 1 1 0], linspace(0,1,n));

otherwise
    error('Unknown custom colormap name: %s', name);
end

end
