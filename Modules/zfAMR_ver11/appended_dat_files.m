close all;
clear;
clc;

% Define the folder where the files are located
folderPath = 'C:\Users\User\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 131\MG131_Non-FIB_Par1_and_Perp1_InplaneRotator_zfAMR';

% Define the files to read
files = {'Vxx1_Vxx2_Ixx_5mAmp_f_177p77Hz_Field_11T_Temp_4K_zfAMR_until_90_deg',...
         'Vxx1_Vxx2_Ixx_5mAmp_f_177p77Hz_Field_11T_Temp_4K_zfAMR_from_90_deg',...
       };

% Define the output file
outputFile = fullfile(folderPath, 'Vxx1_Vxx2_Ixx_5mAmp_f_177p77Hz_Field_11T_Temp_4K_zfAMR_appended.dat');

% Define the delta_T and duration threshold
delta_T = 0.3; % Temperature change threshold
min_duration = 10 * 60 * 1000; % 10 minutes in milliseconds
keep_segment = 2 * 60 * 1000; % 2 minutes in milliseconds

% Initialize a variable to track the accumulated time offset
accumulated_time = 0;

% Loop through each file and read the data
for i = 1:length(files)
    filePath = fullfile(folderPath, files{i});
    
    % Read the file data
    data = readtable(filePath, 'FileType', 'text', 'Delimiter', '\t', 'VariableNamingRule', 'preserve');
    
    % Check the starting temperature
    start_temp = data{1, 3};
    if abs(start_temp - 50) > delta_T
        % Find the first instance within the acceptable temperature range
        valid_start_index = find(abs(data{:, 3} - 50) <= delta_T, 1, 'first');
        if ~isempty(valid_start_index)
            time_trimmed = data{valid_start_index, 1} - data{1, 1};
            data = data(valid_start_index:end, :);
            fprintf('Trimmed the beginning of %s after %.2f minutes\n', files{i}, time_trimmed / 60000);
        else
            warning('No valid starting temperature found within 50 ± %f for %s', delta_T, files{i});
        end
    end
    
    % Write the header if it's the first file
    if i == 1
        writetable(data(1, :), outputFile, 'WriteVariableNames', true, 'Delimiter', '\t');
    end
    
    % Extract the time and temperature columns
    time = data{:, 1};
    temperature = data{:, 3};
    
    % Debugging output
    disp(['Processing file: ', files{i}]);
    
    % Initialize variables for finding the longest stable segment
    stable_end_index = length(time);
    stable_start_index = stable_end_index;
    
    % Traverse from the end to the beginning to find the longest stable segment
    for j = stable_end_index:-1:1
        if abs(temperature(stable_end_index) - temperature(j)) <= delta_T
            stable_start_index = j;
        else
            break;
        end
    end
    
    stable_time = time(stable_end_index) - time(stable_start_index);
    
    % Initialize the variable to hold the kept data
    keep_data = data;
    
    % If the stable segment is longer than 10 minutes, keep only the first 2 minutes
    if stable_time > min_duration
        start_keep_index = stable_start_index + find(time(stable_start_index:end) >= (time(stable_start_index) + keep_segment), 1, 'first') - 1;
        keep_data = data(1:start_keep_index, :);
        fprintf('Stable segment duration for %s: %f minutes\n', files{i}, stable_time / 60000);
    else
        fprintf('Stable segment duration for %s: %f minutes\n', files{i}, stable_time / 60000);
    end
    
    % Adjust time for the current segment
    keep_data{:, 1} = keep_data{:, 1} + accumulated_time;
    accumulated_time = keep_data{end, 1};
    
    % Write the data to the output file
    writetable(keep_data, outputFile, 'WriteVariableNames', false, 'Delimiter', '\t', 'WriteMode', 'append');
    
    % Plot the data
    figure('Name', ['Temperature and Field Profile for ' files{i}], 'Position', [100, 100, 1000, 600]);
    subplot(2, 1, 1);
    hold on;
    plot(time, temperature, 'r', 'DisplayName', 'Raw Data');
    if stable_time > min_duration
        plot(time(1:start_keep_index), temperature(1:start_keep_index), 'b', 'LineWidth', 2, 'DisplayName', 'Kept Segment');
    else
        plot(time, temperature, 'b', 'LineWidth', 2, 'DisplayName', 'Kept Segment (All Data)');
    end
    ylabel('Temperature [K]');
    title(['Temperature Profile for ' files{i}]);
    legend('show');
    hold off;
    
    subplot(2, 1, 2);
    hold on;
    field = data{:, 2};
    plot(time, field, 'r', 'DisplayName', 'Raw Data');
    if stable_time > min_duration
        plot(time(1:start_keep_index), field(1:start_keep_index), 'b', 'LineWidth', 2, 'DisplayName', 'Kept Segment');
    else
        plot(time, field, 'b', 'LineWidth', 2, 'DisplayName', 'Kept Segment (All Data)');
    end
    ylabel('Field [T]');
    xlabel('Time [ms]');
    title(['Field Profile for ' files{i}]);
    legend('show');
    hold off;
end

% Plot the final appended data
final_data = readtable(outputFile, 'FileType', 'text', 'Delimiter', '\t', 'VariableNamingRule', 'preserve');
figure('Name', 'Final Appended Data', 'Position', [100, 100, 1000, 600]);
subplot(2, 1, 1);
hold on;
plot(final_data{:, 1}, final_data{:, 3}, 'r', 'DisplayName', 'Temperature [K]');
ylabel('Temperature [K]');
title('Temperature Profile for Final Appended Data');
legend('show');
hold off;

subplot(2, 1, 2);
hold on;
plot(final_data{:, 1}, final_data{:, 2}, 'r', 'DisplayName', 'Field [T]');
ylabel('Field [T]');
xlabel('Time [ms]');
title('Field Profile for Final Appended Data');
legend('show');
hold off;

% Display a message indicating the files have been combined and processed
disp('Files have been combined and processed successfully.');
