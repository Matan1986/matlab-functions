function [chMap, plotChannels, labels, Normalize_to] = select_preset(preset_name)
switch preset_name
    case '1xy_2xx_3xy_4xx'
        chMap = struct('ch1',s(1), 'ch2',s(2), 'ch3',s(3), 'ch4',s(4));
        labels = struct('ch1','ρ_{xy1}','ch2','ρ_{xx2}','ch3','ρ_{xy3}','ch4','ρ_{xx4}');
        plotChannels = struct('ch1',true,'ch2',true,'ch3',true,'ch4',true);
        Normalize_to = [2 2 4 4];

    case '1xy_2xx'
        chMap = struct('ch1',s(1), 'ch2',s(2), 'ch3',s(0), 'ch4',s(0));
        labels = struct('ch1','ρ_{xy1}','ch2','ρ_{xx2}','ch3','','ch4','');
        plotChannels = struct('ch1',true,'ch2',true,'ch3',false,'ch4',false);
        Normalize_to = [2 2];

    case '1xx_2xx'
        chMap = struct('ch1',s(1), 'ch2',s(2), 'ch3',s(0), 'ch4',s(0));
        labels = struct('ch1','ρ_{xx1}','ch2','ρ_{xx2}','ch3','','ch4','');
        plotChannels = struct('ch1',true,'ch2',true,'ch3',false,'ch4',false);
        Normalize_to = [1 2];

    case '2xx_3xy'
        chMap = struct('ch1',s(1), 'ch2',s(2), 'ch3',s(3), 'ch4',s(4));
        labels = struct('ch1','ρ_{xy1}','ch2','ρ_{xx2}','ch3','ρ_{xy3}','ch4','ρ_{xx4}');
        plotChannels = struct('ch1',false,'ch2',true,'ch3',true,'ch4',false);
        Normalize_to = [2 2];

    case '2xx_3xy_4xx'
        chMap = struct('ch1',s(1), 'ch2',s(2), 'ch3',s(3), 'ch4',s(4));
        labels = struct('ch1','ρ_{xy1}','ch2','ρ_{xx2}','ch3','ρ_{xy3}','ch4','ρ_{xx4}');
        plotChannels = struct('ch1',false,'ch2',true,'ch3',true,'ch4',true);
        Normalize_to = [2 2 4];

    case '2xx'
        chMap = struct('ch1',s(0), 'ch2',s(2), 'ch3',s(0), 'ch4',s(0));
        labels = struct('ch1','','ch2','ρ_{xx2}','ch3','','ch4','');
        plotChannels = struct('ch1',false,'ch2',true,'ch3',false,'ch4',false);
        Normalize_to = [2];

    case '1xy_2xx_3xx'
        chMap = struct('ch1',s(1), 'ch2',s(2), 'ch3',s(3), 'ch4',s(0));
        labels = struct('ch1','ρ_{xy1}','ch2','ρ_{xx2}','ch3','ρ_{xx3}','ch4','');
        plotChannels = struct('ch1',true,'ch2',true,'ch3',true,'ch4',false);
        Normalize_to = [2 2 3];

        % === NEW preset: 2xx_4xx ===
    case '2xx_4xx'
        chMap = struct('ch1',s(0), 'ch2',s(2), 'ch3',s(0), 'ch4',s(4));
        labels = struct('ch1','','ch2','ρ_{xx2}','ch3','','ch4','ρ_{xx4}');
        plotChannels = struct('ch1',false,'ch2',true,'ch3',false,'ch4',true);
        Normalize_to = [2 4];

    case '1xy_3xx'
        chMap = struct('ch1',s(1), 'ch2',s(0), 'ch3',s(3), 'ch4',s(0));
        labels = struct('ch1','ρ_{xy1}','ch2','','ch3','ρ_{xx3}','ch4','');
        plotChannels = struct('ch1',true,'ch2',false,'ch3',true,'ch4',false);
        Normalize_to = [3 3];

    case '1xx_2xx_3xy'
        chMap = struct('ch1',s(1), 'ch2',s(2), 'ch3',s(3), 'ch4',s(0));
        labels = struct('ch1','ρ_{xx1}','ch2','ρ_{xx2}','ch3','ρ_{xy3}','ch4','');
        plotChannels = struct('ch1',true,'ch2',true,'ch3',true,'ch4',false);
        Normalize_to = [1 2 2];

    otherwise
        error('Unknown preset_name: %s', preset_name);
end

% add labels into plotChannels as a field
plotChannels.labels = labels;

    function o = s(src)
        o = struct('src', src, 'sign', +1, 'scale', 1);
    end
end
