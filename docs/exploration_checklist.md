# Planet exploration upgrade - checklist

Status: [ ] not started · [~] in progress (implemented, waiting for an in-game test counts as in progress) · [x] completed (implemented AND tested) · [!] blocked / needs attention

Claude cannot run Godot itself, so nothing is marked [x] before Emil has tested it in the game.

## 1. Swimming and underwater exploration
- [~] 1.1 Walk from the beach into the sea (deep water no longer blocks you)
- [~] 1.2 Swimming state at the surface: buoyancy, water drag, slower movement
- [~] 1.3 Diving and rising in any direction (look direction, Space up, C down)
- [~] 1.4 Smooth changes walk -> wade -> swim -> dive -> climb out onto land
- [~] 1.5 Never through the seabed or stuck under the terrain (seabed walking: see 10.8)
- [~] 1.6 Underwater camera: colour tint, fog / visibility by depth, darker light
- [~] 1.7 Water surface visible from below
- [~] 1.8 Underwater world explorable: seabed plants, rocks, animals visible
- [~] 1.9 Aquatic animals move naturally in 3D under water

## 2. First- and third-person cameras
- [~] 2.1 Visible player character model
- [~] 2.2 Character animations: idle, walk, run, jump, swim
- [~] 2.3 Third-person follow camera (default), smooth
- [~] 2.4 Camera does not clip into terrain / objects
- [~] 2.5 First-person mode, V switches smoothly, own head/body hidden
- [~] 2.6 Both modes work all around the sphere (also upside down)

## 3. Scale (player, animals, plants 50%)
- [~] 3.1 Player 50%: eye height, body radius, speeds, jump
- [~] 3.2 Animals 50% (incl. reach, flee distances, holding view)
- [~] 3.3 Vegetation 50% (plants, trees, ground cover)
- [~] 3.4 Rocks / objects reviewed (small ones smaller, big formations kept)
- [~] 3.5 Collisions, obstacles, interaction distances adjusted
- [~] 3.6 Camera distances / FOV adjusted

## 4. Capsule boost (Shift)
- [~] 4.1 Shift = about 2.5x top speed, smooth ramp up and down
- [~] 4.2 Stable steering at high speed
- [~] 4.3 No tunnelling through terrain at high speed (sub-steps)

## 5. 3D creature colours
- [~] 5.1 Find and fix the real cause of black 3D creatures
- [~] 5.2 Fix crash for Corona (Sun) creatures
- [~] 5.3 3D colours use the same colour regions as the 2D drawings
- [ ] 5.4 Check every element and hybrids (photos)
- [ ] 5.5 Colours correct in different light (gallery, battle, dark)

## 6. Environmental realism
- [~] 6.1 More plant variety: sizes, ages, growth forms per planet
- [~] 6.2 Plants bend away when the player walks through them
- [ ] 6.3 Water reacts to wind / weather (waves, foam, shore)
- [~] 6.4 Splashes when player, animals or capsule enter water
- [~] 6.5 Shallow -> deep water colour and visibility
- [~] 6.6 Animal behaviours: feeding, resting, fleeing, exploring, swimming, meeting others
- [ ] 6.7 Fog / clouds / atmospheric depth improved, weather influences them
- [ ] 6.8 Planet-specific environmental effects
- [ ] 6.9 Terrain / rock / geology variation
- [ ] 6.10 Less repetition over large areas

## 7. Mycelia mushroom valley
- [~] 7.1 Narrow, deep valley carved into the terrain
- [~] 7.2 Steep walls cannot be walked up; valley cannot be jumped across
- [~] 7.3 Valley atmosphere: fog, roots, fungi, rock formations
- [~] 7.4 Giant mushrooms at different heights as platforms
- [~] 7.5 Standing on caps works with spherical gravity
- [~] 7.6 Bounce: cap squashes, springs back, launches you; spores, sound, air control

## 8. Performance
- [~] 8.1 Measurement: FPS / frame time / draw calls overlay + log (F3)
- [~] 8.2 Distance detail levels with fading (no hard pop-in) for props and plants
- [~] 8.3 Animals: near full, medium simplified animation, far paused / hidden
- [~] 8.4 Shadows only near the player
- [~] 8.5 Particles reduced / stopped when far or unseen
- [ ] 8.6 Clouds and atmosphere stay cheap (shader shells)
- [~] 8.7 Static prop parts merged (fewer draw calls)
- [!] 8.8 Before / after numbers compared

## 10. Second round (2026-11-19 request)
- [~] 10.1 Crash explosion: flash, fireball, mushroom cloud, shockwave, smoke column, fire, secondary blasts, sound (not on water)
- [~] 10.2 Mycelia valley placement and visibility (bigger, beacons, lit rims, trail, navigator)
- [~] 10.3 Mushroom crossing - all hops checked in a physics simulation, in-game traversal test still needed
- [~] 10.4 Objective navigator (valley, objects, quest sites, nearest unknown animal), N / B
- [~] 10.5 Further scale step (player 46 cm, animals 25%, plants 25%, cover 35%)
- [~] 10.6 Surface swimming (face-down crawl, faces swimming direction, floats)
- [~] 10.7 Diving and underwater swimming (3D, buoyancy, resistance, body follows the swim direction)
- [~] 10.8 Seabed walking (down to 7 m, upright, slow, Space swims up)
- [~] 10.9 Water <-> land transitions (land, swim, seabed, back to land)
- [~] 10.10 Carrying sea animals (rules, swim while carrying, release in water / on land, stranded animals flop back)
- [~] 10.11 Grass and ground details (lush multi-green grass, moss, leaf litter, twigs)
- [~] 10.12 Pebbles and loose stones (irregular, half buried, mixed colours)
- [~] 10.13 Terrain roughness and close-up detail
- [~] 10.14 Richer vegetation colours (deep / leaf / emerald / olive / yellow-green)
- [~] 10.15 Plant geometry and detail (leaves serrated with veins, curved grass; trees not reworked yet)
- [~] 10.16 Vegetation movement and natural patchy distribution
- [~] 10.18 Capsule breaks apart: hull in 8 panels + rings, fins, engines, window, tail fin, legs, lamps, shards; mass-based flight, tumbling, bouncing; biggest pieces burn and smoke; intact capsule hidden until repaired
- [~] 10.19 Shockwave much smaller and brief (about 10 m, 0.5 s, fainter)
- [~] 10.20 Aftermath: pieces lie on the ground ~18 s, fire ~10 s, smoke ~14 s, then shrink away and are removed (pieces in the sea sink away)
- [!] 10.17 Performance verification (needs F3 numbers with F4 on and off from Emil)

## 11. Planet environment upgrade (scale, surfaces, living ecosystems)
- [~] 11.1 Scale checked once and set as absolute sizes (no stacked multipliers): explorer 0.23 m, capsule 0.5, animals 0.125, plants 0.125, rocks / crystals 0.3; collisions, camera distances and speeds adjusted
- [~] 11.2 Surface geometry: finer terrain mesh (144 cells per face, about 1.2 m), small bumps and erosion grooves everywhere, strength per planet (Ferrum / Pebble / Voltara rough, Glacia / Aquora smooth)
- [~] 11.3 Surface materials: soil matte, rock with varied reflectivity, glinting grains (crystal, salt, ice, metal, obsidian), glossy ice with a blue-green depth, wet sheen on Mycelia and shores
- [~] 11.4 Streamed ground layer: 20 m patches near the player, GPU instancing (one MultiMesh per kind per patch), nearest patches first, work spread over frames, fades out with distance, removed far away
- [~] 11.5 Grass: dense, multi-green, moves with the wind, a different variant per patch
- [~] 11.6 Small details: flowers, ferns, bushes, moss, leaf litter, twigs, pebbles, stones, fungi, shells
- [~] 11.7 Natural distribution: noise clumps, flat fertile ground dense, rock lovers on slopes, crack plants only in cracks, shore and underwater kinds
- [~] 11.8 Pebble: gravel, stones, lichen, crack moss, hardy sprouts, scrap; beetles and dust
- [~] 11.9 Glacia: frost grass, frost ferns, snow patches / clumps, ice shards; drifting snow, ice crawlers
- [~] 11.10 Mycelia: mini mushrooms, bell mushrooms, spore puffs, fungal threads, moss, lichen; glowing spores, fungus bugs
- [~] 11.11 Aquora: grass, beach grass, shells, wet stones, flowers, seaweed, seagrass; crabs on the shore, flutterers
- [~] 11.12 Verdis: thick grass, tall grass, ferns, bushes, flowers, moss, leaf litter, twigs, stones, small mushrooms; butterflies, beetles, pollen
- [~] 11.13 Ferrum: cinders, glowing lava cracks, heat plants, ember plants, hardy sprouts; rising embers
- [~] 11.14 Voltara: storm grass, wind bushes, spark crystals, metal nodules; spark motes
- [~] 11.15 Solara: crystal grass, sun dishes, salt crust, glass pebbles; light motes, glass beetles
- [~] 11.16 Ambient life around the player: insects fly from plant to plant, land for a moment and flee from your feet; crawlers wander and scurry away; motes drift in the wind (3 draw calls)
- [~] 11.17 More small plant props (x1.6)
- [ ] 11.18 Animals interacting with each other (beyond feeding / fleeing)
- [~] 11.20 Crash explosion re-sized for the smaller capsule (drawn at 45 %: fireball ~6 m, cloud ~12 m)
- [!] 11.19 Performance on all 8 planets (needs the PERF lines from Emil's computer)

## 12. Scale, water, jump, cannon (2026-11-19, third request) - implemented = [~], tested in game = [x]
- [~] 12.1 Final scale for plants, rain and small objects: plants 0.1 (was 0.125), ground detail x0.8, rain streaks 6 mm x 16 cm (were 3 cm x 70 cm), splash / snow / spore / pollen / ember particles about 30 %, bubbles 1.4 cm; explorer (0.23 m), capsule (x0.5) and animals (0.125) kept - they are small now because the world grew
- [~] 12.2 Sense of scale: planets 1.8x the radius (e.g. Verdis 120 -> 216 m), hills / mountains / terraces / lakes / landforms 1.5x bigger and wider; horizon on foot about 1.35x further; lower third-person camera, narrower lens on foot (62°), chase camera closer to the capsule; more props and animals on the bigger planets (same density)
- [~] 12.3 Parked capsule visible nearby: no distance culling on the capsule, grass is pressed flat under it, blinking parking beacon; position / locator unchanged (saved positions are re-projected onto the bigger planets)
- [~] 12.4 Higher-detail water: fine moving water patch around you (dense rings in the middle, coarser outwards = adaptive), cheap far sphere; depth-dependent colour and transparency from baked depth maps (whole planet + sharp 80 m map around you); shore foam, breaking-wave lines, crest light; sky reflection + sun glints (no screen-space refraction: see limits)
- [~] 12.5 Dynamic waves: 5 wave layers (21 m swell .. 1.1 m chop) with sharper crests, following the wind, stronger in storms, lower and breaking in shallow water, stop at the beach
- [~] 12.6 Player and animal splashes: jumping in (size from fall speed), wading rings, swimming wake + stroke splashes, diving rings, landing in shallow water / rivers; animals splash entering water, leave wakes at the surface, leaping fish splash by size
- [~] 12.7 Capsule and water: touch-down splash by speed / angle (existing rules), V-shaped wake while surfing, take-off spray, downwash rings and spray when flying low over the sea, cannon shells splash with a water column; 24 ring waves at once, sized by what made them
- [~] 12.8 Streams, rivers and waterfalls: traced downhill on Aquora, Verdis, Glacia (water) and Ferrum (lava), carved into the terrain; flowing ribbons with rapids, waterfalls with mist, pools at the end, fading into the sea at the mouth; no plants in the water; lava rivers block walking
- [~] 12.9 Underwater: visibility shrinks with depth (existing fog), sea floor colours fade to blue-green with depth, moving caustics on the sea floor, floating plankton particles, smaller bubbles
- [~] 12.10 Jump distance about doubled (jump 1.9 -> 2.6, air speed x1.45: about 1.1 m -> 2.3 m on normal gravity), air control kept, landing / platforms unchanged
- [~] 12.11 Capsule cannon: left mouse button (hold for steady fire) or X; crosshair with distance and reload ring; shell flies visibly with light and trail; one shot per 0.9 s, max 4 in the air
- [~] 12.12 Shell collision with the real terrain (checked every 0.6 m against the ground's height function, exact hit point found by bisection), trees / rocks, the sea
- [~] 12.13 Real craters: the ground's height function is changed (ragged bowl + raised rim + rubble); walking, capsule, animals, ground detail and the mesh all use the new shape; only the 1-4 touched terrain chunks are rebuilt (extra fine 0.5 m cells nearby); exposed rock layers coloured in the crater; plants / rocks in the blast destroyed
- [~] 12.14 Cavities in mountain walls: on steep rock the blast cuts everything above the impact's floor inside the outline away = a deep notch into the wall (height field: no overhanging tunnels)
- [~] 12.15 Persistent deformation: kept for the whole session and in the save game (up to 80 craters per planet; the oldest fills in after that)
- [~] 12.16 Weapon performance / cleanup: explosion parts remove themselves after 10 s, rock fragments after ~19 s, no physics engine, local rebuilds only
- [ ] 12.17 Full gameplay test (Emil): scale on foot / from the capsule, capsule nearby, water from above and below, splashes, rivers, jumps (terrain, cliffs, mushrooms, water), cannon on flat ground and on a mountain wall, crater still there after leaving and coming back

## 13. Character, collisions, water, plants, light, space travel (2026-11-19, fourth request) - implemented = [~], tested in game = [x]
- [~] 13.1 Player character scale: 23 cm -> 34 cm (x1.5) - body, eyes, collision radius (9 cm), walk / run speed, swim depths and speeds, third-person camera distance, use / enter reach, carried animals, bubbles all set to match
- [~] 13.2 Jump distance and air control: jump 2.6 -> 4.3 m/s, faster fall after the top (not floaty), air speed x1.4 with steering kept: about 4.3 m far / 1 m high on normal gravity (was 2.3 m / 0.36 m); mushroom bounces unchanged
- [~] 13.3 Ground collision: cause found - the drawn ground (chunks at different detail) and the height the player stood on were different, and the detail level was chosen by a chunk's centre, so the ground next to you could be drawn coarsely; now walking / landing use the exact drawn triangles (`TerrainLOD.surface_height`), detail is chosen by the nearest edge, movement runs in small sub-steps (no skipping through caps or thin ground)
- [~] 13.4 Wall and obstacle collision: cause found - a jump into a steep wall put you on top of it (walls were only checked while on the ground), and cliffs / arches / rocks were one circle each (you could walk into most of a cliff); now walls stop you in the air too (slide along them), landforms get their real outline at walking height from their triangles (arches stay open underneath), rocks are as wide as they look; a spatial grid keeps it fast
- [~] 13.5 Water opacity, colour and reflections: mostly opaque (78-97 %), deep teal to deep blue, sky reflection with Schlick fresnel, sun glints
- [~] 13.6 Small water waves and surface detail: 8 small wave trains (12 cm - 1 m) plus drifting noise, roughness varying with gusts, glints on the ripples; big waves much calmer unless the weather is rough
- [~] 13.7 Aquora aquatic plants: 6 new alien species (lattice fan, bladder kelp tower, anemone bloom, spiral frond, bubble algae, arch-root tree) with stems, branches, roots, blades, bulbs, tentacles, fins and webbing, colour gradients, glowing tips, sway in the current; 8 variants each + random size / lean / turn; tall ones always stay under water
- [~] 13.8 Naturalistic greens: green plant colours pulled towards deep forest, leaf, emerald and olive greens (chosen per plant), darker inside, fresh at the tips; fungi, ice, crystals and flowers untouched (Mycelia and Glacia keep their colours)
- [~] 13.9 Flashlight: 24° -> 50° beam with a soft edge and natural falloff, plus a short spill light around you; bluer and shorter under water; capsule headlights 48 -> 70 m, 30° -> 40°
- (removed in stage 8: no more flying between planets) ~~13.10 Space flight and leaving the air: no height limit any more; the air thins out smoothly (less drag, more thrust), the planet stops turning while you are in space, haze fades so the planet stays visible behind you; capsule and camera keep a smoothly turning "up"~~
- [~] 13.11 Distant planet stand-ins: every other planet (and the sun) at its real system position as one light sphere with a picture baked from its real terrain (sea, lava, ice, clouds, day / night side, air glow); far ones drawn closer and smaller by the same factor (look identical, stay in camera range)
- (removed in stage 8: no more flying between planets) ~~13.12 Continuous travel: one shared system coordinate space (`solar_system.gd`, ready for orbits later); Tab / M picks a target, hold Q turns towards it, markers with distances; the destination is built step by step from 2.5 km out (dropped beyond 4 km), and 650 m above its ground everything is re-measured from the new planet in the same frame (capsule, speed, camera, stars, old planet) - no fade, no teleport~~
- (removed in stage 8: no more flying between planets) ~~13.13 Atmospheric entry and landing: the air brakes you smoothly from space speed (starting higher the faster you are), you fly on into the air and land as usual; the destination is the real planet with its saved state; planets still held by the Umbra (and the sun) can be flown to but not entered~~
- [~] 13.14 Stronger Shift boost: x4.5 in the air (17 -> 78 m/s, was x2.7), x5 in space (about 1100 m/s), smooth ramp up and down, collision checked in up to 24 steps per frame
- [~] 13.15 Performance and state: stand-ins are 1 draw call each, pictures baked once per session a few rows per frame, the next planet is prepared over many frames (some 100-300 ms steps remain), hysteresis between 2.5 km / 4 km; planet state (craters, time, finds, buildings) kept; a planet left in space starts with a normal arrival next time
- [ ] 13.16 Full regression test (Emil): character size / both cameras; jumps on terrain, slopes, cliffs, mushrooms, water; walk / run / jump into walls, rocks, cliffs from all sides; water from above / below; Aquora plants; greens on Verdis; flashlight at night and under water; leave Aquora, fly to Verdis (Tab / Q / Shift), watch Aquora shrink and Verdis grow, enter its air and land; boost in air and space

## 14. Capsule camera and mouse during space travel (2026-11-19, fifth request) - implemented = [~], tested in game = [x]
- [~] 14.1 Cause of the camera-distance drift found: (a) the chase distance grew with height up to 30 m - in space the height is huge, so always 30 m; (b) the camera chased the capsule's world position with smoothing, which leaves it behind by speed / 7 - at 1100 m/s boost about 160 m (the capsule became a dot); (c) the field of view widened with the boost (66° -> 84°)
- [~] 14.2 Capsule position and size on screen stabilised: the camera now follows in the capsule's own frame (only the offset is smoothed, never the world position, so speed can't pull it away); distance 3.4 m in space and low flight (a bit more only high up inside the air), offset kept within 70-115 % of the wanted distance (no clipping into the camera, no drifting away); boost widens the view only 66° -> 72°; the boost itself is unchanged (x5 in space)
- [ ] 14.3 Verify the camera at maximum Shift boost (in game)
- [~] 14.4 Cause of the lost mouse found: at the hand-over to the next planet the new view captured the mouse, then the old view's clean-up (`_exit_tree`) set the mouse free at the end of the same frame - cursor visible, touchpad moved the pointer, steering stopped. Nothing else (loading, terrain, water, plants) touches the mouse
- [~] 14.5 Mouse-look kept through every planet transition: the old view no longer frees the mouse when it hands over, the new view captures it at once, and one rule is checked every frame (flying / walking / swimming = captured with controls on; windows, quest list, pause / exit menu, leaving for the ship, photo tour, game window not focused = free) - lost capture is restored immediately
- [~] 14.6 Menus and on-foot behaviour kept: windows, quests and the pause menu still free the mouse; walking, swimming, getting in / out unchanged
- [ ] 14.7 Test normal flight, boosted flight and planetary approach (in game)
- [ ] 14.8 Test all camera and input transitions: menus, pause, getting in / out, first / third person, hand-over (in game)
- [ ] 14.9 No regressions in flight: take-off, landing, water landing, atmospheric entry (in game)

## 15. No flight between planets; water, terrain, animals (2026-11-19, sixth request) - implemented = [~], tested in game = [x]
- [~] 15.1 Seamless interplanetary flight removed: the capsule has a firm ceiling 150 m above the ground again (no space state possible); space thrust / drag / boost, entry braking, target selection (Tab / M / Q), planet markers, step-by-step planet building, the hand-over between planets, space dust, the frozen day and the camera-range code are all deleted. Kept: the neighbouring planets in the sky (one cheap sphere each, at their system positions) and the turning stars
- [~] 15.2 Planet travel: T opens "Leave <planet>" with "Fly up to the ship" and "Fly to <planet>" for every planet you have freed; the capsule climbs away, a short travel cinematic (about 3.5 s, any key skips) shows the old planet falling away and the new one growing, then the destination loads as usual and you arrive at your saved place (or the landing place)
- [ ] 15.3 Verify progression and saves (freed planets, buildings / mines, finds, craters, capsule state, old save files)
- [~] 15.4 Water surface: small waves in 8 layers plus the 5 bigger ones, wind / weather driven, rings / splashes / wakes, shore foam and breaking lines, sky reflections and glints, not see-through (stage 6), unchanged here
- [~] 15.5 Water physics: the game now knows the real wave height everywhere (the same wave formula as the drawing): the floating capsule rides and tilts with the waves and is pushed down their faces, with more water resistance the faster it goes; swimmers rise and fall with the waves, buoyancy grows the deeper you are, water resistance grows with speed; animals at the surface ride the waves; falling debris splashes by its weight and speed, then sinks slowly to the sea floor; running into the water throws spray forwards
- [~] 15.6 Underwater: sunlight turns blue-green and dims with depth (plus the existing fog, caustics, plankton, bubbles); new seabed rock pillars with sponges, fans and anemones growing on them, and bubbling vents; swimming, diving, seabed walking unchanged
- [~] 15.7 Rivers / streams / pools: 8 rivers on Aquora and Verdis (were 6), 4 new streams on Mycelia (ending in pools), lava rivers on Ferrum, meltwater on Glacia; beds carved into the real ground, water only flows downhill (stage 5 system)
- [~] 15.8 Terrain geometry on every planet and island: stronger small bumps and grooves, rolling unevenness (10-20 m), rocky outcrops - stepped ledges of bare rock breaking through the ground, ragged coastlines with coves and points
- [~] 15.9 Surface materials: outcrops and craters are drawn as rock (bumpier, rougher), gravel and loose stones around rock and on moderate slopes, soil matte, wet shores darker and shiny, ice glossy, crystals / metal glinting (stage 4 materials kept)
- [~] 15.10 More animals: twice the density (one group per 380 m² of planet surface instead of 750 m², up to 1100 groups), they appear within 60 m (was 50) and stay visible up to 62 m; at most 120 at once
- [~] 15.11 More species: 13 generated alien species per planet (was 8) plus the 10-14 hand-made ones - different body plans, limbs, eyes, mouths, materials, ways of moving
- [~] 15.12 Animal behaviour: every animal has its own boldness (shy ones run early, bold ones come close); noises (your jumps and landings, splashes, the capsule flying low, cannon blasts) make bold animals come to look, shy ones run and others stop and listen; animals of the same kind go over to each other and greet; plus the existing wandering, feeding, drinking, resting, hunting, fleeing, swimming, flying, climbing
- [~] 15.13 Performance: animals far away think every 3rd frame (18 m) / every 6th frame (38 m), the 120-animal limit, water wave heights computed only where needed; nothing is simulated for other planets any more
- [ ] 15.14 Regression tests on all planets (movement, jumps, capsule landing / water, swimming / diving / seabed, carrying, quests, progression, mines, old saves)

## 16. Big, visible changes: animals, giants, real wave physics, player size, Mycelia (2026-11-19, seventh request) - implemented = [~], tested in game = [x]
- [~] 16.1 Animals much bigger: size factor 0.125 -> 0.3 (most now 15-70 cm, giants 1-2 m; before 5-30 cm and hardly visible), walking speed x1.7, flying higher and wider
- [~] 16.2 Many more animals: one group per 260 m² (was 380, at first 750), up to 1600 groups per planet, appear within 70 m, up to 170 at once; small ones disappear sooner (28 m), big ones are seen from 85 m
- [~] 16.3 Absurd giant species: Cinder Fly on Ferrum (as big as you, four yellow eyes, four veined wings, a glowing yellow spine of plates - own design from Emil's traits), Drift Hulk on Glacia (original shaggy giant, 3x your height, ice tusks - not a copy of Mammott), Stiltcap and Cap Hopper (Mycelia), Sky Whale (Aquora), Thorn Titan (Verdis), Coil Runner (Voltara), Mirror Strider (Solara), Boulder Tick (Pebble)
- [~] 16.4 Dark spots on the water: cause - the moving water surface received the sun's shadows (only within 45 m = "when I approach", with blotchy shadow artefacts on the waves); water no longer receives shadows
- [~] 16.5 Real water physics: the 2D wave equation solved on the graphics card in a 48 x 48 m area around you (256 x 256 cells, 16-bit heights, a step every frame); splashes, strokes, wakes, capsule landings and falling objects push the surface, the waves spread, interfere and bounce off shores and rocks; the sea shader moves, lights and foams with them (checked in a Python model: stable, waves die out, reflection at the shore)
- [~] 16.6 Player 60 cm (was 34 cm): body, eyes, collision (15 cm), walk 2.4 / run 4.8 m/s, jump about 7 m / 1.5 m high, swimming depths and speeds, cameras, reach, carried animals
- [~] 16.7 Mycelia fuller: 2.2x the fungus plants (giant mushrooms, tiered caps, trumpets, puffballs, coral fungus, shelf fungus, moss mounds, glow bulbs ...), 2x the ground detail; plants on all planets grown with the bigger player (x1.8), ground detail x1.7
- [~] 16.8 Mushroom valley: first and last caps right at the cliff edges (about 1.5 m from the wall, slightly above the rim), the middle caps 1.5-3 m higher and closer; softer bounces (they threw you 14-17 m - past the next cap); landing help pulls you gently towards a cap's middle while you come down on it (checked in a Python model)
- [~] 16.9 Natural effects: wind gusts roll across grass and plants in visible waves (silvery sheen where they bend), running kicks up dust / snow at your feet
- [ ] 16.10 Test (Emil): animals everywhere and big, the giants on Ferrum / Glacia, water near you (no dark spots, waves from splashes bouncing off the shore), player size, Mycelia plants, the valley crossing

## 17. Savanna, strange cows and rabbits, loading screen, smoothness, players (2026-11-20, eighth request) - implemented = [~], tested in game = [x]
- [~] 17.1 Verdis has regions: jungle, golden savanna, red-earth savanna and lush tropical forest (ragged borders, own ground colours, clearer air)
- [~] 17.2 Savanna plants (after Emil's photos): flat-topped acacias (wide layered roofs on zig-zag limbs), young acacias, thorn bushes, bare dead trees, candelabra succulents, termite mounds, granite rock piles; tall golden grass with seed heads, dry tufts, green tufts, red earth, yellow flowers
- [~] 17.3 Tropics: palms and the jungle plants only in jungle / tropical regions; the trees around the landing place match the region
- [~] 17.4 Strange savanna animals: Forkneck (giraffe with two necks, one-eyed and three-eyed head, glowing bulbs), Sailback Tusker (six legs, three trunks, sail ears, a garden with a tree on its back), Sunmane (hunter with a glowing mane), Grass Skipper - they live only in the savanna
- [~] 17.5 Aquora cows and rabbits: Coral Cow (coral horns and patches, fin ears, snorkel), Merry Moo (cow in front, fish tail behind, swims and leaps), Shellbunny (snail shell, three eyes, fin ears), Bubble Bunny (floats in a bubble)
- [~] 17.6 Loading screen: the planet turns and is painted band by band, the capsule spirals in, stars stream past, progress bar with the current step, tips; the planet is built a little every frame behind it
- [~] 17.7 Hitches while flying fixed: ground chunks were built in one go (up to ~140 ms with their colours) - now spread over frames by time (3.5 ms); ground detail by time (2.5 ms); animals queued and built one by one (2.5 ms); every material and every species drawn once behind the loading screen, so the graphics driver doesn't stop to prepare them in flight
- [~] 17.8 Lighter: an animal's shapes are merged per moving part (a handful of draw calls instead of dozens, the meshes shared by all animals of a species); at most 140 animals at once (was 170); slightly less savanna grass
- [~] 17.9 Mycelia warning flood fixed (veils with zero-length threads made broken meshes)
- [~] 17.10 Players: "Who is playing?" at the start; each player has their own saved game; new player = new game; rename, delete; "Switch player" in the menu (Esc); the existing save became "Player 1"
- [ ] 17.11 Test (Emil): Verdis savanna and tropics, the new animals on Verdis and Aquora, loading screen, smooth flight (no stops), players and their saves

## 18. Water: clear shallows, lakes to swim in, streams, water plants, real sea waves (2026-11-20, ninth request) - implemented = [~], tested in game = [x]
- [~] 18.1 Sea see-through like real water: how much you see through depends on the depth and the angle you look at (sand and stones visible in the shallows); from far away the sea is one even colour per planet (blue on Aquora, greyer / greener / violet elsewhere)
- [~] 18.2 Swimming only where it is deep enough: the sea and the new lakes (2-3 per wet planet, 11-19 m wide, up to about 3.5 m deep); streams and small pools are only for wading (there is no swamp on any planet yet)
- [~] 18.3 Under water: murky (you see about 8-15 m, lakes murkier than the sea), coloured by planet
- [~] 18.4 Keys in the water: Space rises, Shift (or C) sinks, Ctrl swims faster (on land Shift still runs)
- [~] 18.5 Small streams (5-12 per planet, 0.6-1.7 m wide, shallow) with a weak current that pushes you gently downstream while you wade; stony beds, stones sticking out with white water swirling around them and trailing downstream; clear water showing the stones
- [~] 18.6 Plants and stones at and in the water: reeds with cattails along every stream / lake, water lilies (some flowering) on lakes and pools, leafy water weed on lake floors, stones and pebbles in stream beds, big mossy rocks along the banks, sunken logs in lakes, driftwood on beaches
- [~] 18.7 Sea floor: pale sand (darker deeper down) with rocky reefs and boulders rising out of it, stones and leafy sea weed between them, more kelp on Aquora; lake floors fine grey-brown sand and mud
- [~] 18.8 Real sea waves: Gerstner waves (the water also moves in circles, so crests are sharp and troughs wide), a long ocean swell on the open sea (only where it is deep), whitecaps streaked by the wind on the high crests in rough weather; swimmers, the capsule and animals still ride exactly these waves
- [ ] 18.9 Test (Emil): see-through shallows, far colour, swimming in the sea and a lake, Space / Shift in the water, wading in a stream (current), stones and white water, reeds, lilies, sea floor, waves in calm and stormy weather

## 19. Verdis: flat savannas, realistic plants, palms and frogs, lighter (2026-11-20, tenth request) - implemented = [~], tested in game = [x]
- [~] 19.1 Savanna regions are wide flat plains now (the land only rolls gently, about a fifth of the hills), soft borders to the hillier jungle
- [~] 19.2 Acacias more real: the crown is several flat "tables" of feathery leaves at different heights (one per limb plus one on top), darker underneath, drooping rims (like the photo)
- [~] 19.3 Savanna grass with pale feathery seed plumes over the golden blades
- [~] 19.4 Tropics: real palms (curved ringed trunks, long arching feathery fronds, fruit clusters), tree ferns, big glossy-leaf plants in the undergrowth; fewer plain grass tufts there
- [~] 19.5 Strange frogs in the jungle and tropics: Lantern Frog (four eyes, glowing throat sac that flashes at night), Stilt Frog (legs twice its length, eyes on stalks, poisonous orange), Umbrella Frog (leaf-like frills it spreads like an umbrella, three golden eyes)
- [~] 19.6 Lighter: every plant / rock kind is built in only 6-8 shapes per region, all others are copies sharing their meshes (much faster loading, far less memory); acacia crowns kept to about 550 leaf cards
- [ ] 19.7 Test (Emil): flat savannas, acacias, grass, palms, frogs, loading time and FPS on Verdis

## 20. Riding animals; Verdis rainforest (2026-11-20, eleventh request) - implemented = [~], tested in game = [x]
- [~] 20.1 Ride every animal bigger than you (body 45 cm and up: giraffes, tuskers, hulks, giant flies, striders, big hoppers ...): Q (or "Ride" in its window) climbs on, Q gets off; you sit on its back
- [~] 20.2 Riding: it goes where you look, W / S forward / back, A / D sideways, Shift runs; land animals stay on the ground and stop at deep water, lava and walls; flying / floating ones climb with Space and sink with C (up to 28 m); the camera moves further back on big animals
- [~] 20.3 Verdis rainforest: one region (about 160 m across, 100 m from the landing place) of very dense forest - giant jungle trees, palms, tree ferns, shrubs, vines, mossy rocks; ferns, big leaves, moss, leaf litter and many red, orange and pink flowers on the ground; a dark damp floor
- [~] 20.4 Mist: thick misty air inside the rainforest and veils of mist hanging between the trees
- [~] 20.5 Twintail Baboons: troops of five, high shoulders, shaggy mane, long muzzle with a red nose, glowing blue cheek ridges, two curled tails - only in the rainforest
- [~] 20.6 Many red Ember Frogs (poisonous, in groups on the leaves) and 28 big blue butterflies around you while you are in the rainforest
- [ ] 20.7 Test (Emil): riding on foot animals and flyers, getting off; the rainforest (density, mist, baboons, frogs, butterflies, FPS)

## 21. No dark blot after blasts and crashes; navigator to the rainforest (2026-11-20, twelfth request) - implemented = [~], tested in game = [x]
- [~] 21.1 The dark circle after shooting the ground / crashing: the fireball turned into a dark smoke ball and dark smoke puffs lay over the spot for 5-9 s. Now the fireball pales to light grey and thins out, the smoke is light, faint and short; the crater's middle is only slightly darker
- [~] 21.2 Navigator on Verdis: "Rainforest" is the first target (N switches as before)
- [ ] 21.3 Test (Emil): shoot the ground and crash - no dark circle; navigator leads to the rainforest

## 22. Much denser rainforest, FPS meter, more efficient rendering (2026-11-20, thirteenth request) - implemented = [~], tested in game = [x]
- [~] 22.1 Rainforest about 3-4x denser: ~4900 trees, palms, tree ferns, shrubs, vines, bulb plants, thorn bushes and mossy rocks packed closely (2.6 m between big trees); ground 2-3x denser (ferns, big leaves, moss, bushes, broad grass, flowers, leaf litter)
- [~] 22.2 Instanced drawing: in the rainforest every plant shape is drawn with one MultiMesh per 40 m area (one draw call for many plants instead of one node each); blasts still destroy the plants they hit
- [~] 22.3 Fast placement: the spacing check uses the obstacle grid (was a search through every obstacle - thousands of plants made loading slow); the grid now takes new obstacles one by one instead of being rebuilt
- [~] 22.4 FPS meter always on (bottom right): FPS, average and worst frame time of the last 2 s, render resolution; green / yellow / red. F3 still shows the details; the log line also records the resolution and whether you were in the rainforest
- [~] 22.5 Adaptive render resolution: under 45 FPS the 3D picture is drawn smaller in steps (down to 70 %, the interface stays sharp), above 57 FPS back up to 100 %; F2 switches it off
- [~] 22.6 Cheaper shadows: 2048 shadow map (was 4096) with a light soft filter, 40 m shadow distance
- [ ] 22.7 Test (Emil): rainforest density, FPS there and elsewhere (send the log), F2 / F3

## 23. Smaller, denser rainforest with tall trees; steadier FPS (2026-11-20, fourteenth request) - implemented = [~], tested in game = [x]
- [~] 23.1 Rainforest smaller (about 90 m across instead of 160 m, 80 m from the landing place) and about twice as dense again: big trees 1.9 m apart, shrubs 0.5 m; the ground under them 1.4x denser
- [~] 23.2 Tall trees: rainforest giants 2.1x the height of jungle trees elsewhere (about 7-12 m), palms 1.6x, tree ferns 1.5x, shrubs 1.3x, each with its own size
- [~] 23.3 Far-away light versions: beyond 32 m (+ cell) instanced plants are drawn with a third of their leaf cards (made bigger, so crowns stay full) and without shadows; near ones full detail with shadows; 30 m cells
- [~] 23.4 Steadier frame rate: capped at 60 FPS (even frame times); when the resolution is already down to 70 % and it is still under 45 FPS, ground detail and animals are drawn less far (down to 60 %), back up when it is smooth again (shown in the FPS meter)
- [ ] 23.5 Test (Emil): rainforest (size, density, tree height), FPS in it and elsewhere (send the log)

## 24. Rainforest: hitboxes, more bushes and animals, no mist (2026-11-20, fifteenth request) - implemented = [~], tested in game = [x]
- [~] 24.1 Hitboxes: trees were surrounded by an invisible wall 6-9 m wide; now the solid part is as wide as the real trunk (trunk radius + 0.2 m), tree ferns likewise, mossy rocks 10 % smaller; shrubs, vines and bulbs are soft (walk through), thorn bushes are small; trees can now really stand close together
- [~] 24.2 More bushes: rainforest shrubs 150 -> 320, vines 60 -> 90, thorn bushes 40 -> 90, ground bushes 3x
- [~] 24.3 More animals: guaranteed groups in the rainforest (9 baboon troops, 12 ember frog groups, 9 groups of the other frogs), up to 170 animals alive at once, 50 blue butterflies (was 28)
- [~] 24.4 Mist removed: no hanging mist veils, no extra fog in the rainforest, so plants are no longer faint
- [~] 24.6 More rainforest animals: Maskface Monkey and Ember Tamarin (monkey body like the baboon, other colours and sizes), Lanternbill Toucan (huge beak, flies between the trees) and Skyfire Parrot (new bird model); 10 baboon troops, 12 ember frog groups, 4 groups each of the three other frogs; up to 190 animals alive
- [ ] 24.5 Test (Emil): walk between the trees (no invisible walls, still solid trunks), density of bushes and animals, FPS (send the log)

## 9. Tests (by Emil, in the game)
- [ ] 9.1 Walk into the sea and start swimming
- [ ] 9.2 Dive and explore under water
- [ ] 9.3 Come back up and onto land
- [ ] 9.4 Switch first / third person many times
- [ ] 9.5 Walk around the whole planet in both camera modes
- [ ] 9.6 Player, animals, plants about half size; collisions / interactions still work
- [ ] 9.7 Shift boost is clearly faster
- [ ] 9.8 3D creature colours match the 2D drawings
- [ ] 9.9 Creature colours in light / dark
- [ ] 9.10 Cross the Mycelia valley by mushroom jumping
- [ ] 9.11 Bounces follow the local gravity
- [ ] 9.12 FPS before / after
- [ ] 9.13 Distant detail cheaper without obvious quality loss
- [ ] 9.14 Pebble: look from the capsule and walk around on foot (ground detail, materials, small life, FPS)
- [ ] 9.15 Glacia: look from the capsule and walk around on foot (ground detail, materials, small life, FPS)
- [ ] 9.16 Mycelia: look from the capsule and walk around on foot (ground detail, materials, small life, FPS)
- [ ] 9.17 Aquora: look from the capsule and walk around on foot (ground detail, materials, small life, FPS)
- [ ] 9.18 Verdis: look from the capsule and walk around on foot (ground detail, materials, small life, FPS)
- [ ] 9.19 Ferrum: look from the capsule and walk around on foot (ground detail, materials, small life, FPS)
- [ ] 9.20 Voltara: look from the capsule and walk around on foot (ground detail, materials, small life, FPS)
- [ ] 9.21 Solara: look from the capsule and walk around on foot (ground detail, materials, small life, FPS)

## 25. Crash circles, ice scratches, splashes, real sea waves (2026-11-20, sixteenth request) - implemented = [~], tested in game = [x]
- [~] 25.1 Black circles after a crash: the real cause were the capsule's broken pieces - the hull is dark navy and very metallic, so the 8 curved hull panels, the round leg feet and the shards lay on the ground as black discs (lit only from behind, nothing to reflect). Wreck pieces now get a lighter, less metallic two-sided material and sink away after 6-9 s (debris boxes after 4.5 s); crash dust has the colour of the ground (white powder on snow / ice); crash smoke is lighter and fainter
- [~] 25.2 Ice scratches (Glacia): when the capsule's leg rods touch a frozen lake while moving, each rod carves a groove (fine white hairlines, frosted, a bit broken) that stays and fades over about 4 minutes; ice chips and frost powder fly from the rods; the ice screeches (louder / higher the faster); the ice holds the capsule back a little and it shakes
- [~] 25.3 Rods in the water: a splash when a rod dips in (sea, lake, river, stream), then spray from the rod, a wake with foam on the sea, and the water holds the capsule back a little
- [~] 25.4 Landing on the water: besides the splash a deep push into the simulated waves (rings spread over the real waves) and a patch of white foam; fast flat landings throw spray to both sides
- [~] 25.5 Real sea waves: 10 Gerstner wave trains (62 m swell down to 1.1 m chop) spread around the wind, each at the speed of real deep-water waves; the water moves in circles (sharp narrow crests, wide flat troughs), light normals computed exactly from the waves; whitecaps where the crests are pinched; the capsule, swimmers and animals ride exactly these waves (the CPU finds the water's circle movement too)
- [~] 25.6 Wake like a boat: the capsule surfing pushes the simulated water every frame; ring waves now run at ~5-6 m/s, so a faster capsule draws a V-shaped wake; simulated area 64 m (was 48 m)
- [~] 25.7 Foam trails like a jet ski: a foam layer on the water (16-bit, follows the camera): the hull and two side sheets leave white foam lines that spread, turn lacy at the edges and fade over several seconds; splashes leave foam; steep simulated fronts foam; two white sheets of spray to both sides when surfing fast
- [~] 25.8 Look: turquoise light shining through the wave tops when looking towards the sun, darker troughs, stronger sun glitter on the ripples
- [~] 25.10 Water colour: full clear blue instead of dark navy - Aquora turquoise shallows (reaching further out) and bright blue deep sea, Verdis / Glacia water bluer too; the water body glows with scattered sunlight, smoother glassy surface (ripples only sparkle), troughs barely darker
- [~] 25.11 Natural splashes: ragged spray puffs instead of round dots, turned at random, very different sizes and lifetimes, slowed by the air so they fan out and hang, growing as they thin; boiling white foam where something hits; the drawn ring waves are only a light touch (the simulated water makes the real uneven rings), ring foam broken up
- [~] 25.12 Still too dark: the sea is now drawn with its own colours (unshaded - the scene light made it dark), sky reflection, light through the waves and sun glitter added by hand; Aquora bright turquoise -> clear cyan-blue; wider, whiter foam trails that last longer
- [~] 25.13 Water not see-through any more: from above almost opaque (88-100 %, only right at the beach a hint of sand), from below 60 %; Aquora water turquoise everywhere (deeper turquoise out at sea)
- [~] 25.14 REAL cause of the dark, see-through sea: the near water patch's triangles face downwards, so seen from above the shader drew its UNDER-water look (dark, 60-92 % see-through). Now above / below is decided by where the camera is; from above the water is drawn fully opaque (separate pass), from below a second, 60 % see-through pass
- [~] 25.15 Splashes and foam as defined white shapes: solid white spray lumps with crisp ragged outlines (slightly shaded underside), opaque most of their life; foam trails on the water solid white with a crisp ragged edge
- [~] 25.16 Sea turquoise everywhere: outside the sharp depth map around you (the square) the sea used the whole-planet depth map baked before the land was finished, thought it was land and wasn't drawn (you saw the tinted sea floor). The whole-planet map is now baked again after loading (1.5 ms per frame) and the water is never cut off by the depth map (land simply covers it)
- [~] 25.17 Thinner, runnier water: simulated waves are damped much less (0.9982 instead of 0.994 per step) so rings and wakes travel far, ring waves fade slower, the capsule glides further on the water, spray slowed less by the air
- [~] 25.18 Real spray: splashes, wakes and rod spray are mostly single drops - thin white streaks along their flight, very different sizes, falling in arcs - plus a few white lumps of water; the jet-ski sheets are 220 drops + 80 lumps per side
- [~] 25.19 Turquoise everywhere, not only in a strip close by: further away (flat view angle) the mirrored sky covered the water and the scene's haze washed it pale - now only a light touch of sky reflection, the water has its own light haze only towards the horizon
- [~] 25.20 Foam trails fade quickly (gone after about 3 s) and are less white (less foam laid down, softer white)
- [~] 25.21 Still strips: the sea now has ONE colour everywhere (the planet's turquoise) - no change with depth or distance, no haze; beach foam and breaking-wave bands only near you (far away the coarse depth map drew stripes)
- [x] 25.22 THE cause of the strip: the round water patch around you was scaled along the world axes (Basis.scaled) instead of its own, so it was a narrow strip everywhere but at the poles - and the far sea leaves a round hole for it, so outside the strip there was no water. Fixed; checked with in-game screenshots (Emil: "now it is good")
- [~] 25.23 Water lit by the sun (wave faces to the sun lighter), deeper water a little bluer
- [~] 25.24 Always small wind waves: the short wave trains (6.6 m - 1.1 m) never go flat, even in calm weather (more in rain / storm); wind ripples on top at full strength again
- [~] 25.25 Much bigger cannon: blasts 1.8x (wider, deeper craters, bigger explosion); a shell hitting the sea punches a hole into the water, throws a 10-15 m column of water with a crown of spray and mist, and sends out a big ring wave (up to ~2 m, lower in shallow water) that runs out over the sea and rocks the capsule and animals
- [~] 25.26 Screenshots for checking: F12, and 4 automatic ones after arriving on a planet with a sea (user://screenshots/game/)
- [ ] 25.9 Test (Emil): crash on Glacia (no black circles), skim over a frozen lake (scratches, chips, sound), dip the rods into the sea / a lake, land on the sea, surf fast (V wake, foam trail, spray sheets), waves in calm and stormy weather, FPS on Aquora

## Progress log
### 2026-11-19 (stage 1)
Overall progress: 0/66 tasks completed (0%) - Completed 0 · In progress 43 · Not started 22 · Blocked 1

Implemented, waiting for the in-game test:
- Swimming (explorer.gd): wade in, swim from 0.62 m depth, look-direction swimming, Space up / C down, buoyancy,
  water drag, no seabed walking (floor = limit), surface clamp, climb out at the shore, splash, ripples, bubbles.
- Under water (sphere_world.gd / explore_screen.gd / shaders.gd): fog + light by depth, blue tint, the water
  surface drawn from below (bright window with moving light); Aquora sea floor: reef rocks, sea fans, tube sponges;
  sea animals choose depths between surface and seabed and dart away from you.
- Player body (suit, helmet, backpack) with idle / walk / run / jump / swim animations; third person (default,
  pulls in when terrain / rocks / trees are in the way), V = first person (smooth 0.3 s blend, helmet hidden).
- Scale: player 50% (eye 0.82 m, body radius 0.22, walk 2.9, run 5.4, jump 3.4), animals 50% (incl. reach,
  hover / flight heights, speeds 65%), plants 50% (props, trees, ground cover x1.3-1.4 denser), small rocks 65%,
  crystals 70%, big landforms 100%; obstacles and reach scaled with them.
- Capsule: Shift = 2.7x thrust (top speed ~2.7x), ramps in / out smoothly, sideways drift damped at speed, camera
  widens to 86° FOV, movement split into up to 8 collision checks per frame.
- 3D creatures black: CAUSE = the tube meshes (bodies, limbs, necks, tails, horns) were wound counter-clockwise;
  Godot treats clockwise as the front, so the outsides were back faces and the new outline shell covered them
  completely. Fixed in CMesh.tube. Corona (Sun) creatures crashed the builder (no kit) - added.
  Also fixed: "Basis must be normalized" error spam from animals (wildlife.gd).
- Mycelia valley (sphere_terrain.gd + sphere_world.gd): 110 m long, 13 m wide, 20 m deep, winding, 48 m from the
  landing place across your way; walls too steep to walk (MAX_RISE); 3 mushroom crossings (easy / medium / hard,
  bounces 6.5-11.5), 8 floor springs to get back up, cap squash + wobble, spores, sound, air control, roots,
  glowing wall fungi, mist.
- Performance: F3 meter (FPS, frame time, worst frame, draw calls, objects, triangles; log line every 10 s),
  F4 = optimisations on / off for an A/B comparison; shadows 2 cascades up to 45 m (was 120 m), no shadows from
  small props, fading instead of popping, animals 40-120 m update every 3rd frame, far geysers pause.

Not started / still open: 6.3, 6.7-6.10 (water / atmosphere / geology / repetition improvements), 8.6 (clouds:
already one shader shell - not re-checked), 8.7 (merging prop parts), 5.4 / 5.5 (need photos), all tests (9.x).
Blocked: 8.8 needs FPS numbers from Emil's computer (F3 / F4 or the PERF lines in godot.log).

### 2026-11-19 (stage 2)
Overall progress: 0/83 tasks completed (0%) - Completed 0 · In progress 60 · Not started 21 · Blocked 2

Findings from Emil's test: valley not found (it existed 48 m from the landing place, but the capsule
starts where it was left); swimming showed the body lying on its back (sign of the tilt was wrong);
PERF lines: 22-54 FPS with 1000-7700 draw calls - too many separate objects is the main cost.
Done in stage 2: explosion, valley 220 m x 18 m x 28 m 70 m from the landing place with beacons + navigator
(selected by default on Mycelia), swimming / seabed state machine with correct poses, carrying sea animals,
second scale step (absolute values, applied once), grass / moss / litter / twigs / pebbles in patches on all
planets, richer leaf and grass textures, terrain roughness and close-up detail, merged prop meshes, animals
only within 70 m, props 55-150 m with fading.
Known open problems: trees were not rebuilt (only leaves / colours), 6.3 / 6.7-6.10 not started,
creature colours (5.4 / 5.5) need gallery photos, no in-game test of anything yet.

### 2026-11-19 (stage 3: capsule breakup)
Overall progress: 0/86 tasks completed (0%) - Completed 0 · In progress 63 · Not started 21 · Blocked 2
Fixed: Parser error "COVER_SCALE not declared" (the declaration edit had missed; plants were also still 0.5).
New: 10.18-10.20. Repair (R, free, instant) shows the capsule again.

### 2026-11-19 (stage 4: planet environment upgrade)
Overall progress: 0/114 tasks completed (0%) - Completed 0 · In progress 80 · Not started 31 · Blocked 3
New: 11.1-11.20, 9.14-9.21. The old one-off ground scatter is replaced by the streamed ground layer on all
8 planets. The terrain has a finer mesh with bumps and erosion grooves; the ground shader knows soil,
rock, glinting grains, ice and wet sheen. Small life (insects, crawlers, motes) lives around the player.
Not started: 11.18 (animal-to-animal interaction), 11.20 (explosion size).
Blocked: 8.8, 10.17, 11.19 need FPS numbers (F3 / PERF lines).
Risks: grass density on Verdis / Aquora may cost too many triangles on Iris Xe (the densities are one
number per kind in biomes.gd "ground"); patches can appear late when flying low and fast in the capsule.

### 2026-11-19 (stage 5: scale, water, jump, cannon)
Overall progress: 0/131 tasks completed (0%) - Completed 0 · In progress 97 · Not started 31 · Blocked 3
Inspected first: the planets were only 80-125 m in radius, so from the explorer's 0.23 m eye height
the horizon was just ~7 m away - the strong curvature, not the object sizes, made the planets feel
small. Shrinking everything again would have made that worse, so the planets grew (radius x1.8,
landforms x1.5) and only plants / rain / particles were reduced. The terrain is now 216 chunks with
distance LOD (built a bit every frame) - also what makes local crater rebuilds possible.
Limits (honest): mountain "cavities" are deep notches (the terrain is a height field: no tunnels);
water has transparency, depth colour and sky reflection but no screen-space refraction / mirror
reflections of the land (risky on the Compatibility renderer); rivers are drawn coarser when far away.
Not tested in game yet (nothing in 12.x is [x]); stage 4 runs had no script errors (23-60 FPS).

### 2026-11-19 (stage 6: character, collisions, water, plants, light, space travel)
Overall progress: 0/147 tasks completed (0%) - Completed 0 · In progress 112 · Not started 32 · Blocked 3
Inspected first: player movement is analytic (no physics engine): the player stood on the smooth height
function while the ground was drawn as chunks of different detail - the visible mismatch looked like
sinking into the ground; walls were only checked on the ground; landforms had one round obstacle.
The neighbour planets in the sky were decorative spheres 2 km away, not real places.
Stage 5 logs (Ferrum, Aquora): no script errors, 40-60 FPS. Fixed in the file: the "9. Tests" heading
had been lost in stage 5 (the items were all still there).
Not done / limits: preparing the next planet still has a few 100-300 ms steps during the flight
(building in a background thread is not safe for scene nodes in Godot by default); the far stand-in
and the real planet look slightly different at the hand-over (650 m out); planets don't orbit yet;
you can only land on planets you have freed. Nothing tested in game yet.

### 2026-11-19 (stage 7: capsule camera and mouse during travel)
Overall progress: 0/156 tasks completed (0%) - Completed 0 · In progress 117 · Not started 36 · Blocked 3
From Emil's log (21:01-21:11): space travel works - hand-overs Pebble -> Glacia -> Aquora -> Verdis at
645-650 m, the system frame check was 0.000000 on every planet, no script errors.
Fixed: camera drift at boost (speed-independent follow), mouse released at the hand-over (old view's
clean-up), plus a per-frame input-state rule. Boost speed unchanged. Not tested in game yet.

### 2026-11-19 (stage 8: no flight between planets; water, terrain, animals)
Overall progress: 0/167 tasks completed (0%) - Completed 0 · In progress 126 · Not started 38 · Blocked 3
The flight between planets is removed on Emil's request (13.10, 13.12, 13.13 struck out, not counted).
Planets are reached through the ship or the new "Fly to <planet>" travel (short cinematic, normal
arrival). Known limits: animals you carried are not remembered after they despawn (each group always
comes back at the same home with the same look - their identity is fixed by a seed); water has no
real refraction. Nothing tested in game yet.

### 2026-11-19 (stage 9: animals, giants, wave physics, player size, Mycelia)
Overall progress: 0/177 tasks completed (0%) - Completed 0 · In progress 135 · Not started 39 · Blocked 3
Why "nothing changed": the log showed 35-122 animals near you, but at 1/8 size most were 5-30 cm
and invisible; plants had been shrunk for the 23 cm explorer. Fixed by size, not only numbers.
Log 21:36-21:41: no script errors, 27-60 FPS, up to 4400 draw calls with 120 animals.

### 2026-11-20 (stage 10: savanna, cows and rabbits, loading screen, smoothness, players)
Overall progress: 0/188 tasks completed (0%) - Completed 0 · In progress 145 · Not started 40 · Blocked 3
Cause of the stops in flight (log 2026-11-20): worst frames 70-150 ms whenever new ground came
close - a fine ground chunk (up to 9409 vertices, each with a noise-based colour) was built in a
single frame. Now built row by row with a time limit. Also a warning flood from Mycelia veils.
Not tested in game yet.

### 2026-11-20 (stage 11: water)
Overall progress: 0/197 tasks completed (0%) - Completed 0 · In progress 153 · Not started 41 · Blocked 3
Wave check: sideways movement of all six layers together stays below the limit where crests
would fold over (sum of k·D ≤ 0.8). Not tested in game yet.

### 2026-11-20 (stage 12: Verdis savanna and tropics)
Overall progress: 0/204 tasks completed (0%) - Completed 0 · In progress 159 · Not started 42 · Blocked 3
Not tested in game yet.

### 2026-11-20 (stage 13: riding, rainforest)
Overall progress: 0/211 tasks completed (0%) - Completed 0 · In progress 165 · Not started 43 · Blocked 3
Not tested in game yet.

### 2026-11-20 (stage 14: blast smoke, rainforest navigator)
Overall progress: 0/214 tasks completed (0%) - Completed 0 · In progress 167 · Not started 44 · Blocked 3

### 2026-11-20 (stage 15: dense rainforest, FPS meter, rendering)
Overall progress: 0/221 tasks completed (0%) - Completed 0 · In progress 173 · Not started 45 · Blocked 3
Not tested in game yet.

### 2026-11-20 (stage 16: smaller denser rainforest, steadier FPS)
Overall progress: 0/226 tasks completed (0%) - Completed 0 · In progress 177 · Not started 46 · Blocked 3
Not tested in game yet.

### 2026-11-20 (stage 17: rainforest hitboxes, bushes, animals, no mist)
Overall progress: 0/232 tasks completed (0%) - Completed 0 · In progress 182 · Not started 47 · Blocked 3
Also: more rainforest animals (monkeys, toucan, parrot). Not tested in game yet.

### 2026-11-20 (stage 18: crash circles, ice scratches, splashes, real sea waves)
Section 25 added (9 tasks). Not tested in game yet. Backup of the changed scripts before this stage: docs/backup_before_water/
