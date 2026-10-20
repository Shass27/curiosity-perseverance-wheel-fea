---
name: fea-results
description: How to load and interpret the Ansys results in "Simulation results/" with MATLAB (folder layout, tab-separated .xls format, parameter parsing, microstrain units, missing or unverified cases, running matlab -batch). Use it whenever you write or run a MATLAB script that reads this project's FEA results.
---

# Loading the FEA results in MATLAB

Read the root `CLAUDE.md` sections "Results data format" and "Known data issues" first. This skill adds the code patterns.

## Run MATLAB
The user runs scripts in the MATLAB GUI. Don't launch MATLAB from the terminal unless asked. Scripts live in `scripts and outputs/tier_N/` and write to `scripts and outputs/tier_N/output/`.

## Walk the cases
```matlab
root = fullfile(pwd, 'Simulation results');
S = dir(fullfile(root, 'Feature *', '*', 'r*mm', '*_summary.xls'));   % one per case
for k = 1:numel(S)
    parts = split(S(k).folder, filesep);
    feat = sscanf(parts{end-2}, 'Feature %d');
    stem = strtrim(parts{end-1});                                     % 't=7.5_s=10_r=3'
    p = sscanf(stem, 't=%f_s=%f_r=%f');                               % [t; s; r]
    R = sscanf(parts{end}, 'r%dmm');                                  % patch radius, mm
end
```

## Read the files
```matlab
opts = {'FileType','text','Delimiter','\t'};
N = readmatrix(nodalFile, opts{:});            % [node X Y Z value], header skipped
T = readtable(summaryFile, opts{:}, 'ReadVariableNames', true);
% the last row is 'Applied pressure (MPa)' with P in column 2, and area = 300 / P (mm^2)
```

## Export generations (use the folder's file count)
- **4 files** (the `t=7.5_*_r=3` stems of every feature, from the 19 Oct run): Total Deformation is present and strain is in mm/mm.
- **3 files** (every other case, from `batch_log_2` and `batch_log_3`): there's no Total Deformation, and strain is in **microstrain**, so multiply by 1e-6 to get mm/mm. Sanity check: von Mises stress / strain ≈ 72e3 MPa.
- The user chose to document these issues only. Don't silently correct or drop data. Report the generation per case, and ask before converting.

## Cases to flag
- Missing: Feature 5 `t=7.5_s=10_r=1/r4mm` and `t=7.5_s=12_r=1/r4mm`.
- Unverified: Feature 5, t=7.5, s ∈ {10, 12, 15}, r ∈ {1, 5}, R ∈ {6, 8, 10}. These have the same area at every R. See `NOTE.md`.
- `Simulation results/Tier 1/` has a different format (linearized path data), and the `Feature *` glob above skips it. Its layout is in the root `CLAUDE.md` under "Tier 1 data".
