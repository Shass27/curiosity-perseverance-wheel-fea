% Tier 1 analytical model: stress along the FEA path (2 mm above base = top of skin)
% Flat skin between two grouser blocks, outer end faces fixed, P over a circular patch at mid-span.
% Units: N, mm, MPa.
clear; clc; close all;

% ---- parameters ----
t     = 2.0;            % skin thickness
h_g   = 5.5;            % grouser height above skin
D     = t + h_g;        % grouser block total depth
w_g   = 5.0;            % grouser block width (along span)
L_tot = 83.0;           % overall length, fixed at x = 0 and x = L_tot
b     = 40.0;           % panel width (into page)
r_f   = 1.0;            % junction fillet radius
P     = 400.0;          % total load
a_list = 2:2:10;        % patch radius (rock sharpness)
E     = 72e3;           % Al 7075-T7351
nu    = 0.33;
z_path = 2.0;           % path height above base
N     = 20001;          % grid points along x
sigma_fail = 106;      % failure line (MPa)

out_dir = fullfile(fileparts(mfilename('fullpath')), 'output');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

x  = linspace(0, L_tot, N);
xc = L_tot/2;
in_g = x <= w_g | x >= L_tot - w_g;            % inside a grouser block
I    = b * t^3 / 12 * ones(size(x));
I(in_g) = b * D^3 / 12;
z_na = t/2 * ones(size(x));
z_na(in_g) = D/2;

Kt = peterson_kt_shoulder_bending(D, t, r_f);
x_j = [w_g, L_tot - w_g];                      % junction stations (skin side)
ij = [find(x > w_g, 1), find(x < L_tot - w_g, 1, 'last')];   % first skin points next to each grouser
[~, ic] = min(abs(x - xc));

self_check(L_tot, w_g, P, E, b, t, N);

% ---- sweep patch radius ----
k = sqrt(1 - nu + nu^2);                       % sigma_vm / |sigma_x| for sigma_y = nu*sigma_x
rows = zeros(numel(a_list), 8);
SVM  = zeros(numel(a_list), N);                % sigma_vm(x) per a, saved for fea_vs_analytical.m
figure('Name', 'Path stress'); hold on; grid on;
cols = lines(numel(a_list));
for i = 1:numel(a_list)
    a = a_list(i);
    M = fixed_fixed_moment(x, patch_line_load(x, xc, a, P), E * I);
    sx = -M .* (z_path - z_na) ./ I;           % sagging M > 0 compresses the top
    svm = k * abs(sx);                          % plane stress: sigma_y = nu*sigma_x, sigma_z = 0
    SVM(i,:) = svm;
    % ponytail: Kt applied only at the junction stations, not as a smeared fillet profile
    s_nom_j = max(abs(sx(ij)));
    s_max_j = Kt * k * s_nom_j;
    s_c     = svm(ic);
    rows(i,:) = [a, max(abs(M(ij))), s_nom_j, Kt, s_max_j, abs(sx(ic)), s_c, s_max_j / s_c];

    plot(x, svm, 'Color', cols(i,:), 'LineWidth', 1.4, 'DisplayName', sprintf('a = %g mm', a));
    plot(x_j, [s_max_j s_max_j], 'v', 'Color', cols(i,:), 'MarkerFaceColor', cols(i,:), 'HandleVisibility', 'off');
end
plot(NaN, NaN, 'v', 'Color', [0.6 0.6 0.6], 'MarkerFaceColor', [0.6 0.6 0.6], ...
    'DisplayName', sprintf('junction peak K_t\\sigma (K_t = %.2f), colour = a', Kt));   % one legend entry for all triangles
xline(x_j, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');   % junction stations, grey for dark background
yline(sigma_fail, ':', sprintf('Failure (%g MPa)', sigma_fail), 'Color', 'w', 'LineWidth', 1.5, 'DisplayName', sprintf('Failure (%g MPa)', sigma_fail));   % failure threshold
xlabel('Path length x [mm]'); ylabel('\sigma_{vm} [MPa]');
title(sprintf('Analytical \\sigma_{vm} along path (t = %g mm, r = %g mm, K_t = %.2f)', t, r_f, Kt));
legend('Location', 'best'); xlim([0 L_tot]);
exportgraphics(gcf, fullfile(out_dir, 'path_stress_vs_x.png'), 'Resolution', 450);

T = array2table(rows, 'VariableNames', {'a_mm', 'M_junction_Nmm', 'sigma_nom_junction_MPa', 'Kt', ...
    'sigma_vm_max_junction_MPa', 'sigma_x_centre_MPa', 'sigma_vm_centre_MPa', 'ratio_junction_to_centre'});
disp(T);
writetable(T, fullfile(out_dir, 'summary.csv'));
save(fullfile(out_dir, 'analytical.mat'), 'x', 'SVM', 'a_list', 'x_j', 'Kt', 'T', 'L_tot', 'P');   % input for fea_vs_analytical.m

figure('Name', 'Peak stress vs a'); hold on; grid on;
plot(T.a_mm, T.sigma_vm_max_junction_MPa, 'o-', 'LineWidth', 1.4, 'DisplayName', 'junction (K_t \sigma_{nom})');
plot(T.a_mm, T.sigma_vm_centre_MPa, 's-', 'LineWidth', 1.4, 'DisplayName', 'panel centre');
xlabel('Patch radius a [mm]'); ylabel('\sigma_{vm} [MPa]'); legend('Location', 'best');
title('Junction vs centre stress');
exportgraphics(gcf, fullfile(out_dir, 'peak_stress_vs_a.png'), 'Resolution', 450);

% ================= local functions =================
function q = patch_line_load(x, xc, a, P)
    % circular patch of radius a, pressure P/(pi a^2), integrated across the width
    u = x - xc;
    q = zeros(size(x));
    in = abs(u) < a;
    q(in) = P / (pi * a^2) * 2 * sqrt(a^2 - u(in).^2);
end

function M = fixed_fixed_moment(x, q, EI)
    % M(x) = M0 + V0*x - Mq(x); M0, V0 from zero slope and deflection at x = L
    L  = x(end);
    Mq = cumtrapz(x, cumtrapz(x, q));
    f  = 1 ./ EI;
    A  = [trapz(x, f),           trapz(x, x .* f);
          trapz(x, (L - x) .* f), trapz(x, x .* (L - x) .* f)];
    rhs = [trapz(x, Mq .* f); trapz(x, Mq .* (L - x) .* f)];
    c  = A \ rhs;
    M  = c(1) + c(2) * x - Mq;
end

function Kt = peterson_kt_shoulder_bending(D, d, r)
    % Stepped flat bar with shoulder fillet in bending (Peterson / Roark Table 17.1 case 3b)
    % ponytail: symmetric-shoulder fit for a one-sided T-junction; slightly conservative
    h  = (D - d) / 2;
    hr = h / r;
    if hr <= 2
        C = [ 1.007 + 1.000*sqrt(hr) - 0.031*hr;
             -0.114 - 0.585*sqrt(hr) + 0.314*hr;
              0.241 - 0.992*sqrt(hr) - 0.271*hr;
             -0.134 + 0.577*sqrt(hr) - 0.012*hr];
    else
        C = [ 1.042 + 0.982*sqrt(hr) - 0.036*hr;
             -0.074 - 0.156*sqrt(hr) - 0.010*hr;
             -3.418 + 1.220*sqrt(hr) - 0.005*hr;
              3.450 - 2.046*sqrt(hr) + 0.051*hr];
    end
    s  = 2 * h / D;
    Kt = C(1) + C(2)*s + C(3)*s^2 + C(4)*s^3;
end

function self_check(L_tot, w_g, P, E, b, t, N)
    % near-point load + rigid grousers -> fixed-fixed beam of span L: |M| = PL/8 at ends and centre
    x  = linspace(0, L_tot, N);
    q  = patch_line_load(x, L_tot/2, 0.2, P);
    assert(abs(trapz(x, q) - P) / P < 5e-3, 'patch load does not integrate to P');
    I  = b * t^3 / 12 * ones(size(x));
    I(x <= w_g | x >= L_tot - w_g) = 1e9;
    M  = fixed_fixed_moment(x, q, E * I);
    ref = P * (L_tot - 2*w_g) / 8;
    [~, ij] = min(abs(x - w_g));
    [~, ic] = min(abs(x - L_tot/2));
    assert(abs(abs(M(ij)) - ref) / ref < 0.01, 'junction moment check failed');
    assert(abs(M(ic) - ref) / ref < 0.01, 'centre moment check failed');
end
