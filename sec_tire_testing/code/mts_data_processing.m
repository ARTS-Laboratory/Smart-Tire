
%% ================================================================
%  MTS_Data_Filtering.m
%
%  Reads an MTS CSV containing ONE complete test run.
%  Cleans the data, low-pass filters Force
%  (Displacement optional), and saves a filtered CSV.
%
%  No Test Run selection or time-range input required.
% ================================================================

clear; clc; close all;

%% ---- USER SETTINGS ----
cutoffHz   = 5;      % Low-pass cutoff for Force (Hz)
filterDisp = false;  % true = also filter Displacement


%% ================================================================
%  1. PICK MTS FILE
% ================================================================

[mtsName, mtsFolder] = uigetfile( ...
    {'*.csv','CSV files (*.csv)'}, ...
    'Select the MTS CSV file');

if isequal(mtsName, 0)
    error('No MTS file selected.');
end

mtsFile = fullfile(mtsFolder, mtsName);


%% ================================================================
%  2. READ MTS FILE
% ================================================================

fid = fopen(mtsFile, 'rt');

if fid == -1
    error('Could not open selected MTS file.');
end

raw = textscan(fid, '%s', ...
    'Delimiter', '\n', ...
    'Whitespace', '');

fclose(fid);

lines = raw{1};


%% ================================================================
%  3. FIND DATA HEADER
% ================================================================

% Expected MTS columns:
%
% Axial Displacement, Axial Force, Running Time
% m, N, sec

headerIdx = find( ...
    contains(lines, 'Axial Displacement') & ...
    contains(lines, 'Axial Force') & ...
    contains(lines, 'Running Time'), 1);

if isempty(headerIdx)
    error('Could not find the MTS data header.');
end


%% ================================================================
%  4. EXTRACT NUMERIC DATA
% ================================================================

disp_m  = [];
force_N = [];
runTime = [];

% Start immediately after the header.
% Unit rows and nonnumeric rows are ignored.

dataLines = lines(headerIdx + 1:end);

for i = 1:numel(dataLines)

    vals = sscanf( ...
        strrep(dataLines{i}, '"', ''), ...
        '%f,%f,%f');

    if numel(vals) == 3

        disp_m(end+1,1)  = vals(1); %#ok<AGROW>
        force_N(end+1,1) = vals(2); %#ok<AGROW>
        runTime(end+1,1) = vals(3); %#ok<AGROW>

    end
end

if isempty(runTime)
    error('No numeric MTS data were extracted.');
end

fprintf('\nExtracted %d samples.\n', numel(runTime));


%% ================================================================
%  5. CLEAN INVALID VALUES
% ================================================================

good = ...
    isfinite(runTime) & ...
    isfinite(disp_m) & ...
    isfinite(force_N);

runTime = runTime(good);
disp_m  = disp_m(good);
force_N = force_N(good);


%% ---- Sort by time ----

[runTime, sortIdx] = sort(runTime);

disp_m  = disp_m(sortIdx);
force_N = force_N(sortIdx);


%% ---- Remove duplicate timestamps ----

[runTime, uniqueIdx] = unique(runTime, 'stable');

disp_m  = disp_m(uniqueIdx);
force_N = force_N(uniqueIdx);


%% ================================================================
%  6. VALIDATE COMPLETE TEST
% ================================================================

if numel(runTime) < 20
    error('Too few valid samples in the MTS file.');
end

fprintf('\nUsing entire MTS test.\n');
fprintf('Start time: %.3f s\n', min(runTime));
fprintf('End time:   %.3f s\n', max(runTime));
fprintf('Duration:   %.3f s\n', max(runTime) - min(runTime));
fprintf('Total samples: %d\n', numel(runTime));


%% ================================================================
%  7. ESTIMATE SAMPLE RATE
% ================================================================

dtValues = diff(runTime);

dtValues = dtValues( ...
    isfinite(dtValues) & dtValues > 0);

if isempty(dtValues)
    error('Could not determine the sampling interval.');
end

dt = median(dtValues);
fs = 1 / dt;

fprintf('Estimated sample rate: %.2f Hz\n', fs);


%% ================================================================
%  8. LOW-PASS FILTER
% ================================================================

fc = min(cutoffHz, 0.45 * fs);

if fc <= 0
    error('Invalid filter cutoff frequency.');
end

[b, a] = butter(4, fc/(fs/2), 'low');


%% ---- Filter Force ----

force_filtered = filtfilt(b, a, force_N);


%% ---- Optionally filter Displacement ----

if filterDisp

    disp_filtered = filtfilt(b, a, disp_m);

else

    disp_filtered = disp_m;

end


%% ================================================================
%  9. PLOT RAW VS FILTERED FORCE
% ================================================================

figure;

plot( ...
    runTime, ...
    force_N, ...
    'Color', [0.85 0.85 0.85], ...
    'DisplayName', 'Raw');

hold on;

plot( ...
    runTime, ...
    force_filtered, ...
    'LineWidth', 1.5, ...
    'DisplayName', 'Filtered');

xlabel('Running Time (s)');
ylabel('Axial Force (N)');
title('Force Raw vs Filtered');

legend('Location', 'best');
grid on;


%% ================================================================
%  10. CREATE OUTPUT TABLE
% ================================================================

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


%% ================================================================
%  11. SAVE FILTERED DATA
% ================================================================

%% ---- Extract test number from original filename ----
[~, baseName, ~] = fileparts(mtsName);

token = regexp(baseName, 'trial_(\d+)', 'tokens', 'once', 'ignorecase');

if isempty(token)
    error('Could not identify the trial number from the filename.');
end

testNumber = str2double(token{1});

%% ---- Create standardized output filename ----
outName = fullfile( ...
    mtsFolder, ...
    sprintf('MTS_Test_%02d_filtered.csv', testNumber));

% Prevent accidental overwriting
if isfile(outName)
    error(['Output file already exists: %s\n' ...
           'Rename or move the existing file before rerunning.'], ...
           outName);
end

writetable(T_cleaned, outName);


%% ================================================================
%  FINISHED
% ================================================================

fprintf('\n========================================\n');
fprintf('MTS data successfully processed.\n');
fprintf('Saved filtered data to:\n%s\n', outName);
fprintf('========================================\n');
