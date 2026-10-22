# 고을 생성기 v2 — Layers 3–8 설계 (Claude ↔ Codex 세션 A, 3·4회차)

## 3회차 — Layers 3–5 (구역, 길·물, 블록·필지)
**Layers 3–5 should produce one settlement-wide subdivision.** Districts express demand and preferences; streets establish access; parcels divide the remaining land using shared edges. Density comes from continuous residential frontage, compact parcels, and rear gardens—not arbitrary street proliferation.

All defaults below belong in the existing rules file with units, source, confidence, and applicability. Lengths are **world metres**, already scaled ×1.2; areas ×1.44.

**1. Layer 3 — districts and activity allocation**

Consume only Layer 0–2 artifacts, including preserved territory permissions, locks/access contracts, program counts, and existing-route constraints. Do not rediscover towns or enlarge their allocations.

Districts have a **land-use role plus household mixture**, rather than exclusive class zoning:

```text
reserve civic/ritual envelopes and locked land
identify main-gate → civic-entrance primary-corridor chain
reserve market activity and named public spaces
allocate residential/craft capacity to usable components
allocate gardens/agriculture/open land from remaining budgets
assign household quotas to districts
```

Select the main gate by program-weighted external-route demand and civic access cost; respect any supplied designation. The civic forecourt remains its reserved dominant void. Market space occupies frontage along the approach, with a small square only where the program funds one. Stalls receive an activity band outside the clear travel corridor.

For allocation, use 4 m cells clipped to actual usable polygons. Each district seed has a role and area quota. Compute terrain-cost distance from seeds, then minimize:

\[
E=\sum_i a_i[C_{i,k}+\lambda_k]+\beta L_{\rm interfaces}
\]

Here \(a_i\) is clipped cell area; update district prices \(\lambda_k\) to meet quotas. Deterministic connected boundary-cell transfers refine the result. Default quota tolerance: 2% or one clipped cell, whichever is larger. Reject transfers disconnecting a district; difficult cases return alternatives.

Normalize suitability components using fixed rules-file ranges. Initial preference weights:

- **Market:** approach-chain frontage `.6`, gate accessibility `.4`.
- **Clerical households:** civic walking access `.6`, dry level land `.4`.
- **Elite households:** land quality `.6`, quietness `.4`.
- **Craft livelihoods:** transport `.5`, compatible work/water access `.5`.
- **Ordinary households:** livelihood access `.5`, land quality `.5`.

Class, wealth, and livelihood remain separate attributes. Quiet affluent clusters are preferences; no mandatory “north = elite” rule. Potentially polluting crafts receive explicit water-use compatibility constraints.

District boundaries are planning labels, **not automatic roads or walls**. Layer 5 may adjust them within quota tolerance to follow actual parcels.

Outside-wall hamlets require allocated extramural households and permitted land. Cluster usable terraces beside existing approaches or water-working access; default 5–15 households per cluster. Route-distance clustering splits disconnected terraces. Preserve mapped/protected paddies and irrigation; place houses along their dry edges. Allocate new agricultural parcels only where the program permits them. No decorative hamlet creation by consuming protected farmland.

**Invariants:** every programmed household assigned once; civic/lock geometry preserved; mutually exclusive land accounting; market circulation clear; district components accessible. Record unmet quotas explicitly.

**2. Layer 4 — streets, crossings, and drainage**

| Hierarchy | Width | Spacing/access rule |
|---|---:|---|
| Primary | Existing Layer 2 geometry | Preserve approved corridor and entrances |
| Secondary | 4.08–6.0 | Target 96–144 between successive branches |
| Lane | 2.4–3.6 | Add for actual rear-access demand |
| Cul-de-sac | 1.8–3.0 | Length ≤36; normally serves 2–5 households |
| Village 고샅 | 1.2–3.6 | Follow cluster access needs |

These derive from [settlement-metrics.md](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/docs/reports/settlement-metrics.md). Primary target width is 6–8.4 m, but approved narrower existing corridors remain recorded exceptions.

For **읍성**, instantiate typed graph obligations, not geometric grids:

- Connect civic entrances, markets, gates, water access, and district access points.
- Generate secondary branch candidates along primary chainage at target spacing.
- Route toward district demand centroids, another secondary, or a named destination.
- Prefer a T connection to an existing street over a new crossing when costs are within 10%.
- Add lanes where planned households cannot otherwise receive acceptable frontage/access.

For **villages**, cluster household demand first. Compute feasible terrain-cost routes among cluster centres, entrances, and water access. Use a minimum spanning tree over these costs. Add a loop when network/direct-route detour exceeds 1.8 and the added route serves at least eight households; loops never justify an otherwise unneeded bridge.

Use Layer 2’s A* and grade rules. Add heading-state penalties for deviation from planned civic bearings and excessive turns:

\[
c_e=l_e(1+8g_e^2+2R_e)+C_{\rm turn}+C_{\rm crossing}
\]

\(R\) is normalized flood susceptibility; permanent occupied access still obeys exclusions. Crossing costs are typed, not generic water penalties.

**Geometry reasons:** `planned_axis`, `contour_follow`, `water_setback`, `obstacle_avoidance`, `existing_route`, `junction_approach`.

Simplify path stair-stepping within 0.5 m. Fit tangent-continuous curves only inside the feasible corridor; default minimum radius 6 m for secondary streets, 2.4 m for lanes. Planned civic sections remain straight where feasible. Sample fitted geometry every 0.5 m and recheck grade, clearance, water, locks, and intersections. Failure retains a validated polyline. No random waves or mandatory curvature percentage.

Junctions are explicit nodes. Endpoint matching uses the established 0.10 m semantic tolerance; a connection beyond that distance requires routing a connector. Node genuine same-level intersections, split links, and prohibit accidental near-miss crossings. Bridge crossings do not connect the street graph to the water graph.

Create plazas only from funded `market`, `civic_forecourt`, `well`, or `gate` programs. No circular junction plazas. An optional wall-access strip is reserved separately; do not force a perimeter ring road.

**Water crossings:** enumerate straight bank-to-bank candidates, preferably within 20° of the channel normal. Require dry abutments, feasible approaches, and a supported span variant. Otherwise reroute or report failure. Fords require explicit depth/seasonal data; default to bridge or infeasible. Preserve every mapped channel through crossings.

**Drainage:** reserve channels and their outlets first. Street drains are separate directed links with invert profiles; default minimum fall 0.5%. Follow downhill street sides where feasible. Flat/reversing streets need an explicitly feasible drain alignment, culvert, or later grading contract. Never manufacture a downhill outlet or discharge across a parcel without an easement. Hydraulic sizing is deferred.

**Blocks:** subtract the dissolved union of street corridors, plazas, water corridors, civic reserves, and locks from allocated land. Connected residual polygons, including holes, are block faces. Cul-de-sac buffers indent blocks without pretending to create closed street loops.

Use noded boundary linework and `polygonize_full` to diagnose cuts, dangles, and invalid rings. Its outputs distinguish these conditions explicitly. [Shapely documentation](https://shapely.readthedocs.io/en/stable/reference/shapely.polygonize_full.html)

**3. Layer 5 — blocks and parcels**

Maintain one authoritative planar subdivision with half-edges. Neighbours reference the **same edge geometry in opposite directions**; never independently inset parcel boundaries.

```text
for block in stable_id_order:
    insert immutable anchor/reservation boundaries
    allocate street-frontage intervals
    partition frontage strips
    partition remaining rear land
    request missing access from Layer 4
    rebuild affected faces; retry
    validate quotas, geometry and access; commit transaction
```

Use bounded retries: three access revisions, eight split alternatives per block. Exhaustion reports an unresolved block; it does not silently drop households.

Initial district-specific ranges:

| Parcel role | Frontage | Area m² |
|---|---:|---:|
| Urban primary frontage | 7.2–16.8 | 115–360 |
| Urban secondary frontage | 12–24 | 216–576 |
| Rear residential | 18–36 | 475–1,152 |
| Clerical/specialist | 24–42 | 864–1,800 |
| Elite urban | 36–60 | 1,728–3,600 |
| Ordinary village | 21.6–42 | 432–1,296 |

Use the report’s distributions and depth/frontage ratios jointly: sample candidate width, ratio, and area; reject incompatible combinations. Layer 1’s area medians are capacity estimates, not competing parcel targets. Reconcile actual land consumption through its ledger.

Measure frontage along the **street boundary**, not centreline. Allocate widths by deterministic seeded sampling, then constrained redistribution so intervals exactly cover each assigned run. Respect junction visibility and entrance exclusions.

Construct inward split candidates from interval endpoints, approximately normal to the local frontage tangent. Maximum frontage-strip depth: 30 m. Curved front boundaries inherit street curvature; lateral boundaries may be straight or justified polylines. Target departure angle 70–110°. Where normals collide, solve the entire local partition together; do not clip independently generated lots.

For the first implementation, use recursive oriented-bounding-box cuts:

1. Generate split candidates near the local frontage normal and block principal axes.
2. Split the parent polygon exactly.
3. Score child area, frontage, compactness, terrain, and access.
4. Retain the best feasible subdivision.

Rear land uses the same recursion with larger parcel targets. Request a cul-de-sac/easement when rear households lack access. Easements are explicit access faces with beneficiaries, width, and entrances; they are not assumed pedestrian passage through another courtyard.

Unallocated rear land becomes funded garden/agricultural/open parcels with management access. It cannot conceal missing household demand.

Merge a sliver into the compatible neighbour sharing the longest boundary only if household count, frontage, and buildable-envelope checks survive. Default sliver trigger: area below half the applicable minimum or unusable neck below 1.8 m. Otherwise redesign the split.

Story anchors enter as immutable subdivision faces. Preserve doors, interaction clearances, and access sockets. Conflicts request upstream revision; anchors never move.

For later Layer 7, every boundary edge carries adjacency, purpose, geometry reason, and allowed closure types. Street curvature propagates through shared boundaries. This establishes continuity contracts; Layer 7 must still validate actual wall/gate/building joints.

**4. Data, modules, drawings, and checks**

Extend the plan with records of this form; geometry references resolve into one shared geometry store:

```json
{
  "districts": [{
    "id": "d1", "face_ids": ["f1"],
    "role": "mixed_residential",
    "household_quota": {"ordinary": 12},
    "livelihood_quota": {}, "area_budget_m2": 6000
  }],
  "streets": {
    "nodes": [{"id": "n1", "xz": [0, 0], "level": 0}],
    "links": [{
      "id": "s1", "nodes": ["n1", "n2"],
      "geometry": "g1", "corridor_face": "f2",
      "hierarchy": "lane", "reason": "contour_follow",
      "width_m": 3, "grade_profile": "p1"
    }]
  },
  "water": {"channels": [], "crossings": [], "drains": []},
  "subdivision": {
    "vertices": [],
    "edges": [{
      "id": "e1", "geometry": "g2",
      "left_face": "lot1", "right_face": "lot2",
      "reason": "parcel_split", "closure_policy": "compound_boundary"
    }],
    "faces": [{"id": "lot1", "rings": [["e1+", "e2-"]]}]
  },
  "parcels": [{
    "id": "lot1", "district": "d1", "use": "residential",
    "household_id": "h1", "frontages": [],
    "access_contract": "a1", "minimum_envelope": "g3"
  }],
  "revision_requests": []
}
```

Add `districts.py`, `street_templates.py`, `streets.py`, `water.py`, `subdivision.py`, `parcels.py`, and `metrics.py`.

SVGs:

- `03-districts`: role colours, household mixtures, quotas, market approach, forecourt.
- `04-streets-water`: hierarchy widths, junction IDs, grades, crossings, drainage arrows, blocks.
- `05-parcels`: numbered parcels, access strips, shared edges, locks, geometry reasons.
- Combined drawing retains Layer 0–2 hazards and territory limits.

Hard checks: valid coverage, exact twin edges, no overlaps/unclassified residuals, one household assignment each, accessible occupied parcels, preserved locks/wall openings, connected required streets, typed crossings, valid drain outlets. Coverage validation alone permits holes; also compare the face union against the intended domain. [Shapely documentation](https://shapely.readthedocs.io/en/2.1.2/reference/shapely.coverage_is_valid.html)

**5. Acceptance and scope**

Across four synthetic and four real sites:

- Street-width compliance ≥90% by length, excluding recorded inherited exceptions.
- Parcel frontage/area medians within ±15% of applicable targets; overlapping interquartile ranges; samples below three reported without judgment.
- Secondary spacing median 96–144 m where enough branches exist.
- Residential access 100%; cul-de-sac length ≤36 m.
- No unexplained boundary gaps, duplicate shared edges, or quota loss.

Roof coverage and frontage enclosure remain **later-layer checks**: 35–50% roofs in arterial residential bands, 22–32% across urban residential blocks, 85–100% urban frontage enclosure. Layers 3–5 reserve suitable parcels and continuous frontage but cannot certify roofs.

First pass includes constrained districts, typed routing, bridges, drainage reservations, recursive shared-edge subdivision, and access revision. Defer straight skeletons, hydraulic simulation, sophisticated craft hazards, and global parcel optimization. Run deterministic repeat tests plus curved-frontage, narrow-block, anchor-obstruction, bridge-failure, and rear-access fixtures; owner review approves composition before proceeding.
## 4회차 — Claude 메모
Layers 3–5 accepted as you wrote them (with my notes below). Now design Layers 6–7 in the same rigor; Layer 8 briefly.


## 4회차 — Layers 6–8 (집 짜임·지형, 경계(담·대문), 꾸밈) + 굽기 계약
**Confirmed on both notes:** Layer 3 supports an extramural market immediately outside the main gate, connected to the same civic approach. Layer 5 prefers narrow, deep frontage parcels with gardens behind them. That preference remains subordinate to access, terrain, and minimum compound dimensions.

**Layers 6–7 must solve geometry jointly at block scale.** A compound cannot independently choose levels, projecting roofs, or boundary replacements that conflict with its neighbour.

All proposed defaults below belong in the versioned rules file. Historical-space dimensions receive ×1.2 exactly once; gameplay clearances are already world metres.

**1. Layer 6 — compound grammar and placement**

Each household/institution program supplies mandatory functions, optional additions, privacy relationships, and permitted grammar productions.

| Term | Required data |
|---|---|
| Bay | Function, dimensional family, wall/open sides, floor level |
| Wing | Ordered bays, frontage/back roles, roof family |
| Junction | Compatible wings, shared structure, roof-join recipe |
| Court | Purpose, minimum clear polygon, entrances, activity reservations |
| Connection | Required route between sockets; width, headroom, privacy |
| Façade | Solid wall/open veranda/door/shopfront/service back |
| Socket | Position, orientation, elevation, clearance, compatible connections |
| Obligation | Required function, adjacency, access, privacy, drainage |

Grammar examples:

- Ordinary: 一 + service wing; ㄱ; detached facing pair.
- Prosperous farmer/shopkeeper: ㄱ/ㄷ; frontage shop/행랑 + rear dwelling.
- Elite: 사랑채/public court → 중문 → private 안채 court; service route and optional 사당.
- Civic: prescribed entrance sequence and forecourt, with public/private administrative areas.

Shapes are candidate organizations, not symbols imposed on every parcel. A ㅁ configuration may have connected wings or detached buildings around a court; its structural distinction must remain explicit.

```text
derive up to 24 grammar candidates per parcel
enumerate permitted bearings, frontage attachments and entrance positions
place mandatory wings + courts + route clearances
solve neighbouring levels, roofs and shared-boundary constraints
rank feasible candidates; retain optional additions only if they fit
validate assembled geometry; commit the whole block
```

Use deterministic beam search: width 16, fixed candidate ordering, three block-level retries. Exhaustion requests a parcel revision; it never deletes mandatory functions or changes household class.

Initial normalized objective weights: program fit `.25`, court quality `.20`, entrance/privacy `.20`, terrain economy `.15`, frontage continuity `.10`, solar orientation `.10`. Hard constraints precede scoring.

**Orientation and circulation**

Living façades face the court and preferably south ±45°. Shops face streets; service backs can form boundaries. South-facing preference must not rotate shops away from customers or obstruct the court.

Solve an explicit route graph:

```text
street → entrance/gate → public court → building door
                         → 중문 → private court → private door
```

Reserve kitchen-to-yard, storage, latrine, fuel, and 장독대 access sockets. For elite privacy, prohibit direct ground-level sightlines from public entrance to designated private-room openings; an offset gate, 중문, or 내외담 satisfies the obligation.

World-space gameplay defaults: use the actual character capsule, initially radius `.35 m`, height `2.0 m`; clear door width ≥`.9 m`, headroom ≥`2.2 m`, ordinary walking route width ≥`1.2 m`. Validate door swing and approach space. Low eaves cannot overhang these swept volumes.

**Dimensions and roof compatibility**

Treat the supplied measurements as calibration targets for applicable preset families:

- Bay: **2.568–2.616 m** world.
- Eave-tip reference: approximately **2.46 m** world.
- Overhang: **1.32–2.16 m** world.
- Floor above base: **0.552–0.684 m**, assuming the supplied floor measurements are historical-space values.

Record measurement datum: eave tip versus underside, foundation versus finished yard. Collision uses the actual roof underside, not the nominal eave height.

The current [`_spec.gd`](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/_spec.gd) still has class-specific scaling, including ×1.22. Export **resolved world-space descriptors** with `scale_applied=true`; the new pipeline must not scale them again.

Descriptors expose foundation polygons, solid façades, opening intervals, roof surfaces, drip lines, and sockets. Existing coarse eave rectangles are insufficient for final validation.

Roof intersections are allowed only through a registered junction recipe:

- 회첨: compatible roof surfaces trimmed to one shared valley.
- 맞배 connection: compatible ridge/end conditions and explicit end-wall treatment.
- Detached wings: no roof intersection.

Default clearance between unrelated roof solids: `.30 m`; increase to `.60 m` where either roof is thatch. These are provisional game rules, not historical fire regulations. Attached construction requires an approved assembly. Drip lines must drain onto owned land, public drainage, or an explicit easement.

A building may meet a parcel boundary only through a verified solid façade. Projecting eaves still require clearance/easement; shortening or removing them requires a supported roof variant.

**2. Terrain, courts, and thresholds**

Solve levels for streets, thresholds, courts, buildings, and drainage together while preserving Layer 4’s approved street profile. If that profile cannot support a compound, return a revision request.

Each compound may have several terrace planes. Candidate levels come from entrance elevation and terrain percentiles, quantized to `.05 m`. Minimize cut/fill, retaining height, stair burden, and drain length.

Defaults:

- Courtyard fall: **1–2%** toward a reserved outlet.
- Ordinary terrace cut/fill: ≤`1.2 m`; exceptional profile limit `2.0 m`.
- Retaining lift: ≤`1.2 m` before another bench or engineered variant.
- Navigation step: ≤`.32 m`; larger changes require stairs.
- Stair riser ≤`.20 m`, tread ≥`.28 m`, clear width ≥`1.2 m`.

Check surface transitions against the controller; do not assume every `.32 m` ledge is comfortable circulation.

Retaining structures carry retained side, top/toe profiles, drainage outlets, foundation, and upper enclosure load. They are distinct from enclosure walls, although both may occupy the same alignment.

Neighbouring terraces share a solved retaining contract. Apply the complete terrain delta once; never flatten parcels sequentially. Protect streams, abutments, locks, and drainage inverts.

Clear-court defaults, measured after roof projection and circulation reservations: ordinary court minimum width `3.6 m`, usable area `16 m²`; elite principal court `6 m` and `48 m²`. These are provisional profile values. Civic forecourts retain Layer 2’s reserved dimensions.

**3. Layer 7 — boundary intervals, joints, and continuity**

Use Layer 5’s shared edges and Layer 6’s verified façade/entrance contacts. Keep the 읍성 ring’s topology and approved openings; compound-wall rules must not create new town-wall openings.

For every edge, collect exact chainage breakpoints from:

- Gates and typed entrances.
- Solid façade contacts.
- Material/height changes.
- Retaining transitions.
- Corners, T-junctions, and drainage passages.

Partition the edge once. Each interval has exactly one enclosure treatment:

`wall | solid_building_face | gate | fence | hedge | typed_opening`

Retaining is an independent structural attachment. A hedge is visual enclosure, not guaranteed collision or security.

A façade replaces a boundary only where its **actual solid exterior face** covers that interval and connects through explicit return sockets. Never subtract roof bounds or proximity circles.

Material policy combines means, role, region, and stone availability:

- Modest: 토담, 토석담, 싸리울.
- Stone-rich setting: 돌담/토석담.
- Elite/civic: approved 화방담 or tile-capped variants.
- Agricultural boundary: fence, hedge, low stone, or intentional open edge.

World-space height defaults, including coping: 토담 `1.92–2.16 m`; tile-capped `2.16–2.40 m`; 돌담 `1.68–2.16 m`; 싸리울 `1.20–1.80 m`. Retaining height is additional and separately measured.

Tile-capped walls normally have stepped horizontal tops; rough-stone profiles may slope within their assembly limits. Solve coping continuously through corners and explicit step modules. Do not independently distribute tiles on adjacent runs.

**Joint construction**

- Corner: intersect thickness envelopes; generate one compatible corner solid.
- T: split the trunk edge and construct one three-way joint.
- Gate: wall endpoints terminate at jamb sockets; gate opening remains clear.
- Building: return meets a designated solid-face socket.
- Material transition: explicit transition/end module.

Store one semantic span chain; generate one watertight mesh per compatible chain, with deliberate splits at gates, joints, or chunk boundaries. Shared walls have one render owner and one collision representation.

Curvature inherits street/water/terrain geometry. Do not round ordinary corners or add waves. If wall thickness cannot follow an inherited curve safely, request a shared-edge revision; never repair one neighbour independently.

For every enclosed compound, virtually close gates and typed entrances and verify a closed boundary cycle. Intentionally open farm/service compounds have explicit exceptions. Also validate the **thick 3D solids**: topological closure alone does not guarantee visible closure.

**4. Layer 8 — activity-driven dressing**

Place props from activity reservations: kitchen supplies by kitchen sockets, market stock outside circulation, fuel near service access, agricultural tools beside working yards.

Sample ground wear from the solved entrance/activity route graph; add drip wear below eaves and dampness from drainage. Keep planting out of these corridors.

Trees use mature canopy and trunk envelopes. Check buildings, courts, wells, and gates before placement. At the owner’s 22° camera, provisional caps are canopy occlusion ≤20% of projected roofs and ≤15% of principal courts; preserve the gate–market–civic approach sightline. Decorative density never overrides access.

**5. Bake/runtime contract and records**

Python owns planning. A **headless Godot bake adapter** exports builder descriptors and generates/cache-validates actual building meshes. Runtime loads resolved geometry and transforms; it performs no placement or terrain solving.

Prebuilt modules: doors, gates, windows, posts, stairs, approved roof junctions, coping joints, repeated props. Generated meshes: parcel-specific walls, retaining structures, terraces, unusual roof assemblies, and terrain patches.

Use 32 m chunks initially, batching static geometry by material and visibility role. Keep doors, interiors, removable roofs, and camera-hide walls independently controlled. MultiMesh serves identical repeated assets in small spatial groups; individual instances are not independently culled. [Godot documentation](https://docs.godotengine.org/en/4.4/tutorials/performance/using_multimesh.html)

LODs remove small roof/coping detail before changing silhouettes. Shared chunk-seam vertices remain identical. Collision preserves every entrance and terrace transition at all visual LODs.

Extend JSON with:

```text
Compound: parcel_ids, grammar_derivation, obligations, courts,
          connections, building_ids, terrace_ids
Building: resolved_spec_hash, transform, foundation, roof_surfaces,
          facades, sockets, mesh_resources
Terrace: plane, polygon, terrain_delta, outlets, retaining_ids
BoundarySpan: edge_id, interval, treatment, material, profiles,
              endpoint_socket_ids, retaining_id, render_owner
Joint: incident_spans, kind, socket_positions, mesh_resource
Dressing: activity_id, asset_id, transform, clearance, canopy
```

Add `grammar.py`, `compounds.py`, `levels.py`, `boundaries.py`, `dressing.py`, and `godot_bake_adapter`.

**6. Verification and first pass**

Hard acceptance:

- Mandatory obligations and entrance-to-door routes: **100% satisfied**.
- Unregistered roof intersections, neighbour intrusions, blocked drains: **zero**.
- Boundary interval coverage: **100%**, without duplicate enclosure spans.
- Unexplained dangling endpoints: **zero**.
- Joint socket gap ≤`.02 m`; unintended visible through-gaps **zero**.
- Terrain, stair, headroom, and court minima: **100% compliant**.

Morphology targets retain the report’s definitions: arterial residential roof coverage **35–50%**, urban residential blocks **22–32%**, urban frontage enclosure **85–100%**. Trees and props do not count as structural closure. Report measured building-wall contribution separately.

Court legibility: all required usable polygons remain clear; provisional principal-court visible fraction ≥50% from its designated 22° review view. This is a visual review target, not permission to break privacy.

Report straight-run lengths, curvature radii, and curved-edge share **by geometry reason**. Require 100% explained curvature and zero unsupported deformations; impose no universal straight/curved quota.

Export roofless compound plans, roof/drip overlays, terrain sections, colour-coded boundary intervals, joint close-ups, and 22° views with canopy disabled/enabled.

First pass includes all hard checks, ordinary/elite/civic grammar families, approved roof joins, terraces, shared boundary joints, and minimal activity dressing. Test the eight accepted sites plus stepped shared walls, curved frontage, T-joints, gate/façade returns, and roof conflicts. Defer elaborate roof families, advanced erosion, seasonal dressing, and hydraulic simulation.