# 고을·마을·건물 배치 재설계 v1 (Claude ↔ Codex 논의, 2026-10-22)

사용자 지시: "도시 마을 건물 배치 로직을 전체 바꾸는 한이 있어도 제대로 논의하라". 담장 검토(codex/answer.md) → 1차 전체 진단 → 2차 반론·수렴 순서로 논의했다. 결론: **C안 — 배치 생성기를 새 모델로 교체하고, 건물 빌더·로더 어댑터는 유지, 집 짜임은 '문법(grammar)'으로 생성**. 생성은 오프라인 굽기(bake), 런타임은 읽기만.

## 0. 담장 단독 검토 (Codex)
The main defect is structural: **walls are generated independently per lot, then erased wherever something nearby looks like a replacement.** Nothing guarantees that the remaining pieces form a compound boundary. Better wall meshes alone will preserve these problems.

Read-only review; no files changed. Most reference pages opened, but preview-image requests failed. Visual comparisons below use your attached ref1/ref5; the [ACON set](https://www.acon3d.com/ko/product/1000002203) and [Dontdraw village](https://dontdraw.com/itemDetail.html?pdIdx=1767) provide context.

**1. Why the artifacts occur**

Line references below are in [organic.gd](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd).

- **Lots do not form a shared subdivision.** `_own_grid`/`_depth_at` (315–369) approximate street ownership on a 1m grid. `_block_lot` (535–577) reconstructs boundaries independently from street normals and simplifies front/back lines separately. Unlike settlement-metrics §4’s “blocks = street-enclosed faces,” these are street strips. Their meeting lines need not coincide. `_try_lot` additionally randomizes side angles/depths (636–643), producing diagonal boundaries.
- **Double walls become gaps.** `_emit` independently insets every lot by 0.35m (1494), separating even coincident boundaries by approximately 0.7m. `share_end` simply omits a side (1507), without confirming a successful neighbour; measured filling can subsequently reject that neighbour (1914–1918). Shared-wall suppression then deletes samples within 1.6m of an earlier, roughly parallel segment (1557–1572). Proximity is neither ownership nor connection.
- **Stubs are explicitly permitted.** Building/shared-wall subtraction samples every approximately 0.1m and keeps remnants longer than only 0.5m (1554–1577). Random `partial_walls` removes whole sides without proving a replacement boundary (1498–1506). `_gap_piece` creates standalone frontage walls without endpoint attachment checks (1987–2002); its 1.5m sampling also need not reach the gap’s endpoint.
- **Buildings do not actually become boundary faces.** `_emit` cuts against expanded bounding rectangles (1325), rather than identified exterior wall faces. Sampling stops short of those expanded rectangles, leaving clearance instead of a joint. `open_a/open_b` suppress end geometry; they do not establish attachment.
- **Gates use holes, not joints.** Lines 1511–1547 subtract a circle around the gate and rotate it to the nearest segment, without snapping its centre/jamb sockets to that segment. Forty percent of simple gates are then removed, leaving an intentional but untyped opening.
- **The racetrack shape is prescribed.** `_wall_runs` adds random inward waves (1240, 1263–1264) and rounds most non-tile corners with quadratic curves (1272–1285). Slope disables “planned” status (1201); contour correction moves points inward without solving a contour (1260–1262). Every `nature/*` piece counts as a tree (1205). These operations lack boundary/collision revalidation.
- **Shared geometry becomes stale.** `wall_segs` records the original straight cuts (1583–1584), not the subsequently curved geometry. `_wall_runs` joins only sequential matching endpoints (1207–1219); `_wall_pieces` likewise fixes local joints, not compound topology.
- **Corners and colour compound the problem.** Independent strip reconstruction, simplification and rounding cut across block corners. `inset()` intersects infinite offset lines without robust concave clipping (86–103); `_emit` drops suspicious edges rather than repairing them (1502). `_wall_kind` uses house type/density, not region or boundary role (955–963). Mud’s tan palette in `village/todam.gd:33` offers little separation from the pictured ground.

**2. Replacement algorithm**

Use one **planar boundary graph**, constructed before emitting any lot.

```text
Vertex: id, XZ, junction_kind
Edge: id, vertices/polyline, left_lot, right_lot,
      role(frontage|side_party|back|field), constraint_id
Span: edge_interval, closure(wall|building|hedge|open|gate),
      material, base/top_profile, endpoint_socket_ids
```

Split edges at T-junctions; both neighbours reference the same edge. Assign deterministic ownership and seed from stable edge IDs.

- **Frontage:** compound enclosure or building frontage; reserve explicit entrances.
- **Side/back:** one shared enclosure. Replace only intervals occupied by verified, sufficiently aligned solid building faces; exclude open verandas.
- **Field edge:** low stone, 싸리울, hedge or nothing according to cultivation/access rules. Every opening needs an explicit purpose.
- **Gates:** reserve an edge interval before building placement; align to its tangent, connect both jamb sockets exactly, and reserve a traversable street-to-yard corridor. An ungated entrance remains a typed opening.
- **Buildings:** expose foundation, solid-face and roof-overhang polygons separately. Attach wall ends to facade sockets using short returns where necessary; do not subtract roof bounding boxes.
- **Corners:** retain the actual block junction. Use corner/T-junction modules; permit chamfers only for recorded road-clearance or site constraints.
- **Curvature:** straight by default. Permit road/stream following, verified contours or retained-tree avoidance. Proposed world-space defaults: radius ≥3m, ordinary straight runs ≥2m; surface irregularity belongs in the mesh. Solve constrained curves once for both neighbours.
- **Slopes:** derive elevations after terracing. Use horizontal stepped tops with explicit risers; permit gently sloping rough-stone tops through a material policy. Separate retaining structures from enclosure walls.

Material policy should combine class, region and local stone availability: modest compounds use 토담/토석담 and 싸리울; stone-rich districts favour 돌담; wealthier/civic compounds allow 화방담 and 기와 갓. These require distinct assets.

Treat heights as tunable art ranges: historical-space 토담 1.6–1.8m, tile-capped walls 1.8–2.0m, stone 1.4–1.8m; multiply once by the documented ×1.2 world factor. Define whether height includes coping.

**3. Core steps and prioritized changes**

```text
streets = planarize_and_buffer_streets()
blocks = extract_land_faces(streets, water, exclusions)
lots = subdivide_blocks_with_shared_edges(blocks, measured_rules)
graph = build_boundary_graph(lots)

reserve_entrances(graph)
compounds = place_buildings_using_boundary_constraints(lots)
classify_spans(graph, compounds.solid_faces, regional_policy)
solve_shared_curves_and_elevations(graph, finished_terrain)
attach_gate_building_and_junction_sockets(graph)
repair_short_runs_and_validate(graph)
emit_each_shared_span_once(graph)
```

1. Refactor `run`, `_cut_run[_m]` and `_emit` into layout, compound planning, boundary solving, then emission. Stop emitting walls during subdivision.
2. Replace `_block_lot`’s independent rear boundaries and `share_end`/`wall_segs` heuristics with shared graph edges.
3. Replace sampled subtraction with exact edge intervals and facade/socket attachments; absorb or redesign remnants **<2m**, except necessary attached gate returns.
4. Remove automatic waves/rounding; make `_wall_runs` consume solved geometry. Add elevation profiles and junction modules to `bldg/wall`.
5. Validate: zero unexplained degree-one endpoints, duplicate shared spans, crossings or boundary escapes; socket gaps ≤2cm; enclosed compounds close when gate intervals are virtually sealed; entrances pass navigation tests.
6. Add seed fixtures for unequal back-to-back lots, failed neighbours, T-junctions, curved frontages, building replacements and slopes. Current metrics can count props as frontage closure and tolerate 10m of double wall (`settle_metrics.gd:401–421`), so passing them does not establish continuity.

**4. Reaching the reference look**

**Procedural work:** establish coherent street edges, deliberate courtyard voids, aligned ancillary buildings and distinct town/village density. Preserve measured targets—22–32% town-wide roof coverage versus 35–50% arterial bands. Reduce canopy obstruction; place wear, drainage, grass and planting from actual circulation/boundaries.

**Asset work:** improve roof-to-body proportions, eave thickness/curvature, thatch silhouettes, foundations and timber/plaster contrast. Build compatible straight/corner/T/stepped wall, coping, gate and facade-return kits. Use downloaded [KHS models](https://digital.khs.go.kr/heritage/catalog.do?order=2&index=1) for measured forms and selected derived modules.

Work order: **boundary topology → representative street/compound → roof and wall kits → materials/ground → vegetation**. Keep existing building scales; calibrate against the 2m character. For M1 Mobile, batch opaque geometry by material/spatial chunk, instance repeated modules, use LODs and simple colliders, and profile fixed walking views after each stage.
## 1. 1차 — 전체 진단과 제안 (Codex)
**Recommend C: replace the layout generator, while retaining building builders and introducing authored, KHS-informed compound programs.** The fundamental defect is that streets, parcels, courtyards and boundaries never become one coordinated spatial model. Better parameter distributions cannot establish those relationships.

Read-only review; no files changed. Reference observations below concern the attached images; numerical historical ranges come from your measurement document unless stated otherwise.

**1. What is structurally wrong**

- **Tier → site:** tiers select fixed square dimensions; civic buildings occupy prescribed offsets before site feasibility is considered ([settlement.gd:24](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/settlement.gd:24), [334](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/settlement.gd:334)). A 200m “city” provides 4ha while retaining substantial civic footprints. This compression must change the program or settlement extent; it cannot preserve every full-size institution and measured neighbourhood structure simultaneously. Rivers constrain later infill, rather than selecting the civic site.

- **Settlement → districts:** each district runs its own generator ([settlement.gd:136](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/settlement.gd:136)). District borders therefore influence geometry without representing physical boundaries. There is no settlement-wide negotiation of connecting streets or adjacent parcels.

- **Street network:** perpendicular departures, random heading changes and proximity stopping create polylines ([organic.gd:236](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:236)). `parent`/`joined` annotations do not constitute a planar junction graph. Grade limits, drainage, bridge requirements and access demand are missing from the network solve. Random circular junction plazas further remove frontage without establishing a designed public space ([300](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:300)).

- **Blocks → parcels:** “measured” still assigns ground to the nearest street on a 1m grid, capped at 40m, then reconstructs independent strips using street normals ([315](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:315), [535](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:535), [1784](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:1784)). There are no actual block faces or shared parcel edges. Wider street spacing consequently creates unclaimed interiors. Lanes are added after that ownership grid is computed.

- **Parcels → programs:** subdivision immediately fills and emits each lot; failure skips it, followed by frontage patches ([1886](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:1886), [1934](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:1934)). Roof-share targets even change household class ([2042](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:2042)). Household economics, required activities and spatial relationships should generate roof composition, rather than being changed to satisfy it.

- **Compound → buildings:** the main building takes the first feasible northern candidate; the courtyard becomes a short rectangle; ancillary buildings occupy remaining perimeter positions ([2263](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:2263), [2324](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:2324), [2370](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:2370)). This packs objects, not rooms around a purposeful outdoor room. Yangban fitting additionally inherits frontage-relative orientation ([1053](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:1053)); the separate town template rotates entire opposite rows 180° ([town.gd:42](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/town.gd:42)).

- **Footprints → enclosure:** placement, wall subtraction and measurement reuse roof bounding rectangles. `bounds()` merges wings into one rectangle, including courtyard voids ([building.gd:1643](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/building.gd:1643)). This wastes usable space and mistakes eaves for enclosing walls. Independent wall insets, deletion and gate holes then compound the topology problem ([organic.gd:1494](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:1494)).

- **Terrain → dressing:** lot platforms use averaged frontage heights and retrospective retaining walls ([1453](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:1453)). They do not jointly solve road, threshold and neighbouring platform elevations. Gardens scan leftover ground as rectangles; trees use local clearance rather than settlement-wide canopy and sightline constraints ([1852](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:1852), [2434](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/organic.gd:2434)).

- **Metrics:** frontage “closure” accepts roof rectangles, trees and props; double walls tolerate 10m ([settle_metrics.gd:390](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/tools/bldg/settle_metrics.gd:390), [421](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/tools/bldg/settle_metrics.gd:421)). Village coverage and household density use different spatial denominators ([264](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/tools/bldg/settle_metrics.gd:264), [337](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/tools/bldg/settle_metrics.gd:337)). Passing cannot establish coherent morphology.

**2. What the references embody**

Their shared feature is **clustered roof mass around legible courtyard voids, connected by continuous street edges**. Apparent roof overlap often comes from perspective and layered depth; it does not imply intersecting roofs.

| Type | Spatial grammar visible in the sheets |
|---|---|
| 읍성 town — 1767, 2198, 2203 | Civic axes and compounds dominate; subordinate streets form differently sized neighbourhoods. Repeated frontage divisions create continuity. Civic courts are deliberate large voids within dense residential fabric. |
| Market — 1767, 5198, 2204 | Sustained shop façades, posts, awnings and merchandise address the street. Small passages interrupt the row and reach rear housing. Roofs repeat rhythmically with limited setbacks; a sequence of activities supplies detail. |
| 양반 village — 2203, 47649 | Large, internally ordered compounds anchor smaller neighbours. Long walls bend at meaningful corners; gates announce transitions between public access, reception and private courts. Tile roofs form coherent groups. |
| 민촌 — 2204, 2432 | Small unequal clusters share winding lanes. Main and subsidiary roofs hold a working yard between them. Enclosures follow lanes and terraces; garden strips and trees occupy edges. Greenery does not replace missing compounds. |
| 산촌 | The supplied sheets offer insufficient direct evidence for a distinct mountain-settlement grammar. Infer compact terraces, contour access and stepped compounds as a design hypothesis, then validate against regional examples. Avoid treating 산촌 as 민촌 with extra curvature. |

Across the sheets, irregularity occurs at junctions, property adjustments and terrain transitions. Buildings within a compound generally maintain stronger alignment than neighbouring compounds. Trees punctuate courts, lane bends and settlement margins.

Contact sheets cannot establish metre-scale block dimensions or historical frequencies. Keep their visual grammar separate from measured evidence. Likewise, south-facing placement is a regional/program preference: Suncheon’s official description documents a southeast-facing main house deep inside its courtyard, not a universal street-facing rule. [Suncheon heritage description](https://www.suncheon.go.kr/kr/info/0013/0002/?boardId=bbs_0000000000011610&cntId=104&mode=view)

**3. Replacement architecture**

Use a persistent intermediate model:

```text
Site: terrain, drainage, flood exclusions, existing routes, protected anchors
StreetGraph: junctions, graded centre-lines, hierarchy, corridor polygons
BlockFace: land polygon, ordered street frontages, constraints
Parcel: shared half-edges, access rights, household/program, terrace IDs
Compound: typed courts, buildings, adjacency/privacy/access graph
Building: wall/foundation/roof polygons, façade roles, doors, service sockets
BoundarySpan: shared edge interval, wall/building/gate/open, elevation, joints
```

Every ground region receives an explicit use. Open land remains valid; unexplained leftover geometry does not.

**Site and streets.** Tier selects institutional requirements, household demand and catchment relationships. Fit civic anchors to feasible terrain and existing connections. Use a constrained town skeleton—gates, civic approaches, market route—then grow subordinate connections. A tensor field can guide contour and route alignment, but should not decide civic structure. Villages begin with feasible household clusters and access demand; route lanes between them. Planarize intersections and solve road grades before subdivision.

**Blocks and parcels.** Extract faces from buffered corridors plus settlement boundaries and exclusions. Partition whole blocks transactionally. Allocate frontage intervals, use a medial/straight skeleton to organize rear land, and frontage-constrained OBB splits within suitable subregions. Reject inaccessible/sliver parcels; merge or move shared cuts. Reserve rear-access lanes before committing adjacent parcels. Rural compounds need not form closed urban blocks.

**Programs and placement.** Author adjustable courtyard programs: modest house, working farmstead, shop-house, jumak, hyangri residence, yangban reception/private courts. Specify required/optional buildings, façade relationships, kitchen service, privacy and gate routes. Fit courts and buildings jointly using discrete orientations and bay counts plus bounded positional search.

South-facing preference applies chiefly to residential living fronts; shop fronts address streets, service backs may form street boundaries, and reception buildings address their courts. Store true north separately from settlement rotation. Permit recorded exceptions.

Use separate wall, roof, drainage and circulation envelopes. Courtyard dimensions constrain packing; they are never merely the residue. On failure, reconsider the template or neighbouring parcel cut before downgrading the household.

**Terrain and boundaries.** Jointly optimize terrace levels against cut/fill, road grades and thresholds. Split hillside compounds across terraces where necessary. Solve retaining edges and drainage explicitly. A 2m heightfield cannot represent every narrow threshold: use local platform, ramp and drain meshes.

Reserve gates as shared-edge intervals with jamb sockets. Classify remaining spans as walls, solid building faces or intentional openings; emit each shared span once.

**Dressing and assets.** Place jars from kitchen sockets, working props from activity zones, wear from circulation, weeds from drainage/shade, and trees from canopy envelopes. Recalibrate roof silhouettes using KHS dimensions while retaining the agreed world scale. Current `_choga` already increases eaves ([spec:239](/Users/sinjaeho/Documents/works/trend-mcp-seolhwa-integ/seolhwa_godot/kit/bldg/_spec.gd:239)); earlier documentation is partly stale.

```text
rules = load_versioned_rules(region, era, morphology, world_scale)
site = analyze_site(terrain, water, routes, protected_anchors)
program = allocate_demand(tier, site, rules)
graph, blocks = solve_streets_and_faces(site, program)

for block in stable_order(blocks):
    candidates = partition_with_frontage_and_access(block, program)
    solution = bounded_search(candidates):
        jointly_fit_typed_courts_buildings_and_terraces()
        score_access + frontage + orientation + earthwork + composition
    commit_valid_solution_or_explicit_failure(solution)

boundaries = classify_shared_spans(parcels, solid_faces, entrances)
dress_from_activity_and_environment()
assert_topology_access_and_geometry()
emit_and_measure()
```

Store source, confidence and applicability with every rule. Use stable entity IDs, independent stage/entity RNG streams, canonical ordering and versioned geometry tolerances. A prop edit must not reshuffle parcels.

**4. Choice, milestones and acceptance**

| Option | Benefit | Principal risk |
|---|---|---|
| A: refactor | Reuses implementation | Replacing topology and stage coupling already approaches a rewrite; patches remain tempting. |
| B: wholly procedural rewrite | Maximum flexibility | A general compound solver can produce valid but characterless arrangements. |
| **C: new layout + authored programs** | Reliable architectural relationships with procedural variation | Repetition; control through program variants, bay counts and conditional attachments. |

Build offline; retain existing render, collision and placement adapters.

1. **Compound benchmark:** approve six programs on flat and stepped sites. Require connected gate-to-door routes, no unintended intersections, and deliberate courtyard enclosure. Review silhouettes against KHS and courtyard composition against references.
2. **Neighbourhood benchmark:** one town block, one market segment, one village cluster. Require zero parcel overlaps, inaccessible households, duplicate shared boundaries or unexplained boundary ends; joint gaps ≤2cm. Backtrack failed packing.
3. **Settlement benchmark:** test at least 20 seeds per morphology. Apply documented world-scaled frontage/area distributions; town residential roof coverage 22–32%, arterial bands 35–50%, while reporting gross settlement, neighbourhood and parcel denominators separately. Check conditional distributions, not medians alone.
4. **Visual/performance gate:** fixed overhead, 22° town, 30° field and first-person views under identical lighting. Approve continuous frontage rhythm, readable courts, clustered roofs and restrained canopy before adding polish. Retain accepted views as goldens. Profile the same M1 walking routes; require the agreed frame budget before replacing Namwon.
## 2. 2차 — Claude의 반론 7가지
I agree with option C (new layout model + programs, keep building builders/adapters). Challenges:

1. **Repetition vs authoring.** Namwon alone has ~3,000 house sites. Fixed authored programs will repeat visibly. I propose programs as a small *grammar* (wing configurations 一/ㄱ/ㄷ/ㅁ/two-ㄱ facing, bay counts, 툇칸, attachment slots: 부엌 end, 외양간, 헛간, 뒷간, 장독대, 가게채 on frontage, 사랑채+중문 for 양반) instantiated by parcel shape and household economics, with KHS measured houses as calibration fixtures. Do you agree, and what are the minimal grammar terms?

2. **읍성 skeleton rules.** Korean 읍성 historically: 관아(동헌/객사) toward the north centre on the main axis from the south gate; gates often offset so the main street forms T-junctions rather than a through 十字路; market inside/near south gate; 향교 outside walls; 사직단 west, 여단 north. Our settlement-rules.md documents some. Should the skeleton be a typed template graph (gate→civic approach, market street, ring/back lanes) parameterized by terrain, rather than growth + tensor field? I lean template-graph for towns, growth/cluster-first for villages.

3. **Compression.** The world map compresses geography (~0.3× real distances), so a 중도시 gets a few ha, not 30–60 ha. My proposal: keep building/parcel sizes at true(×1.2 world) scale and preserve morphology ratios, but reduce household count and number of neighbourhoods ("fewer, true-size houses"), keep all civic institutions but allow compact variants (e.g. 객사 with fewer bays). How exactly would you allocate area: civic % / residential / market / open / fields, and which ratios must be kept to read correctly from the 22° camera?

4. **Runtime vs bake.** Bounded search/backtracking in GDScript at load time is risky for load times (current region load ~7.5 s). I propose generation is an offline bake tool (deterministic) writing placement JSON + boundary spans that the runtime loader consumes; runtime only streams and instantiates. Agree? Any parts that must stay runtime (e.g. terrain-dependent elevation solve if heightfield changes)?

5. **Fixed story anchors.** Story houses/locations (e.g. 월매 집, 이겸 거처, 주막, 광한루) must remain at fixed positions/footprints/door positions. How do they enter the solver (locked parcels/compounds, with street graph routed around them)?

6. **Performance.** Denser continuous walls and more 곁채 increase draw calls. Proposal: wall/gate modules and repeated building parts as MultiMesh/instanced modules per chunk, LOD by chunk, collision as merged simple shapes. Anything else?

7. **Visual acceptance.** I propose golden views matched to reference angles + the in-game cameras, judged by the owner, plus numeric gates. Also a 'frontage rhythm' metric (spacing of gates/façade breaks per 10 m), 'court legibility' (each compound has one dominant court with ≥X m² clear and ≥Y% enclosed edges), 'canopy cover from 22° view' cap. Good metrics? Suggest thresholds or how to derive them from references.

Then produce the **converged design spec** (≤2200 words): data schema (JSON-ish) for StreetGraph/BlockFace/Parcel/Compound/Building/BoundarySpan; stage interfaces & ownership; program grammar terms; 읍성/market/양반촌/민촌/산촌 skeleton rules; compression/area allocation; bake vs runtime split; invariants & metrics with thresholds; Milestone 1 (vertical slice: one 읍성 block + one market segment + one 민촌 cluster in Namwon) as a concrete task list with acceptance criteria.

## 3. 2차 — 수렴된 설계 명세 (Codex)
Agreed on C, with one refinement: **author the grammar and its constraints; generate each compound’s arrangement.** KHS houses become calibration fixtures, rather than a catalogue to repeat.

Read-only; no files changed. Numerical proposals below are initial design thresholds unless explicitly identified as existing measured targets.

**Responses to the seven challenges**

1. **Grammar:** yes. Minimal terms are: functional bay, wing, wing junction, court, access connection, façade role, attachment socket and boundary obligation. 一/ㄱ/ㄷ/ㅁ are derived configurations. “Two facing ㄱ” requires two buildings and a court relationship, not another indivisible preset. Variation must affect visible structure—court proportions, roof grouping, entrance sequence—not merely props.

2. **읍성 skeleton:** agree: typed template graphs for towns; cluster-first generation for villages. Treat north-centred civic approaches, offset gates and T-junctions as selectable regional patterns, not universal historical requirements. Ring lanes are optional. Existing Namwon geography and documented locations override defaults.

3. **Compression:** agree with fewer households and neighbourhoods, maintaining local dimensions. Preserve street enclosure, frontage cadence, court-to-building proportions and civic hierarchy. Area percentages are adjustable budgets; institutional minimum envelopes determine feasibility. Compact civic variants must retain functional identity and entrance sequence.

4. **Bake:** agree completely. Bake geometry, elevations, terrain modifications, navigation and mesh resources. A changed heightfield invalidates affected bake dependencies; it should not silently trigger a runtime elevation solve.

5. **Story anchors:** import immutable geometry and access contracts before streets. Lock footprints, doors, thresholds, interaction areas and required approaches. Route around these constraints, while connecting their entrances explicitly. A collision produces a diagnostic, never automatic relocation.

6. **Performance:** agree selectively. MultiMesh only genuinely repeated meshes; merge unique static walls by material and spatial chunk. Individual MultiMesh instances lack independent visibility culling and share object-level lighting limits, making small spatial batches important. [Godot MultiMesh documentation](https://docs.godotengine.org/en/stable/classes/class_multimesh.html) Preserve independently controlled doors, interiors and camera-hide geometry. Collision simplification must preserve openings and courtyards.

7. **Acceptance:** agree, but courts must be program-specific: a yangban residence can intentionally have several courts. Measure frontage events by semantic type; mesh joints are not façade breaks. Measure canopy obstruction against projected buildings/courts, not the entire screen. Derive final visual thresholds from owner-approved examples.

**Converged spec — data contract**

Coordinates are world metres; parcel geometry uses XZ, elevation uses explicit profiles. True north and settlement orientation are separate. Dimensions receive world scaling once.

```text
Bake {
  schema_version, generator_version, rules_version, seed,
  input_hashes: {terrain, water, anchors, assets},
  scale_policy, north_vector, geometry, records, chunks, diagnostics
}

geometry {
  vertices: [{id, xz}],
  edges: [{id, vertex_ids, polyline, left_face, right_face}]
}

StreetGraph {
  nodes: [{id, xz, y, role, anchor_id?}],
  links: [{
    id, from, to, hierarchy, centreline_xyz,
    corridor_polygon, width_profile, grade_profile,
    frontage_policy, bridge_id?
  }]
}

BlockFace {
  id, polygon_with_holes, boundary_halfedges,
  frontages: [{street_id, edge_id, interval}],
  land_use_budget, terrain_constraints, parcel_ids
}

Parcel {
  id, block_id, boundary_halfedges,
  frontage_intervals, access_easements,
  household: {means, livelihood, members, status},
  program_id, compound_id, terrace_ids, lock_contract?
}

Compound {
  id, parcel_ids, grammar_derivation,
  courts: [{id, role, polygon, clear_polygon, enclosure_target}],
  connections: [{from_socket, to_socket, route, clearance}],
  building_ids, entrance_ids, activity_zones, terrace_ids
}

Building {
  id, compound_id, builder_spec, transform,
  foundation_polygons, wall_polygons, roof_polygons,
  facades: [{id, segment, role, solid_intervals, sockets}],
  terrace_id, collision_ref, render_groups, lock_contract?
}

BoundarySpan {
  id, edge_id, interval, adjacent_parcels,
  closure: wall|building_face|gate|fence|intentional_open,
  building_face_ref?, entrance_ref?, material,
  base_profile, top_profile, endpoint_socket_ids,
  render_owner_chunk
}
```

Half-edges reference one shared geometric edge with opposite directions. Building footprints support multiple polygons and holes; bounding rectangles are acceleration structures only. Retaining structures are separately typed and may coexist with enclosure spans.

**Stage interfaces and ownership**

| Stage | Consumes → owns |
|---|---|
| Site analysis | Terrain, water, anchors → suitability, drainage, exclusions, locked envelopes |
| Settlement planning | Site, tier, demand → civic programs, clusters, land budgets, skeleton |
| Street solve | Skeleton, access contracts → planar graph, corridors, preliminary grades, block faces |
| Block solve | Faces, household demand → shared parcels, easements, compound candidates |
| Compound/terrain solve | Candidates → buildings, courts, thresholds, terraces, terrain delta |
| Boundary solve | Shared edges, solid façades, entrances → spans and joints |
| Dressing | Activity zones, circulation, shade/drainage → props, planting, wear |
| Compilation | Validated model → placement JSON, spans, scenes/meshes, collision, navigation, reports |

Later stages cannot silently alter earlier geometry. A required rear lane requests a street revision and face rebuild; parcel/compound failures trigger a bounded block transaction. Commit an entire valid block, or return an explicit failure.

The compound and terrain solver jointly chooses levels; the boundary solver consumes those levels. Terrain edits are applied once from the complete terrain-delta layer, avoiding order-dependent flattening.

**Program grammar and settlement rules**

Grammar terms:

- **Bay:** room, hall, kitchen, storage, stable, shop, passage; measured dimension family.
- **Wing:** ordered bays, depth rows, 툇칸, roof/body specification.
- **Junction:** continuation, return, connected corner, detached facing; explicit roof compatibility.
- **Court:** domestic/work/reception/private/service; dimensions, required addressing façades.
- **Connection:** public→gate→court→door, optional 중문/privacy turn.
- **Façade:** street-active, court-active, service, solid boundary.
- **Socket:** kitchen end, livestock access, shed attachment, jars, chimney, entrance.
- **Obligation:** enclosure, daylight preference, access, drainage, separation.

Household economics selects required functions, optional functions and construction quality. Parcel/terrain constraints select configurations and bay counts. Mirroring must also transform kitchen/service relationships.

Use hierarchical variation: neighbourhood construction families, household programs, then component variation. Discourage adjacent identical structural signatures; do not manufacture arbitrary uniqueness across 3,000 sites.

Skeleton policies:

| Morphology | Skeleton and packing |
|---|---|
| 읍성 | Gate/civic approach graph; offset/T or crossing variant; market approach; optional wall service lanes. Civic orientation and terrain constrain connections. |
| Market | Two-sided active frontage, controlled widening, rear service/access passages, jumak/workshop nodes. Maintain a clear through-route around stalls. |
| 양반촌 | Lineage/major-house anchors, reception/private court sequences, subordinate households and branching access. Terrain determines local hierarchy; avoid a universal upper/lower split. |
| 민촌 | Feasible household clusters around shared access/water; branching lanes, unequal connected yards, adjacent productive land. |
| 산촌 | Feasible terrace clusters first; contour routes with controlled climbing links, smaller developable envelopes, stepped compounds. Roof materials follow regional evidence. |

향교, 사직단 and 여단 enter as external institutional nodes with source-backed location preferences. Water crossings require explicit bridge/ford decisions.

**Compression and allocation**

Define gross intramural area consistently; allocate non-overlapping uses. Courts belong to their compounds, while market carriageways belong to streets.

A starting budget for a **4ha compressed town** is:

| Use | Share | Area |
|---|---:|---:|
| Civic compounds, including their courts | 22% | 8,800m² |
| Residential compounds | 42% | 16,800m² |
| Market premises | 8% | 3,200m² |
| Streets, public lanes, wall access | 12% | 4,800m² |
| Public spaces | 6% | 2,400m² |
| Fields/gardens outside compounds | 10% | 4,000m² |

These are design budgets, not historical findings. First reserve locked anchors and minimum viable civic programs; then fit streets and households. Report resulting percentages and unmet demand.

If institutions do not fit, select compact variants, reduce neighbourhood/household count, or enlarge the envelope. Do not shrink every court or narrow every lane. “Keep all institutions” and “fixed few-hectare envelope” can be incompatible; emit that conflict.

At 22°, prioritize:

- Continuous street-facing boundaries with purposeful entrances.
- Residential roof coverage versus usable court space.
- Main/subsidiary roof hierarchy and near/far layering.
- Civic buildings remaining visibly dominant.
- Trees punctuating, rather than concealing, these relationships.

Preserve these locally; compressed towns need fewer blocks, not universally miniaturized blocks.

**Bake, runtime and performance contract**

Bake deterministic search with stable entity IDs, canonical iteration and RNG streams keyed by stage/entity. Enforce candidate-count budgets, not wall-clock cutoffs. Record derivations and rejection reasons.

A terrain change rebakes affected roads, blocks, neighbouring terrace dependencies, collision and navigation. Runtime verifies hashes and loads compatible products. Gates, destruction and camera visibility remain runtime state; they do not reshape parcels.

Compile material batches in initially **32m render cells**, testing 16/32/64m alternatives. Streaming cells may be larger. Maintain canonical ownership for cross-cell spans, with streaming dependencies that prevent missing shared walls.

Use repeated modules where repetition is real; unique wall runs can become merged meshes. Retain coarse exterior HLOD and separate near interiors. Godot supports replacing individual houses with grouped geometry through visibility ranges. [Godot HLOD documentation](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html)

Bake mesh resources as well as placement: otherwise first-load building generation remains expensive. Profile shadow geometry, outline passes, vegetation overdraw, node count and collision shapes alongside draw calls. Never merge collision into a convex shape that fills a court or gate.

**Invariants and acceptance metrics**

Hard gates:

- Zero parcel overlaps, invalid shared-edge incidence, unexplained land remnants or duplicate spans.
- Zero relocated locked anchors; door positions and approach contracts preserved.
- Every occupied compound connects to the public network with player-capsule clearance.
- Gate joints ≤2cm; all enclosure openings explicitly typed.
- No unintended building/roof intersections; only declared architectural joints allowed.
- Walkable steps ≤0.32m; larger transitions require stairs/ramps validated by traversal.
- Identical inputs produce identical model hashes; dressing changes do not reshuffle layout.

Morphology gates:

| Metric | Initial criterion |
|---|---|
| Dimensions | Existing measured, world-scaled frontage/parcel/street distributions; inspect conditional distributions and tails |
| Roof coverage | Existing targets: residential neighbourhood 22–32%; arterial band 35–50%, using documented fixed denominators |
| Frontage closure | Town 85–100%; 민촌 60–90%; solid façades/enclosures only, explicit entrances classified separately |
| Entrance rhythm | Town residential initial 0.4–1.0 entrances/10m per street side; derive from frontage demand, not compulsory insertion |
| Court clearance | Poor: ≥12m²/2.5m minimum width; commoner: ≥24m²/3m; middle: ≥40m²/4m; provisional world-space minima |
| Court enclosure | Commoner court ≥50% perimeter addressed by court-facing façades/enclosures within 1.5m; openings remain usable |
| Canopy obstruction | Initial cap: foliage hides ≤25% of projected target roof/court pixels in designated overview views |

Market shop openings, household entrances and roof breaks receive separate rhythm statistics. Yangban courts have individual role-based requirements; there is no “one dominant court” rule.

For visual calibration, annotate at least ten comparable reference crops per supported category. Measure ratios and event sequences; infer metres only where scale is available. Approve matching generated views, freeze their ranges, then test new seeds. The owner approves composition; automated image differences detect regressions.

**Milestone 1 — Namwon vertical slice**

1. Freeze the terrain, assets, anchors and baseline routes. Choose three real sites: an available town block, an approximately 80m market segment and a 6–10-house 민촌 cluster. Preserve surrounding access.
2. Implement schema, shared-edge topology, anchor contracts and deterministic serialization.
3. Implement modest-house, working-household and shop-house grammar derivations, calibrated against KHS fixtures; include a fixed story compound at a slice boundary.
4. Solve whole-block parcels, court/building placement, terraces, entrances and shared spans. Include one rear-access lane and one stepped-site fixture.
5. Compile placement, meshes, collision/navigation and reports behind a reversible placement-layer switch.
6. Produce overhead, 22°/30° and first-person goldens plus walking routes through gates, courts and market passages.
7. Test ten seeds per slice: all hard invariants pass; provisional visual gates pass or receive an explicit owner-approved program exception.
8. At 1080p Mobile/M1, target warm traversal p99 ≤16ms. Compare cold/warm region loads over repeated runs against the approximately 7.5s baseline; permit no unexplained regression above 5%. Record memory and streaming spikes.

Milestone completion requires owner approval of all three spatial compositions, not merely passing aggregate metrics.