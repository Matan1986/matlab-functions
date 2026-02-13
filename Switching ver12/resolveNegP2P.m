function NegP2P = resolveNegP2P(pathStr, mode)
% resolveNegP2P
%
% Smart, self-contained decision of NegP2P sign from folder path.
%
% Supports automatic detection of configuration number (1–4) from:
%   Conf1 / conf1
%   Config1 / config1
%   Configuration1 / configuration1
%
% RULES (auto mode):
%   Config 2,3 → NegP2P = true
%   Config 1,4 → NegP2P = false
%   No config  → assume Config2 → NegP2P = true
%
% INPUT:
%   pathStr : char / string
%   mode    : "auto" | "forcePositive" | "forceNegative"
%
% OUTPUT:
%   NegP2P  : logical

    arguments
        pathStr (1,:) char
        mode    (1,1) string = "auto"
    end

    switch mode
        case "forcePositive"
            NegP2P = false;
            return

        case "forceNegative"
            NegP2P = true;
            return

        case "auto"
            pathLower = lower(pathStr);

            % Regex explanation:
            % (conf|config|configuration)  → keyword
            % \D*                          → optional separator
            % ([1-4])                     → config number
            expr = '(conf|config|configuration)\D*([1-4])';

            tokens = regexp(pathLower, expr, 'tokens', 'once');

            if isempty(tokens)
                % No configuration mentioned → default = Config2
                NegP2P = true;
                return
            end

            cfg = str2double(tokens{2});

            switch cfg
                case {2, 3}
                    NegP2P = true;
                case {1, 4}
                    NegP2P = false;
                otherwise
                    % Safety fallback (should never happen)
                    NegP2P = true;
            end

        otherwise
            error('resolveNegP2P:InvalidMode', ...
                'Unknown NegP2P mode: %s', mode);
    end
end
