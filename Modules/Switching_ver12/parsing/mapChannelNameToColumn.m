function colIdx = mapChannelNameToColumn(chName)
% MAPCHANNELNAMETOCOLUMN
% maps 'ch1'..'ch4' → column index in stored_data{i,1..3}
% col 1 is time, so ch1→2, ch2→3, ch3→4, ch4→5

    switch chName
        case 'ch1'
            colIdx = 2;
        case 'ch2'
            colIdx = 3;
        case 'ch3'
            colIdx = 4;
        case 'ch4'
            colIdx = 5;
        otherwise
            error('Unknown channel name: %s', chName);
    end
end
