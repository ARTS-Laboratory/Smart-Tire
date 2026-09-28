%% clean_SEC_lvm.m
% Reads a LabVIEW .lvm file, cleans spikes/noise, low-pass filters the data,
% plots raw/noisy data in the background and filtered data in front,
% then exports cleaned data to CSV and figures to PNG.

clear; clc; close all;

%% ================= USER SETTINGS =================

channelToPlot = 1;       % Change this if your sensor is on another channel
cutoffHz = 1;            % Low-pass filter cutoff. Try 1, 2, or 5 Hz.
baselineSec = 5;         % First few seconds used as unloaded baseline
outlierWindowSec = 0.5;  % Window for spike removal
outlierFactor = 6;       % Larger = removes fewer spikes, smaller = removes more

%% ================= PICK LVM FILE =================

[fileName, folderName] = uigetfile( ...
    {'*.lvm;*.txt;*.csv;*.*', 'Data files (*.lvm, *.txt, *.csv)'}, ...
    'Select your LVM file');

if isequal(fileName, 0)
    error('No file selected.');
end

filePath = fullfile(folderName, fileName);
[~, baseName, ~] = fileparts(fileName);

fprintf('Reading file:\n%s\n\n', filePath);

%% ================= READ NUMERIC DATA =================

M = readNumericBlockFromLVM(filePath);

if size(M, 2) < 2
    error('Could not find at least two numeric columns in the file.');
end

%% ================= DETECT TIME COLUMN =================

firstCol = M(:,1);
dFirst = diff(firstCol);

isTimeColumn = all(isfinite(firstCol)) && ...
               sum(dFirst > 0) > 0.95 * numel(dFirst) && ...
               (max(firstCol) - min(firstCol)) > 0;

if isTimeColumn
    t = firstCol;
    Yraw = M(:,2:end);
else
    fsManual = input('No time column detected. Enter sensor sample rate in Hz: ');

    if isempty(fsManual) || ~isnumeric(fsManual) || fsManual <= 0
        error('Invalid sample rate.');
    end

    Yraw = M;
    t = (0:size(Yraw,1)-1)' ./ fsManual;
end

% Remove duplicate or invalid time values
goodRows = isfinite(t) & all(isfinite(Yraw), 2);
t = t(goodRows);
Yraw = Yraw(goodRows, :);

[t, uniqueIdx] = unique(t, 'stable');
Yraw = Yraw(uniqueIdx, :);

dtVals = diff(t);
dtVals = dtVals(isfinite(dtVals) & dtVals > 0);

if isempty(dtVals)
    error('Could not determine sample rate from time column.');
end

dt = median(dtVals);
fs = 1 / dt;

nSamples = size(Yraw, 1);
nChannels = size(Yraw, 2);

if channelToPlot > nChannels
    error('channelToPlot is larger than the number of detected channels.');
end

fprintf('Detected sample rate: %.3f Hz\n', fs);
fprintf('Detected %d sensor channel(s)\n', nChannels);
fprintf('Samples: %d\n\n', nSamples);

%% ================= CLEAN + FILTER =================

Yclean = nan(size(Yraw));
Yfilt = nan(size(Yraw));
dC = nan(size(Yraw));

outlierWindow = max(5, round(outlierWindowSec * fs));

for ch = 1:nChannels

    y = Yraw(:,ch);

    % Replace non-finite data with NaN, then interpolate
    y(~isfinite(y)) = NaN;
    y = fillmissing(y, 'linear', 'EndValues', 'nearest');

    % Moving median spike removal
    yMed = movmedian(y, outlierWindow, 'omitnan');
    residual = y - yMed;

    localMAD = movmedian(abs(residual), outlierWindow, 'omitnan');

    globalMAD = median(abs(y - median(y, 'omitnan')), 'omitnan');

    if isnan(globalMAD) || globalMAD == 0
        globalMAD = std(y, 'omitnan');
    end

    if isnan(globalMAD) || globalMAD == 0
        globalMAD = 1;
    end

    localMAD(~isfinite(localMAD) | localMAD == 0) = globalMAD;

    bad = abs(residual) > outlierFactor * 1.4826 .* localMAD;

    yClean = y;
    yClean(bad) = NaN;
    yClean = fillmissing(yClean, 'linear', 'EndValues', 'nearest');

    % Low-pass filtering
    fc = min(cutoffHz, 0.45 * fs);

    if fc <= 0
        error('Invalid cutoff frequency.');
    end

    try
        [b, a] = butter(4, fc / (fs/2), 'low');
        yFiltered = filtfilt(b, a, yClean);
    catch
        warning('Butterworth filter failed. Using moving average instead.');
        smoothWindow = max(5, round(fs / fc));
        yFiltered = movmean(yClean, smoothWindow, 'omitnan');
    end

    % Baseline subtraction
    baselineIdx = t <= (t(1) + baselineSec);

    if sum(baselineIdx) < 5
        baselineIdx = 1:max(5, round(0.05 * nSamples));
    end

    C0 = median(yFiltered(baselineIdx), 'omitnan');

    Yclean(:,ch) = yClean;
    Yfilt(:,ch) = yFiltered;
    dC(:,ch) = yFiltered - C0;
end

%% ================= EXPORT CLEANED CSV =================

outCsv = fullfile(folderName, [baseName '_filtered.csv']);

T = table(t, 'VariableNames', {'time_s'});

for ch = 1:nChannels
    T.(sprintf('C%d_raw_pF', ch)) = Yraw(:,ch);
    T.(sprintf('C%d_clean_pF', ch)) = Yclean(:,ch);
    T.(sprintf('C%d_filtered_pF', ch)) = Yfilt(:,ch);
    T.(sprintf('dC%d_pF', ch)) = dC(:,ch);
end

writetable(T, outCsv);

fprintf('Saved cleaned CSV:\n%s\n\n', outCsv);

%% ================= PLOT RAW VS FILTERED CAPACITANCE =================

ch = channelToPlot;

figure;

% Raw/noisy data (light gray)
plot(t,Yraw(:,ch), ...
    'Color',[0.85 0.85 0.85], ...
    'LineWidth',0.5, ...
    'DisplayName','Raw');

hold on;

% Filtered data (MATLAB blue)
plot(t,Yfilt(:,ch), ...
    'Color',[0 0.4470 0.7410], ...
    'LineWidth',2.5, ...
    'DisplayName','Filtered');

xlabel('Time (s)');
ylabel('Capacitance (pF)');
title(sprintf('Raw and Filtered SEC Capacitance - Channel %d',ch));

legend('Location','best');
grid on;
%% ================= PLOT RAW VS FILTERED DELTA C =================

baselineIdx = t <= (t(1) + baselineSec);

if sum(baselineIdx) < 5
    baselineIdx = 1:max(5,round(0.05*nSamples));
end

C0_raw = median(Yraw(baselineIdx,ch),'omitnan');
dC_raw = Yraw(:,ch)-C0_raw;

figure;

% Raw noisy ΔC
plot(t,dC_raw,...
    'Color',[0.85 0.85 0.85],...
    'LineWidth',0.5,...
    'DisplayName','Raw');

hold on;

% Filtered ΔC
plot(t,dC(:,ch),...
    'Color',[0 0.4470 0.7410],...
    'LineWidth',2.5,...
    'DisplayName','Filtered');

xlabel('Time (s)');
ylabel('\DeltaC (pF)');
title('Filtered Capacitance Change');

legend('Location','best');
grid on;
%% ================= OPTIONAL: PLOT ALL FILTERED CHANNELS =================

figure;

colors = lines(nChannels);

hold on

for ch = 1:nChannels
    plot(t,dC(:,ch),...
        'Color',colors(ch,:),...
        'LineWidth',2);
end

xlabel('Time (s)');
ylabel('\DeltaC (pF)');
title('Filtered Capacitance Change - All Channels');

grid on;

legendLabels = strings(1,nChannels);

for ch = 1:nChannels
    legendLabels(ch)=sprintf('Channel %d',ch);
end

legend(legendLabels,'Location','best');
%% ================= LOCAL FUNCTION =================

function M = readNumericBlockFromLVM(filePath)
    txt = fileread(filePath);
    lines = splitlines(txt);

    numberPattern = '[-+]?(?:\d*\.\d+|\d+\.?)(?:[eEdD][-+]?\d+)?';

    rowVals = {};
    rowLineNumbers = [];
    rowNcols = [];

    for i = 1:numel(lines)
        line = char(lines{i});

        if isempty(strtrim(line))
            continue;
        end

        nums = regexp(line, numberPattern, 'match');

        if numel(nums) < 2
            continue;
        end

        leftover = regexprep(line, numberPattern, '');
        leftover = regexprep(leftover, '[\s\t,;]', '');

        % Skip header rows that contain letters or other non-numeric text
        if ~isempty(strtrim(leftover))
            continue;
        end

        nums = strrep(nums, 'D', 'E');
        nums = strrep(nums, 'd', 'e');
        vals = str2double(nums);

        if all(isfinite(vals))
            rowVals{end+1,1} = vals; %#ok<AGROW>
            rowLineNumbers(end+1,1) = i; %#ok<AGROW>
            rowNcols(end+1,1) = numel(vals); %#ok<AGROW>
        end
    end

    if isempty(rowVals)
        error('No numeric data block found in the file.');
    end

    % Find longest continuous numeric block with the same number of columns
    bestStart = 1;
    bestEnd = 1;
    curStart = 1;

    for k = 2:numel(rowVals)
        sameCols = rowNcols(k) == rowNcols(k-1);
        nearLine = rowLineNumbers(k) - rowLineNumbers(k-1) <= 2;

        if ~(sameCols && nearLine)
            if (k - 1 - curStart) > (bestEnd - bestStart)
                bestStart = curStart;
                bestEnd = k - 1;
            end
            curStart = k;
        end
    end

    if (numel(rowVals) - curStart) > (bestEnd - bestStart)
        bestStart = curStart;
        bestEnd = numel(rowVals);
    end

    nRows = bestEnd - bestStart + 1;

    if nRows < 5
        error('Numeric block found, but it is too short to be real data.');
    end

    nCols = rowNcols(bestStart);
    M = nan(nRows, nCols);

    for r = 1:nRows
        M(r,:) = rowVals{bestStart + r - 1};
    end
end