%% ================================================================
%  clean_DOT_force.m
%  Picks a DOT file, extracts one Test Run, low-pass filters Force
%  (Displacement optional), and saves a cleaned CSV.
% ================================================================

clear; clc; close all;

%% ---- USER SETTINGS ----
cutoffHz      = 5;      % low-pass cutoff for Force. Try 2, 5, or 10 Hz.
filterDisp    = false;  % set true if you also want Displacement smoothed

%% ---- 1. Pick DOT file ----
[dotName, dotFolder] = uigetfile({'*.csv','CSV files (*.csv)'}, ...
    'Select the DOT file (e.g. DOTTireTest.csv)');
if isequal(dotName, 0)
    error('No DOT file selected.');
end
dotFile = fullfile(dotFolder, dotName);

%% ---- 2. Parse DOT file into Test Run blocks ----
fid = fopen(dotFile, 'rt');
raw = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
lines = raw{1};

runStartIdx = [];
runIDs      = [];
for i = 1:numel(lines)
    tok = regexp(lines{i}, '"Test Run: Test Run (\d+)"', 'tokens');
    if ~isempty(tok)
        runStartIdx(end+1) = i; %#ok<AGROW>
        runIDs(end+1)      = str2double(tok{1}{1}); %#ok<AGROW>
    end
end
runStartIdx(end+1) = numel(lines) + 1;

fprintf('Test Runs found in DOT file: %s\n\n', mat2str(runIDs));

%% ---- 3. Ask which Test Run to clean ----
targetRun = input('Which Test Run do you want to clean? ');

blockIdx = find(runIDs == targetRun);
if isempty(blockIdx)
    error('Test Run %d not found.', targetRun);
end
blockStart = runStartIdx(blockIdx);
blockEnd   = runStartIdx(blockIdx+1) - 1;

colHeaderIdx = find(contains(lines(blockStart:blockEnd), 'Axial Displacement'), 1) + blockStart - 1;
dataStartIdx = colHeaderIdx + 2;
dataLines = lines(dataStartIdx:blockEnd);

disp_m = []; force_N = []; runTime = [];
for i = 1:numel(dataLines)
    vals = sscanf(dataLines{i}, '%f,%f,%f');
    if numel(vals) == 3
        disp_m(end+1,1)  = vals(1); %#ok<AGROW>
        force_N(end+1,1) = vals(2); %#ok<AGROW>
        runTime(end+1,1) = vals(3); %#ok<AGROW>
    end
end

%% ---- 4. Estimate sample rate ----
dt = median(diff(runTime));
fs = 1/dt;
fprintf('Estimated sample rate: %.2f Hz\n', fs);

%% ---- 5. Low-pass filter Force (and optionally Displacement) ----
fc = min(cutoffHz, 0.45*fs);
[b, a] = butter(4, fc/(fs/2), 'low');

force_filtered = filtfilt(b, a, force_N);

if filterDisp
    disp_filtered = filtfilt(b, a, disp_m);
else
    disp_filtered = disp_m;  % unchanged
end

%% ---- 6. Plot raw vs filtered Force (sanity check) ----
figure;
plot(runTime, force_N, 'Color',[0.85 0.85 0.85], 'DisplayName','Raw'); hold on;
plot(runTime, force_filtered, 'LineWidth',1.5, 'DisplayName','Filtered');
xlabel('Running Time (s)'); ylabel('Axial Force (N)');
title(sprintf('Force Raw vs Filtered (Test Run %d)', targetRun));
legend('Location','best'); grid on;

%% ---- 7. Save cleaned CSV ----
T = table(runTime, disp_m, disp_filtered, force_N, force_filtered, ...
    'VariableNames', {'RunningTime_s','Displacement_raw_m','Displacement_m', ...
    'Force_raw_N','Force_N'});

outName = fullfile(dotFolder, sprintf('TestRun%d_cleaned.csv', targetRun));
writetable(T, outName);
fprintf('\nSaved cleaned data to:\n%s\n', outName);