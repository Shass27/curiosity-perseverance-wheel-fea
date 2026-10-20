# MOS_Project

Batch FEA of curved R250 panels (rover-wheel features) in Ansys Workbench 2025 R1. Each case puts a 300 N load on a circular patch of radius R at the panel's geometric centre, solves it, and exports the results.
**The Ansys phase is finished, and no more runs are planned.** The current phase is **MATLAB post-processing** of `Simulation results/`.

## Layout
- `CAD_models/Feature 1..5/*.STEP`: 92 files. Each feature has 18 combinations of t ∈ {2, 7.5}, s ∈ {10, 12, 15} and r ∈ {1, 3, 5}, and Features 4 and 5 also have `t=7.5_s=6_r=3`. The name `Feature 4/t=7.5_s=12_r=5 .STEP` contains a stray space, so trim it when parsing.
- `Simulation results/Feature N/<stem>/r<R>mm/`: one case per folder, R ∈ {2, 4, 6, 8, 10} (patch radius, not the CAD `r`).
- `Simulation results/batch_log.txt` (85 OK), `batch_log_2.txt` (106 OK, 4 FAILED, plus SKIPPED lines) and `batch_log_3.txt` (225 OK: the remaining Feature 1–3 stems): one line per case, with `A=` (patch area, mm²) and `P=` (pressure, MPa).
- `Simulation results/Tier 1/a=<a>.xls`: path data for the simplified flat-skin model, with CAD in `CAD_models/Tier 1/`. These files use a different format; see "Tier 1 data" below.
- `Simulation results/NOTE.md`: review of `batch_log_2`. Read it before trusting Feature 5 data.
- `ansys_batch_export.py` + `Ansys simulation template/`: the Workbench journal that produced the data. It's only for reference, and its paths point at a teammate's Windows machine.
- `scripts and outputs/tier_N/`: MATLAB analysis scripts for the report tiers. Each writes to `scripts and outputs/tier_N/output/`, which has a README listing what each file is. Tier 1 is the analytical path-stress model of the simplified flat-skin model.
- `latex/Failure analysis/` (Tier 1 report) and `latex/Surrogate Model/` (Tier 3 report): `main.tex` + `report.pdf` each. Figures are read by relative path (`../../`) from `scripts and outputs/tier_N/output/` and `media/`.
- `media/`: images used in the report (wheel location, segment CAD, Ansys run screenshot).

## Results coverage (458 cases)
| Feature | Stems run | Cases |
|---|---|---|
| 1, 2, 3 | all 18 | 90 each |
| 4 | all 19 | 95 |
| 5 | all 19 | 93 (`t=7.5_s=10_r=1/r4mm` and `t=7.5_s=12_r=1/r4mm` missing: mesh failure) |

## Results data format
- The `.xls` files are **tab-separated text** with one header row, not Excel. Read them with `'FileType','text','Delimiter','\t'`.
- The nodal files are `<base>_Equivalent_Stress.xls`, `_Equivalent_Elastic_Strain.xls` and `_Total_Deformation.xls`. Their columns are `Node Number, X (mm), Y (mm), Z (mm), value`.
- `<base>_summary.xls` has `Result, Minimum, Maximum, Average, Unit` rows, then a blank line, then `Applied pressure (MPa)<TAB>P`. The patch area is 300 / P mm².
- `<base>` = `<stem>_r<R>mm`.

## Known data issues (documented, not auto-corrected)
- **Two export generations.** Tell them apart by the file count in the folder.
  - **4 files:** the `t=7.5_s={10,12,15}_r=3` stems of every feature, plus `t=7.5_s=6_r=3` in Features 4 and 5 (the 19 Oct run). These include Total Deformation, and strain is in mm/mm.
  - **3 files:** every other case (from `batch_log_2` and `batch_log_3`). There is **no Total Deformation**, and strain is in **microstrain** even though the header says mm/mm (39.1 MPa against 545 gives E ≈ 72 GPa for Al 7075).
- **Unverified:** 18 Feature 5 folders (t=7.5; s=10, 12, 15; r=1, 5; R=6, 8, 10 mm) report the same area and pressure at every R. See `Simulation results/NOTE.md`.
- The patch area is **not** πR². The load goes on every outward face of the cut plug, so the features at the centre (ribs on Features 4 and 5) change the area. That's expected.
- Material: Al 7075-T7351 (E ≈ 72 GPa). The ends of the arc are fixed.

## Tier 1 data (simplified flat-skin model)
- These are tab-separated text files with CRLF line endings. Lines 1–13 are a linearization summary block, line 14 is blank, and line 15 is the path header. Lines 16–64 hold 49 points at S = 0…85 mm.
- The columns are `S, X, Y, Z, Membrane, Bending, Membrane+Bending, Peak, Total`. Comparisons use **Total** (column 9).
- The FEA was solved at **300 N**. The analytical model uses **400 N**, so `fea_vs_analytical.m` scales the FEA by 4/3. The fatigue limit line is at 106 MPa.

## MATLAB
- R2025b. **Don't launch MATLAB from the terminal unless the user asks.** The user runs the scripts in the MATLAB GUI and reports back.
- The `fea-results` skill (`.claude/skills/fea-results/`) covers how to load the dataset.

## How the Ansys script worked (reference)
1. Discovery (`SC_SCRIPT`) runs first; SpaceClaim isn't installed.
   - It finds the panel centre as the UV mid-point of the inner skin, moved out to R250.
   - A cylinder cutter with radius R is intersected with the body, which leaves a plug.
   - `NS_LOAD` is every outward face of the plug.
   - `NS_FIX` is the two flat end faces at ±22.5°.
2. Mechanical (`MECH_SCRIPT`) assigns the material, sets the pressure P = 300 N / area on `NS_LOAD` and the Fixed Support on `NS_FIX`, then solves and exports.

## Status
- 19 Oct 2026: the first full run finished with 85/85 OK.
- 20 Oct 2026: a continuation run on the updated Feature 4/5 CAD. The Ansys phase is closed, and MATLAB post-processing starts next.
- 20 Oct 2026: the Tier 1 analytical vs FEA study and report are done (`latex/`). `batch_log_3` ran the remaining 225 Feature 1–3 cases with 225/225 OK, so every feature now has all its stems; this data is for surrogate modelling later.
