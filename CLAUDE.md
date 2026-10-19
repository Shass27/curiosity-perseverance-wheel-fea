# MOS_Project

Batch FEA of curved R250 panels in Ansys Workbench 2025 R1. For every STEP file and every patch radius, a 300 N load is applied on a circular patch at the panel's geometric centre, the model is solved, and the results are exported.

## Layout
- `ansys_batch_export.py`: the Workbench journal that drives everything (IronPython 2.7).
- `Ansys simulation template/Workbench.wbpj` + `Workbench_files/`: the template project, with system name `SYS` (Static Structural). The script never saves it.
- `CAD_models/Feature 1..5/*.STEP`: the input geometry, 17 files in total. The names encode the parameters, e.g. `t=7.5_s=10_r=3`.
- `Simulation results/Feature N/<step file>/r<R>mm/`: the output. Each folder holds `*_summary.xls` (min/max/avg per result plus the applied pressure) and nodal `*_Equivalent_Stress.xls`, `*_Equivalent_Elastic_Strain.xls` and `*_Total_Deformation.xls`.
- `Simulation results/batch_log.txt`: one OK/FAILED line per case. FAILED lines include the full traceback.

## Running
Close Workbench first, or the project lock blocks the run. The command below is for PowerShell, which needs the leading `&`:
```powershell
& "C:\Program Files\ANSYS Inc\v251\Framework\bin\Win64\RunWB2.exe" -B -R "C:\Users\shasw\Documents\MOS_Project\ansys_batch_export.py"
```
A case takes about 1.5 min, and the full run (85 cases) about 2–2.5 h. If a crash leaves `Ansys simulation template\Workbench_files\.lock` behind and no Ansys process is running, delete the lock.
The settings are at the top of the script: `INPUT_FOLDERS`, `RADII_MM = [2,4,6,8,10]`, `TOTAL_FORCE_N = 300`, `MATERIAL = "Al 7075-T7351"` and `RESULTS_ROOT`.
To test, run a copy of the script that points `INPUT_FOLDERS` at a scratch folder with one STEP file and sets `RADII_MM` to `[2]` or `[2, 10]`.

## How the script works
1. **Geometry, in Discovery** (`SC_SCRIPT`, units in m). SpaceClaim is **not installed**. `Edit(IsSpaceClaimGeometry=True)` silently opens DesignModeler, which then runs the Python as JScript, so the script must use `Edit(IsDiscoveryGeometry=True)`.
   - Bodies sit in sub-components, so collect them with `part.GetDescendants[IDesignBody]()`, not `part.Bodies`.
   - Panel centre: the UV mid-point of the largest cylindrical face, which is the unbroken inner skin (R240, or R242.5 on Feature 4). The centre is then moved radially onto the outer skin.
   - The outer skin is always **R250**. The script raises an error if it isn't.
   - Cutter: a circle of radius R starting at r = 300 mm, extruded 80 mm inward. `SplitBody.ByCutter` does nothing in Discovery, so the script falls back to `Combine.Intersect`.
   - `NS_LOAD`: every outward-facing face of the cut plug's top, at the geometric centre regardless of what's there. On Features 4 and 5 a rib sits on the centre, so the loaded area is larger than πR².
   - `NS_FIX`: the two flat end faces of the arc, which are planes through the skin axis at ±22.5°. Don't pick them by area: the Feature 5 ribs are within 1% of the end faces' area.
   - Shared topology is turned on. The patch area in mm² is written to `%TEMP%\ns_load_area.txt`.
2. **Mechanical** (`MECH_SCRIPT`): assigns `MATERIAL` to all bodies, because new geometry arrives with none.
   - Scopes Pressure to `NS_LOAD` with P = 300 N / area. A Pressure is added if the template has none.
   - Scopes the first Fixed Support to `NS_FIX`, and suppresses Fixed Support 2 and the template Force.
   - Solves, checks that the status is Done, and exports.

## Gotchas
- `SendCommand` swallows script errors in both Discovery and Mechanical. `guarded()` wraps each script in try/except and writes the traceback to `%TEMP%\ns_load_area.txt.err`, and `read_err()` surfaces it.
- IronPython keeps files locked until they're closed explicitly. Always call `close()`, or the next case's `os.remove` fails with Errno 13.
- Template supports and loads that were picked directly on geometry break when the geometry is replaced. Use named selections.
- Keep `{` and `}` out of `SC_SCRIPT` and `MECH_SCRIPT` except for the `.format` placeholders. Use `dict()` instead of `{}`.

## Status
- 19 Oct 2026: the full run finished with 85/85 OK.
