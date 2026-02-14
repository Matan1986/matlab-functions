function RUN_URGENT_VALIDATION()
warning on all;
disp('RUN_URGENT_VALIDATION: START');
try
    FinalFigureFormatterUI();
    pause(2);
    close all force;
    disp('RUN_URGENT_VALIDATION: VALIDATION_DONE');
catch ME
    disp(getReport(ME,'extended'));
    disp('RUN_URGENT_VALIDATION: VALIDATION_FAILED');
end
end
