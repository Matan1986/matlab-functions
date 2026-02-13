function formatPaperPreset(mode)
% FORMATPAPERPRESET
% Quick presets for postFormatAllFigures
%
% שימוש:
%   formatPaperPreset('small')    % טור יחיד
%   formatPaperPreset('medium')   % טור יחיד גדול
%   formatPaperPreset('large')    % טור כפול
%   formatPaperPreset('custom')   % פתוח לשינוי שלך
%
% כל הפריסטים משתמשים ב:
%   skipName = 'CtrlGUI'
%   clearTitles = true
%   פונט = Arial

if nargin < 1
    mode = "small";
end

mode = lower(string(mode));

switch mode

    case "small"
        % טור יחיד (PRL / Nano Lett)
        postFormatAllFigures([600 450], "Arial", 14, 'CtrlGUI', "white", true);
        disp("Applied preset: SMALL (600×450, font 14)");

    case "medium"
        % טור יחיד גדול יותר (Nature style)
        postFormatAllFigures([700 500], "Arial", 16, 'CtrlGUI', "white", true);
        disp("Applied preset: MEDIUM (700×500, font 16)");

    case "large"
        % טור כפול (figures רחבים)
        postFormatAllFigures([950 600], "Arial", 18, 'CtrlGUI', "white", true);
        disp("Applied preset: LARGE (950×600, font 18)");

    case "transparent"
        % שקוף ל־Overleaf
        postFormatAllFigures([600 450], "Arial", 14, 'CtrlGUI', "transparent", true);
        disp("Applied preset: TRANSPARENT (600×450, font 14)");

    case "custom"
        % תבנית פתוחה להרחבה שלך
        postFormatAllFigures([800 550], "Arial", 15, 'CtrlGUI', "white", true);
        disp("Applied preset: CUSTOM (800×550, font 15)");

    otherwise
        error("Unknown preset. Options: small, medium, large, transparent, custom");
end

end
