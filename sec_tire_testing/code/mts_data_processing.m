%% ================================================================
%  mts_data_processing.m
%
%  Reads an MTS CSV containing MULTIPLE Test Runs.
%  Finds all available Test Runs, asks which one to process,
%  extracts that run, low-pass filters Force
%  (Displacement optional), and saves an individual filtered CSV.
% ================================================================

clear; clc; close all;

%% ---- USER SETTINGS ----
cutoffHz   = 5;      % low-pass cutoff for Force (Hz)
filterDisp = false;  % true = also filter displacement


%% ================================================================
%  1. PICK MULTI-RUN MTS FILE
% ================================================================

[dotName, dotFolder] = uigetfile( ...
    {'*.csv','CSV files (*.csv)'}, ...
    'Select the MTS CSV containing all Test Runs');

if isequal(dotName, 0)
    error('No MTS file selected.');
end

dotFile = fullfile(dotFolder, dotName);


%% ================================================================
%  2. READ FILE AS TEXT
% ================================================================

fid = fopen(dotFile, 'rt');

if fid == -1
    error('Could not open selected MTS file.');
end

raw = textscan( ...
    fid, ...
    '%s', ...
    'Delimiter', '\n', ...
    'Whitespace', '');

fclose(fid);

lines = raw{1};


%% ================================================================
%  3. FIND ALL TEST RUNS
% ================================================================

runStartIdx = [];
runIDs      = [];

for i = 1:numel(lines)

    % Looks for lines such as:
    % "Test Run: Test Run 25"

    tok = regexp( ...
        lines{i}, ...
        '"?Test Run:\s*Test Run\s*(\d+)"?', ...
        'tokens');

    if ~isempty(tok)

        runStartIdx(end+1) = i; %#ok<AGROW>

        runIDs(end+1) = ...
            str2double(tok{1}{1}); %#ok<AGROW>

    end

end


%% ---- Make sure runs were found ----

if isempty(runIDs)

    error([ ...
        'No Test Run blocks were found in the selected file. ' ...
        'Check that this is the original multi-run MTS CSV.']);

end


% Add final boundary so the last Test Run can be extracted
runStartIdx(end+1) = numel(lines) + 1;


%% ---- Display available Test Runs ----

fprintf('\n========================================\n');
fprintf('Test Runs found in MTS file:\n');
fprintf('========================================\n');

fprintf('%d ', runIDs);

fprintf('\n========================================\n\n');


%% ================================================================
%  4. ASK WHICH TEST RUN TO PROCESS
% ================================================================

targetRun = input('Which Test Run do you want to process? ');


blockIdx = find(runIDs == targetRun, 1);


if isempty(blockIdx)

    error( ...
        'Test Run %d was not found in the selected MTS file.', ...
        targetRun);

end


%% ---- Determine beginning/end of selected block ----

blockStart = runStartIdx(blockIdx);

blockEnd = runStartIdx(blockIdx + 1) - 1;


fprintf('\nProcessing Test Run %d...\n', targetRun);


%% ================================================================
%  5. FIND COLUMN HEADER INSIDE SELECTED RUN
% ================================================================

selectedBlock = lines(blockStart:blockEnd);


% Find row containing Axial Displacement
headerRelativeIdx = find( ...
    contains(selectedBlock, 'Axial Displacement'), ...
    1);


if isempty(headerRelativeIdx)

    error( ...
        'Could not find the data header for Test Run %d.', ...
        targetRun);

end


colHeaderIdx = ...
    blockStart + headerRelativeIdx - 1;


%% ================================================================
%  6. READ NUMERIC DATA FROM SELECTED RUN
% ================================================================

disp_m  = [];
force_N = [];
runTime = [];


% Start searching immediately after the header.
% Non-numeric/unit rows are automatically ignored.
dataLines = lines(colHeaderIdx + 1:blockEnd);


for i = 1:numel(dataLines)

    % Expected MTS columns:
    %
    % Axial Displacement,
    % Axial Force,
    % Running Time

    vals = sscanf( ...
        strrep(dataLines{i}, '"', ''), ...
        '%f,%f,%f');


    if numel(vals) == 3

        disp_m(end+1,1) = vals(1); %#ok<AGROW>

        force_N(end+1,1) = vals(2); %#ok<AGROW>

        runTime(end+1,1) = vals(3); %#ok<AGROW>

    end

end


%% ---- Make sure data were extracted ----

if isempty(runTime)

    error( ...
        'No numeric data were extracted from Test Run %d.', ...
        targetRun);

end


fprintf('Extracted %d samples.\n', length(runTime));


%% ================================================================
%  7. CLEAN INVALID VALUES
% ================================================================

good = ...
    isfinite(runTime) & ...
    isfinite(disp_m) & ...
    isfinite(force_N);


runTime = runTime(good);

disp_m = disp_m(good);

force_N = force_N(good);


%% ---- Sort BY TIME ----

[runTime, sortIdx] = sort(runTime);

disp_m = disp_m(sortIdx);

force_N = force_N(sortIdx);


%% ---- Remove duplicate timestamps ----

[runTime, uniqueIdx] = unique( ...
    runTime, ...
    'stable');


disp_m = disp_m(uniqueIdx);

force_N = force_N(uniqueIdx);


%% ---- Check data length ----

if numel(runTime) < 10

    error( ...
        'Too few valid samples were found in Test Run %d.', ...
        targetRun);

end


%% ================================================================
%  8. ESTIMATE SAMPLE RATE
% ================================================================

dtValues = diff(runTime);


% Keep only valid positive time steps
dtValues = dtValues( ...
    isfinite(dtValues) & ...
    dtValues > 0);


if isempty(dtValues)

    error('Could not determine the MTS sampling interval.');

end


dt = median(dtValues);

fs = 1 / dt;


fprintf('Estimated sample rate: %.2f Hz\n', fs);


%% ================================================================
%  9. LOW-PASS FILTER
% ================================================================

fc = min( ...
    cutoffHz, ...
    0.45 * fs);


if fc <= 0

    error('Invalid filter cutoff frequency.');

end


[b, a] = butter( ...
    4, ...
    fc / (fs/2), ...
    'low');


%% ---- Filter Force ----

force_filtered = filtfilt( ...
    b, ...
    a, ...
    force_N);


%% ---- Optionally filter Displacement ----

if filterDisp

    disp_filtered = filtfilt( ...
        b, ...
        a, ...
        disp_m);

else

    disp_filtered = disp_m;

end


%% ================================================================
%  10. PLOT RAW VS FILTERED FORCE
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

title(sprintf( ...
    'Force Raw vs Filtered - Test Run %d', ...
    targetRun));


legend('Location','best');

grid on;


%% ================================================================
%  11. CREATE OUTPUT TABLE
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
%  12. SAVE INDIVIDUAL FILTERED TEST RUN
% ================================================================

outName = fullfile( ...
    dotFolder, ...
    sprintf( ...
        'TestRun_%02d_filtered.csv', ...
        targetRun));


writetable( ...
    T_cleaned, ...
    outName);


%% ================================================================
%  FINISHED
% ================================================================

fprintf('\n========================================\n');

fprintf( ...
    'Test Run %d successfully processed.\n', ...
    targetRun);

fprintf( ...
    'Saved filtered data to:\n%s\n', ...
    outName);

fprintf('========================================\n');