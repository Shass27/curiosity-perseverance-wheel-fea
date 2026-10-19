# -*- coding: utf-8 -*-
# Ansys Workbench 2025 R1/R2 journal script
# For every geometry file in INPUT_FOLDERS and every radius in RADII_MM:
#   1. load the geometry into the Static Structural system
#   2. SpaceClaim: split a circular patch (radius r) at the centre of the top skin,
#      tag it as Named Selection "NS_LOAD"
#   3. Mechanical: pressure normal to the patch so total force = 300 N,
#      solve, export nodal data + summary to .xls
#
# Run from Workbench:  File > Scripting > Run Script File...
# Or headless (cmd):   "C:\Program Files\ANSYS Inc\v251\Framework\bin\Win64\RunWB2.exe" -B -R "C:\path\ansys_batch_export.py"
#   (use v252 for 2025 R2)

import os, math, traceback

# ========================= EDIT THESE =========================
PROJECT_FILE = r"C:\Users\Pabit\Work\mosworkbench.wbpj"          # template project
INPUT_FOLDERS = [
    r"C:\Users\Pabit\Work\cad_folder\Feature_1\Feature 1",
    r"C:\Users\Pabit\Work\cad_folder\Feature 3",
]
RESULTS_ROOT = r"C:\Users\Pabit\Work\result"
GEOM_EXTS =(".step", ".stp", ".igs", ".iges", ".x_t", ".x_b", ".scdoc")
RADII_MM = [2, 4, 6, 8, 10]
TOTAL_FORCE_N = 300.0
SYSTEM_NAME = "SYS"
MATERIAL = "Al 7075-T7351"          # assigned to every body (new geometry has none)
TMP_AREA_FILE = os.path.join(os.environ.get("TEMP", r"C:\Temp"), "ns_load_area.txt")
# ==============================================================

Open(FilePath=PROJECT_FILE)
system = GetSystem(Name=SYSTEM_NAME)
if system is None:
    raise Exception("No system named '%s' in %s - check the system's Name in its Properties"
                    % (SYSTEM_NAME, PROJECT_FILE))
geometry = system.GetContainer(ComponentName="Geometry")
model = system.GetComponent(Name="Model")
modelContainer = system.GetContainer(ComponentName="Model")

# ---------------- runs INSIDE SpaceClaim (units: metres) ----------------
SC_SCRIPT = r'''
import math
R = {r_mm} / 1000.0
part = GetRootPart()
def all_bodies():
    # imported STEP/IGES bodies live in sub-components, not part.Bodies
    return list(part.GetDescendants[IDesignBody]())
def is_solid(b):
    try:
        return b.Shape.IsClosed and b.Shape.Volume > 1e-15
    except:
        return False
solids = [b for b in all_bodies() if is_solid(b)]
if not solids:
    raise Exception("No solid body found in geometry")
body = max(solids, key=lambda b: b.Shape.Volume)       # main solid

def is_cyl(f):
    return f.Shape.Geometry.GetType().Name == "Cylinder"
cyl_faces = [f for f in body.Faces if is_cyl(f) and f.Shape.Geometry.Radius < 1.0]

# Panel centre = mid-point of the largest cylindrical face (the inner skin,
# which is one unbroken face; the outer skin is cut into pieces by features)
ref = max(cyl_faces, key=lambda f: f.Area)
box = ref.Shape.BoxUV
uv = PointUV.Create((box.RangeU.Start + box.RangeU.End) / 2.0,
                    (box.RangeV.Start + box.RangeV.End) / 2.0)
c_ref = ref.Shape.Geometry.Evaluate(uv).Point

# Outer skin = radius with the largest total area among outward-facing
# (not reversed) cylindrical faces
totals = dict()
for f in cyl_faces:
    if not f.Shape.IsReversed:
        k = round(f.Shape.Geometry.Radius, 6)
        totals[k] = totals.get(k, 0.0) + f.Area
if not totals:
    raise Exception("No outward-facing cylindrical skin found")
skin_r = max(totals.keys(), key=lambda k: totals[k])
if abs(skin_r - 0.25) > 1e-4:
    raise Exception("Outer skin radius is %g m, expected 0.25 m (top face is always R250)" % skin_r)

# Move the panel centre radially onto the outer skin; outward normal is radial
axis = ref.Shape.Geometry.Axis
o, d = axis.Origin, axis.Direction.UnitVector
v = c_ref - o
v = v - d * Vector.Dot(v, d)
n = v.Direction
c = o + d * Vector.Dot(c_ref - o, d) + n.UnitVector * skin_r
before = set(all_bodies())

# Circle on the tangent plane, a little above the surface, extruded down
# through the skin -> cylinder cutter
# start well outside the ribs (they reach r = 265 mm) so the cutter passes
# through whatever sits on the geometric centre: rib, skin or both
start = c + n.UnitVector * 0.05
frame = Frame.Create(start, n)
ViewHelper.SetSketchPlane(Plane.Create(frame))
SketchCircle.Create(start, R)
ViewHelper.SetViewMode(InteractionMode.Solid)
new = [b for b in all_bodies() if b not in before]
if not new:
    raise Exception("Sketch circle did not create a disk body")
disk = new[-1]
opts = ExtrudeFaceOptions()
opts.ExtrudeType = ExtrudeType.ForceIndependent
before = set(all_bodies())
ExtrudeFaces.Execute(FaceSelection.Create(disk.Faces[0]), -n, 0.08, opts)   # to r = 220 mm, past the inner skin
new = [b for b in all_bodies() if b not in before and is_solid(b)]
cutter = new[-1] if new else disk

# Split the main solid with the cutter's side face -> plug + rest
side = [f for f in cutter.Faces if is_cyl(f)][0]
n_before = len([b for b in all_bodies() if is_solid(b)])
SplitBody.ByCutter(BodySelection.Create(body), FaceSelection.Create(side), True)
if len([b for b in all_bodies() if is_solid(b)]) <= n_before:
    # ByCutter did nothing (seen in Discovery 2025 R1): intersect with the
    # cutter solid instead, which splits the body where they overlap
    Combine.Intersect(BodySelection.Create(body), BodySelection.Create(cutter))
try:
    Delete.Execute(BodySelection.Create(cutter))
except:
    pass
for b in all_bodies():
    if not is_solid(b):                       # leftover disk surface
        Delete.Execute(BodySelection.Create(b))

# Load face = outermost face of the plug at the geometric centre, whatever it
# is (R250 skin, or the top of a rib that sits on the centre line)
solids = [b for b in all_bodies() if is_solid(b)]
if len(solids) < 2:
    raise Exception("Split did not create a plug body")
plug = min(solids, key=lambda b: b.Shape.Volume)
# Take every outward-facing face of the plug top (rib top, fillets, skin),
# not just one: on Feature 5 the rib-top face alone was a 2.5 mm2 sliver that
# Mechanical defeatured ("load could not be applied to small entity")
def out_normal(f):
    bx = f.Shape.BoxUV
    ev = f.Shape.Geometry.Evaluate(PointUV.Create((bx.RangeU.Start + bx.RangeU.End) / 2.0,
                                                  (bx.RangeV.Start + bx.RangeV.End) / 2.0))
    nv = ev.Normal.UnitVector
    return -nv if f.Shape.IsReversed else nv
load_faces = [f for f in plug.Faces if Vector.Dot(out_normal(f), n.UnitVector) > 0.1]
if not load_faces:
    raise Exception("No outward-facing top face on the load plug")
load_area = sum(f.Area for f in load_faces)

res = NamedSelection.Create(FaceSelection.Create(load_faces), Selection.Empty())
res.CreatedNamedSelection.SetName("NS_LOAD")

# Supports = the two flat end faces of the arc: radial planes (they contain the
# skin axis) at the extreme angles either side of the panel centre. Area alone
# is not enough - Feature 5 ribs are within 1% of the end-face area.
e2 = Vector.Cross(d, n.UnitVector)
radial = []
for b in all_bodies():
    for f in b.Faces:
        if f.Shape.Geometry.GetType().Name != "Plane":
            continue
        bx = f.Shape.BoxUV
        ev = f.Shape.Geometry.Evaluate(PointUV.Create((bx.RangeU.Start + bx.RangeU.End) / 2.0,
                                                      (bx.RangeV.Start + bx.RangeV.End) / 2.0))
        pn = ev.Normal.UnitVector
        if abs(Vector.Dot(pn, d)) > 1e-3 or abs(Vector.Dot(pn, ev.Point - o)) > 1e-4:
            continue                          # not a plane through the axis
        w = ev.Point - o
        radial.append((math.atan2(Vector.Dot(w, e2), Vector.Dot(w, n.UnitVector)), f))
if len(radial) < 2:
    raise Exception("Could not find the two flat end faces for the supports")
radial.sort(key=lambda t: t[0])
# keep every face at either extreme angle (an end may be split into pieces)
lo, hi = radial[0][0], radial[-1][0]
ends = [f for a, f in radial if abs(a - lo) < 1e-3 or abs(a - hi) < 1e-3]
res = NamedSelection.Create(FaceSelection.Create(ends), Selection.Empty())
res.CreatedNamedSelection.SetName("NS_FIX")

# Share topology so plug and skin mesh conformally
part.ShareTopology = ShareTopologyType.Share

f = open(r"{area_file}", "w"); f.write(repr(load_area * 1e6)); f.close()   # mm^2
'''

# ---------------- runs INSIDE Mechanical ----------------
MECH_SCRIPT = r'''
import os
out_dir = r"{out_dir}"
base = r"{base}"
P = {pressure}                                     # MPa = N/mm^2
model = ExtAPI.DataModel.Project.Model
for ns in model.NamedSelections.Children:
    if ns.ScopingMethod == GeometryDefineByType.Worksheet:
        ns.Generate()
    if ns.TotalSelection == 0:
        raise Exception("Named Selection '%s' is empty for %s" % (ns.Name, base))
for b in model.Geometry.GetChildren(DataModelObjectCategory.Body, True):
    b.Material = "{material}"
analysis = model.Analyses[0]
prs = [c for c in analysis.Children if c.GetType().Name == "Pressure"]
pr = prs[0] if prs else analysis.AddPressure()      # template may not have one
nss = [ns for ns in model.NamedSelections.Children if ns.Name == "NS_LOAD"]
if not nss:
    raise Exception("Named Selection NS_LOAD not transferred to Mechanical for %s" % base)
pr.Location = nss[0]

# Template supports/Force were picked on the old geometry: scope one Fixed
# Support to NS_FIX, suppress the rest and the Force (load is the pressure)
fix_ns = [ns for ns in model.NamedSelections.Children if ns.Name == "NS_FIX"]
if not fix_ns:
    raise Exception("Named Selection NS_FIX not transferred to Mechanical for %s" % base)
fixes = [c for c in analysis.Children if c.GetType().Name == "FixedSupport"]
fx = fixes[0] if fixes else analysis.AddFixedSupport()
fx.Location = fix_ns[0]
fx.Suppressed = False
for c in fixes[1:] + [c for c in analysis.Children if c.GetType().Name == "Force"]:
    c.Suppressed = True
pr.Magnitude.Output.DiscreteValues = [Quantity(P, "MPa")]
sol = analysis.Solution
if not [r for r in sol.Children if hasattr(r, "Maximum")]:
    sol.AddTotalDeformation()
    sol.AddEquivalentStress()
analysis.Solve(True)
if str(sol.Status) != "Done":
    msgs = ["%s: %s | %s" % (m.Severity, m.DisplayString, getattr(m, "Source", ""))
            for m in ExtAPI.Application.Messages]
    setup = ["%s (%s, %s)" % (c.Name, c.GetType().Name, c.ObjectState) for c in analysis.Children]
    setup.append("Mesh state %s, nodes %s" % (model.Mesh.ObjectState, model.Mesh.Nodes))
    setup.append("Materials: %s" % [m.Name for m in model.Materials.Children])
    for b in model.Geometry.GetChildren(DataModelObjectCategory.Body, True):
        setup.append("Body %s: material=%r state=%s" % (b.Name, b.Material, b.ObjectState))
    raise Exception("Solve did not finish (status %s)\nAnalysis tree: %s\nMessages:\n%s"
                    % (sol.Status, ", ".join(setup), "\n".join(msgs)))
rows = ["Result\tMinimum\tMaximum\tAverage\tUnit"]
for r in sol.Children:
    try:
        mx = r.Maximum
    except:
        continue
    if mx is None:
        continue
    rname = r.Name.replace(" ", "_")
    r.ExportToTextFile(os.path.join(out_dir, base + "_" + rname + ".xls"))
    rows.append("%s\t%g\t%g\t%g\t%s" % (r.Name, r.Minimum.Value, mx.Value,
                                        r.Average.Value, mx.Unit))
rows.append("")
rows.append("Applied pressure (MPa)\t%g" % P)
f = open(os.path.join(out_dir, base + "_summary.xls"), "w")
f.write("\n".join(rows))
f.close()
'''

# SendCommand (Discovery and Mechanical) swallows script errors, so run each
# script inside try/except and have it write the traceback to ERR_FILE
ERR_FILE = TMP_AREA_FILE + ".err"
def guarded(script):
    if os.path.exists(ERR_FILE):
        os.remove(ERR_FILE)
    return ("import traceback\ntry:\n"
            + "\n".join("    " + l for l in script.splitlines())
            + "\nexcept:\n    _e = open(r\"%s\", \"w\"); _e.write(traceback.format_exc()); _e.close()\n"
            % ERR_FILE)
def read_err():
    if not os.path.exists(ERR_FILE):
        return "no output"
    fe = open(ERR_FILE)
    msg = fe.read()
    fe.close()
    return msg

log = []
for folder in INPUT_FOLDERS:
    for fname in sorted(os.listdir(folder)):
        if not fname.lower().endswith(GEOM_EXTS):
            continue
        path = os.path.join(folder, fname)
        stem = os.path.splitext(fname)[0]
        for r_mm in RADII_MM:
            base = "%s_r%dmm" % (stem, r_mm)
            # Results\<Feature N>\<step file>\r<R>mm\
            out_dir = os.path.join(RESULTS_ROOT, os.path.basename(folder), stem, "r%dmm" % r_mm)
            if not os.path.isdir(out_dir):
                os.makedirs(out_dir)
            try:
                geometry.SetFile(FilePath=path)                 # fresh geometry each run
                if os.path.exists(TMP_AREA_FILE):
                    os.remove(TMP_AREA_FILE)                    # never reuse a stale area
                # SpaceClaim is not installed on this machine (v251\scdm has no
                # SpaceClaim.exe); IsSpaceClaimGeometry silently falls back to
                # DesignModeler, which runs SendCommand as JScript. Discovery
                # runs the same SpaceClaim Python API.
                geometry.Edit(IsDiscoveryGeometry=True)
                geometry.SendCommand(Language="Python", Command=guarded(
                    SC_SCRIPT.format(r_mm=r_mm, area_file=TMP_AREA_FILE)))
                geometry.Exit()
                if not os.path.exists(TMP_AREA_FILE):
                    raise Exception("Geometry script failed:\n" + read_err())

                fa = open(TMP_AREA_FILE)                         # close explicitly: IronPython keeps
                area = float(fa.read())                          # it locked and the next run's
                fa.close()                                       # os.remove fails (Errno 13)
                pressure = TOTAL_FORCE_N / area

                model.Refresh()
                modelContainer.Edit(Interactive=False)
                summary = os.path.join(out_dir, base + "_summary.xls")
                if os.path.exists(summary):
                    os.remove(summary)
                modelContainer.SendCommand(Language="Python", Command=guarded(
                    MECH_SCRIPT.format(out_dir=out_dir, base=base, pressure=pressure,
                                       material=MATERIAL)))
                modelContainer.Exit()
                if not os.path.exists(summary):
                    raise Exception("Mechanical script failed:\n" + read_err())
                log.append("OK      %s  r=%dmm  A=%.3f mm2  P=%.4f MPa" % (path, r_mm, area, pressure))
            except Exception as e:
                log.append("FAILED  %s  r=%dmm  ->  %s\n%s" % (path, r_mm, e, traceback.format_exc()))
                for c in (geometry, modelContainer):
                    try:
                        c.Exit()
                    except:
                        pass

f = open(os.path.join(RESULTS_ROOT, "batch_log.txt"), "w")
f.write("\n".join(log))
f.close()
