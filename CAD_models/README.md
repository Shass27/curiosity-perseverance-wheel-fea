# Parametric CAD models

STEP files for the two FEA studies in this repository.

## Feature 1–5 (surrogate model study)

Five grouser features, each swept over three parameters:

| Parameter | Meaning | Values |
|---|---|---|
| `t` | skin thickness (mm) | 2, 7.5 |
| `s` | grouser angle (deg) | 10, 12, 15 |
| `r` | fillet radius (mm) | 1, 3, 5 |

Each feature has 2 × 3 × 3 = 18 files. Features 4 and 5 also have `t=7.5_s=6_r=3`, which makes **92 files** in total.

```text
CAD_models/
├── Feature 1/   t=2_s=10_r=1.STEP … t=7.5_s=15_r=5.STEP   (18)
├── Feature 2/   (18)
├── Feature 3/   (18)
├── Feature 4/   (18 + t=7.5_s=6_r=3)
├── Feature 5/   (18 + t=7.5_s=6_r=3)
└── Tier 1/      a=2, 4, 6, 8, 10 .STEP   (flat segment for the failure analysis; a = load-patch radius, mm)
```

Note: `Feature 4/t=7.5_s=12_r=5 .STEP` has a stray space before the extension, so trim names when parsing.
