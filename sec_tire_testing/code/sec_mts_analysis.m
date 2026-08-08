%% ================================================================
%  plot_cap_vs_cleaned.m
%  Plots Capacitance vs Force and Capacitance vs Displacement,
%  using the CLEANED TestRunXX_cleaned.csv files instead of the
%  raw DOT file. No autosave — figures just display.
% ================================================================

clear; clc; close all;

nTests = input('How many tests do you want to plot? ');

for k = 1:nTests

    fprintf('\n--- Test %d of %d ---\n', k, nTests);

    % --- pick cleaned DOT test-run file ---
    [dotCleanName, dotCleanFolder] = uigetfile({'*.csv','CSV files (*.csv)'}, ...
        sprintf('Select cleaned TestRunXX_cleaned.csv for test %d', k));
    if isequal(dotCleanName, 0)
        warning('No file selected, skipping test %d.', k);
        continue;
    end
    dotCleanFile = fullfile(dotCleanFolder, dotCleanName);

    % --- pick capacitance file ---
    [capName, capFolder] = uigetfile({'*.csv','CSV files (*.csv)'}, ...
        sprintf('Select capacitance file for test %d', k));
    if isequal(capName, 0)
        warning('No file selected, skipping test %d.', k);
        continue;
    end
    capFile = fullfile(capFolder, capName);

    targetRun = input('  Test Run number (for plot titles): ');
    t01_start = input('  Capacitance time (s) when MTS turned ON: ');
    t01_end   = input('  Capacitance time (s) when MTS turned OFF: ');

    % --- load cleaned DOT data ---
    dotT = readtable(dotCleanFile);
    runTime = dotT.RunningTime_s;
    force_N = dotT.Force_N;         % cleaned column
    disp_m  = dotT.Displacement_m;  % cleaned column
    disp_m = dotT.Displacement_m * 1000;   % convert m -> mm

    % --- load capacitance data ---
    capT = readtable(capFile);
    cap_time = capT.time_s;
    cap_pF   = capT.C1_filtered_pF;

    % --- two-point linear time alignment ---
    mts_start = min(runTime);
    mts_end   = max(runTime);
    dot_time_aligned = t01_start + (runTime - mts_start) * ...
                        (t01_end - t01_start) / (mts_end - mts_start);

    % --- interpolate capacitance at aligned times ---
    valid = dot_time_aligned >= min(cap_time) & dot_time_aligned <= max(cap_time);
    cap_at_dot = interp1(cap_time, cap_pF, dot_time_aligned(valid), 'linear');
    force_v    = force_N(valid);
    disp_v     = disp_m(valid);

    force_abs = abs(force_v);
    disp_abs  = abs(disp_v);

    % --- Plot 1: Capacitance vs Force ---
    figure;
    plot(force_abs, cap_at_dot, '.', 'MarkerSize', 4);
    xlabel('Axial Force (N)'); ylabel('Capacitance (pF)');
    title(sprintf('Capacitance vs Force, cleaned (Test Run %d)', targetRun));
    grid on;

    % --- Plot 2: Capacitance vs Displacement ---
    figure;
    plot(disp_abs, cap_at_dot, '.', 'MarkerSize', 4);
    xlabel('Axial Displacement (mm)'); ylabel('Capacitance (pF)');
    title(sprintf('Capacitance vs Displacement, cleaned (Test Run %d)', targetRun));
    grid on;
end


%% ================================================================
%  plot_dualaxis_cap_force_vs_disp.m
%  X-axis: Displacement (mm)
%  Left Y-axis: Capacitance (pF)
%  Right Y-axis: Force (N)
%  Uses cleaned TestRunXX_cleaned.csv + matching capacitance file.
% ================================================================

clear; clc; close all;

nTests = input('How many tests do you want to plot? ');

for k = 1:nTests

    fprintf('\n--- Test %d of %d ---\n', k, nTests);

    % --- pick cleaned DOT test-run file ---
    [dotCleanName, dotCleanFolder] = uigetfile({'*.csv','CSV files (*.csv)'}, ...
        sprintf('Select cleaned TestRunXX_cleaned.csv for test %d', k));
    if isequal(dotCleanName, 0)
        warning('No file selected, skipping test %d.', k);
        continue;
    end
    dotCleanFile = fullfile(dotCleanFolder, dotCleanName);

    % --- pick capacitance file ---
    [capName, capFolder] = uigetfile({'*.csv','CSV files (*.csv)'}, ...
        sprintf('Select capacitance file for test %d', k));
    if isequal(capName, 0)
        warning('No file selected, skipping test %d.', k);
        continue;
    end
    capFile = fullfile(capFolder, capName);

    targetRun = input('  Test Run number (for plot title): ');
    t01_start = input('  Capacitance time (s) when MTS turned ON: ');
    t01_end   = input('  Capacitance time (s) when MTS turned OFF: ');

    % --- load cleaned DOT data ---
    dotT = readtable(dotCleanFile);
    runTime = dotT.RunningTime_s;
    force_N = dotT.Force_N;
    disp_mm = dotT.Displacement_m * 1000;   % m -> mm

    % --- load capacitance data ---
    capT = readtable(capFile);
    cap_time = capT.time_s;
    cap_pF   = capT.C1_filtered_pF;

    % --- two-point linear time alignment ---
    mts_start = min(runTime);
    mts_end   = max(runTime);
    dot_time_aligned = t01_start + (runTime - mts_start) * ...
        (t01_end - t01_start) / (mts_end - mts_start);

    % --- interpolate capacitance at aligned times ---
    valid = dot_time_aligned >= min(cap_time) & dot_time_aligned <= max(cap_time);
    cap_at_dot = interp1(cap_time, cap_pF, dot_time_aligned(valid), 'linear');
    force_v    = abs(force_N(valid));
    disp_v     = abs(disp_mm(valid));

    % --- sort by displacement so lines look clean, not zig-zagged ---
    [disp_sorted, sortIdx] = sort(disp_v);
    cap_sorted   = cap_at_dot(sortIdx);
    force_sorted = force_v(sortIdx);

%% ---- Dual-axis plot ----
    figure;
    yyaxis left
    plot(disp_sorted, cap_sorted, '-', 'LineWidth', 1.5, 'DisplayName', 'Capacitance');
    ylabel('Capacitance (pF)');

    yyaxis right
    plot(disp_sorted, force_sorted, '-', 'LineWidth', 1.5, 'Color', [0.6 0 0], 'DisplayName', 'Force');
    ylabel('Axial Force (N)');
    ax = gca;
    ax.YAxis(2).Color = [0.6 0 0];

    xlabel('Axial Displacement (mm)');
    title(sprintf('Capacitance & Force vs Displacement (Test Run %d)', targetRun));
    legend('Location','best');
    grid on;
end