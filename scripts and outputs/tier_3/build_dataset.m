% Tier 3: grid every verified FEA case onto a shared (u, Z) footprint for the GP surrogate
% Writes output/tier3_dataset.mat. Units: mm, MPa, strain in mm/mm.
clear; clc; close all;

% ---- parameters ----
here    = fileparts(mfilename('fullpath'));
res_dir = fullfile(here, '..', '..', 'Simulation results');
out_dir = fullfile(here, 'output');
h       = 6;            % grid cell size (mm)
umax    = 98.2;         % half arc length on R250 (22.5 deg)
zmax    = 204.5;        % half panel width in Z
n_ok    = 440;          % expected cases after dropping the 18 unverified F5 cases
opts    = {'FileType', 'text', 'Delimiter', '\t'};

if ~exist(out_dir, 'dir'), mkdir(out_dir); end
nu = ceil(2*umax/h); nz = ceil(2*zmax/h);
u  = -umax + h*((1:nu) - 0.5);                 % cell centres
z  = -zmax + h*((1:nz) - 0.5);

% ---- walk cases ----
tic;
S = dir(fullfile(res_dir, 'Feature *', '*', 'r*mm', '*_summary.xls'));
n = numel(S);
[feat, t, s, r, R, gen, smax, emax] = deal(zeros(n, 1));
stem = strings(n, 1);
Gs = zeros(n, nu, nz, 'single'); Ge = Gs;
keep = false(n, 1);
for k = 1:n
    parts = split(S(k).folder, filesep);
    f  = sscanf(parts{end-2}, 'Feature %d');
    st = strtrim(parts{end-1});
    p  = sscanf(st, 't=%f_s=%f_r=%f');
    Rk = sscanf(parts{end}, 'r%dmm');
    if f == 5 && p(1) == 7.5 && ismember(p(3), [1 5]) && ismember(Rk, [6 8 10]), continue; end  % unverified (NOTE.md)
    keep(k) = true;
    feat(k) = f; stem(k) = st; t(k) = p(1); s(k) = p(2); r(k) = p(3); R(k) = Rk;

    base = erase(S(k).name, '_summary.xls');
    gen(k) = numel(dir(fullfile(S(k).folder, '*.xls')));
    assert(ismember(gen(k), [3 4]), '%s: %d files', S(k).folder, gen(k));
    Ns = readmatrix(fullfile(S(k).folder, [base '_Equivalent_Stress.xls']), opts{:});
    Ne = readmatrix(fullfile(S(k).folder, [base '_Equivalent_Elastic_Strain.xls']), opts{:});
    assert(isequal(Ns(:,1), Ne(:,1)), '%s: stress/strain node order differs', base);
    if gen(k) == 3, Ne(:,5) = Ne(:,5) * 1e-6; end   % 3-file export is microstrain

    % ---- grid: per-cell max on (u, Z), empty cells from nearest filled ----
    uu = 250 * atan2(Ns(:,2), Ns(:,3));
    iu = min(max(floor((uu + umax)/h) + 1, 1), nu);
    iz = min(max(floor((Ns(:,4) + zmax)/h) + 1, 1), nz);
    gs = accumarray([iu iz], Ns(:,5), [nu nz], @max, NaN);
    ge = accumarray([iu iz], Ne(:,5), [nu nz], @max, NaN);
    gs = fillmissing2(gs, 'nearest'); ge = fillmissing2(ge, 'nearest');   % base MATLAB, no Image Processing Toolbox
    Gs(k,:,:) = single(gs); Ge(k,:,:) = single(ge);

    smax(k) = max(Ns(:,5)); emax(k) = max(Ne(:,5));
    assert(abs(double(max(Gs(k,:))) - smax(k)) <= 1e-6*smax(k), '%s: grid max != node max (stress)', base);
    assert(abs(double(max(Ge(k,:))) - emax(k)) <= 1e-6*emax(k), '%s: grid max != node max (strain)', base);
    E = smax(k) / emax(k) / 1e3;
    assert(E >= 55 && E <= 80, '%s: smax/emax = %.1f GPa (missed microstrain conversion?)', base, E);
    if mod(k, 50) == 0, fprintf('%d / %d files scanned (%.0f s)\n', k, n, toc); end
end

% ---- keep verified cases and save ----
assert(nnz(keep) == n_ok, 'expected %d cases, got %d', n_ok, nnz(keep));
Gs = Gs(keep,:,:); Ge = Ge(keep,:,:);
cases = table(feat(keep), t(keep), s(keep), r(keep), R(keep), stem(keep), gen(keep), smax(keep), emax(keep), ...
    'VariableNames', {'feat', 't', 's', 'r', 'R', 'stem', 'gen', 'smax', 'emax'});
save(fullfile(out_dir, 'tier3_dataset.mat'), 'u', 'z', 'h', 'cases', 'Gs', 'Ge');
fprintf('%d cases, grid %d x %d (h = %g mm), %d 3-file + %d 4-file, %.1f s\n', ...
    height(cases), nu, nz, h, nnz(cases.gen == 3), nnz(cases.gen == 4), toc);
