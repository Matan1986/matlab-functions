function chans = build_channels(chMap, LI_XV, I, Scaling_factor)
    getMapped = @(m) localGetMapped(m, LI_XV, LI_XV{1});
    chans.ch1 = getMapped(chMap.ch1) / I * Scaling_factor;
    chans.ch2 = getMapped(chMap.ch2) / I * Scaling_factor;
    chans.ch3 = getMapped(chMap.ch3) / I * Scaling_factor;
    chans.ch4 = getMapped(chMap.ch4) / I * Scaling_factor;
end