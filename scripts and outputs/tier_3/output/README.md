# Tier 3 outputs

Run `../build_dataset.m` first, then `../train_surrogate.m`, then `../tier3_gui.m`. Nothing in `output/` is committed yet.

**Inputs:** 440 FEA cases from `Simulation results/Feature */`. The 18 unverified Feature 5 cases (t = 7.5, r ∈ {1, 5}, R ∈ {6, 8, 10}; see `Simulation results/NOTE.md`) are excluded, and 3-file exports are converted from microstrain to mm/mm.
**Grid:** 6 mm cells on (u, Z), with u = 250·atan2(X, Y) the arc length on R250, so every case shares one 33 × 69 footprint. Each cell holds the max nodal value, and empty cells take the nearest filled cell.
**Surrogate:** PCA of log10 field (99.5 % variance, at most 40 modes) with one ARD squared-exponential GP per mode, plus a GP on log10 of the max. Fields are at 300 N and scale linearly with load.
**Units:** mm, MPa, strain in mm/mm.

| File | Description | Script | Data |
|---|---|---|---|
| `tier3_dataset.mat` | `u`, `z`, `h`, `cases` (feat, t, s, r, R, stem, gen, smax, emax) and the gridded fields `Gs`, `Ge` (single, ncase × nu × nz). | `build_dataset.m` | `Simulation results/Feature */` |
| `tier3_model.mat` | Trained surrogate: `u`, `z`, `h`, `in` (input scaling), `stress`, `strain` (mu, V, gp, gpmax, floor, unit), `cases`, `Gs`, `Ge`, `levels`, `cv`. | `train_surrogate.m` | `tier3_dataset.mat` |
| `cv_metrics.csv` | 5-fold stem-grouped CV per field and subset (all, F1–F5): field R² (linear and log), max R² (linear and log), median and 90th-percentile max relative error, 95 % interval coverage of the max. | `train_surrogate.m` | `tier3_dataset.mat` |
| `cv_parity_max.png` | CV-predicted vs FEA max stress and max strain (log-log), coloured by feature. | `train_surrogate.m` | `tier3_dataset.mat` |
