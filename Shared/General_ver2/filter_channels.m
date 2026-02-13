function chans = filter_channels(chans, Angledeg, FieldT, TemperatureK)
    chans.ch1 = medfilt1(chans.ch1, 100); if numel(chans.ch1)>1, chans.ch1(1) = chans.ch1(2); end
    chans.ch2 = medfilt1(chans.ch2, 100); if numel(chans.ch2)>1, chans.ch2(1) = chans.ch2(2); end
    chans.ch3 = medfilt1(chans.ch3, 100); if numel(chans.ch3)>1, chans.ch3(1) = chans.ch3(2); end
    chans.ch4 = medfilt1(chans.ch4, 100); if numel(chans.ch4)>1, chans.ch4(1) = chans.ch4(2); end
    chans.filtered_angle = medfilt1(Angledeg,10);  if numel(chans.filtered_angle)>1,  chans.filtered_angle(1)  = chans.filtered_angle(2);  end
    chans.filtered_field = medfilt1(FieldT,150);   if numel(chans.filtered_field)>1,  chans.filtered_field(1)  = chans.filtered_field(2);  end
    chans.filtered_temp  = medfilt1(TemperatureK,120); if numel(chans.filtered_temp)>1, chans.filtered_temp(1)   = chans.filtered_temp(2); end
end