function tier3_gui()
% Tier 3: interactive surrogate (GP on PCA modes of log10 fields) vs nearest FEA case
% Run build_dataset.m and train_surrogate.m first; they write output/tier3_model.mat.
% Units: mm, N, MPa; strain shown in microstrain.

% ---- parameters ----
here       = fileparts(mfilename('fullpath'));
mat_file   = fullfile(here, 'output', 'tier3_model.mat');
media_dir  = fullfile(here, '..', '..', 'media');
sigma_fail = 106;       % fatigue limit (MPa)
sigma_y    = 435;       % 7075-T7351 yield (MPa)
F_fea      = 300;       % load the FEA was solved at
ue         = 1e6;       % mm/mm -> microstrain
red        = [0.85 0 0];       % fatigue-limit warning only
white      = [1 1 1];
yellow     = [1 0.9 0];        % interpolated-value message
th         = linspace(0, 2*pi, 100);

% ---- load model ----
if ~exist(mat_file, 'file')
    uialert(uifigure('Name', 'Tier 3 surrogate'), 'Run build_dataset.m and train_surrogate.m first', 'Model not found');
    return;
end
M  = load(mat_file);
nu = numel(M.u); nz = numel(M.z);
C  = M.cases;
span = M.in.hi - M.in.lo;                      % normalisation for (s, r, logR)

% ---- figure layout ----
fig = uifigure('Name', 'Tier 3 surrogate', 'Position', [40 40 1450 880], 'Theme', 'dark');   % dark theme so white text is readable
g   = uigridlayout(fig, [1 2], 'ColumnWidth', {330, '1x'});
L   = uigridlayout(g, [13 2], 'ColumnWidth', {90, '1x'}, ...
    'RowHeight', {22, 170, 18, 22, 22, 'fit', 22, 'fit', 22, 'fit', 22, 'fit', '1x'});
at(uilabel(L, 'Text', 'Feature'), 1, 1);
dd_f = at(uidropdown(L, 'Items', {'1','2','3','4','5'}, 'ItemsData', 1:5, 'Value', 1, 'ValueChangedFcn', @(~,~) update()), 1, 2);
img  = at(uiimage(L, 'ScaleMethod', 'fit'), 2, [1 2]);
at(uilabel(L, 'Text', 'Grouser plan-view profile', 'HorizontalAlignment', 'center', 'FontAngle', 'italic'), 3, [1 2]);
at(uilabel(L, 'Text', 't (mm)'), 4, 1);
dd_t = at(uidropdown(L, 'Items', {'2','7.5'}, 'ItemsData', [2 7.5], 'Value', 2, 'ValueChangedFcn', @(~,~) update()), 4, 2);
names = {'s (mm)', 'r (mm)', 'R patch (mm)', 'F force (N)'};
defs  = [12 3 6 300];
ed = gobjects(1, 4); st = gobjects(1, 3);
for k = 1:4
    at(uilabel(L, 'Text', names{k}), 3 + 2*k, 1);
    ed(k) = at(uieditfield(L, 'numeric', 'Value', defs(k), 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', ...
        'ValueChangedFcn', @(~,~) update()), 3 + 2*k, 2);
    if k < 4, st(k) = at(uilabel(L, 'Text', '', 'WordWrap', 'on'), 4 + 2*k, [1 2]); end
end
at(uilabel(L, 'Text', 'Only features 1–5 are modelled; new profiles cannot be predicted.', 'WordWrap', 'on', 'FontAngle', 'italic'), 12, [1 2]);

Rg = uigridlayout(g, [3 2], 'RowHeight', {'1x', '1x', 'fit'});
ax = gobjects(2, 2);
for k = 1:4
    [i, j] = ind2sub([2 2], k);
    ax(i, j) = at(uiaxes(Rg), i, j);
    colorbar(ax(i, j));
end
P  = at(uipanel(Rg, 'Title', 'Readouts'), 3, [1 2]);
PL = uigridlayout(P, [4 1], 'RowHeight', {'fit', 'fit', 'fit', 'fit'});
lb_s = uilabel(PL, 'FontWeight', 'bold'); lb_y = uilabel(PL, 'FontColor', white, 'FontWeight', 'bold');
lb_e = uilabel(PL, 'FontWeight', 'bold'); lb_n = uilabel(PL, 'WordWrap', 'on', 'Interpreter', 'none');

update();

% ---- callbacks ----
    function update()
        feat = dd_f.Value; t = dd_t.Value;
        s = ed(1).Value; r = ed(2).Value; R = ed(3).Value; kF = ed(4).Value / F_fea;
        f_img = fullfile(media_dir, sprintf('feature %d.jpeg', feat));
        if exist(f_img, 'file'), img.ImageSource = f_img; end
        lv = M.levels(feat);
        set_status(st(1), s, lv.s, s_note(s));
        set_status(st(2), r, lv.r, '');
        set_status(st(3), R, lv.R, '');

        % ---- prediction ----
        x = [double((1:5) == feat), double(t == 7.5), ([s r log(R)] - M.in.lo) ./ span];
        [Ps, ms, ls, hs] = gp_field(M.stress, x, kF);
        [Pe, me, le, he] = gp_field(M.strain, x, kF * ue);

        % ---- nearest FEA case (same feature and t) ----
        idx = find(C.feat == feat & C.t == t);
        d = sqrt(sum((([C.s(idx) C.r(idx) log(C.R(idx))] - [s r log(R)]) ./ span).^2, 2));
        [dmin, jn] = min(d); n = idx(jn);
        Ns = kF * double(reshape(M.Gs(n,:,:), nu, nz));
        Ne = kF * ue * double(reshape(M.Ge(n,:,:), nu, nz));
        nm = sprintf('Nearest FEA: %s, R=%g mm', string(C.stem(n)), C.R(n));

        % ---- plots ----
        cs = [0 max([Ps(:); Ns(:); eps])]; ce = [0 max([Pe(:); Ne(:); eps])];
        show(ax(1,1), Ps, cs, 'Predicted stress (MPa)', R, true);
        show(ax(1,2), Ns, cs, [nm ' (MPa)'], R, true);
        show(ax(2,1), Pe, ce, 'Predicted strain (µε)', R, false);
        show(ax(2,2), Ne, ce, [nm ' (µε)'], R, false);

        % ---- readouts ----
        lb_s.Text = sprintf('Predicted max stress = %.1f MPa [%.1f, %.1f] (95%%)', ms, ls, hs);
        lb_s.FontColor = white;
        if ms >= sigma_fail, lb_s.Text = [lb_s.Text ': above 106 MPa fatigue limit']; lb_s.FontColor = red; end
        lb_y.Text = '';
        if ms > sigma_y, lb_y.Text = 'Exceeds 7075-T7351 yield (~435 MPa): the linear model is invalid'; end
        lb_e.Text = sprintf('Predicted max strain = %.0f µε [%.0f, %.0f] (95%%)', me, le, he);
        lb_n.Text = sprintf('Nearest case: %s, R = %g mm, normalised distance %.3f; true max stress %.1f MPa, max strain %.0f µε (at F = %g N)', ...
            string(C.stem(n)), C.R(n), dmin, C.smax(n) * kF, C.emax(n) * kF * ue, ed(4).Value);
    end

% ---- helpers ----
    function [fld, mx, lo, hi] = gp_field(S, x, k)
        m = zeros(1, numel(S.gp));
        for q = 1:numel(S.gp), m(q) = predict(S.gp{q}, x); end   % PCA mode scores
        fld = k * reshape(10.^(S.mu(:)' + m * S.V'), nu, nz);
        [mm, sd] = predict(S.gpmax, x);                          % log10 of the max
        mx = k * 10^mm; lo = k * 10^(mm - 1.96*sd); hi = k * 10^(mm + 1.96*sd);
    end

    function show(a, fld, cl, ttl, R, is_stress)
        cla(a);
        imagesc(a, M.u, M.z, fld'); hold(a, 'on');
        if is_stress && max(fld(:)) >= sigma_fail
            contour(a, M.u, M.z, fld', [sigma_fail sigma_fail], 'w', 'LineWidth', 1.5);
        end
        plot(a, R*cos(th), R*sin(th), 'm-', 'LineWidth', 1.2);  % load patch
        hold(a, 'off');
        axis(a, 'equal'); axis(a, 'tight'); a.YDir = 'normal'; a.CLim = cl; colorbar(a);
        xlabel(a, 'Arc length u (mm)'); ylabel(a, 'Z (mm)'); title(a, ttl, 'Interpreter', 'none');
    end

    function set_status(lab, v, lv, extra)
        if any(abs(v - lv) < 1e-9), txt = 'sampled'; col = [0 0.8 0];
        elseif v >= min(lv) && v <= max(lv), txt = 'between samples (interpolated)'; col = yellow;
        else, txt = 'outside sampled range (unreliable)'; col = red;
        end
        if ~isempty(extra), txt = [txt '; ' extra]; end
        lab.Text = txt; lab.FontColor = col;
    end

    function note = s_note(s)
        note = '';
        if s > 10 && s < 12, note = 'grouser count changes between s=10 (5 grousers) and s=12 (3): the field is a blend'; end
        if s < 10, note = 's<10 rests on one stem (sparse)'; end
    end
end

% ---- local functions ----
function c = at(c, row, col)
c.Layout.Row = row; c.Layout.Column = col;     % place a component in its grid cell
end
