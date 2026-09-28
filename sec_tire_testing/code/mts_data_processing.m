%% ================================================================
%  clean_DOT_force_single.m
%  Picks a DOT CSV file containing one test run, low-pass filters Force
%  (Displacement optional), and saves a cleaned CSV.
% ================================================================

clear; clc; close all;

%% ---- USER SETTINGS ----
cutoffHz  = 5;      % low-pass cutoff for Force. Try 2, 5, or 10 Hz.
filterDisp = false; % set true if you also want Displacement smoothed

%% ---- 1. Pick DOT file ----
[dotName, dotFolder] = uigetfile({'*.csv','CSV files (*.csv)'}, ...
    'Select the DOT CSV file');

if isequal(dotName, 0)
    error('No DOT file selected.');
end

dotFile = fullfile(dotFolder, dotName);

%% ---- 2. Read the single test run ----
T = readtable(dotFile, 'VariableNamingRule', 'preserve');

% Display the column names so you can see what was found
fprintf('\nColumns found in file:\n');
disp(T.Properties.VariableNames');

%% ---- 3. Find the needed columns ----
varNames = string(T.Properties.VariableNames);

% Find time column
timeIdx = find(contains(lower(varNames), "runningtime") | ...
               contains(lower(varNames), "time"), 1);

% Find displacement column
dispIdx = find(contains(lower(varNames), "displacement"), 1);

% Find force column
forceIdx = find(contains(lower(varNames), "force"), 1);

if isempty(timeIdx)
    error('Could not find a time column.');
end

if isempty(dispIdx)
    error('Could not find a displacement column.');
end

if isempty(forceIdx)
    error('Could not find a force column.');
end

fprintf('\nUsing columns:\n');
fprintf('Time:         %s\n', varNames(timeIdx));
fprintf('Displacement: %s\n', varNames(dispIdx));
fprintf('Force:        %s\n', varNames(forceIdx));

%% ---- 4. Extract columns ----
runTime = T{:, timeIdx};
disp_m  = T{:, dispIdx};
force_N = T{:, forceIdx};

%% ---- 5. Clean invalid values ----
good = isfinite(runTime) & isfinite(disp_m) & isfinite(force_N);

runTime = runTime(good);
disp_m  = disp_m(good);
force_N = force_N(good);

% Remove duplicate time values
[runTime, idx] = unique(runTime);
disp_m  = disp_m(idx);
force_N = force_N(idx);

%% ---- 6. Estimate sample rate ----
dt = median(diff(runTime));
fs = 1/dt;

fprintf('\nEstimated sample rate: %.2f Hz\n', fs);

%% ---- 7. Low-pass filter Force (and optionally Displacement) ----
fc = min(cutoffHz, 0.45*fs);

[b, a] = butter(4, fc/(fs/2), 'low');

force_filtered = filtfilt(b, a, force_N);

if filterDisp
    disp_filtered = filtfilt(b, a, disp_m);
else
    disp_filtered = disp_m;
end

%% ---- 8. Plot raw vs filtered Force ----
figure;

plot(runTime, force_N, ...
    'Color',[0.85 0.85 0.85], ...
    'DisplayName','Raw');

hold on;

plot(runTime, force_filtered, ...
    'LineWidth',1.5, ...
    'DisplayName','Filtered');

xlabel('Running Time (s)');
ylabel('Axial Force (N)');
title('Force Raw vs Filtered');

legend('Location','best');
grid on;

%% ---- 9. Save cleaned CSV ----
T_cleaned = table( ...
    runTime, ...
    disp_m, ...
    disp_filtered, ...
    force_N, ...
    force_filtered, ...
    'VariableNames', { ...
    'RunningTime_s', ...
    'Displacement_raw_m', ...
    'Displacement_m', ...
    'Force_raw_N', ...
    'Force_N'});

% Keep the original filename and add "_cleaned"
[~, baseName, ~] = fileparts(dotName);

outName = fullfile(dotFolder, ...
    sprintf('%s_filtered.csv', baseName));

writetable(T_cleaned, outName);

fprintf('\nSaved cleaned data to:\n%s\n', outName);