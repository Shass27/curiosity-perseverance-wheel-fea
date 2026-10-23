% Tier 1: FEA path stress vs analytical model across multiple mesh sizes
% Run path_stress_analytical.m first to generate output/analytical.mat.
% Units: mm, MPa.
clear; clc; close all;

% ---- parameters ----
base_fea_dir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'Simulation results', 'Tier 1');
base_out_dir = fullfile(fileparts(mfilename('fullpath')), 'output');
mat_file     = fullfile(base_out_dir, 'analytical.mat');

if ~exist(mat_file, 'file')
    error('analytical.mat not found: run path_stress_analytical.m first');
end
A = load(mat_file);
if ~isfield(A, 'P')
    error('analytical.mat has no P: re-run path_stress_analytical.m');
end

mesh_folders = {'10mm_meshing' , '1mm_meshing', '0.1mm_meshing'};
win_j        = 15;        % junction window
win_c        = 10;        % centre window
sigma_fail   = 106;       % failure line (MPa)
P_fea        = 300;       % load FEA was solved at
shade        = 0.6;       % analytical colour shade

scale = A.P / P_fea;
fprintf('Scaling FEA stresses from %g N to %g N (x%.4f)\n', P_fea, A.P, scale);

% ---- pre-allocate multi-mesh peak matrices ----
num_radii = numel(A.a_list);
fj_matrix = zeros(num_radii, numel(mesh_folders));
fc_matrix = zeros(num_radii, numel(mesh_folders));

% ---- loop over mesh directories ----
for m = 1:numel(mesh_folders)
    mesh_name = mesh_folders{m};
    fea_dir   = fullfile(base_fea_dir, mesh_name);
    out_dir   = fullfile(base_out_dir, mesh_name);
    
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    if ~exist(fea_dir, 'dir')
        warning('Mesh directory not found: %s. Skipping.', fea_dir);
        continue;
    end
    
    fprintf('\n--- Processing mesh: %s ---\n', mesh_name);

    % ---- read FEA path files (a=<radius>.xls) ----
    files = dir(fullfile(fea_dir, 'a=*.xls'));
    if isempty(files)
        warning('No a=*.xls files found in %s', fea_dir);
        continue;
    end
    
    a_fea = arrayfun(@(f) sscanf(f.name, 'a=%f'), files);
    [a_fea, order] = sort(a_fea);
    files = files(order);
    
    fea = struct('S', {}, 'total', {});
    for i = 1:numel(files)
        d = readmatrix(fullfile(files(i).folder, files(i).name), 'FileType', 'text', 'Delimiter', '\t', 'NumHeaderLines', 15);
        fea(i).S = d(:,1);
        fea(i).total = d(:,9) * scale;
    end
    assert(isequal(a_fea(:), A.a_list(:)), 'FEA radii in %s do not match analytical a_list', mesh_name);

    S_end   = fea(1).S(end);
    x_shift = (S_end - A.L_tot) / 2;
    xa      = A.x + x_shift;
    xj      = A.x_j + x_shift;
    cols    = lines(numel(a_fea));

    % ---- FEA peaks and calibration ----
    n = numel(a_fea);
    fj = zeros(n,1); fc = zeros(n,1);
    for i = 1:n
        S = fea(i).S; s = fea(i).total;
        fj(i) = max(s(S < win_j | S > S_end - win_j));
        fc(i) = max(s(abs(S - S_end/2) <= win_c));
    end
    
    % Store into multi-mesh matrices
    fj_matrix(:, m) = fj;
    fc_matrix(:, m) = fc;

    aj = A.T.sigma_vm_max_junction_MPa;
    ac = A.T.sigma_vm_centre_MPa;
    C = table(a_fea, fj, aj, fj ./ aj, fc, ac, fc ./ ac, 'VariableNames', ...
        {'a_mm', 'fea_junction_MPa', 'analytical_junction_MPa', 'C_junction', ...
         'fea_centre_MPa', 'analytical_centre_MPa', 'C_centre'});
    disp(C);
    writetable(C, fullfile(out_dir, 'fea_vs_analytical.csv'));

    % ---- FEA Fig 1: Total along path for every a ----
    figure('Name', ['FEA path stress - ' mesh_name]); hold on; grid on;
    for i = 1:n
        plot(fea(i).S, fea(i).total, '.-', 'Color', cols(i,:), 'LineWidth', 1.4, 'MarkerSize', 10, ...
            'DisplayName', sprintf('a = %g mm', a_fea(i)));
    end
    yline(sigma_fail, ':', sprintf('Failure (%g MPa)', sigma_fail), 'Color', 'r', 'LineWidth', 1.5, 'DisplayName', sprintf('Failure (%g MPa)', sigma_fail));
    xlabel('Path length S [mm]'); ylabel('\sigma_{vm} [MPa]');
    title(sprintf('FEA \\sigma_{vm} along path (%s)', mesh_name));
    legend('Location', 'best'); xlim([0 S_end]);
    exportgraphics(gcf, fullfile(out_dir, 'fea_path_stress_vs_x.png'), 'Resolution', 450);

    % ---- FEA Fig 2: junction vs centre against a ----
    figure('Name', ['FEA peak stress vs a - ' mesh_name]); hold on; grid on;
    c2 = lines(2);
    plot(a_fea, fj, 'o', 'Color', c2(1,:), 'MarkerFaceColor', c2(1,:), 'DisplayName', 'FEA junction');
    plot(a_fea, fc, 's', 'Color', c2(2,:), 'MarkerFaceColor', c2(2,:), 'DisplayName', 'FEA centre');
    plot(a_fea, aj, '--', 'Color', shade * c2(1,:), 'LineWidth', 1.4, 'DisplayName', 'analytical junction');
    plot(a_fea, ac, '--', 'Color', shade * c2(2,:), 'LineWidth', 1.4, 'DisplayName', 'analytical centre');
    xlabel('Patch radius a [mm]'); ylabel('\sigma_{vm} [MPa]'); legend('Location', 'best');
    title(sprintf('Junction vs centre stress (%s)', mesh_name));
    exportgraphics(gcf, fullfile(out_dir, 'fea_peak_stress_vs_a.png'), 'Resolution', 450);

    % ---- overlay per radius ----
    for i = 1:n
        figure('Name', sprintf('Overlay a = %g (%s)', a_fea(i), mesh_name)); hold on; grid on;
        plot(fea(i).S, fea(i).total, 'o-', 'Color', cols(i,:), 'MarkerSize', 4, 'LineWidth', 1.0, 'DisplayName', 'FEA (Total)');
        ca = shade * cols(i,:);
        plot(xa, A.SVM(i,:), '-', 'Color', ca, 'LineWidth', 1.6, 'DisplayName', 'analytical');
        plot(xj, [aj(i) aj(i)], 'v', 'Color', ca, 'MarkerFaceColor', ca, 'DisplayName', sprintf('analytical K_t\\sigma (K_t = %.2f)', A.Kt));
        yline(sigma_fail, ':', sprintf('Failure (%g MPa)', sigma_fail), 'Color', 'r', 'LineWidth', 1.5, 'DisplayName', sprintf('Failure (%g MPa)', sigma_fail));
        xlabel('Path length [mm]'); ylabel('\sigma_{vm} [MPa]');
        title(sprintf('a = %g mm (%s): C_j = %.2f, C_c = %.2f', a_fea(i), mesh_name, C.C_junction(i), C.C_centre(i)));
        legend('Location', 'best'); xlim([0 S_end]);
        exportgraphics(gcf, fullfile(out_dir, sprintf('overlay_a%g.png', a_fea(i))), 'Resolution', 450);
    end
end
fprintf('\nAll mesh folders processed successfully.\n');


% =========================================================================
% ---- MULTI-MESH SUMMARY PLOTS ----
% =========================================================================

mesh_sizes = [10, 1, 0.1]; % Nominal element sizes [mm]

% ---- Mesh convergence (Junction & Panel centre vs Element size) ----
figure('Name', 'Mesh Convergence Study', 'Position', [100, 100, 1100, 480]);

% Left subplot: Junction peak
subplot(1, 2, 1); hold on; grid on;
for i = 1:n
    plot(mesh_sizes, fj_matrix(i,:), 'o-', 'Color', cols(i,:), ...
        'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', sprintf('a = %g mm', a_fea(i)));
end
set(gca, 'XDir', 'reverse', 'XScale', 'log');
xlabel('Nominal element size [mm] (finer \rightarrow)');
ylabel('\sigma_{vm} [MPa]');
title('Junction peak convergence');
legend('Location', 'southeast', 'FontSize', 8);

% Right subplot: Panel-centre peak
subplot(1, 2, 2); hold on; grid on;
for i = 1:n
    plot(mesh_sizes, fc_matrix(i,:), 'o-', 'Color', cols(i,:), ...
        'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', sprintf('a = %g mm', a_fea(i)));
end
set(gca, 'XDir', 'reverse', 'XScale', 'log');
xlabel('Nominal element size [mm] (finer \rightarrow)');
ylabel('\sigma_{vm} [MPa]');
title('Panel-centre peak convergence');
legend('Location', 'southeast', 'FontSize', 8);

exportgraphics(gcf, fullfile(base_out_dir, 'mesh_convergence.png'), 'Resolution', 450);


% ---- Multi-mesh FEA vs Analytical & Fatigue Limit ----
figure('Name', 'FEA vs Analytical Across Meshes', 'Position', [100, 100, 1100, 480]);

% Left subplot: Junction peak comparison
subplot(1, 2, 1); hold on; grid on;
plot(a_fea, fj_matrix(:,1), 'o-', 'Color', [0.8 0.4 0], 'LineWidth', 1.2, 'DisplayName', '10 mm mesh');
plot(a_fea, fj_matrix(:,2), 'o-', 'Color', [0.9 0.8 0], 'LineWidth', 1.2, 'DisplayName', '1 mm mesh');
plot(a_fea, fj_matrix(:,3), 'o-', 'Color', [0.2 0.6 0.9], 'LineWidth', 1.2, 'DisplayName', '0.1 mm mesh');
plot(a_fea, aj,            '--k', 'LineWidth', 1.5, 'DisplayName', 'analytical (K_t \sigma_{nom})');
yline(sigma_fail, ':', sprintf('%g MPa fatigue limit', sigma_fail), 'Color', 'r', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlabel('Patch radius a [mm]');
ylabel('\sigma_{vm} [MPa]');
title('Junction peak vs patch radius');
legend('Location', 'southwest', 'FontSize', 8);
xlim([0 max(a_fea)+1]); ylim([0 210]);

% Right subplot: Centre peak comparison
subplot(1, 2, 2); hold on; grid on;
plot(a_fea, fc_matrix(:,1), 'o-', 'Color', [0.8 0.4 0], 'LineWidth', 1.2, 'DisplayName', '10 mm mesh');
plot(a_fea, fc_matrix(:,2), 'o-', 'Color', [0.9 0.8 0], 'LineWidth', 1.2, 'DisplayName', '1 mm mesh');
plot(a_fea, fc_matrix(:,3), 'o-', 'Color', [0.2 0.6 0.9], 'LineWidth', 1.2, 'DisplayName', '0.1 mm mesh');
plot(a_fea, ac,            '--k', 'LineWidth', 1.5, 'DisplayName', 'analytical');
yline(sigma_fail, ':', 'Color', 'r', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlabel('Patch radius a [mm]');
ylabel('\sigma_{vm} [MPa]');
title('Panel-centre peak vs patch radius');
legend('Location', 'northeast', 'FontSize', 8);
xlim([0 max(a_fea)+1]); ylim([0 190]);

exportgraphics(gcf, fullfile(base_out_dir, 'fea_vs_analytical_comparison.png'), 'Resolution', 450);

fprintf('Multi-mesh summary figures successfully generated and saved.\n');
