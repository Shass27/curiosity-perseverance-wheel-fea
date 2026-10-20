function tier3_gui()
% Tier 3: interactive surrogate (GP on PCA modes of log10 fields) vs nearest FEA case
% Run build_dataset.m and train_surrogate.m first; they write output/tier3_model.mat.
% Units: mm, N, MPa; strain shown in microstrain.

% ---- parameters ----
here       = fileparts(mfilename('fullpath'));
mat_file   = fullfile(here, 'output', 'tier3_model.mat');
media_dir  = fullfile(here, '..', '..', 'media');
sigma_fail = 106;       % fatigue limit (MPa)
eps_fail   = 0.08;      % failure strain (8%)
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
L   = uigridlayout(g, [17 2], 'ColumnWidth', {150, '1x'}, ...
    'RowHeight', {22, 60, 18, 22, 22, 'fit', 22, 'fit', 22, 'fit', 22, 'fit', 8, 'fit', 'fit', 'fit', '1x'});
lab_info('Feature', 1, @() 'Only features 1–5 are modelled; new profiles cannot be predicted.');
dd_f = at(uidropdown(L, 'Items', {'1','2','3','4','5'}, 'ItemsData', 1:5, 'Value', 1, 'ValueChangedFcn', @(~,~) update()), 1, 2);
img  = at(uiimage(L, 'ScaleMethod', 'fit'), 2, [1 2]);
at(uilabel(L, 'Text', 'Grouser plan-view profile', 'HorizontalAlignment', 'center', 'FontAngle', 'italic'), 3, [1 2]);
lab_info('Thickness (mm)', 4, @() 'Modelled at 2 mm and 7.5 mm only. It is a discrete choice: no interpolation between them.');
dd_t = at(uidropdown(L, 'Items', {'2','7.5'}, 'ItemsData', [2 7.5], 'Value', 2, 'ValueChangedFcn', @(~,~) update()), 4, 2);
names = {'Angle (deg)', 'Fillet radius (mm)', 'Patch Radius (mm)', 'Force (N)'};
defs  = [12 3 6 300];
ed = gobjects(1, 4); st = gobjects(1, 3);
for k = 1:4
    lab_info(names{k}, 3 + 2*k, @() range_info(k));
    ed(k) = at(uieditfield(L, 'numeric', 'Value', defs(k), 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', ...
        'ValueChangedFcn', @(~,~) update()), 3 + 2*k, 2);
    if k < 4, st(k) = at(uilabel(L, 'Text', '', 'WordWrap', 'on'), 4 + 2*k, [1 2]); end
end

% ---- readout tables (left column, below inputs) ----
T1 = at(uigridlayout(L, [4 3], 'ColumnWidth', {95, 55, '1x'}, 'RowHeight', {'fit', 'fit', 'fit', 'fit'}, 'Padding', 0, 'RowSpacing', 4), 14, [1 2]);
uilabel(T1, 'Text', 'Prediction', 'FontWeight', 'bold', 'FontAngle', 'italic');
uilabel(T1, 'Text', 'Value', 'FontWeight', 'bold');
hg = uigridlayout(T1, [1 2], 'ColumnWidth', {'fit', 24}, 'Padding', 0, 'ColumnSpacing', 4);
uilabel(hg, 'Text', 'Confidence Range', 'FontWeight', 'bold');
uibutton(hg, 'Text', 'ⓘ', 'ButtonPushedFcn', @(~,~) uialert(fig, 'The range in which the surrogate is 95% confident the true value lies.', 'Info', 'Icon', 'info'));   % info popup
uilabel(T1, 'Text', 'Max stress (MPa)');
v_s = uilabel(T1); r_s = uilabel(T1);
uilabel(T1, 'Text', 'Max strain (µε)');
v_e = uilabel(T1); r_e = uilabel(T1);
lb_w = at(uilabel(T1, 'WordWrap', 'on', 'FontWeight', 'bold', 'Text', ''), 4, [1 3]);

T2 = at(uigridlayout(L, [6 2], 'ColumnWidth', {95, '1x'}, 'RowHeight', repmat({'fit'}, 1, 6), 'Padding', 0, 'RowSpacing', 4), 15, [1 2]);
at(uilabel(T2, 'Text', 'Nearest FEA case', 'FontWeight', 'bold', 'FontAngle', 'italic'), 1, [1 2]);
nt = gobjects(1, 5);
nn = {'Case', 'Patch R (mm)', 'Distance', 'Max stress (MPa)', 'Max strain (µε)'};
for k = 1:5
    uilabel(T2, 'Text', nn{k});
    nt(k) = uilabel(T2, 'Interpreter', 'none');
end

T3 = at(uigridlayout(L, [2 2], 'RowHeight', {'fit', 'fit'}, 'Padding', 0, 'RowSpacing', 4), 16, [1 2]);
uilabel(T3, 'Text', 'Export predicted field', 'FontWeight', 'bold', 'FontAngle', 'italic');
dd_x = uidropdown(T3, 'Items', {'.xls (tab text)', '.csv', '.txt (tab text)', '.xlsx', '.mat'}, 'ItemsData', {'.xls', '.csv', '.txt', '.xlsx', '.mat'}, 'Value', '.xls');
uibutton(T3, 'Text', 'Export stress…', 'ButtonPushedFcn', @(~,~) export_field('stress'));
uibutton(T3, 'Text', 'Export strain…', 'ButtonPushedFcn', @(~,~) export_field('strain'));

Rg = uigridlayout(g, [2 2], 'RowHeight', {'1x', '1x'});
ax = gobjects(2, 2);
for k = 1:4
    [i, j] = ind2sub([2 2], k);
    ax(i, j) = at(uiaxes(Rg), i, j);
    colorbar(ax(i, j));
end

cur = struct();      % last predicted fields + inputs, used by export_field
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

        cur.S = Ps; cur.E = Pe; cur.in = [feat t s r R ed(4).Value];

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
        v_s.Text = sprintf('%.1f', ms); r_s.Text = sprintf('[%.1f, %.1f]', ls, hs);
        v_e.Text = sprintf('%.0f', me); r_e.Text = sprintf('[%.0f, %.0f]', le, he);
        v_s.FontColor = white; v_e.FontColor = white; w = {};
        if ms >= sigma_fail, v_s.FontColor = red; w{end+1} = 'Stress above 106 MPa fatigue limit'; end
        if ms > sigma_y, w{end+1} = 'Stress exceeds 7075-T7351 yield (~435 MPa): the linear model is invalid'; end
        if me >= eps_fail * ue, v_e.FontColor = red; w{end+1} = 'Strain above 8% failure limit'; end
        lb_w.Text = strjoin(w, newline); lb_w.FontColor = red;
        nt(1).Text = char(string(C.stem(n))); nt(2).Text = sprintf('%g', C.R(n));
        nt(3).Text = sprintf('%.3f', dmin);
        nt(4).Text = sprintf('%.1f', C.smax(n) * kF); nt(5).Text = sprintf('%.0f', C.emax(n) * kF * ue);   % scaled to input force
    end

% ---- helpers ----
    function export_field(kind)
        % write the last predicted field in the recorded-data layout (pseudo-nodes on the (u, Z) grid)
        is_s = strcmp(kind, 'stress'); in = cur.in;
        if is_s, fld = cur.S; hdr = 'Equivalent (von-Mises) Stress (MPa)'; label = 'Equivalent Stress'; unit = 'MPa';
        else, fld = cur.E; hdr = 'Equivalent Elastic Strain (µε)'; label = 'Equivalent Elastic Strain'; unit = 'µε'; end
        base = sprintf('%s_F%g_t%g_s%g_r%g_R%g_F%gN', kind, in);
        xe = dd_x.Value;   % format picked in the dropdown
        [fn, fp] = uiputfile(['*' xe], 'Export', base);
        if isequal(fn, 0), return; end
        f = fullfile(fp, fn); [~, nm, ext] = fileparts(f);
        [U, Z] = ndgrid(M.u(:), M.z(:));
        T = table((1:numel(U))', 250*sin(U(:)/250), 250*cos(U(:)/250), Z(:), fld(:), 'VariableNames', ...
            {'Node Number', 'X Location (mm)', 'Y Location (mm)', 'Z Location (mm)', hdr});
        try
            switch lower(ext)
                case '.csv', writetable(T, f);
                case '.xlsx', writetable(T, f, 'FileType', 'spreadsheet');
                case '.mat', u = M.u; z = M.z; save(f, 'T', 'u', 'z', 'in');   % in = [feature t s r R F]
                otherwise, writetable(T, f, 'FileType', 'text', 'Delimiter', '\t');
            end
            if ~strcmpi(ext, '.mat')   % summary in the recorded layout; force replaces pressure (not defined for a prediction)
                fid = fopen(fullfile(fp, [nm '_summary.xls']), 'w');
                fprintf(fid, 'Result\tMinimum\tMaximum\tAverage\tUnit\n%s\t%g\t%g\t%g\t%s\n\nApplied force (N)\t%g\n', ...
                    label, min(fld(:)), max(fld(:)), mean(fld(:)), unit, in(6));
                fclose(fid);
            end
            uialert(fig, ['Saved ' f], 'Export', 'Icon', 'success');
        catch err
            uialert(fig, err.message, 'Export failed');
        end
    end

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

    function lab_info(txt, row, msgFcn)
        g1 = at(uigridlayout(L, [1 2], 'ColumnWidth', {'fit', 24}, 'Padding', 0, 'ColumnSpacing', 4), row, 1);
        uilabel(g1, 'Text', txt, 'FontWeight', 'bold');
        uibutton(g1, 'Text', 'ⓘ', 'ButtonPushedFcn', @(~,~) uialert(fig, msgFcn(), 'Info', 'Icon', 'info'));   % info popup
    end

    function msg = range_info(k)
        if k == 4
            msg = sprintf('Simulated at %g N; the field scales linearly with load, so any force > 0 is predicted exactly by scaling.', F_fea); return
        end
        lv = M.levels(dd_f.Value); v = {lv.s, lv.r, lv.R}; v = v{k};
        msg = sprintf('Modelled at: %s.\nInterpolated between %g and %g; outside that range the prediction is unreliable.', strjoin(compose('%g', v), ', '), min(v), max(v));
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
