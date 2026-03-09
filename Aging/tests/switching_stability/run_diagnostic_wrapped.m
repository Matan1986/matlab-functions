%% Wrapper to run diagnostic with explicit output capture

logfile = 'diagnostic_captured_output.txt';
diary(logfile);

try
    fprintf('=== DIAGNOSTIC RUN START ===\n');
    fprintf('Time: %s\n',datestr(now));
    
    % Run diagnostic
    diagnostic
    
    fprintf('=== DIAGNOSTIC RUN SUCCESS ===\n');
catch ME
    fprintf('=== DIAGNOSTIC RUN FAILED ===\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('Stack:\n%s\n', ME.getReport());
end

diary off;
fprintf('Output saved to: %s\n', logfile);
exit;
