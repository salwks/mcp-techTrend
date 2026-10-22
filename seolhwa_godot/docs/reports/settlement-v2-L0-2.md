# 고을 생성기 v2 — 도시계획 기초부터 층층이 (Layers 0–2 설계, Claude ↔ Codex 세션 A)

사용자: "도시계획의 기초부터 차곡 쌓이면 되는 거라고 생각했는데" / "도시 빌더 제대로 만들어 줘". 원칙: 층(layer)마다 설계 → 2D 평면도 생성기로 구현 → 서로 다른 4곳에서 검증 → 승인 뒤 다음 층. 고을마다 손으로 만들지 않는다(입력: 지형·물·길 데이터 + 규모 + 선택 힌트 + 고정 이야기 장소).

## 1회차 — 레이어 구성과 Layer 0–2 초안 (Codex)
**The generator should allocate viable land to a settlement program, then solve its enclosing frame.** Buildings come later. The target illustration is useful for civic hierarchy, connected streets, cultivated edges, and a readable enclosure; its particular composition should not become a template.

Below, **[H]** means historical evidence, **[D]** a proposed generator default. Numerical defaults are design assumptions unless identified otherwise.

**1. Ordered layer stack**

Each layer produces versioned data, diagnostics, and a north-up plan with scale bar. Later layers request revisions upstream; they cannot silently change earlier geometry.

| Layer / purpose | Inputs → output data | Hard invariants | Verification drawing |
|---|---|---|---|
| **0 Site:** discover opportunities and constraints | Terrain, water, routes, land use → fields, candidate basins, exclusions | Preserve source data; flag missing coverage | Relief, drainage, suitability, candidate axes |
| **1 Program:** establish demand | Tier, regional period/profile → households, institutions, area ranges, relationships | Budget balances; mandatory functions retained | Area bars and adjacency diagram |
| **2 Frame:** establish territorial structure | Site + program + locks → footprint, wall, gates, civic reserves, primary corridors | Valid enclosure, capacity, access, drainage | Frame over contours and hazard fields |
| **3 Districts:** organize activities | Frame + demand → civic, residential, commercial, agricultural allocation | Account for every household and reserved area | Land-use polygons; class/livelihood distributions |
| **4 Streets/water:** establish circulation | Gates, reserves, terrain → planar street graph, crossings, drainage corridors | Connected access; feasible grades; explicit crossings | Network, widths, grades, drainage |
| **5 Blocks/parcels:** allocate land | Streets + districts → shared-edge subdivision, easements | No overlaps; every occupied parcel accessible | Numbered parcels and frontage |
| **6 Compounds/terrain:** organize domestic and institutional life | Parcels + programs → buildings, courts, terraces, entrances | Functional clearances; feasible earthworks | Roofless compound plans and level annotations |
| **7 Boundaries:** resolve enclosure | Shared edges + buildings → walls, fences, gates, retaining structures | Shared edges emitted once; every opening typed | Closure graph and junction details |
| **8 Dressing:** express activity | Courts, circulation, water, cultivation → planting, props, wear | Preserve entrances, drainage, interaction space | Activity and vegetation overlay |
| **9 Bake:** compile | Validated layers → JSON, terrain deltas, navigation, assets | Deterministic output; dependency hashes | Automated report plus representative views |

**2. Layer 0 — site analysis**

Use explicit coordinate metadata: horizontal/vertical scale, true north, source resolution. Compute physical game-world slopes from the actual heightfield; retain source-geography distances separately. Never assume vertical compression equals horizontal compression.

[D] Analyze the proposed search region plus a **1 km world-space halo**; expand hydrological coverage to upstream catchments where available. Missing upstream coverage lowers confidence.

Compute:

- **Slope/aspect:** Gaussian-smooth terrain at σ=2 m; use central derivatives \(p=z_x,q=z_y\).  
  \(\theta=\arctan\sqrt{p^2+q^2}\); aspect is the downslope vector. Retain unsmoothed relief for construction checks.
- **Sun:** horizon angles in 16 directions; integrate unoccluded incidence \(\max(0,n\cdot s_t)\) hourly on winter-solstice and equinox days at regional latitude. Flat ground has no preferred aspect.
- **Relative elevation:** \(TPI_r=z-\operatorname{mean}_r(z)\), at radii 30, 100, 300 m. Also record local relief and percentile elevation.
- **Drainage:** preserve known lakes; condition a separate DEM to mapped channels. Resolve artificial pits/flats, derive D8 receivers, and accumulate \(A_i=a_{\rm cell}+\sum A_{\rm upstream}\). Preserve conditioning depth as uncertainty. These are standard hydrological operations; GRASS documents accumulation and routing alternatives. [GRASS documentation](https://grass.osgeo.org/grass-stable/manuals/r.watershed.html)
- **Flood susceptibility:** derive channel-connected height \(H=z-z_{\rm receiving\ channel}\), bank distance \(d\), and low-ground connectivity. [D] Screen connected inundation at channel stages +1/+3/+5 m. Supplement with  
  \(R=\max[I_{+3m},e^{-d/60}\operatorname{clamp}(1-H/5,0,1)]\).  
  These are scenario screens, not flood probabilities. Reject permanent occupation in the connected +3 m envelope by default. Coastal sites require tide/surge scenarios; river distance alone cannot establish safety.
- **Buildability:** water, flood exclusions, unstable slopes, locks, drainage corridors. [D] Ordinary housing prefers ≤8°, rejects >15°; civic compounds prefer ≤5°, reject >10°. Evaluate an entire minimum compound envelope, including predicted cut/fill; a suitable centre pixel is insufficient.
- **Water access:** least-cost walking distance to usable freshwater banks/springs; distinguish access from potability. [D] Prefer ≤150 m, penalize >300 m. Require a water-supply reservation; groundwater availability remains unknown without additional data.
- **Route access:** planarize existing routes and crossings; compute least-cost connectors using \(c=1+8\tan^2\theta\), excluding unbridged water. Record through-route importance and detour cost.
- **Agricultural relationship:** reachable cultivable area within 300/600 m, irrigation connections, and farmland displaced. Preserve productive lowlands where safer terraces can accommodate houses.
- **View/prominence:** sampled terrain viewsheds, horizon enclosure, and summit prominence measured above the connecting saddle; distinguish civic visibility from defensive command.

**진산/안산 are candidate interpretations, not terrain facts.** [D] Extract peaks/ridges at 100–300 m smoothing scales. For candidate civic point \(x\), test facing bearings every 15°. Rank rear ridges 100–1,000 m away by prominence, visible angular extent, and connection to the civic spur. Rank lower foreground hills in the opposite sector as 안산. Reward rear shelter, open sunny frontage, and accessible water; permit absent or ambiguous matches.

For **수구**, trace basin drainage through the candidate landform’s downstream opening; identify high-flow channels passing a narrow valley cross-section. Recompute outlet intersections after Layer 2 chooses its boundary. There can be several outlets; a 수구 does not automatically imply a traffic gate.

For each tier, first reject candidates unable to contain its minimum program or satisfy locks. Then [D]:

\[
S_T=.25B+.20F+.15W+.15A+.10K+.10P+.05D
\]

All terms are normalized to [0,1]: buildable capacity, flood safety, water access, route access, cultivation, landscape relationships, defense. For 산성 transfer .10 from cultivation/access to defense. Market towns transfer .10 from landscape/defense to access.

Score **candidate territories**, including bottlenecks and contiguous capacity, rather than averaging attractive pixels.

**3. Layer 1 — settlement program**

Administrative rank, economic role, and physical setting are separate attributes. A market town need not be an 읍치; 산촌 and 어촌 are setting/livelihood profiles. Encode these in tier presets to keep per-town inputs small. Period is a regional setting.

[D] Initial **represented** household budgets—not historical census estimates:

| Preset | Households | Elite / clerical-specialist / ordinary-dependent households |
|---|---:|---:|
| Small 군·현 읍치 | 80 | 5 / 15 / 80% |
| Medium 목·부 읍치 | 180 | 7 / 18 / 75% |
| Large regional seat | 360 | 8 / 22 / 70% |
| Market town | 90 | 3 / 12 / 85% |
| 양반 village | 40 | 25 / 5 / 70% |
| 민촌 / 산촌 / waterside village | 30 / 18 / 35 | 3 / 2 / 95% |

[D] Population = households ×4.5, reported as an estimate. Record legal status, wealth, livelihood, and dependent membership separately: 노비 may belong within another household; merchants are not a legal class.

**Institution program:**

- 읍치: distinct 객사 and 동헌 reserves; private 내아 associated with 동헌; 향청, 작청/질청, administrative storage, 옥; regional additions for 감영, military command, or transport.
- Reserve 향교, 사직단, 여단, 성황 facilities in the wider settlement territory; do not require them inside walls.
- Villages: communal water, ritual/community place; lineage village adds 종가/사당 and potentially 서당. Do not automatically generate a 서원.
- Use generic administrative grain storage unless evidence/profile supports **사창**. Its institutional history and nineteenth-century revival make it an unsafe universal label. [AKS account](https://waks.aks.ac.kr/rsh/dir/rview.aspx?dataID=AKS-2013-CKD-1240001_DIC@00010895&rshID=AKS-2013-CKD-1240001)

[H] Civic and ritual facilities formed related landscapes, with local variation. Use 좌묘우사 and rear-mountain relationships as soft preferences. [읍치 landscape research](https://journal.kgeography.or.kr/articles/xml/9RKe/)

[D] Residential parcel medians, before ×1.44 area scaling: ordinary urban 350 m², clerical/specialist 900, elite 1,800; ordinary village 550. Use distributions from the repo’s metrics, not identical lots.

[D] Small-seat compound reserves: 객사 3,000 m², 동헌·내아 4,000, other administration/storage/prison 3,000 combined, 향교 3,000 outside if feasible. Medium/large factors: ×1.5/×2.5. These are provisional envelopes.

\[
A_{\rm core}=
\frac{\sum n_c a_c+A_{\rm institutions}+A_{\rm market}+A_{\rm special}}
{1-f_{\rm circulation}-f_{\rm open/cultivated}}
\]

[D] Start fractions at .15 and .20; explicitly separate intra-/extramural budgets.

[H] Five-day periodic markets were widespread. [National Institute of Korean History](https://contents.history.go.kr/mobile/km/view.do?levelId=km_016_0030_0020_0020) [D] Reserve 15 m² per simultaneous stall including circulation, initially 20/40/80 stalls by 읍치 tier. Test gate-outside and internal through-route locations.

**Compression:** scale local dimensions ×1.2 once. Compressing a historical footprint ×0.3 leaves approximately \((.3/1.2)^2=1/16\) household capacity before civic reservations. Reduce represented households, allow extramural growth, or enlarge the footprint. Never squeeze full-size programs into a prescribed square.

**4. Layer 2 — settlement frame**

Jointly solve footprint, civic reserves, gates, and primary corridors:

```text
enumerate feasible civic sites, bearings, wall types
reserve mandatory envelopes, access and drainage
generate candidate boundaries
solve route-to-gate assignments and primary corridors
measure usable capacity and construction costs
reject invariant failures; rank feasible alternatives
```

[D] Retain eight alternatives; use deterministic seeds and bounded search. Footprint means occupied territory; wall interior may additionally contain hills, fields, and defensive land.

- **평지성:** seed oriented rectangles and rounded quadrilaterals, aspect 1:1–1:1.6. Orient toward candidate landscape/civic axes; optimize boundary vertices against flood exclusions, capacity, earthworks, and perimeter. Square-ish is a prior, not a requirement.
- **평산성:** seed an enclosure combining habitable terrace and rear hill. Generate upper arcs along ridges/shoulders and lower arcs around usable land; connect across feasible side slopes. Charge separately for enclosed unbuildable hillside.
- **산성:** build a ridge–saddle graph, augmented with feasible cross-valley links. Beam-search simple cycles enclosing required terraces and water access; reward command, penalize uphill exterior dominance and construction difficulty. Do not force a radial contour or convex hull.
- **Unwalled settlements:** grow connected residential capacity along feasible access branches, reserving cultivation and waterfront working areas; retain distinct clusters where terrain requires them.

For gates, cluster external route approaches by bearing and demand; test wall intersections and nearby low-grade saddles. Minimize connector cost, detour, earthworks, and defensive exposure. [D] Prefer 2–4 gates, without requiring cardinal placement. Reserve drainage crossings independently as typed 수문/culverts.

Choose civic reserves on safe, accessible benches with rear support. Preserve 객사’s symbolic prominence and 동헌/내아 functional separation; the primary approach may bend. Class location follows access, livelihood, lineage, and land quality—not fixed north/south zoning.

**Hard acceptance:** one simple closed wall cycle; gate intervals retain boundary topology; no crossings or unexplained gaps; all drainage intersections engineered; locks preserved; required envelopes and buffers fit; gates connect external routes to civic access; [D] primary corridors ≤10% grade. Failure returns named constraints and alternatives.

Verify Layers 0–2 on four contrasting sites: flat river terrace, hill-backed basin, steep ridge/valley, and coastal/estuarine ground. Draw contours, hazards, usable capacity, civic envelopes, axes, gates, drainage openings, and route connections. Compare identical presets across sites before approving the next layer.
## 2회차 — Claude 반론
1. **Capacity is driven by the game world, not history.** Our world compresses geography; each town already has an in-world area allotted by the region map (e.g. Namwon's walled town occupies roughly a few hundred metres per side in-world; region data has the existing town placement and the farm parcels around it). Your note that a historical footprint ×0.3 leaves ~1/16 capacity is exactly our situation. Proposal: Layer 1 sizes the program FROM the available footprint (capacity-first): after civic minimums (compact variants allowed), fill residential with represented households keeping class/livelihood proportions and the morphology ratios; report "represented vs historical" households. Footprint can grow only within limits set by the region map (roads, rivers, farmland, neighbouring places). Agree? Give the exact procedure.
2. **Implementation platform.** Hydrology on a 4353×2113 heightfield, planar graphs, robust polygon booleans/offsets/straight skeleton are weak in GDScript. Proposal: the offline bake layers are a Python tool (numpy/scipy/shapely available; networkx if needed), deterministic, outputting versioned JSON + SVG plan drawings; Godot only loads results. Agree? Any library choices/risks (shapely precision, snapping tolerance, deterministic ordering)?
3. **Test sites.** We need 4 contrasting sites from our existing region data where possible (region_data/* directories listed below), otherwise synthetic heightfields. Specify the synthetic generator (parametric terrain recipes for flat river terrace, hill-backed basin, steep ridge/valley, estuary) so tests are reproducible.
4. **Verification drawings.** Specify the SVG layer set and legend for Layers 0–2 (so the owner can judge), plus automated checks per layer.
5. **Scoring weights and defaults** must be data (a rules file with source/confidence), not code. Provide the rules file structure.
6. **Scope cut for the first implementation pass**: what is the minimum of Layers 0–2 that still yields correct frames on the 4 sites (e.g. simplified flood screen, 진산 detection optional), and what is deferred.

Output: the FINAL Layers 0–2 spec (≤1800 words) with data schemas (JSON), algorithms with defaults, module/file layout for the Python tool, test plan with acceptance criteria.
GG_HANYANG
GS_GYEONGJU
GW_GANGNEUNG
HG_HAMHEUNG
HH_HWANGJU
JJ_JEJU

## 2회차 — 확정 명세 (Codex)
**Agreed: capacity comes from the allotted game-world territory.** Tier selects institutional obligations and social/economic proportions; it does not prescribe household count. The following replaces the earlier population-first proposal. All numerical defaults below are provisional rules, not historical measurements.

**1. Capacity-first contract and procedure**

Distinguish:

- `preferred`: existing town allocation.
- `allowed`: maximum permitted territory.
- `protected`: farmland, neighbouring places, water, and other exclusions.
- `locks`: immutable footprints, entrances, and required approaches.

Existing roads remain access constraints; they are not automatically forbidden territory.

The inspected region data contains `settlements.core`, `bbox`, `area_m2`, land-use rasters, routes, and sometimes existing walls. These have different meanings: **do not interpret a derived `bbox` as permission to expand**. Adapter precedence: explicit planning envelope → existing `core`/wall interior → conservative allocation reconstructed from recorded area around the settlement centre. Expansion defaults to zero without an explicit allowed envelope. Report disagreements between these representations.

For each candidate frame:

```text
1. Intersect allocation with allowed territory; subtract protected land.
2. Reserve locks, mandatory civic envelopes, water access and primary corridors.
3. Try civic variant bundles, largest first; retain each feasible bundle.
4. Measure remaining connected, accessible residential land.
5. Solve maximum represented household count under area constraints.
6. Validate distribution across usable components; reject inaccessible capacity.
7. Rank feasible solutions; retain alternatives and capacity diagnostics.
```

For residential component \(j\):

\[
\sum_c n_{jc}a_c \le (1-f_{\rm lanes}-f_{\rm cultivation})A_j
\]

Defaults: lanes `.12`, cultivation/open ground `.20`; primary corridors and civic courts are already subtracted. Parcel areas include domestic courtyards, not public lanes.

Class counts use largest-remainder rounding of profile proportions. Livelihood counts are a separate conditional distribution. Preserve morphology by using parcel-area distributions and minimum component widths; do not shrink parcels to increase counts. Initial historical-space medians: ordinary urban 350 m², specialist 900, elite 1,800; ordinary rural 550. Multiply areas by **1.44 once**.

Civic variants specify actual envelope dimensions, entrance clearance, courtyard minimums, and functional contents. `compact` reduces ancillary provision while retaining named functions. Select the largest variant that leaves the profile’s residential minimum; otherwise report `insufficient_capacity`.

Output household counts are **planning capacity estimates**, pending parcel verification in later layers. Report historical households and represented/historical ratio only when a sourced historical count exists; otherwise use `null`.

**2. Python platform, files, and schemas**

Agreed: Python bake; Godot loads validated JSON.

Use NumPy/SciPy for rasters, Pillow for 16-bit PNG decoding, Shapely 2.x/GEOS for geometry, and NetworkX only for small vector graphs. Avoid millions of NetworkX raster nodes. Pin exact dependency versions, including GEOS.

Shapely precision reduction can split or collapse geometry; validate after every operation rather than treating snapping as repair. [Shapely documentation](https://shapely.readthedocs.io/en/stable/reference/shapely.set_precision.html)

Defaults: geometry grid **0.05 m**; optional endpoint matching **0.10 m**, only between semantically compatible endpoints. Never proximity-snap unrelated boundaries. Reject repairs changing component count, locks, or area beyond the configured tolerance. No straight skeleton is required for Layers 0–2.

Canonicalize ring orientation/start vertex, component ordering, feature IDs, graph traversal, and ties. Use stable hashes, seeded PCG64, sorted JSON keys, and no timestamps in reproducible artifacts. Determinism is guaranteed within the pinned environment.

```text
tools/settlement/
  cli.py, adapters/region.py, schemas/
  raster.py, site.py, program.py, frame.py
  geometry.py, routing.py, validate.py, svg.py
  fixtures.py, rules/default.json, tests/
```

CLI:

```text
python -m tools.settlement.cli bake --region JL_NAMWON_UNBONG \
  --settlement namwon_eup --rules rules/default.json --out OUTPUT
```

Normalized input contract:

```json
{
  "schema": "settlement-input/1",
  "id": "namwon_eup",
  "seed": 2203,
  "coordinates": {"units": "world_m", "north_xz": [0, -1]},
  "height": {
    "file": "height.png",
    "origin_xz": [-4352, -2112],
    "cell_m": 2,
    "decode": {"min": 3, "max": 730, "denominator": 65535},
    "already_remapped": true
  },
  "tier": "medium_eupchi",
  "wall_type": "plain",
  "territory": {
    "preferred": "preferred.geojson",
    "allowed": "allowed.geojson",
    "protected": "protected.geojson"
  },
  "features": "features.geojson",
  "locks": "locks.json",
  "historical_households": null
}
```

Region PNG heights already encode game heights; **do not apply `height.remap` again**. Preserve remap metadata for provenance. River points use `[x,z,y]`; roads commonly use `[x,z]`. Handle large water bodies using water masks and `sea.kind`: PA_PYEONGYANG’s `sea` represents a river.

Output:

```json
{
  "schema": "settlement-plan/1",
  "status": "valid",
  "provenance": {
    "generator": "1",
    "rules_hash": "sha256",
    "input_hashes": {},
    "dependencies": {}
  },
  "site": {"fields": "site-fields.npz", "features": "site.geojson"},
  "program": {
    "households": {},
    "institutions": [],
    "area_ledger": {},
    "historical_households": null,
    "representation_ratio": null
  },
  "frame": {
    "territory": {},
    "wall_ring": [],
    "openings": [],
    "civic_reserves": [],
    "primary_corridors": [],
    "water_access": []
  },
  "diagnostics": [],
  "alternatives": []
}
```

Geometry uses GeoJSON Polygon/MultiPolygon/LineString conventions with `[x,z]`; elevations are separate profiles. Openings reference wall chainage intervals and type `gate|water_passage`.

**3. Algorithms and rules as data**

Layer 0 computes smoothed slope/aspect, 30/100/300 m relative elevation, water distance, flood screen, usable components, route accessibility, and farmland displacement.

- Gaussian σ=2 m; \(\theta=\arctan\|\nabla y\|\).
- Housing slope ≤15°, civic ≤10°; preferred thresholds 8°/5°.
- Flood screen: interpolate nearest water-surface elevation \(W(x)\); at offsets +1/+3/+5 m, retain components of \(y\le W+\Delta\) connected to mapped water. Exclude +3 m from occupation. Flag missing/inconsistent water elevations.
- Reserve mapped drainage corridors: channel width plus 3 m each side.
- A* uses 2 m cells, eight neighbours, no diagonal corner cutting; edge cost \(l(1+8g^2)\), where \(g\) is grade. Primary grade limit 10%; corridor width 7.2 m.
- Water access target 150 m, screening limit 300 m; record freshwater uncertainty.

Layer 2 enumerates civic sites every 10 m and bearings every 15°, including supplied axes. Fit civic envelopes using polygon containment and terrain samples; compact civic envelopes allow maximum 2 m terrain relief before requiring a later terrace design.

Frame candidates:

- **평지성:** oriented rectangles/chamfered rectangles, aspect 1–1.6; dimensions in 10 m increments within allocation. Vertex moves of 2 m, in fixed order, improve the objective while preserving validity.
- **평산성:** extract closed components of smoothed terrain sublevel sets at 2 m elevation intervals; combine with feasible rear-ridge arcs, then validate the resulting complete cycle.
- **산성:** enumerate enclosed high-ground components from terrain superlevel sets at 2 m intervals. These provide ridge-oriented cycle candidates; retain only those enclosing civic benches and water access. A failed search reports `no_candidate_found`, not proven infeasibility.
- **Unwalled:** connected usable components linked by reserved corridors; retain separate clusters when justified.

For gates, sample boundary every 4 m. Assign route-approach clusters to 2–4 gates by connector cost; enumerate assignments for the eight best candidates per cluster. Every route/wall intersection must become a gate or an explicit reroute. Drainage intersections receive independent water passages.

Rules structure:

```json
{
  "schema": "settlement-rules/1",
  "sources": {
    "metrics": {"path": "docs/reports/settlement-metrics.md"},
    "design": {"description": "Session A provisional defaults"}
  },
  "parameters": {
    "geometry.grid": {
      "value": 0.05, "unit": "world_m",
      "source": "design", "confidence": "provisional",
      "kind": "engineering"
    }
  },
  "profiles": {},
  "institution_variants": {},
  "objectives": {},
  "acceptance": {}
}
```

Every tunable scalar/distribution follows that metadata format. Objective weights: civic fit `.25`, access `.25`, compactness `.20`, terrain economy `.20`, axis preference `.10`; all components use explicit fixed normalization ranges. Hard constraints precede scoring. Retain eight alternatives. Missing axis evidence contributes neutrally.

**4. Reproducible sites**

Real-data integration candidates:

1. `JL_NAMWON_UNBONG/namwon_eup`: terrace.
2. `GS_GYEONGJU/bulguksa_village`: hill-backed setting.
3. `JL_NAMWON_UNBONG/banseon`: valley.
4. `GW_GANGNEUNG/anmok_village`: estuary.

Confirm terrain statistics before assigning these categories. Use synthetic fixtures for guaranteed wall-type coverage.

Synthetic domain: \(x,z\in[-512,512]\), 2 m cells, north = −z; no noise. Define \(G(a,b,s)=e^{-((x-a)^2+(z-b)^2)/(2s^2)}\).

- Terrace: \(y=4+.004z+5[1+\tanh((z+80)/12)]\); river `z=-140`, width 20, surface 3.
- Basin: terrace + \(45G(0,-200,140)+25G(-240,0,100)+25G(240,0,100)\); river `z=180`, surface 4.
- Ridge: \(y=20+.12|x|+70e^{-((\sqrt{x^2+z^2}-180)/65)^2}\); stream `x=0`, surface sampled from terrain minus 1 m.
- Estuary: \(y=.025(160-x)+8G(-160,0,140)\); sea `x≥160`, level 0; river `z=0`, width 20, surface 0.

Persist terrain, water, two approach roads, allocation polygons, and hashes in fixture manifests.

**5. Drawings and acceptance**

SVG groups: relief/5 m contours; preferred/allowed/protected boundaries; blue water; cyan flood bands; hatched exclusions; green usable land; brown farmland; numbered civic reserves; black wall; red gates; blue water passages; orange routes/corridors; purple axes/locks; diagnostics.

Export `00-site.svg`, `01-program.svg`, `02-frame.svg`, plus combined SVG. Include north, scale, legend, household estimate, area ledger, and confidence labels.

Automated checks:

- L0: decoded ranges, coordinate alignment, water connectivity, known synthetic slope/elevation probes.
- L1: ledger residual ≤0.1 m²; class rounding error <1 household; no double scaling.
- L2: valid simple closed wall; no untyped crossings; reservations inside permitted land; zero protected/lock intrusion; corridor connectivity and grades pass.
- Repeat runs produce identical canonical JSON/SVG. Fixtures include blocked access, impossible civic fit, and water-crossing failures.

**6. First-pass scope**

Implement the flood screen, capacity ledger, civic envelopes, all four frame families, route gates, typed drainage passages, drawings, and validation now.

Defer full-region flow accumulation, simulated floods, automatic 진산/안산 interpretation, viewsheds, optimized earthworks, straight skeletons, parcels, and dressing. Use supplied axes as preferences. Passing these layers establishes a valid planning frame; final household realizability remains a later parcel-layer check.