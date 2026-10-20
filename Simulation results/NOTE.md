# NOTE: batch_log_2 review (Feature 4 / Feature 5 continuation run)

Reviewed 20 Oct 2026 against `Simulation results/batch_log_2.txt` and the result folders.

## The log's 4 FAILED cases (all Feature 5, t=7.5, r=4mm)

| Case | Verdict | Detail |
|---|---|---|
| `t=7.5_s=10_r=3` | Not a real failure | `r4mm` already holds complete results from the earlier run (19 Oct 08:07, 4 files, applied pressure 4.7095 MPa). The failed re-run did not overwrite them. Kept. |
| `t=7.5_s=15_r=3` | Not a real failure | Same as above. Kept. |
| `t=7.5_s=10_r=1` | **Real failure** | Mesh could not be generated. `r4mm` folder was empty. **Folder deleted.** |
| `t=7.5_s=12_r=1` | **Real failure** | Same. `r4mm` folder was empty. **Folder deleted.** |

The two deleted cases have no `r4mm` result, so they need to be re-run if r=4mm data is required for them.

## Observation: log-OK cases after the failures

The patch area is the sum of all outward-facing faces on the cut plug's top, so it varies with the features at the panel centre and is not expected to be πR². That logic is unchanged and is being kept.

However, these 18 folders (Feature 5, t=7.5; s = 10, 12, 15; r = 1, 5; radii 6, 8, 10 mm) report the same area and pressure at three different radii:

| s | Area (mm²) | Pressure (MPa) |
|---|---|---|
| 10 | 56.613 | 5.2991 |
| 12 | 429.336 | 0.6988 |
| 15 | 429.735 | 0.6981 |

The value depends on `s` and is identical across the r=1, r=3 and r=5 STEP files, and the r=6 area is smaller than the r=4 area for the same part. This suggests the load was applied to a face that does not grow with the cutter radius. The likely cause is the plug selection in `SC_SCRIPT` (`plug = min(solids, key=Volume)` picks the smallest solid in the model, which can be another body once the plug grows past it). This is not confirmed against the geometry.

The `r=3` folders (s = 10, 12, 15) are not affected: the log shows the same constant values for them, but the folders still hold the correct 19 Oct 08:07 data (pressures 2.0362 / 1.194 / 0.7913 MPa at 6 / 8 / 10 mm).

Treat the 18 folders above as unverified when using the results.

## Observation: export differences in the new run

Folders written from 19 Oct 23:29 onward (untracked Feature 4 and Feature 5 results) differ from the committed 85 cases:
- No `*_Total_Deformation.xls` (3 files per case instead of 4).
- `Equivalent Elastic Strain` values are about 1e6 times larger than expected (e.g. max 78 against 5.6 MPa stress, a ratio of about 14, where the committed cases give about 1.4e-5). Stress values appear consistent.
