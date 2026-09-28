%% ================================================================
%  SEC_MTS_Time_Comparison.m
%
%  Compares SEC capacitance with MTS force and displacement
%  using TIME as the common x-axis.
%
%  Creates:
%    Figure 1: Capacitance + Force vs Time
%    Figure 2: Capacitance + Displacement vs Time
%
%  Designed for cyclic MTS testing.
%
%  Inputs:
%    - Cleaned/filtered MTS CSV
%    - Processed/filtered SEC capacitance CSV
%
%  Figures are DISPLAYED ONLY and are NOT automatically saved.
% ================================================================

clear;
clc;
close all;


%% ================================================================
%  1. PICK CLEANED MTS FILE
% ================================================================

[mtsName, mtsFolder] = uigetfile( ...
    {'*.csv','CSV files (*.csv)'}, ...
    'Select cleaned MTS CSV file');

if isequal(mtsName,0)
    error('No MTS file selected.');
end

mtsFile = fullfile(mtsFolder,mtsName);


%% ================================================================
%  2. PICK PROCESSED SEC CAPACITANCE FILE
% ================================================================

[capName,capFolder] = uigetfile( ...
    {'*.csv','CSV files (*.csv)'}, ...
    'Select processed SEC capacitance CSV file');

if isequal(capName,0)
    error('No capacitance file selected.');
end

capFile = fullfile(capFolder,capName);


%% ================================================================
%  3. USER INPUT FOR TIME ALIGNMENT
% ================================================================

targetRun = input( ...
    'Test Run number (for plot titles): ');

t01_start = input( ...
    'Capacitance time (s) when MTS turned ON: ');

t01_end = input( ...
    'Capacitance time (s) when MTS turned OFF: ');


%% ================================================================
%  4. LOAD MTS DATA
% ================================================================

mtsT = readtable( ...
    mtsFile, ...
    'VariableNamingRule','preserve');

mtsNames = string(mtsT.Properties.VariableNames);

fprintf('\nMTS columns found:\n');
disp(mtsNames');


%% ---- Find MTS time column ----

timeIdx = find( ...
    contains(lower(mtsNames),'runningtime') | ...
    contains(lower(mtsNames),'running time') | ...
    contains(lower(mtsNames),'time'), ...
    1);


%% ---- Find MTS displacement column ----

dispIdx = find( ...
    contains(lower(mtsNames),'displacement'), ...
    1);


%% ---- Find MTS force column ----

forceIdx = find( ...
    contains(lower(mtsNames),'force'), ...
    1);


%% ---- Check columns ----

if isempty(timeIdx)
    error('Could not find MTS time column.');
end

if isempty(dispIdx)
    error('Could not find MTS displacement column.');
end

if isempty(forceIdx)
    error('Could not find MTS force column.');
end


fprintf('\nUsing MTS columns:\n');

fprintf('  Time:         %s\n', mtsNames(timeIdx));
fprintf('  Displacement: %s\n', mtsNames(dispIdx));
fprintf('  Force:        %s\n', mtsNames(forceIdx));


%% ---- Extract MTS data ----

runTime = mtsT{:,timeIdx};

disp_m = mtsT{:,dispIdx};

force_N = mtsT{:,forceIdx};


%% ---- Convert displacement to mm ----

disp_mm = disp_m * 1000;


%% ================================================================
%  5. CLEAN MTS DATA
% ================================================================

goodMTS = ...
    isfinite(runTime) & ...
    isfinite(disp_mm) & ...
    isfinite(force_N);

runTime = runTime(goodMTS);
disp_mm = disp_mm(goodMTS);
force_N = force_N(goodMTS);


%% ---- Sort by time ----

[runTime,mtsSortIdx] = sort(runTime);

disp_mm = disp_mm(mtsSortIdx);
force_N = force_N(mtsSortIdx);


%% ---- Remove duplicate timestamps ----

[runTime,mtsUniqueIdx] = unique( ...
    runTime, ...
    'stable');

disp_mm = disp_mm(mtsUniqueIdx);
force_N = force_N(mtsUniqueIdx);


%% ================================================================
%  6. LOAD SEC CAPACITANCE DATA
% ================================================================

capT = readtable( ...
    capFile, ...
    'VariableNamingRule','preserve');

capNames = string(capT.Properties.VariableNames);

fprintf('\nSEC columns found:\n');
disp(capNames');


%% ---- Find SEC time column ----

capTimeIdx = find( ...
    contains(lower(capNames),'time'), ...
    1);


%% ---- Find filtered capacitance column ----

% First preference: C1_filtered
capIdx = find( ...
    contains(lower(capNames),'c1_filtered') | ...
    contains(lower(capNames),'c1 filtered'), ...
    1);


% Second preference: any filtered column
if isempty(capIdx)

    capIdx = find( ...
        contains(lower(capNames),'filtered'), ...
        1);

end


% Third preference: any capacitance column
if isempty(capIdx)

    capIdx = find( ...
        contains(lower(capNames),'capacitance'), ...
        1);

end


%% ---- Check SEC columns ----

if isempty(capTimeIdx)
    error('Could not find SEC time column.');
end

if isempty(capIdx)
    error('Could not find filtered capacitance column.');
end


fprintf('\nUsing SEC columns:\n');

fprintf('  Time:        %s\n', capNames(capTimeIdx));
fprintf('  Capacitance: %s\n', capNames(capIdx));


%% ---- Extract SEC data ----

cap_time = capT{:,capTimeIdx};

cap_pF = capT{:,capIdx};


%% ================================================================
%  7. CLEAN SEC DATA
% ================================================================

goodCap = ...
    isfinite(cap_time) & ...
    isfinite(cap_pF);

cap_time = cap_time(goodCap);
cap_pF = cap_pF(goodCap);


%% ---- Sort SEC data by time ----

[cap_time,capSortIdx] = sort(cap_time);

cap_pF = cap_pF(capSortIdx);


%% ---- Remove duplicate SEC timestamps ----

[cap_time,capUniqueIdx] = unique( ...
    cap_time, ...
    'stable');

cap_pF = cap_pF(capUniqueIdx);


%% ================================================================
%  8. ALIGN MTS TIME WITH SEC TIME
% ================================================================

mts_start = min(runTime);
mts_end   = max(runTime);


if mts_end == mts_start
    error('MTS data has zero time duration.');
end


% Maps:
%
% beginning of MTS test -> t01_start in SEC recording
% end of MTS test       -> t01_end in SEC recording

mts_time_in_sec = ...
    t01_start + ...
    (runTime - mts_start) .* ...
    (t01_end - t01_start) ./ ...
    (mts_end - mts_start);


%% ================================================================
%  9. FIND OVERLAPPING DATA
% ================================================================

valid = ...
    mts_time_in_sec >= min(cap_time) & ...
    mts_time_in_sec <= max(cap_time);


if ~any(valid)

    error([ ...
        'No overlap exists between MTS and SEC data. ' ...
        'Check t01_start and t01_end.']);

end


%% ================================================================
%  10. INTERPOLATE SEC CAPACITANCE AT MTS TIMES
% ================================================================

cap_at_mts = interp1( ...
    cap_time, ...
    cap_pF, ...
    mts_time_in_sec(valid), ...
    'linear');


%% ---- Matching MTS values ----

time_plot = runTime(valid);

force_plot = abs(force_N(valid));

disp_plot = abs(disp_mm(valid));


%% ================================================================
%  IMPORTANT:
%  Reset time so the MTS test begins at t = 0 s.
% ================================================================

time_plot = time_plot - time_plot(1);


%% ================================================================
%  11. FIGURE 1
%      CAPACITANCE + FORCE VS TIME
% ================================================================

figure;


%% ---- Left Y-axis: Capacitance ----

yyaxis left

plot( ...
    time_plot, ...
    cap_at_mts, ...
    '-', ...
    'LineWidth',1.5, ...
    'DisplayName','Capacitance');

ylabel('Capacitance (pF)');


%% ---- Right Y-axis: Force ----

yyaxis right

plot( ...
    time_plot, ...
    force_plot, ...
    '-', ...
    'LineWidth',1.5, ...
    'Color',[0.6 0 0], ...
    'DisplayName','Force');

ylabel('Axial Force (N)');


%% ---- Make right axis red ----

ax = gca;

ax.YAxis(2).Color = [0.6 0 0];


%% ---- Labels ----

xlabel('Time (s)');

title(sprintf( ...
    'Capacitance & Force vs Time - Test Run %d', ...
    targetRun));

legend('Location','best');

grid on;


%% ================================================================
%  12. FIGURE 2
%      CAPACITANCE + DISPLACEMENT VS TIME
% ================================================================

figure;


%% ---- Left Y-axis: Capacitance ----

yyaxis left

plot( ...
    time_plot, ...
    cap_at_mts, ...
    '-', ...
    'LineWidth',1.5, ...
    'DisplayName','Capacitance');

ylabel('Capacitance (pF)');


%% ---- Right Y-axis: Displacement ----

yyaxis right

plot( ...
    time_plot, ...
    disp_plot, ...
    '-', ...
    'LineWidth',1.5, ...
    'Color',[0.6 0 0], ...
    'DisplayName','Displacement');

ylabel('Axial Displacement (mm)');


%% ---- Make right axis red ----

ax = gca;

ax.YAxis(2).Color = [0.6 0 0];


%% ---- Labels ----

xlabel('Time (s)');

title(sprintf( ...
    'Capacitance & Displacement vs Time - Test Run %d', ...
    targetRun));

legend('Location','best');

grid on;


%% ================================================================
%  FINISHED
% ================================================================

fprintf('\nFinished.\n');
fprintf('Generated:\n');
fprintf('  1. Capacitance + Force vs Time\n');
fprintf('  2. Capacitance + Displacement vs Time\n');