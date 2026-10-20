# Curiosity to Perseverance Rover Wheels: Skin Stress FEA and Surrogate Model

[![Code: MIT](https://img.shields.io/badge/code-MIT-blue.svg)](LICENSE)
[![Data & docs: CC BY 4.0](https://img.shields.io/badge/data%20%26%20docs-CC%20BY%204.0-lightgrey.svg)](LICENSE-DATA.md)
![MATLAB R2025b](https://img.shields.io/badge/MATLAB-R2025b-orange.svg)
![Ansys 2025 R1](https://img.shields.io/badge/Ansys-2025%20R1-yellow.svg)

The thin aluminium skin of NASA's Curiosity rover wheels cracked and punctured on sharp Martian rocks. For Perseverance, the wheel was redesigned with a thicker skin and a different grouser (tread) pattern. This project quantifies both designs with finite-element analysis in Ansys 2025 R1. It then turns 440 solved FEA cases into a machine-learning **surrogate model** that predicts the full stress and strain maps of a wheel panel almost instantly, for any combination of grouser feature, skin thickness, grouser angle, fillet radius, rock size and load.

**Reports:**
- [Failure analysis (PDF)](latex/Failure%20analysis/report.pdf): a hand calculation against FEA on a flat Curiosity skin segment.
- [Surrogate model (PDF)](latex/Surrogate%20Model/report.pdf): Curiosity vs Perseverance designs, the ML model and the GUI.

## Key findings

- **Curiosity's skin fails in fatigue under sharp rocks.** A rock contact of radius 2 mm at 400 N drives the 2 mm skin above the 106 MPa fatigue limit of Al 7075-T7351.
- **The Perseverance changes cut the peak stress about 4.5 times.** The median sharp-rock peak at 300 N falls from 86 MPa (Feature 1, 2 mm skin, Curiosity-like) to 19 MPa (Feature 4, 7.5 mm skin, Perseverance-like). The ribbed grouser pattern alone more than halves it.
- **The surrogate model is accurate on geometries it has never seen.** Its median peak-stress error is 3.1%, and its 95% confidence band contains the true value in 94% of cases.
- **A simple beam model is good enough for the panel centre but not the grouser junction.** It matches the FEA centre peak within 12% for sharp contacts, but over-predicts the junction stress three to six times.

<p align="center">
  <img src="media/Surrogate%20GUI.png" width="85%" alt="Surrogate model GUI">
  <br><em>The surrogate model GUI: pick a design and a load, and get the predicted stress and strain maps next to the nearest real FEA case.</em>
</p>

## The two studies

### 1. Failure analysis: `scripts and outputs/tier_1`
A flat skin segment between two grousers, loaded by a rock on a circular patch, is modelled two ways: as a fixed stepped beam with a Peterson stress-concentration factor, and as an Ansys solid model. The stress along a path on the skin surface is then compared between them.

<p align="center">
  <img src="media/analysis_location.png" width="32%" alt="Analysed region of the wheel">
  <img src="media/analysis_segment.png" width="45%" alt="Idealised skin segment">
  <br>
  <img src="scripts%20and%20outputs/tier_1/output/overlay_a2.png" width="55%" alt="FEA vs analytical stress, a = 2 mm">
  <br><em>Top: the analysed region and the idealised segment. Bottom: FEA (markers) against the analytical model (line) for a 2 mm contact.</em>
</p>

### 2. Surrogate model: `scripts and outputs/tier_3`
458 Ansys cases were solved on the curved R250 wheel panel, covering 5 grouser features × 2 thicknesses × 3 angles × 3 fillets × 5 rock sizes. 18 cases with unverified load areas were excluded. Each remaining stress or strain field is resampled onto a common grid, compressed with PCA into 40 shape modes, and learnt with Gaussian-process regression. A separate Gaussian process predicts the peak value with a 95% band. The model is validated by holding out whole geometries.

<p align="center">
  <img src="media/deformation%20sim.png" width="60%" alt="Sample Ansys run">
  <br><em>A sample Ansys run on a Curiosity wheel segment. Stress and strain are the surrogate data; the deformation contour is shown for visualisation only.</em>
  <br><br>
  <img src="scripts%20and%20outputs/tier_3/output/cv_parity_max.png" width="85%" alt="Cross-validated parity plot">
  <br><em>Cross-validated peak stress and strain against FEA. Points on the dashed line are exact.</em>
</p>

> The folders are named `tier_1` and `tier_3` for historical reasons. There is no `tier_2` folder, and nothing is missing.

## Repository map

```text
├── CAD_models/                 STEP files: Feature 1–5 sweeps (92) and the flat-segment models (Tier 1)
├── Simulation results/         Ansys exports, one folder per case, plus batch logs
│   └── NOTE.md                 review of the 18 unverified Feature 5 cases
├── scripts and outputs/
│   ├── tier_1/                 failure analysis: analytical model and FEA comparison (MATLAB)
│   └── tier_3/                 surrogate model: dataset, training, GUI (MATLAB)
├── latex/
│   ├── Failure analysis/       report source and PDF
│   └── Surrogate Model/        report source and PDF
├── media/                      images used in the reports and this README
├── ansys_batch_export.py       Workbench journal that generated the data (reference only)
└── Ansys simulation template/  the Workbench project it drove (reference only)
```

Every `output/` folder has its own README listing what each file is and which script writes it.

## Tools and versions

| Tool | Version | Used for |
|---|---|---|
| Ansys Workbench / Mechanical | 2025 R1 | generating the FEA data (finished; no rerun needed) |
| MATLAB | R2025b | all analysis scripts and the GUI |
| Statistics and Machine Learning Toolbox | R2025b | `fitrgp` / `predict` in the surrogate model |
| LaTeX | Overleaf or `tectonic` | the two reports |

## Quickstart

### Run the surrogate GUI
The trained model (`scripts and outputs/tier_3/output/tier3_model.mat`) is committed, so you can open the GUI straight away:

```matlab
cd 'scripts and outputs/tier_3'
tier3_gui
```

To rebuild the model from the raw FEA results, run these in order:

| Script | What it does | Writes to `output/` |
|---|---|---|
| `build_dataset.m` | reads 440 cases and grids each field on 6 mm cells | `tier3_dataset.mat` |
| `train_surrogate.m` | PCA + Gaussian processes, 5-fold cross-validation, refit on all cases | `tier3_model.mat`, `cv_metrics.csv`, `cv_parity_max.png` |
| `tier3_gui.m` | interactive prediction, nearest-case comparison, field export | none |

### Reproduce the failure analysis
From `scripts and outputs/tier_1`, run `path_stress_analytical.m`, then `fea_vs_analytical.m`. The figures and CSV tables go to `tier_1/output/`.

### Build the reports
Compile `main.tex` from inside its own `latex/<report>/` folder. The figures are read from the repository by relative path, so keep the folder structure (on Overleaf too).

## Data format reference

- **Case folders.** Each case is in `Simulation results/Feature N/<stem>/r<R>mm/`. The stem is `t=<t>_s=<s>_r=<r>`: skin thickness in mm, grouser angle in degrees and fillet radius in mm. `R` is the rock-patch radius in mm (2, 4, 6, 8 or 10), not the fillet `r`. (The CAD file `CAD_models/Feature 4/t=7.5_s=12_r=5 .STEP` has a stray space in its name; the results folder does not.)
- **File format.** The `.xls` files are **tab-separated text**, not Excel. Read them with `readmatrix(f, 'FileType', 'text', 'Delimiter', '\t')`.
- **Nodal files.** `<stem>_r<R>mm_Equivalent_Stress.xls` and `_Equivalent_Elastic_Strain.xls` have the columns `Node Number, X, Y, Z, value` (mm, MPa).
- **Summary file.** `_summary.xls` holds the min, max and average of each result, then the applied pressure P. The load is always 300 N, so the patch area is 300 / P mm².
- **Two export generations.** Tell them apart by the number of files in the folder.
  - **4-file folders** include Total Deformation and store strain in mm/mm.
  - **3-file folders** store strain in **microstrain**, even though the header says mm/mm.
- **Excluded cases.** 18 Feature 5 cases (t = 7.5; r = 1 or 5; R = 6, 8 or 10) report the same patch area at every R, so they are excluded. See [`Simulation results/NOTE.md`](Simulation%20results/NOTE.md).
- **Patch area.** The area is not πR². The load is applied to every outward face of the cut patch, so ribs at the centre (Features 4 and 5) change it. This is expected.
- **Material and supports.** Al 7075-T7351 (E ≈ 72 GPa); the arc ends are fixed.
- **Failure-analysis path files** (`Simulation results/Tier 1/a=<a>.xls`) use a different layout: a 13-line linearisation summary, a blank line, a header, then 49 points along the path. Comparisons use the `Total` column.

## Team

| Member | GitHub |
|---|---|
| Pabitra Kumar Sahoo | [@pabitrakumar1607-a11y](https://github.com/pabitrakumar1607-a11y) |
| Ridam Bagul | [@ridambagul](https://github.com/ridambagul) |
| Sibasis Panda | [@Si-kon](https://github.com/Si-kon) |
| Shaswath S | [@Shass27](https://github.com/Shass27) |

## Licence

- **Code** (`*.m`, `*.py`) is under the [MIT License](LICENSE).
- **Everything else** (simulation data, CAD models, reports, figures and media) is under [CC BY 4.0](LICENSE-DATA.md).

You are free to reuse any of it with attribution.

## How to cite

Use the **"Cite this repository"** button on the GitHub page, which is generated from [`CITATION.cff`](CITATION.cff), or cite the reports directly.
