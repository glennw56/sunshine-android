# Sunshine Mini Golf v2 - integration notes

Test World only. v2 = phone-friendly rebuild of all 18 holes + props (v1 in `minigolf/` is untouched). Built headless in Blender from own procedural geometry (CC0/own work, no copied meshes). Brief: /workspace/minigolf/research.md.

## Conventions (all items)
- Godot glTF 2.0 (.glb), metres, Y-up. Holes: **origin = tee** (ball spawn = `Tee` empty at (0,0,0) on the green; the tee mat is painted flush into the felt), play direction **-Z**, green surface y = 0 at the tee.
- One 1024 px baked atlas per item (lighting + fake AO baked into albedo). Every material is OPAQUE with `doubleSided: false` (backface culling on at export); no BLEND anywhere.
- Palette: blush #e8b4b8, cream, chocolate, mint, butter. Felt is slightly darker than props; rails have a cream top over blush/chocolate sides.
- Each hole sits on a "cake" base whose underside is the hole floor (y -0.35 unless noted) - place the scene so the floor meets your ground, or sink it.
- Ball r 0.06 (golf_ball). **Cup: a real hole cut into the green mesh**, radius 0.15 (2.5x ball), 0.15 m deep cylinder liner with a closed bottom, conforming (no collar step); painted chocolate rim ring + cream line. Rails 0.13 wide x 0.135 tall, rounded top, one closed loop per corridor.
- Greens are closed, watertight solids (0.17 m thick) with merged vertices: one continuous surface per green, no seams / steps / T-junctions; ramps, banks and the loop blend with smoothstep tangents.

## Collision
- Every hole has a `Collision` empty with **separate low-poly** `*-colonly` meshes (Godot import suffix: static trimesh body, mesh removed). The same static colliders are also exported alone as `minigolf_v2/<hole>/<hole>_col.glb` (moving-part colliders stay in the main glb as children of their parts):
  - `Green-colonly` coarse closed green solid (rows ~0.15 m) with the **cup cut as a real hole** + liner + bottom (friction high, bounce ~0.1).
  - `Rails-colonly` closed 5-point-profile rails, continuous with no gaps (bounce 0.6-0.8, low friction).
  - `Base-colonly` cake base/fringe (out-of-bounds surface: reset ball +1 when it rests here).
  - Hazard floors (`Flour-colonly`, `Chocolate-colonly`, `Coffee-colonly`): +1 stroke and reset to the last rest spot.
  - `Obstacles-colonly` static obstacles; hole-specific funnels (`Bowl-colonly`, `Chute-colonly`).
- Moving parts carry their own collider as a child (`<Node>-colonly` under the node), so it follows the animation. After import, swap those StaticBody3D for **AnimatableBody3D** (sync_to_physics on) and drive the node from the included looping animation or code.
- Cup: add an Area3D (cylinder r 0.14, h 0.12, top 0.03 below the rim) at `CupCenter` - capture under ~1.2 m/s, else lip-out.

## Animations (glTF, one per moving part / group, loop them)
- Exported as NLA-track animations named in the table below (24 fps). Set loop mode on import. The physics colliders ride along as children.

## Holes

| Hole | Name | Par | Tee | Cup (x, y, z) | Floor y | Tris (visual + collision) | Moving nodes |
|---|---|---|---|---|---|---|---|
| 01 | Welcome Mat | 2 | (0, 0, 0) | (0.00, 0.00, -4.90) | -0.35 | 16228 (12104 + 4124) | - |
| 02 | Rolling Pin Ramps | 2 | (0, 0, 0) | (0.22, 0.00, -6.30) | -0.35 | 20099 (14871 + 5228) | RollingPinL, RollingPinR |
| 03 | Cupcake Bumpers | 3 | (0, 0, 0) | (0.50, 0.00, -5.80) | -0.35 | 28020 (22244 + 5776) | Cupcake1, Cupcake2, Cupcake3, Cupcake4, Cupcake5 |
| 04 | Donut Loop | 3 | (0, 0, 0) | (1.00, 0.00, -6.60) | -0.35 | 41116 (33600 + 7516) | - |
| 05 | Windmill Whisk | 3 | (0, 0, 0) | (-0.20, 0.00, -6.60) | -0.35 | 27258 (22008 + 5250) | Whisk |
| 06 | Croissant Curve | 2 | (0, 0, 0) | (3.00, 0.00, -0.25) | -0.35 | 28160 (21904 + 6256) | - |
| 07 | Sprinkle Slope | 3 | (0, 0, 0) | (0.50, -0.31, -5.90) | -0.65 | 25264 (18636 + 6628) | - |
| 08 | Oven Door Drawbridge | 3 | (0, 0, 0) | (0.00, 0.00, -6.90) | -0.35 | 26078 (20604 + 5474) | OvenDoor |
| 09 | Mixing Bowl Funnel | 2 | (0, 0, 0) | (0.00, -0.90, -7.35) | -1.25 | 26244 (18728 + 7516) | - |
| 10 | Conveyor Cookies | 3 | (0, 0, 0) | (-0.40, 0.00, -6.70) | -0.35 | 23142 (17520 + 5622) | ConveyorBelt, ConveyorSlats |
| 11 | Baguette Bridge | 3 | (0, 0, 0) | (-0.25, 0.00, -7.10) | -0.35 | 24556 (18780 + 5776) | - |
| 12 | Pie Crust Maze | 4 | (0, 0, 0) | (1.30, 0.00, -3.20) | -0.35 | 23962 (17510 + 6452) | - |
| 13 | Sugar Cube Stairs | 3 | (0, 0, 0) | (0.25, -0.45, -6.30) | -0.80 | 24090 (17488 + 6602) | - |
| 14 | Coffee Cup Jump | 3 | (0, 0, 0) | (0.00, 0.40, -4.95) | -0.35 | 24270 (18670 + 5600) | - |
| 15 | Macaron Gates | 3 | (0, 0, 0) | (0.30, 0.00, -6.90) | -0.35 | 28308 (22588 + 5720) | MacaronGate1, MacaronGate2, MacaronGate3 |
| 16 | Cake Tier Spiral | 4 | (0, 0, 0) | (-1.43, 0.50, 2.38) | -0.35 | 47992 (37488 + 10504) | - |
| 17 | Piping Bag Tubes | 3 | (0, 0, 0) | (-0.35, 0.00, -6.90) | -0.35 | 27328 (22278 + 5050) | PipeA_In/Out, PipeB_In/Out, PipeC_In/Out |
| 18 | Sunshine Finale | 4 | (0, 0, 0) | (0.00, 0.35, -9.10) | -0.35 | 44060 (34644 + 9416) | ConfettiL / ConfettiR |

Par total 53 (out 23, in 30).

### Hole 1 - Welcome Mat (par 2)
- File: `minigolf_v2/hole01/hole01.glb` (root `MiniGolfHole01`) + `hole01_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 2; tee (0, 0, 0) facing -Z; cup centre (0.0, 0.0, -4.9); extents [-1.5737, -0.35, -5.73] .. [1.354, 1.24, 0.73].
- Tutorial: straight 6.2 m blush green with a sprinkle trail to the cup.
- Rails: fully closed around the whole green.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Base-colonly.
- Nodes: `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Flag`, `Green`, `HoleSign`, `Rails`, `Tee`

### Hole 2 - Rolling Pin Ramps (par 2)
- File: `minigolf_v2/hole02/hole02.glb` (root `MiniGolfHole02`) + `hole02_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 2; tee (0, 0, 0) facing -Z; cup centre (0.22, 0.0, -6.3); extents [-1.6536, -0.3911, -7.13] .. [1.5317, 1.24, 0.73].
- Flour pit between z -2.4 and -3.8 (surface y -0.20) = hazard (Flour-colonly). Ball rides the groove between the two pins.
- Rail openings: Green ends at the flour pit; ball crosses on the rolling pins (rails run continuously past the pit).
- Greens: Green, GreenB; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, RollingPinL-colonly, RollingPinR-colonly, Flour-colonly, Base-colonly.
- **RollingPinL**: spins about local Z (lengthwise axis) Pivot [-0.105, -0.035, -3.1].
- **RollingPinR**: spins about local Z, opposite direction Pivot [0.105, -0.035, -3.1].
- Animations: `rolling_pins` (RollingPinL), `rolling_pins` (RollingPinR)
- Nodes: `Base`, `Collision`, `Base-colonly`, `Flour-colonly`, `Green-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Flag`, `Flour`, `FlourSack`, `Green`, `GreenB`, `HoleSign`, `Rails`, `RollingPinL`, `RollingPinL-colonly`, `RollingPinR`, `RollingPinR-colonly`, `Tee`

### Hole 3 - Cupcake Bumpers (par 3)
- File: `minigolf_v2/hole03/hole03.glb` (root `MiniGolfHole03`) + `hole03_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 3; tee (0, 0, 0) facing -Z; cup centre (0.5, 0.0, -5.8); extents [-2.2016, -0.3645, -6.53] .. [2.0613, 1.24, 0.73].
- 5 cupcake bumpers (bounce 0.8+).
- Rails: fully closed around the whole green.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Cupcake1-colonly, Cupcake2-colonly, Cupcake3-colonly, Cupcake4-colonly, Cupcake5-colonly, Base-colonly.
- **Cupcake1**: static bumper; squash/stretch on Y about base pivot when hit (code) Pivot [-0.5, 0.0, -2.0].
- **Cupcake2**: static bumper; squash/stretch on Y about base pivot when hit (code) Pivot [0.45, 0.0, -2.5].
- **Cupcake3**: static bumper; squash/stretch on Y about base pivot when hit (code) Pivot [-0.05, 0.0, -3.3].
- **Cupcake4**: static bumper; squash/stretch on Y about base pivot when hit (code) Pivot [0.6, 0.0, -4.2].
- **Cupcake5**: static bumper; squash/stretch on Y about base pivot when hit (code) Pivot [-0.55, 0.0, -4.5].
- Nodes: `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Rails-colonly`, `CupCenter`, `Cupcake1`, `Cupcake1-colonly`, `Cupcake2`, `Cupcake2-colonly`, `Cupcake3`, `Cupcake3-colonly`, `Cupcake4`, `Cupcake4-colonly`, `Cupcake5`, `Cupcake5-colonly`, `Decor1`, `Decor2`, `Decor3`, `Flag`, `Green`, `HoleSign`, `Rails`, `Tee`

### Hole 4 - Donut Loop (par 3)
- File: `minigolf_v2/hole04/hole04.glb` (root `MiniGolfHole04`) + `hole04_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 3; tee (0, 0, 0) facing -Z; cup centre (1.0, 0.0, -6.6); extents [-1.8159, -0.3624, -7.33] .. [2.8338, 2.8006, 0.73].
- Vertical loop radius 0.85 m inside a giant glazed donut (centre x 0.5, y 0.85, z -3.6); the loop shifts the ball +1.0 m in X. Needs speed ~3.2 m/s at loop entry. Butter chevrons mark the run-up.
- v2: Entry lane, loop and exit lane are ONE continuous green surface and one closed rail loop (v1 had 3 overlapping segments).
- Rails: fully closed around the whole green.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.112 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Base-colonly.
- Nodes: `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Decor5`, `Decor6`, `Flag`, `GiantDonut`, `Green`, `HoleSign`, `Rails`, `Tee`

### Hole 5 - Windmill Whisk (par 3)
- File: `minigolf_v2/hole05/hole05.glb` (root `MiniGolfHole05`) + `hole05_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 3; tee (0, 0, 0) facing -Z; cup centre (-0.2, 0.0, -6.6); extents [-1.7237, -0.3501, -7.53] .. [1.504, 2.4448, 0.73].
- Windmill tower straddles the lane at z -3.9; tunnel 0.58 m wide x 0.51 m tall. Whisk hub on the tee-facing side.
- Rails: fully closed around the whole green.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Whisk-colonly, Obstacles-colonly, Base-colonly.
- **Whisk**: rotates about local Z (faces the tee), 1 rev / 4 s; blades sweep the tunnel mouth Pivot [0.0, 1.02, -3.22].
- Animations: `whisk_spin` (Whisk)
- Nodes: `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Obstacles-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Flag`, `Green`, `HoleSign`, `Rails`, `Tee`, `Whisk`, `Whisk-colonly`, `WindmillTower`

### Hole 6 - Croissant Curve (par 2)
- File: `minigolf_v2/hole06/hole06.glb` (root `MiniGolfHole06`) + `hole06_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 2; tee (0, 0, 0) facing -Z; cup centre (3.0, 0.0, -0.25); extents [-1.238, -0.3501, -3.63] .. [4.4033, 1.364, 0.75].
- U-turn banked 14 deg toward the centre through the arc (radius 1.5 m, centre x 1.5, z -1.2). Giant croissant on the island.
- v2: Single banked green + one closed rail loop around the whole U (v1 inner rail gaps fixed).
- Rails: fully closed around the whole green.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.563 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Base-colonly.
- Nodes: `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Flag`, `GiantCroissant`, `Green`, `HoleSign`, `Rails`, `Tee`

### Hole 7 - Sprinkle Slope (par 3)
- File: `minigolf_v2/hole07/hole07.glb` (root `MiniGolfHole07`) + `hole07_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 3; tee (0, 0, 0) facing -Z; cup centre (0.496, -0.307, -5.898); extents [-1.9323, -0.65, -6.738] .. [2.1597, 1.24, 0.7303].
- Cake top tilted ~7 deg toward +X and dropping 0.28 m; 11 candy-dot bumps (r 0.07, half buried).
- Rails: fully closed around the whole green.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.174 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Obstacles-colonly, Base-colonly.
- Nodes: `Base`, `CandyDots`, `Collision`, `Base-colonly`, `Green-colonly`, `Obstacles-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Flag`, `Green`, `HoleSign`, `Rails`, `Tee`

### Hole 8 - Oven Door Drawbridge (par 3)
- File: `minigolf_v2/hole08/hole08.glb` (root `MiniGolfHole08`) + `hole08_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 3; tee (0, 0, 0) facing -Z; cup centre (0.0, 0.0, -6.9); extents [-1.7237, -0.3624, -7.73] .. [2.0171, 2.0, 0.73].
- Chocolate moat z -2.6..-3.62 (surface y -0.25) is a hazard (Chocolate-colonly). Lowered door top is flush with the green (y 0).
- Rail openings: Greens stop at the chocolate moat; the lowered oven door bridges it flush (y 0).
- Greens: Green, GreenB; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, OvenDoor-colonly, Obstacles-colonly, Chocolate-colonly, Base-colonly.
- **OvenDoor**: hinge pivot at oven mouth; rotation.x = 0 lowered (bridge, putt across) -> -PI/2 raised (blocks the oven). Anim oven_door 6 s loop Pivot [0.0, -0.026, -3.62].
- Animations: `oven_door` (OvenDoor)
- Nodes: `Base`, `Chocolate`, `Collision`, `Base-colonly`, `Chocolate-colonly`, `Green-colonly`, `Obstacles-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Flag`, `Green`, `GreenB`, `HoleSign`, `Oven`, `OvenDoor`, `OvenDoor-colonly`, `Rails`, `Tee`

### Hole 9 - Mixing Bowl Funnel (par 2)
- File: `minigolf_v2/hole09/hole09.glb` (root `MiniGolfHole09`) + `hole09_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 2; tee (0, 0, 0) facing -Z; cup centre (0.0, -0.9, -7.35); extents [-1.8036, -1.2628, -8.13] .. [1.8732, 0.845, 0.73].
- Upper green (y 0) feeds a swirl mixing bowl (centre z -3.75, rim r 1.08, drain y -0.52) -> chute -> lower green y -0.90. Whole hole sits on ground y -1.25. Bowl-colonly and Chute-colonly are the funnel surfaces.
- Rail openings: Upper green end opens into the mixing-bowl funnel (bowl rim flush at y 0); lower green fed from the chute above its rail.
- Greens: Green, GreenB; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Bowl-colonly, Chute-colonly, Base-colonly.
- Nodes: `Base`, `BowlLegs`, `Chute`, `Collision`, `Base-colonly`, `Bowl-colonly`, `Chute-colonly`, `Green-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Flag`, `Green`, `GreenB`, `HoleSign`, `MixingBowl`, `Rails`, `Tee`

### Hole 10 - Conveyor Cookies (par 3)
- File: `minigolf_v2/hole10/hole10.glb` (root `MiniGolfHole10`) + `hole10_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 3; tee (0, 0, 0) facing -Z; cup centre (-0.4, 0.0, -6.7); extents [-2.1159, -0.3624, -7.53] .. [1.67, 1.24, 0.73].
- Belt across the lane at z -3.0 (0.8 m deep). Cookie trays at z -4.4 (left) and -5.6 (right) force a zig-zag.
- Rails: fully closed around the whole green.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, ConveyorBelt-colonly, Obstacles-colonly, Base-colonly.
- **ConveyorBelt**: static surface; give its StaticBody constant_linear_velocity (+0.6, 0, 0) m/s (pushes ball toward +X) Pivot [0.0, 0.0, -3.0].
- **ConveyorSlats**: visual: translate local X 0 -> +0.12 m and wrap (anim conveyor_slats, 1 s) for a seamless moving belt Pivot [0.0, 0.0, -3.0].
- Animations: `conveyor_slats` (ConveyorSlats)
- Nodes: `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Obstacles-colonly`, `Rails-colonly`, `Conveyor`, `ConveyorBelt`, `ConveyorBelt-colonly`, `ConveyorSlats`, `CookieTrays`, `Cookies`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Flag`, `Green`, `HoleSign`, `Rails`, `Tee`

### Hole 11 - Baguette Bridge (par 3)
- File: `minigolf_v2/hole11/hole11.glb` (root `MiniGolfHole11`) + `hole11_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 3; tee (0, 0, 0) facing -Z; cup centre (-0.25, 0.0, -7.1); extents [-2.5162, -0.3624, -7.93] .. [2.17, 1.24, 0.73].
- Coffee river z -2.4..-5.0 (surface y -0.18) = hazard (Coffee-colonly, +1 stroke, reset). Baguette deck 0.30 m wide, top y +0.012.
- Rail openings: Greens end at the coffee river; the baguette deck (flat top, y 0) bridges it. Rails run continuously around the river.
- Greens: Green, GreenB; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Obstacles-colonly, Coffee-colonly, Base-colonly.
- Nodes: `Baguette`, `Base`, `Coffee`, `CoffeeBeans`, `Collision`, `Base-colonly`, `Coffee-colonly`, `Green-colonly`, `Obstacles-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Flag`, `FloatingSugar`, `Green`, `GreenB`, `HoleSign`, `Rails`, `Tee`

### Hole 12 - Pie Crust Maze (par 4)
- File: `minigolf_v2/hole12/hole12.glb` (root `MiniGolfHole12`) + `hole12_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 4; tee (0, 0, 0) facing -Z; cup centre (1.3, 0.0, -3.2); extents [-3.2159, -0.3624, -3.83] .. [2.821, 1.24, 0.73].
- Cherry-pie field 4.0 x 4.3 m with lattice-crust walls (h 0.12): several routes. Walls are in Obstacles-colonly.
- Rails: fully closed around the whole green.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Obstacles-colonly, Base-colonly.
- Nodes: `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Obstacles-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Flag`, `Green`, `HoleSign`, `Lattice`, `Rails`, `Tee`

### Hole 13 - Sugar Cube Stairs (par 3)
- File: `minigolf_v2/hole13/hole13.glb` (root `MiniGolfHole13`) + `hole13_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 3; tee (0, 0, 0) facing -Z; cup centre (0.25, -0.45, -6.3); extents [-1.8737, -0.8002, -7.13] .. [1.721, 0.845, 0.7301].
- Four terraces dropping 0.15 m each (y 0, -0.15, -0.30, -0.45); sugar-cube risers. Ground y -0.80.
- v2: v1 vertical 0.15 m steps replaced by smooth S-ramps between terraces (no ledge to snag the ball).
- Rails: fully closed around the whole green.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.385 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Base-colonly.
- Nodes: `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Flag`, `Green`, `HoleSign`, `Rails`, `SugarCubes`, `Tee`

### Hole 14 - Coffee Cup Jump (par 3)
- File: `minigolf_v2/hole14/hole14.glb` (root `MiniGolfHole14`) + `hole14_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 3; tee (0, 0, 0) facing -Z; cup centre (0.0, 0.4, -4.95); extents [-2.5333, -0.3632, -6.9458] .. [2.438, 1.6605, 0.73].
- Latte-foam kicker rises to y 0.42 at z -3.25 (launch ~28 deg). Giant cappuccino cup: rim y 0.60, coffee green y 0.40 (radius 0.93) with latte-art heart; cup at its centre. Missing the mug = out of bounds (land on saucer/base).
- Rail openings: Intentional: the kicker end of the run-up (jump into the mug). The mug wall is the boundary of the coffee green.
- Greens: Green, GreenMug; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Obstacles-colonly, Base-colonly.
- Nodes: `Base`, `CoffeeBeans`, `Collision`, `Base-colonly`, `Green-colonly`, `Obstacles-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Decor5`, `Decor6`, `Flag`, `Green`, `GreenMug`, `HoleSign`, `Mug`, `Rails`, `Spoon`, `Steam`, `Tee`

### Hole 15 - Macaron Gates (par 3)
- File: `minigolf_v2/hole15/hole15.glb` (root `MiniGolfHole15`) + `hole15_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 3; tee (0, 0, 0) facing -Z; cup centre (0.3, 0.0, -6.9); extents [-1.555, -0.3502, -7.73] .. [1.7745, 1.24, 0.73].
- Three macaron gates (r 0.27, h 0.29) at z -2.2/-3.8/-5.4 sliding across the 1.5 m lane with different periods.
- Rails: fully closed around the whole green.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, MacaronGate1-colonly, MacaronGate2-colonly, MacaronGate3-colonly, Base-colonly.
- **MacaronGate1**: slides along local X +-0.42 m (anim macaron_gate1, 5.0 s loop) Pivot [0.0, 0.002, -2.2].
- **MacaronGate2**: slides along local X +-0.42 m (anim macaron_gate2, 4.2 s loop) Pivot [0.0, 0.002, -3.8].
- **MacaronGate3**: slides along local X +-0.42 m (anim macaron_gate3, 3.3 s loop) Pivot [0.0, 0.002, -5.4].
- Animations: `macaron_gate1` (MacaronGate1), `macaron_gate2` (MacaronGate2), `macaron_gate3` (MacaronGate3)
- Nodes: `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Decor5`, `Flag`, `Green`, `HoleSign`, `MacaronGate1`, `MacaronGate1-colonly`, `MacaronGate2`, `MacaronGate2-colonly`, `MacaronGate3`, `MacaronGate3-colonly`, `Rails`, `Tee`

### Hole 16 - Cake Tier Spiral (par 4)
- File: `minigolf_v2/hole16/hole16.glb` (root `MiniGolfHole16`) + `hole16_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 4; tee (0, 0, 0) facing -Z; cup centre (-1.433, 0.5, 2.384); extents [-7.4036, -0.3624, -3.93] .. [1.57, 2.72, 4.521].
- v2b: ONE gentle ramp lap around the cake: 1.5 m flat tee, 11 m ramp 0 -> +0.5 m (max grade 5 %, soft 1 m blends), 2.5 m flat cup green at tier-1 height. Lane 1.1 m everywhere, closed 0.135 m rails both sides + end caps, cake-sponge base under the whole ramp (no drop-offs). Cake centre x -2.7. Replaces the 0.55 m spiral ledge.
- Rails: fully closed around the whole green. Min rail height above the lane edge 0.129 m. No plaque or rise at the cup.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.019 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Obstacles-colonly, Base-colonly. The game loads `hole16.glb` only; collision children are already inside it.
- Nodes: `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Obstacles-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Decor5`, `Flag`, `Green`, `HoleSign`, `LedgePiping`, `Rails`, `Roses`, `SunTopper`, `Tee`, `WeddingCake`

### Hole 17 - Piping Bag Tubes (par 3)
- File: `minigolf_v2/hole17/hole17.glb` (root `MiniGolfHole17`) + `hole17_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 3; tee (0, 0, 0) facing -Z; cup centre (-0.35, 0.0, -6.9); extents [-2.2162, -0.3624, -7.73] .. [1.821, 1.535, 0.73].
- Piping station block z -2.8..-4.1 with three nozzle mouths per side; frosting tubes arc over it.
- Rail openings: Intentional: green A ends at the piping-station face (3 nozzle mouths); green B starts at its back face.
- Greens: Green, GreenB; check: cup depth 0.15 m, worst path height step 0.0 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Obstacles-colonly, Base-colonly.
- **PipeA_In/Out, PipeB_In/Out, PipeC_In/Out**: empties: teleport trigger at *_In mouth (Area3D r 0.12) -> respawn at *_Out moving -Z. Mapping A(x-0.5)->x+0.5, B(x0)->x-0.5, C(x+0.5)->x0 (pick at random for the "3 exits" twist) Pivot [-0.5, 0.06, -2.75].
- Nodes: `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Obstacles-colonly`, `Rails-colonly`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Flag`, `FrostingTubes`, `Green`, `GreenB`, `HoleSign`, `NozzleRings`, `PipeA_In`, `PipeA_Out`, `PipeB_In`, `PipeB_Out`, `PipeC_In`, `PipeC_Out`, `PipingStation`, `Rails`, `Tee`

### Hole 18 - Sunshine Finale (par 4)
- File: `minigolf_v2/hole18/hole18.glb` (root `MiniGolfHole18`) + `hole18_col.glb`; preview `preview.jpg`, top-down rail proof `topdown.jpg`, views `views.jpg`.
- Par 4; tee (0, 0, 0) facing -Z; cup centre (0.0, 0.35, -9.1); extents [-3.0323, -0.3632, -10.08] .. [2.9029, 3.07, 0.73].
- Putt through the bakery door (1.0 m arch at z -3.02), round the display counter (z -4.95), up the ramp (+0.35 m) to the sun-emblem cup at z -9.1. No roof so the chase camera can see in.
- v2: One green from the tee through the door, round the counter and up the ramp (width blends 1.0 -> 3.0 -> 1.2 -> 1.8 m); one closed rail loop.
- Rails: fully closed around the whole green.
- Greens: Green; check: cup depth 0.15 m, worst path height step 0.216 mm, rail gaps 0.
- Collision: Green-colonly, Rails-colonly, Obstacles-colonly, Base-colonly.
- **ConfettiL / ConfettiR**: empties at the cannon mouths: emit pastry confetti (GPUParticles3D) when the ball drops Pivot [-1.13, 0.735, -9.43].
- Nodes: `Awning`, `Base`, `Collision`, `Base-colonly`, `Green-colonly`, `Obstacles-colonly`, `Rails-colonly`, `ConfettiCannons`, `ConfettiL`, `ConfettiR`, `Counter`, `CupCenter`, `Decor1`, `Decor2`, `Decor3`, `Decor4`, `Decor5`, `Decor6`, `Flag`, `Green`, `HoleSign`, `Rails`, `ShopWalls`, `Storefront`, `Tee`

## Props

### Golf ball (r 0.06, origin centre)
- File: `minigolf_v2/golf_ball/golf_ball.glb` (root `GolfBall`), 520 tris; extents [-0.06, -0.06, -0.06] .. [0.06, 0.06, 0.06].
- Radius 0.06 m, origin at centre (RigidBody3D, SphereShape3D r 0.06, CCD on). White + blush/butter sun logo on -Z.
- Collision: none (use a SphereShape3D / held item).
- Nodes: `GolfBall`, `Ball`

### Ball skins: donut, cupcake, croissant (unlockables)
- File: `minigolf_v2/ball_skins/ball_skins.glb` (root `BallSkins`), 1560 tris; extents [-0.24, 0.0, -0.06] .. [0.24, 0.12, 0.06].
- Three r 0.06 balls, each its own node with pivot at its centre (x -0.18 / 0 / +0.18, y 0.06). Swap the ball MeshInstance mesh to apply.
- Collision: none (use a SphereShape3D / held item).
- Nodes: `BallSkins`, `SkinCroissant`, `SkinCupcake`, `SkinDonut`

### Putter (0.9 m, origin at head sole)
- File: `minigolf_v2/putter/putter.glb` (root `Putter`), 228 tris; extents [-0.105, 0.0, -0.03] .. [0.105, 0.896, 0.04].
- Origin at the head sole centre; striking face toward -Z. HandGrip empty at y 0.80 for hand attach.
- Collision: none (use a SphereShape3D / held item).
- Nodes: `Putter`, `Putter.001`, `HandGrip`

### 'Sunshine Mini Golf' entrance arch
- File: `minigolf_v2/entrance_arch/entrance_arch.glb` (root `MiniGolfEntrance`), 10732 tris; extents [-2.85, -0.0005, -0.6454] .. [2.3306, 3.99, 0.5306].
- Walk-through opening 3.0 m wide x 2.3 m clear. Origin = ground centre of the walkway; sign reads from both sides.
- Collision: Pillars-colonly.
- Nodes: `MiniGolfEntrance`, `ArchSign`, `Collision`, `Pillars-colonly`, `GiantBall`, `Pennant`, `Pillars`, `SunEmblem`, `Walkway`

### Scoreboard (pastry card, pars printed)
- File: `minigolf_v2/scoreboard/scoreboard.glb` (root `MiniGolfScoreboard`), 976 tris; extents [-1.35, 0.0, -0.3] .. [1.35, 2.45, 0.3].
- Chalkboard 2.2 x 1.36 m facing -Z with holes 1-18, pars (out 23 / in 30 / total 53). ScoreArea empty = board centre (y 1.55, z -0.075) for Label3D score overlays; the grid cells are 0.2 m wide.
- Collision: Scoreboard-colonly.
- Nodes: `MiniGolfScoreboard`, `Collision`, `Scoreboard-colonly`, `ScoreArea`, `Scoreboard`

### Bench with donut armrests
- File: `minigolf_v2/bench/bench.glb` (root `MiniGolfBench`), 692 tris; extents [-0.9, 0.0, -0.25] .. [0.9, 0.9324, 0.3572].
- 1.7 m bench facing -Z; SeatPoint empty for sit anim.
- Collision: Bench-colonly.
- Nodes: `MiniGolfBench`, `BenchFrame`, `BenchWood`, `Collision`, `Bench-colonly`, `Cushion`, `DonutArms`, `SeatPoint`

### Giant donut (set dressing)
- File: `minigolf_v2/decor_donut/decor_donut.glb` (root `DecorGiantDonut`), 3024 tris; extents [-0.82, 0.0, -0.28] .. [0.82, 1.64, 0.28].
- 1.65 m standing glazed donut, origin ground centre.
- Collision: Donut-colonly.
- Nodes: `DecorGiantDonut`, `Collision`, `Donut-colonly`, `Donut`, `Stand`

### Giant cupcake (set dressing)
- File: `minigolf_v2/decor_cupcake/decor_cupcake.glb` (root `DecorGiantCupcake`), 4044 tris; extents [-0.9226, -0.0002, -0.9227] .. [0.9221, 1.6754, 0.9227].
- ~1.7 m cupcake, origin ground centre.
- Collision: Cupcake-colonly.
- Nodes: `DecorGiantCupcake`, `Collision`, `Cupcake-colonly`, `Cupcake`

### Macaron tower (set dressing)
- File: `minigolf_v2/decor_macarons/decor_macarons.glb` (root `DecorMacaronTower`), 3644 tris; extents [-0.42, 0.0, -0.42] .. [0.42, 2.137, 0.42].
- 5-macaron stack ~1.25 m, origin ground centre.
- Collision: Macarons-colonly.
- Nodes: `DecorMacaronTower`, `Collision`, `Macarons-colonly`, `Macarons`

### Giant croissant (set dressing)
- File: `minigolf_v2/decor_croissant/decor_croissant.glb` (root `DecorGiantCroissant`), 4012 tris; extents [-0.9278, -0.0001, -0.6676] .. [0.9278, 0.6645, 0.5].
- 1.7 m croissant lying flat.
- Collision: Croissant-colonly.
- Nodes: `DecorGiantCroissant`, `Collision`, `Croissant-colonly`, `Croissant`

## Integration checklist
- Load one hole scene at a time behind the Test World wall gate (rewarded-ad session unlock happens before entering).
- Spawn ball at `Tee`; camera flyover from `CupCenter` back to `Tee` (2 s, tap to skip).
- Hole 17: teleport `PipeX_In` -> `PipeX_Out` (Area3D r 0.12), exit velocity along -Z. Hole 18: fire confetti at `ConfettiL`/`ConfettiR` on drop, then show the scorecard.
- Hole 10: conveyor push is physics (`ConveyorBelt` StaticBody constant_linear_velocity +X); `ConveyorSlats` animation is visual only.
- Set dressing (cupcakes/macarons/lollipops `Decor*` nodes) stands on the floor plane outside the rails; it has no collision (out of play).
- Rebuild: `_work/mg2_run.sh <item>` (gen -> Blender build -> compose), `_work/mg2_finalize.py topdown`, `_work/mg2_notes.py`, then `.venv/bin/python _tools/check.py minigolf_v2`.

## Changes from v1
- **Cups**: v1 had a jagged cut with a raised collar ring (ball snagged). v2 cuts a conforming square->circle patch into the green: a true r 0.15 hole, 0.15 m liner with a bottom, manifold rim. Same hole is cut in `Green-colonly`.
- **Greens**: v1 built each hole from overlapping segments (seams, 7-12 mm steps at joins, T-junctions). v2 makes one watertight solid per green from a single path (welded, one component), with smoothstep width/height blends. Verified by sampling ball-path heights every 1 cm on 9 lanes (no step > 2 mm anywhere).
- **Rails**: v1 rails were per-segment with gaps at joins (holes 6, 14, 16 worst). v2 sweeps one closed loop around each corridor (rounded corners, end caps), continuous over hazards; only intentional openings remain (hole 14 jump, hole 9 bowl, hole 17 piping station). Top-down renders are the proof.
- **Collision**: separate low-poly meshes (coarse green solid, 5-point rail profile) instead of copies of the visual meshes; plus `<hole>_col.glb`.
- **Tee mat**: no longer a raised 12 mm box; painted flush into the felt. `Tee` empty moved to y 0.
- **Hole-specific**: 4 one continuous entry-loop-exit green; 6 single banked U with full inner rail; 8 oven door shortened so it meets the green flush (no overlap); 9 chute re-routed to clear the rail; 10 conveyor belt collider flush with the green (top y 0, was +8 mm), slats 3 mm; 11 baguette deck flat-topped at y 0 with square ends (was +12 mm with rounded ends); 13 vertical 0.15 m steps replaced by smooth ramps (riser cubes removed, sugar stacks kept on the fringe); 14 coffee-mug green is a disc green with the cup at its centre; 16 v2b is one 1.1 m lane, a 5% ramp to a flat tier-1 green, closed rails, cake centre x -2.7; 18 one green through door, counter room and ramp (v1 extra rails removed).
- **Texture**: cup area gets 3x texel density in the atlas for a crisp rim.

## Hole 16 v2b (2026-10-22 playtest fix)
- Playtests: ball fell off the 0.55 m north spiral ledge. v2b replaces it with ONE gentle 1.1 m lane lapping the cake (318°, r 2.7 around the cake centre, cake moved to x -2.7): 1.5 m flat tee, 11 m ramp 0 -> +0.5 m (soft 1 m blends), 2.5 m flat cup green level with the tier-1 top. No plaque/rise at the cup.
- Lane check: max grade 5.02% (limit 6), min free width between rails 1.086 m (limit 1.0), min rail height above lane edge 0.129 m (limit 0.12), ball-drop rays at 302 edge samples (both sides, every 0.1 m): 0 without a rail outside.
- Closed 0.135 m rails both sides + end caps; cake-sponge base under the whole ramp. Same node names, Tee (0,0,0), CupCenter (-1.433, 0.5, 2.384), par 4. Cup is a real hole in Green and Green-colonly. Sign and decor are inside the hole mesh and moved outward with it.
