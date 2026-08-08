%% ================================================================
%  cable_lvm_batch_analysis.m
%  Pick as many LVM/CSV files as you want (Cancel when done).
%  For each: parse -> clean -> filter -> plot raw/filtered/FFT.
%  Then overlay all FFTs for comparison (log scale, capped at 5 Hz).
% ================================================================

clear; clc; close all;

%% ---- USER SETTINGS ----
cutoffHz    = 5;    % low-pass cutoff (Hz)
maxFreqPlot = 5;    % Hz — x-axis limit for FFT plots

%% ---- 1. Pick files (loop until Cancel) ----
filePaths = {};
fileLabels = {};

fprintf('Select your files one at a time. Click Cancel when done.\n');

while true
    [fName, fFolder] = uigetfile({'*.lvm;*.txt;*.csv','Data files (*.lvm, *.txt, *.csv)'}, ...
        sprintf('Select file #%d (or Cancel to finish)', numel(filePaths)+1));
    if isequal(fName, 0)
        break;
    end
    filePaths{end+1}  = fullfile(fFolder, fName); %#ok<AGROW>
    [~, baseName, ~]  = fileparts(fName);
    fileLabels{end+1} = baseName; %#ok<AGROW>
end

nFiles = numel(filePaths);
if nFiles == 0
    error('No files selected.');
end
fprintf('\n%d file(s) selected.\n', nFiles);

%% ---- 2. Process each file ----
results = struct('label',{},'f',{},'P1',{});   % starts truly empty, grows only on success
resIdx = 0;

for k = 1:nFiles

    fprintf('\n--- Processing %s ---\n', fileLabels{k});
    filename = filePaths{k};

    % --- read file as text ---
    fid = fopen(filename,'r');
    if fid == -1
        warning('Cannot open %s, skipping.', filename);
        continue;
    end
    rawLines = textscan(fid,'%s','Delimiter','\n','Whitespace','');
    fclose(fid);
    rawLines = rawLines{1};

    % --- replace commas with spaces so both CSV and tab/space files parse ---
    rawLines = strrep(rawLines, ',', ' ');

    % --- find where numeric data starts ---
    startRow = [];
    for i = 1:length(rawLines)
        nums = sscanf(rawLines{i},'%f');
        if numel(nums) >= 2
            startRow = i;
            break;
        end
    end
    if isempty(startRow)
        warning('No numeric data found in %s, skipping.', filename);
        continue;
    end

    % --- convert numeric lines into matrix ---
    data = [];
    for i = startRow:length(rawLines)
        row = sscanf(rawLines{i},'%f')';
        if numel(row) >= 2
            data = [data; row(1:2)]; %#ok<AGROW>  % keep only first 2 cols in case of ragged rows
        end
    end

    if size(data,1) < 5
        warning('Not enough valid numeric rows in %s, skipping.', filename);
        continue;
    end

    % --- extract columns ---
    t = data(:,1);
    C = data(:,2);      % change if capacitance is a different column

    % --- clean ---
    good = ~(isnan(t)|isnan(C));
    t = t(good);
    C = C(good);
    [t, idx] = unique(t);
    C = C(idx);
    C = C - mean(C);

    if numel(t) < 10
        warning('Too few points after cleaning in %s, skipping.', filename);
        continue;
    end

    % --- sampling frequency ---
    Fs = 1/mean(diff(t));

    % --- Butterworth low-pass filter ---
    [b, a] = butter(4, cutoffHz/(Fs/2), 'low');
    Cf = filtfilt(b, a, C);

    % --- FFT ---
    N = length(Cf);
    Y = fft(Cf);
    P2 = abs(Y/N);
    P1 = P2(1:floor(N/2)+1);
    P1(2:end-1) = 2*P1(2:end-1);
    f = Fs*(0:floor(N/2))/N;

    % --- store for comparison plot (only successful files) ---
    resIdx = resIdx + 1;
    results(resIdx).label = fileLabels{k};
    results(resIdx).f = f;
    results(resIdx).P1 = P1;

    % --- Plot: raw vs filtered ---
    figure;
    plot(t, C, 'Color',[0.7 0.7 0.7], 'DisplayName','Raw'); hold on;
    plot(t, Cf, 'LineWidth',1.5, 'DisplayName','Filtered');
    xlabel('Time (s)'); ylabel('C (pF)');
    title(sprintf('%s — Raw vs Filtered', fileLabels{k}), 'Interpreter','none');
    legend('Location','best'); grid on;

    % --- Plot: individual FFT (log scale) ---
    figure;
    semilogy(f, P1, 'k', 'LineWidth', 1.2);
    xlabel('Frequency (Hz)'); ylabel('Amplitude');
    title(sprintf('%s — FFT', fileLabels{k}), 'Interpreter','none');
    grid on;
    xlim([0, maxFreqPlot]);
end

%% ---- 3. Overlaid FFT comparison (only successfully-processed files) ----
nProcessed = numel(results);
if nProcessed == 0
    warning('No files were successfully processed — nothing to compare.');
else
    figure; hold on;
    ax = gca;
    ax.YScale = 'log';   % force log scale (belt-and-suspenders vs semilogy)
    colors = lines(nProcessed);   % MATLAB's built-in colormap function
    for k = 1:nProcessed
        plot(results(k).f, results(k).P1, 'LineWidth', 1.2, ...
            'Color', colors(k,:), 'DisplayName', results(k).label);
    end
    xlabel('Frequency (Hz)'); ylabel('Amplitude');
    title('FFT Comparison — All Files');
    legend('Location','best', 'Interpreter','none');
    grid on;
    xlim([0, maxFreqPlot]);
end

fprintf('\n%d of %d files successfully processed.\n', nProcessed, nFiles);