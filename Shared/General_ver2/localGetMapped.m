function v = localGetMapped(m, LI_XV, defaultVec)
    if m.src==0
        v = zeros(size(defaultVec)); % disabled channel
    else
        v = m.sign * m.scale * LI_XV{m.src};
    end
end