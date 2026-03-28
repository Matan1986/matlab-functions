function out = sanitizeMD(strIn)
    % Minimal markdown sanitization for table display.
    out = strrep(strIn, '|', '\\|');
end

