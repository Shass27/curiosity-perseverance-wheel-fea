% Tier 3: PCA + Gaussian-process surrogate of the gridded stress and strain fields
% Run build_dataset.m first. Writes output/tier3_model.mat, cv_metrics.csv, cv_parity_max.png.
% Prediction: field_log = mu + sum_k score_k*V(:,k)'; cell log-SD = sqrt(sum_k V(:,k).^2*sd_k^2); max = 10^m, 95% band 10^(m +/- 1.96*sd); scale outputs by F/300.
clear; clc; close all;

% ---- parameters ----
here    = fileparts(mfilename('fullpath'));
out_dir = fullfile(here, 'output');
var_tgt = 0.995;        % PCA explained-variance target
k_cap   = 40;           % max PCA modes
n_fold  = 5;            % CV folds, grouped by stem
floors  = [1e-6 1e-12]; % log floor: stress (MPa), strain (mm/mm)
names   = {'stress', 'strain'};
units   = {'MPa', 'mm/mm'};

D = load(fullfile(out_dir, 'tier3_dataset.mat'));
u = D.u; z = D.z; h = D.h; cases = D.cases; Gs = D.Gs; Ge = D.Ge;
n = height(cases);

% ---- inputs: one-hot feature, t flag, s / r / log R scaled to [0,1] ----
in.lo = [min(cases.s), min(cases.r), log(min(cases.R))];
in.hi = [max(cases.s), max(cases.r), log(max(cases.R))];
in.feats = 1:5;
X = encode(cases.feat, cases.t, cases.s, cases.r, cases.R, in);

levels = struct('t', {}, 's', {}, 'r', {}, 'R', {});
for f = in.feats
    m = cases.feat == f;
    levels(f).t = unique(cases.t(m))'; levels(f).s = unique(cases.s(m))';
    levels(f).r = unique(cases.r(m))'; levels(f).R = unique(cases.R(m))';
end

% ---- stem-grouped folds ----
key = string(cases.feat) + "_" + cases.stem;
[ukey, ~, g] = unique(key);
rng(0);
fold_of_stem = mod(randperm(numel(ukey)), n_fold) + 1;
fold = fold_of_stem(g)';

r2 = @(y, p) 1 - sum((y - p).^2, 'all') / sum((y - mean(y, 'all')).^2, 'all');
M = table();
pmax = zeros(n, 2);                            % CV-predicted max per case and field
for q = 1:2
    if q == 1, G = double(Gs(:,:)); vmax = cases.smax; else, G = double(Ge(:,:)); vmax = cases.emax; end
    Y = log10(max(G, floors(q)));
    ym = log10(vmax);

    % ---- cross-validation ----
    Yp = zeros(size(Y)); mp = zeros(n, 1); sp = zeros(n, 1);
    for f = 1:n_fold
        tr = fold ~= f; te = ~tr;
        mdl = fit_field(X(tr,:), Y(tr,:), ym(tr), var_tgt, k_cap);
        sc = zeros(nnz(te), numel(mdl.gp));
        for j = 1:numel(mdl.gp), sc(:,j) = predict(mdl.gp{j}, X(te,:)); end
        Yp(te,:) = mdl.mu + sc * mdl.V';
        [mp(te), sp(te)] = predict(mdl.gpmax, X(te,:));
        fprintf('%s fold %d/%d: %d test cases, k = %d\n', names{q}, f, n_fold, nnz(te), numel(mdl.gp));
    end
    pmax(:,q) = 10.^mp;

    % ---- metrics: all cases, then per feature ----
    for f = 0:5
        m = f == 0 | cases.feat == f;
        rel = abs(10.^mp(m) ./ vmax(m) - 1);
        lbl = "all"; if f > 0, lbl = "F" + f; end
        row = table(string(names{q}), lbl, nnz(m), ...
            r2(G(m,:), 10.^Yp(m,:)), r2(Y(m,:), Yp(m,:)), r2(vmax(m), 10.^mp(m)), r2(ym(m), mp(m)), ...
            median(rel), prctile(rel, 90), mean(abs(ym(m) - mp(m)) <= 1.96*sp(m)), ...
            'VariableNames', {'field', 'subset', 'n', 'field_R2_lin', 'field_R2_log', 'max_R2_lin', 'max_R2_log', ...
            'max_relerr_med', 'max_relerr_p90', 'max_cov95'});
        M = [M; row]; %#ok<AGROW>
    end
end
disp(M);
writetable(M, fullfile(out_dir, 'cv_metrics.csv'));
cv.metrics = M;

% ---- parity plot of CV-predicted max ----
figure('Name', 'CV parity (max)', 'Position', [100 100 1100 480]);
truth = [cases.smax cases.emax];
cols = lines(5);
for q = 1:2
    subplot(1, 2, q); hold on; grid on; box on;
    for f = in.feats
        m = cases.feat == f;
        scatter(truth(m,q), pmax(m,q), 18, cols(f,:), 'filled', 'DisplayName', sprintf('Feature %d', f));
    end
    lim = [min([truth(:,q); pmax(:,q)]) max([truth(:,q); pmax(:,q)])];
    plot(lim, lim, 'k--', 'LineWidth', 1.2, 'DisplayName', 'y = x');
    set(gca, 'XScale', 'log', 'YScale', 'log'); axis([lim lim]);
    xlabel(sprintf('FEA max %s [%s]', names{q}, units{q})); ylabel(sprintf('CV-predicted max %s [%s]', names{q}, units{q}));
    title(sprintf('Max %s: %d-fold CV by stem', names{q}, n_fold));
    legend('Location', 'northwest');
end
exportgraphics(gcf, fullfile(out_dir, 'cv_parity_max.png'), 'Resolution', 450);

% ---- refit on all cases and save ----
for q = 1:2
    if q == 1, G = double(Gs(:,:)); vmax = cases.smax; else, G = double(Ge(:,:)); vmax = cases.emax; end
    mdl = fit_field(X, log10(max(G, floors(q))), log10(vmax), var_tgt, k_cap);
    fprintf('%s: k = %d modes, %.2f%% variance explained\n', names{q}, numel(mdl.gp), 100*mdl.ex);
    mdl = rmfield(mdl, 'ex');
    mdl.floor = floors(q); mdl.unit = units{q};
    if q == 1, stress = mdl; else, strain = mdl; end
end
save(fullfile(out_dir, 'tier3_model.mat'), 'u', 'z', 'h', 'in', 'stress', 'strain', 'cases', 'Gs', 'Ge', 'levels', 'cv');
fprintf('Saved tier3_model.mat (%d cases)\n', n);

% ---- local functions ----
function X = encode(feat, t, s, r, R, in)
X = [double(feat(:) == in.feats), double(t(:) == 7.5), ([s(:) r(:) log(R(:))] - in.lo) ./ (in.hi - in.lo)];
end

function mdl = fit_field(X, Y, ym, var_tgt, k_cap)
mdl.mu = mean(Y, 1);
[~, Sg, V] = svd(Y - mdl.mu, 'econ');
ev = cumsum(diag(Sg).^2) / sum(diag(Sg).^2);
k = min(find(ev >= var_tgt, 1), k_cap);
mdl.V = V(:, 1:k); mdl.ex = ev(k);
sc = (Y - mdl.mu) * mdl.V;
opt = {'KernelFunction', 'ardsquaredexponential', 'Standardize', true};
mdl.gp = cell(1, k);
for j = 1:k, mdl.gp{j} = compact(fitrgp(X, sc(:,j), opt{:})); end
mdl.gpmax = compact(fitrgp(X, ym, opt{:}));
end
