# Tier 1 outputs

Run `../path_stress_analytical.m` first, then `../fea_vs_analytical.m`. The FEA was solved at 300 N and is scaled linearly to the analytical load (400 N) before any comparison.

**Model inputs:** skin t = 2 mm; grouser depth D = 7.5 mm (5 mm wide); overall length 83 mm, fixed at both ends; width b = 40 mm; fillet r = 1 mm; P = 400 N over a circular patch of radius a = 2–10 mm; Al 7075-T7351 (E = 72 GPa, ν = 0.33). The path is 2 mm above the base, on the top of the skin.
**Units:** mm, N and MPa throughout.

| File | Description | Script | Data |
|---|---|---|---|
| `analytical_path_stress_vs_x.png` | Analytical von Mises stress along the path for each patch radius a. Triangles mark the K_t-amplified junction peaks. | `path_stress_analytical.m` | Analytical model |
| `analytical_peak_stress_vs_a.png` | Analytical junction (K_t·σ_nom) and panel-centre stress against patch radius a. | `path_stress_analytical.m` | Analytical model |
| `summary.csv` | One row per a: junction moment, σ_nom, K_t, junction and centre stress, and their ratio. | `path_stress_analytical.m` | Analytical model |
| `analytical.mat` | Analytical curves and parameters passed to the comparison script. | `path_stress_analytical.m` | Analytical model |
| `<h>_meshing/fea_path_stress_vs_x.png` | FEA linearized Total stress along the path for each a, for mesh size h (10mm, 1mm, 0.1mm). | `fea_vs_analytical.m` | `Simulation results/Tier 1/<h>_meshing/a=*.xls` |
| `<h>_meshing/fea_peak_stress_vs_a.png` | FEA junction and centre peaks against a (markers), with the analytical values dashed. | `fea_vs_analytical.m` | FEA + `analytical.mat` |
| `<h>_meshing/overlay_a<a>.png` | FEA and analytical stress along the path for one radius. The title gives C_junction and C_centre. | `fea_vs_analytical.m` | FEA + `analytical.mat` |
| `<h>_meshing/fea_vs_analytical.csv` | One row per a: FEA and analytical peaks and the calibration factors C = σ_FEA / σ_analytical. | `fea_vs_analytical.m` | FEA + `analytical.mat` |
| `mesh_convergence.png` | Junction and centre FEA peaks against element size, one curve per a. | `fea_vs_analytical.m` | All three meshes |
| `fea_vs_analytical_comparison.png` | FEA peaks from all three meshes overlaid on the analytical values. | `fea_vs_analytical.m` | All three meshes + `analytical.mat` |
