% Tier 1: FEA path stress (Ansys linearized "Total") vs the analytical model
% Run path_stress_analytical.m first; it writes output/analytical.mat.
% Units: mm, MPa.
clear; clc; close all;

% ---- parameters ----
fea_dir    = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'Simulation results', 'Tier 1');
win_j      = 15;        % junction window: within this distance of either path end
win_c      = 10;        % centre window: +/- this around mid-path
sigma_fail = 106;       % failure line (MPa)
P_fea      = 300;       % load the FEA was solved at; Total is scaled linearly to the analytical P
shade      = 0.6;       % analytical colour = shade * FEA colour (darker, still visible on black)

out_dir  = fullfile(fileparts(mfilename('fullpath')), 'output');
mat_file = fullfile(out_dir, 'analytical.mat');
if ~exist(mat_file, 'file'), error('analytical.mat not found: run path_stress_analytical.m first'); end
A = load(mat_file);
if ~isfield(A, 'P'), error('analytical.mat has no P: re-run path_stress_analytical.m'); end
scale = A.P / P_fea;                           % linear elastic: stress scales with load
fprintf('Scaling FEA stresses from %g N to %g N (x%.4f)\n', P_fea, A.P, scale);

% ---- read FEA path files (a=<radius>.xls) ----
files = dir(fullfile(fea_dir, 'a=*.xls'));
a_fea = arrayfun(@(f) sscanf(f.name, 'a=%f'), files);
[a_fea, order] = sort(a_fea);
files = files(order);
fea = struct('S', {}, 'total', {});
for i = 1:numel(files)
    d = readmatrix(fullfile(files(i).folder, files(i).name), 'FileType', 'text', 'Delimiter', '\t', 'NumHeaderLines', 15);
    fea(i).S = d(:,1);
    fea(i).total = d(:,9) * scale;             % column 9 = Total (MPa), scaled to A.P
end
assert(isequal(a_fea(:), A.a_list(:)), 'FEA radii %s do not match analytical a_list %s', mat2str(a_fea'), mat2str(A.a_list));

S_end   = fea(1).S(end);
x_shift = (S_end - A.L_tot) / 2;               % centre-align analytical span on the FEA path
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
aj = A.T.sigma_vm_max_junction_MPa;
ac = A.T.sigma_vm_centre_MPa;
C = table(a_fea, fj, aj, fj ./ aj, fc, ac, fc ./ ac, 'VariableNames', ...
    {'a_mm', 'fea_junction_MPa', 'analytical_junction_MPa', 'C_junction', ...
     'fea_centre_MPa', 'analytical_centre_MPa', 'C_centre'});
disp(C);
writetable(C, fullfile(out_dir, 'fea_vs_analytical.csv'));

% ---- FEA Fig 1: Total along path for every a ----
figure('Name', 'FEA path stress'); hold on; grid on;
for i = 1:n
    plot(fea(i).S, fea(i).total, '.-', 'Color', cols(i,:), 'LineWidth', 1.4, 'MarkerSize', 10, ...
        'DisplayName', sprintf('a = %g mm', a_fea(i)));
end
yline(sigma_fail, ':', sprintf('Failure (%g MPa)', sigma_fail), 'Color', 'w', 'LineWidth', 1.5, 'DisplayName', sprintf('Failure (%g MPa)', sigma_fail));
xlabel('Path length S [mm]'); ylabel('\sigma_{vm} [MPa]');
title(sprintf('FEA \\sigma_{vm} along path (linearized Total, scaled %g N \\rightarrow %g N)', P_fea, A.P));
legend('Location', 'best'); xlim([0 S_end]);
exportgraphics(gcf, fullfile(out_dir, 'fea_path_stress_vs_x.png'), 'Resolution', 450);

% ---- FEA Fig 2: junction vs centre against a, analytical dashed ----
figure('Name', 'FEA peak stress vs a'); hold on; grid on;
c2 = lines(2);
plot(a_fea, fj, 'o', 'Color', c2(1,:), 'MarkerFaceColor', c2(1,:), 'DisplayName', 'FEA junction');
plot(a_fea, fc, 's', 'Color', c2(2,:), 'MarkerFaceColor', c2(2,:), 'DisplayName', 'FEA centre');
plot(a_fea, aj, '--', 'Color', shade * c2(1,:), 'LineWidth', 1.4, 'DisplayName', 'analytical junction (K_t \sigma_{nom})');
plot(a_fea, ac, '--', 'Color', shade * c2(2,:), 'LineWidth', 1.4, 'DisplayName', 'analytical centre');
xlabel('Patch radius a [mm]'); ylabel('\sigma_{vm} [MPa]'); legend('Location', 'best');
title(sprintf('Junction vs centre stress: FEA (scaled to %g N) vs analytical', A.P));
exportgraphics(gcf, fullfile(out_dir, 'fea_peak_stress_vs_a.png'), 'Resolution', 450);

% ---- overlay per radius ----
for i = 1:n
    figure('Name', sprintf('Overlay a = %g', a_fea(i))); hold on; grid on;
    plot(fea(i).S, fea(i).total, 'o-', 'Color', cols(i,:), 'MarkerSize', 4, 'LineWidth', 1.0, 'DisplayName', 'FEA (Total)');
    ca = shade * cols(i,:);                    % analytical: darker shade of this a's FEA colour
    plot(xa, A.SVM(i,:), '-', 'Color', ca, 'LineWidth', 1.6, 'DisplayName', 'analytical');
    plot(xj, [aj(i) aj(i)], 'v', 'Color', ca, 'MarkerFaceColor', ca, 'DisplayName', sprintf('analytical K_t\\sigma (K_t = %.2f)', A.Kt));
    yline(sigma_fail, ':', sprintf('Failure (%g MPa)', sigma_fail), 'Color', 'w', 'LineWidth', 1.5, 'DisplayName', sprintf('Failure (%g MPa)', sigma_fail));
    xlabel('Path length [mm]'); ylabel('\sigma_{vm} [MPa]');
    title(sprintf('a = %g mm: C_{junction} = %.2f, C_{centre} = %.2f', a_fea(i), C.C_junction(i), C.C_centre(i)));
    legend('Location', 'best'); xlim([0 S_end]);
    exportgraphics(gcf, fullfile(out_dir, sprintf('overlay_a%g.png', a_fea(i))), 'Resolution', 450);
end
