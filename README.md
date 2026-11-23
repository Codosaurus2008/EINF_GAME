# Sunward (working title) - prototype

The **Umbra**, an evil civilization, have occupied the whole solar system and stolen the technology of
every planet. Each planet's people developed one **element** with one **strength**. You start on the
asteroid Pebble, defeat the Umbra on one planet after the other and take the freed folk with you on
your ship to help free the next planets. On the ship you **hybreed** creatures of different elements.
The last fight frees the Sun.

## Open
In Godot 4: **Import**, select `project.godot`, then press **F5**. Shift+Tab or Esc opens the menu.

## The system (outside -> sun)
| n | Planet | People | Element strength |
|---|---|---|---|
| 0 | Pebble (asteroid, home) | Scrappers | Improvise: +8% attack for every different element in your team |
| 1 | Glacia (ice) | Frostlings | Frost Armor: takes 25% less damage |
| 2 | Mycelia (fungus) | Sporekin | Poison: 60% extra damage over 3 s |
| 3 | Aquora (ocean) | Tidefolk | Healing Waters: heals the weakest ally every 3 s |
| 4 | Verdis (jungle) | Thornbacks | Ambush: first attack deals triple damage |
| 5 | Ferrum (forge) | Forgeborn | Heavy Shot: ignores armor, +20% damage |
| 6 | Voltara (storm) | Arcwings | Chain Lightning: hits jump to 2 more enemies |
| 7 | Solara (light) | Lumen | Sunbeam: 25% chance for double damage |
| 8 | The Sun | Corona | Radiance: 50% extra burn damage (the Umbra fortress) |

## Creatures
- A creature has 1 to **4 elements** and exactly the strengths of its elements.
- **Level** (orange "Lv" badge). New creatures (freed folk, hybrids, copies) start at level 1.
  Winning battles does NOT raise levels. Later, resources produced on freed planets (mines, food,
  other facilities) will be spent to level creatures (`Game.level_up`). A proper leveling system with
  currencies comes later.
- The level sets the **tier** of the strengths: tier I from level 1 (x1), tier II from level 4 (x1.5),
  tier III from level 7 (x2). Every level also adds +10% health and attack.
- Every element above 1 adds +12% health and attack.
- There is no "power" any more.

## Hybreeding (on your ship)
- Two creatures -> a child with all elements of both parents (max 4). It must be something new.
- Costs 1 hybreeding energy (+1 per freed planet, +1 for every creature you sell).
- Takes 20 s per element of the child. Only one at a time; it also grows while the game is closed.
- When the time is over the egg is **ready**: a message appears on any screen (once, also if the
  game was closed) and the Hybreeding button shows a glowing egg until you press **Hatch!** in the lab.
- Chance of a hybrid = 30% + 7% for every level above 1 of both parents (max 95%).
  Otherwise a copy of one parent hatches.

## Battle = several combats on a hex board
- Start: **2 coins, 2 seats**. 30 s to prepare per combat (or "Fight now!"); you see the Umbra wave.
- **Shop**: 5 creatures - your own crew (the 2 strongest you haven't bought are always there) and
  volunteers from freed planets (only for this battle). **Price = elements x tier.**
  Drag a creature into the shop to sell it back. The **lock** keeps the shop for the next round.
- Won combat: 3, 4, 5, 6 coins. Lost combat: -1 life, +1 coin. A new seat costs as many coins as you have seats (max 8).
- Win **4 combats** before you lose **3 lives** and the planet is free.
- The Umbra fight with the stolen element of the planet. Each wave is matched to the team you can
  afford at that point and is a bit weaker (70%, 80%, 88%, 95%), so good choices and placement win.

## New creature designs (preview: F6 or "New looks"; switch the look everywhere with F5)
Creatures built from their elements by `scripts/creatures/`. Two versions of the same designs are
being compared, in every screen (battle board, bench, army, hybreeding): **3D models** (cel-shaded
with outlines, rendered as small animated pictures by `CreatureSprites`) and **2D drawings**
(`CreatureArt2D`, shapes with outlines and cel shading), plus the classic look. `Art.style` /
F5 / the "Creature look" button in battles switches. The gallery's **Board view** shows all three
side by side on battle hexes at real battle size (click: 2x).
- **Colour regions:** every element has a palette for body, belly, head, limbs, armour, horns /
  claws, fins / membranes, eyes and glow (`CreatureLook.KITS[..]["pal"]`); in hybrids different
  regions come from different elements (body from the frame element, limbs and eyes from the
  second, armour from the back's element, horns from the third ...).
- **No fixed models, no spheres:** bodies are lofted along a curved spine (hips, waist, chest with
  their own cross-sections, muscle masses, vertebrae), limbs are jointed (thigh, knee, shin, foot)
  and solved so the feet stay on the ground when walking.
- **Each people has its own anatomy** (`CreatureLook.KITS`): Scrappers (hunched, stone and riveted
  scrap, one big piston claw, brass monocle, exhaust pipes, gear), Frostlings (tall stilt legs,
  crystal crest and spines, clear ice shell, cryo tubes), Sporekin (bulbous body on root tendrils,
  mushroom hood with eye cluster, mushroom grove, brass spore censer), Tidefolk (floating,
  flippers, dorsal fin, angler lure, brass portholes, fluke), Thornbacks (six insect legs, mantis arms,
  bark plates, thorns, leaves, beak), Forgeborn (heavy, iron plates, chimneys, furnace grate, pistons,
  gear knees, molten cracks), Arcwings (wings on copper ribs, coil antennae, forked tail, lightning),
  Lumen (floating on crystal petals, faceless halo mask, brass orrery rings, light organs).
- **Hybrids combine anatomy:** one element gives the frame (posture, proportions, legs), the others
  take the head, back, tail or arms they are best at, and every element "infuses" its features over
  the whole body (scrap plates, frost crystals, little fungi, gills and fin frills, thorns, iron
  bands with glowing seams, copper coils with arcs, light organs). Skin colour from the frame
  element, pattern and glow from the second, rim light from the third. Same species = recognisable,
  but every individual (seed = unit id) varies in proportions, counts, colours and asymmetry.
- **Animations:** breathing, looking around, blinking, walking / running with planted feet,
  swaying tails, antennae, tentacles and leaves, wings, turning gears, working pistons, attack
  (wind-up and lunge, jaw, claws), hurt (flinch, red flash), defeat (collapse, lights fade),
  elemental move (crystals / thorns / fungi grow, glow surge, more particles and arcs).
- **Elemental effects:** frost sparkles, spores, swirling water drops, embers and smoke from the
  chimneys, lightning arcs between conductive parts, light motes, steam, pollen.
- In the preview: play every animation, try any combination of up to 4 elements, Umbra versions,
  new individuals, **Save photos** (or P) writes pictures to `user://screenshots/creatures/`.

## Exploring freed planets - controls added in the 2026-11 upgrade
- On foot: **third person** by default, **V** = first person. Aquora: walk into the sea, swim (W where you look,
  Space up, C down, Shift faster), dive, sink to the sea floor (down to 7 m) and walk there (Space swims up).
  Small sea animals can be carried (G) - swim with them, let them go in the water; on land they flop back.
- Capsule: **Shift** = boost (about 2.7x). Crashing into the ground at crash speed = big explosion; R repairs (free).
- **Navigator:** N = next target (Mycelia valley, unusual objects, construction sites, nearest unknown animal),
  B = on / off. The capsule locator works as before.
- Mycelia: a 220 m long, 28 m deep mushroom valley 70 m from the landing place (glowing beacons at both ends,
  a glowing trail leads there) - cross it by bouncing on the giant caps; springs on the floor take you back up.
- **F3** performance meter, **F4** optimisations on / off (test). Progress: `docs/exploration_checklist.md`.
- **Travelling to another planet:** press **T** in the capsule - "Fly up to the ship" or "Fly to
  <planet>" (every planet you have freed). A short travel scene follows, then you arrive there.
  (Flying directly between planets was removed; the capsule stays inside each planet's air.)
  The other planets are still visible in the sky (`solar_system.gd`, `space_sky.gd`).
- **Cannon (capsule):** left mouse button (hold = steady fire) or **X**. The crosshair shows the
  distance; the shell blasts a real crater into the ground (cavity into rock walls) that stays for the
  session and in the save. **Jump** is about twice as long now (running jumps).
- **Bigger planets (stage 5):** radius x1.8, landforms x1.5 (`WORLD_SCALE`, `FEATURE_SCALE` in
  `sphere_terrain.gd`); terrain in LOD chunks (`terrain_lod.gd`); sea with waves, depth colours,
  splashes and wakes (`water_surface.gd`); rivers / waterfalls / lava rivers (`rivers.gd`).
- **Living ground (stage 4):** every planet has its own ground life (`"ground"` in `biomes.gd`: kind,
  amount per square metre, colour). It is streamed in 20 m patches around you and drawn with GPU
  instancing; small insects, crawlers and drifting motes live around the player (`ambient_life.gd`).
  The terrain has small bumps and erosion grooves, and the ground shader shows matte soil, varied rock,
  glinting grains, glossy ice and wet sheen (`SURFACE` in `sphere_world.gd`, `ROUGH` in `sphere_terrain.gd`).

## Exploring freed planets (round worlds, capsule + on foot)
- On the galaxy map, click a freed planet -> **Land on <planet>** (not the Sun). Your capsule flies
  down from the ship to the landing place.
- Every planet is a small **round world** (80-125 m radius). Ground, plants, rocks, animals,
  water/ice/lava, clouds and the atmosphere all follow the curved surface - fly or walk all the way
  around it. Fly high (up to 160 m) to see the whole planet.
- **Capsule:** mouse / touchpad or arrow keys steer, W / S thrust, A / D slide, Space climb,
  C (or Ctrl) sink, Shift boost. **Landing:** fly slowly close to flat ground and hold C.
- **On foot:** when landed, **E** gets you out (the camera moves from behind the capsule to your eyes).
  WASD walk, mouse / arrows look, Space jump, Shift run. Gravity pulls towards the planet's centre,
  so you can walk around the whole planet. Deep water and lava stop you. Walk back to the capsule
  and press **E** to get in again - it stays parked exactly where you left it.
- **E** on foot uses what is in front of you: observe animals, examine objects, build a **Gem Mine**
  (10 gems) at a construction site. Shy animals run from you if you run - walk slowly to get close.
- **Day and night:** the sun circles the planet (one day = 7 minutes). Sun light, its colour,
  shadows, ambient light, fog, sky, water and the ground itself change with the time of day at the
  place where you are - at night the land is really dark (your suit has a lamp, glowing plants glow).
  **F7** (test) makes time run 40x faster.
- **Points of interest** are marked on screen with their distance: construction sites,
  unusual objects (incl. an abandoned Umbra outpost), and your capsule when you are on foot.
- **J** quests (examples, not playable yet), **T** fly back up to the ship (from the capsule).
- **Saved per planet:** buildings, discoveries, time of day, where the capsule is (and where you
  are, if you were walking) - `Game.planet_dev`.
- **Water:** land on the sea with the capsule (also fast). The result depends on speed, angle and
  tilt: *perfect* (shallow, belly first: big splash, rings, you glide on), *hard* (too fast / too
  steep: bigger splash, speed lost, maybe some damage), *failed* (very steep or very fast: violent
  splash, real damage - a crash only if the hull is used up). On the water you **surf**: W speeds up,
  steer with the mouse (slower than flying), the capsule floats, leaves a wake with spray and rings,
  and Space takes off again when you are fast enough (8 m/s). Reaching the beach stops you.
  Splashes, wakes, leaping animals and wading on foot send rings over the water; waves grow with
  wind and storms, rain makes small rings.
- **Crashes:** hitting ground, mountains, trees or rocks faster than 6 m/s damages the hull,
  faster than 13 m/s (or nose-first) is a crash: sparks, dust, flying debris, smoke, sound. A crashed
  capsule can't fly. **R** opens the repair window: repairs are **free and instant** (0 coins, no
  waiting). To bring prices back later set `Game.REPAIR_COSTS = true` (the old price rules are still
  in `Game.capsule_repair_price`).
- **Capsule states:** Flying, Descending, Landed, Water surfing, Water takeoff, Crashed
  (`Capsule.state()`). Landing checks only run when coming down; after a water takeoff there is no
  landing check until the capsule is clear of the water.
- **Capsule locator:** on foot, a marker shows your capsule with its distance when you can see it,
  otherwise an arrow at the edge of the screen points the way along the planet (also from the far side).
- **Xenobiology:** 10 species per planet. 48 of them are built by `Xeno` from "genes" (`Biomes.SPECIES[..]["genes"]`):
  how they move (legs with knees, radial legs, crawling, hovering, wings, swimming, burrowing, climbing
  trees and spires, rooted), body shape (incl. lopsided ones), eye arrangements, feeding organs
  (proboscis, tendrils, filter fans, mandibles, glowing lures, ring mouths), armour (plates, spines,
  mineral crystals, shells), see-through skin with glowing organs, skin patterns and glowing markings.
  Tiny swarms, small, medium and large species; common and rare ones (rare = far from the landing
  place); preferred places (high ground, lowlands, shore, forest); night animals sleep by day; predators
  hunt small animals and small ones flee from them; groups flash their lights together at night.
  Far away animals pause (faster). New species: add an entry with "plan": "xeno" and genes.
- **Wildlife over the whole planet:** every planet has its hand-made species plus 8 more generated
  by `Xeno.generate()` from the planet's own rules of evolution (`Xeno.POOLS`: which ways of moving
  are common, colours, name sounds, adaptations) - names, descriptions and traits come from their genes.
  150-260 groups of animals live all over the sphere (also on the far side), each placed where its
  species fits: water, shore, high ground, lowlands, near plants, its favourite colour zone, never
  inside rocks or buildings. Common species are everywhere, rare ones sparse and far away. Only the
  groups near you exist (they appear within 95 m, are removed beyond 125 m; one you hold stays), so
  it stays fast. Animals walk to plants and crusts to eat and to the shore to drink.
  The "Discovered" counter counts species. Discoveries are saved.
- **Plants:** branching plants grown from recipes (`WorldProps.TREES` -> `Flora.branch_tree`): a trunk
  that forks into thinner branches, roots spreading into the ground, leaves / needles / fronds /
  crystals / glowing caps / pods at the tips, all merged into few meshes. Every planet grows its own:
  stone lithophytes and wire shrubs (Pebble), frost trees and rime bushes (Glacia), spore trees and
  root curtains (Mycelia), mangroves on stilt roots and palms (Aquora), jungle shrubs (Verdis), charred
  ash trees and heat succulents (Ferrum), storm reeds and rod trees (Voltara), crystal trees and
  sun cacti (Solara). Leaves move with the wind.
- **Landscape:** mountain ranges with ridges and valleys (`"mountains"` per planet), terraces and
  mesas breaking into cliffs (Ferrum, Solara), cliff walls with fallen blocks, cave mouths with
  something glowing inside.
- **Weather on surfaces:** rain makes ground and plants darker and shiny and fills puddles in flat
  hollows (stays wet for a while after the rain, also in fog and mist); snow settles on flat ground,
  on top of rocks and on leaves and melts slowly; rain drops splash on the ground around you;
  fireflies come out at night on Verdis, Mycelia and Aquora.
- **Colour zones:** every planet has several colour zones (ground colours, and on Mycelia / Glacia /
  Voltara / Ferrum / Solara also the colours of mushrooms, ice, crystals and ores per zone).
  Mycelia: teal, pink, amber and dark-blue fungal zones, tiered, trumpet, veil, puffball, coral and
  shelf fungi, moss mounds. Glacia: deep blue, violet and turquoise ice, rocky frozen valleys, ice
  arches (small ice caves), glowing crystal fields, frost flowers, frozen ferns, frozen lakes with
  depth, and an aurora at night (Mycelia has one too).
- **Older animals:** (16 earlier species: many-legged crawlers, floating gas-sac
  organisms, three-legged stilt walkers, four-winged skimmers, glowing sea jellies, furry and
  mineral-plated giants ...). They graze, look around, rest, breathe, curious ones come closer, shy
  ones run if you run. **G** picks up a small one: it wriggles in your hands, right mouse / wheel
  turns it, after 2.5 seconds you know the species (name, origin, description, traits).
  G puts it down again. Big, dangerous, hot, flying and water animals can't be carried (you get told why).
- **Weather** changes by itself on every planet (dust drifts, blizzards, thick fog, spore blooms,
  rain, sea storms with lightning, ash fall, ember storms, thunderstorms, heat wind ...) and fades
  smoothly from one to the next. Wind moves plants, particles and waves; storms darken the sky and
  thicken the fog; rain and wind have sounds. **F8** (test) switches the weather.
- **Lights:** the capsule has two headlights (on when it is dark, while you sit in it), on foot your
  suit flashlight follows your view (automatic at night, **F** switches auto / on / off).
- **Looks on every planet:** irregular rocks with layers, cracks and bumps, textured surfaces on all
  objects, rock layers on cliffs, and planet-specific ground cover (gravel, lichen and scrap on
  Pebble, frost grass, snow and ice shards on Glacia, tiny glowing mushrooms and fungal threads on
  Mycelia, beach grass, shells and seaweed on Aquora, jungle plants on Verdis, heat plants and
  glowing cinders on Ferrum, storm grass and charged crystals on Voltara, crystal grass and glass
  pebbles on Solara). Verdis also has the detailed trees, light shafts and mist.
- Gems can't be earned yet. **For testing: F9 gives +10 gems**, **F10** visits every planet and saves
  screenshots to `user://screenshots/` (both only when started from the Godot editor).

### Adding things later
| What | Where |
|---|---|
| Size, landscape, sky, atmosphere, gravity, which props/animals/objects a planet has | `scripts/explore/biomes.gd` |
| New animal species (looks and description) | `Biomes.SPECIES` (+ body plans in `wildlife.gd`) |
| New plants / rocks / formations | `WorldProps.make()` in `scripts/explore/props.gd` |
| New objects to examine | `Biomes.OBJECTS` + model in `field_object.gd` |
| New building types | `PlanetDev.BUILDINGS` (+ its 3D look in `build_site.gd`) |
| Quests | `PlanetDev.QUESTS` |
| Interaction windows (feed, help, collect ...) | `explore_screen.gd` (`open_animal`, `open_object`, `open_site`) |
| Flight feel (speed, drag, turning, max height) | constants at the top of `capsule.gd` |
| Walking feel (speed, jump, eye height) | constants at the top of `explorer.gd` |
| Crash / water landing limits | `SAFE_HIT`, `CRASH_HIT`, `TAKEOFF_SPEED` ... in `capsule.gd`; repair prices: `Game.REPAIR_COSTS` + `Game.capsule_repair_price` |
| Weather of a planet | `Weather.KINDS` |
| New alien species | `Biomes.SPECIES` with `"plan": "xeno"` and `"genes"` (see the top of `xeno.gd`) |
| Colour zones / zone palettes | `"zones"` in a planet's `"terrain"`, `"palettes"` in `Biomes` |
| Which animals can be carried | `"carry_note"` in `Biomes.SPECIES` (plus size / body plan rules in `Wildlife.carry_reason`) |
| Length of a day | `day_length` in `Biomes` (default 420 s) / `sphere_world.gd` |
| Detailed vegetation for more planets | `"cover"`, `"showcase_trees"`, `"shafts"`, `"mist"` in `Biomes` + meshes in `flora.gd` |

## Files
| File | What it does |
|---|---|
| `scripts/game.gd` | Planets, elements, strengths, levels/tiers, hybreeding, shop prices, Umbra waves, saving |
| `scripts/map_screen.gd` | Galaxy map, your ship next to the active planet, camera flight into the ship |
| `scripts/army_screen.gd` | Ship interior with the crew (shown inside the map after the zoom); click a creature for details and selling |
| `scripts/breed_screen.gd` | Hybreeding lab: parent 1 (left), parent 2 (right), lab in the middle |
| `scripts/battle_screen.gd` | Battle: rounds, shop, bench, seats, lock, timer |
| `scripts/battle_sim.gd` | One combat on the hex board (movement, attacks, strengths) |
| `scripts/hex.gd` | Hex board math |
| `scripts/planet_dev.gd` | Planet development data: building types, number of sites, example quests |
| `scripts/explore/explore_screen.gd` | Planet exploration: chase camera, interface, markers, E-interaction, windows, quests, back to the ship |
| `scripts/explore/sphere_world.gd` | Builds a round planet (sky, sun, atmosphere, sea/ice/lava, clouds, props, animal population + streaming, sites, lightning) |
| `scripts/explore/sphere_terrain.gd` | Height of the ground in every direction, the cube-sphere mesh, landing place |
| `scripts/explore/capsule.gd` | The player's capsule: flight, landing, collisions, model |
| `scripts/explore/explorer.gd` | The player on foot: walking around the round planet, jumping, looking |
| `scripts/explore/flora.gd` | Detailed plants: leaf/grass/fern/flower textures, card meshes, jungle trees, ground cover of every planet |
| `scripts/explore/terrain_lod.gd` | Planet ground in 216 chunks with distance detail levels, local rebuilds (craters) |
| `scripts/explore/water_surface.gd` | The sea: fine wave patch around you, far sphere, depth maps, ring waves |
| `scripts/explore/rivers.gd` | Flowing river / lava ribbons, waterfalls with mist, pools |
| `scripts/explore/solar_system.gd` | Planet / sun positions and sizes (for the sky), the turning planet frame |
| `scripts/travel_screen.gd` | The short travel scene between two planets |
| `scripts/explore/space_sky.gd` | The other planets in the sky (cheap stand-ins), the sun, the turning star sky |
| `scripts/explore/aqua_flora.gd` | Aquora's six underwater plant species, swaying in the current |
| `scripts/explore/cannon.gd` | The capsule's cannon: aiming ray, shells, hits, craters |
| `scripts/explore/ground_layer.gd` | Streamed, instanced ground life near the player (grass, plants, stones, fungi ...) |
| `scripts/explore/ambient_life.gd` | Insects, crawlers and drifting motes around the player |
| `scripts/explore/weather.gd` | Weather kinds of every planet and the smooth changes between them |
| `scripts/explore/effects.gd` | Splashes, sparks, dust, smoke, flying debris |
| `scripts/explore/xeno.gd` | Builds alien organisms from genes (anatomy, materials) |
| `scripts/explore/biomes.gd` | Look and content of every planet, animal species, objects |
| `scripts/explore/props.gd` | Plants, rocks, crystals, mushrooms, trees ... made of 3D shapes |
| `scripts/explore/wildlife.gd` | Native animals: bodies, walking/hopping/flying/swimming on the sphere, reactions |
| `scripts/explore/field_object.gd`, `build_site.gd`, `interactable.gd` | Things you can use with E |
| `scripts/explore/shaders.gd`, `particles.gd` | Water, lava, clouds, wind, glow, heat haze; snow, spores, embers, rain ... |
| `scripts/art.gd` | All drawing (planets, sun, stars, creatures, icons) |

## Art
Planet sounds: `audio/ambient/<planet id>.wav` (generated loops), `thunder.wav`, `engine.wav` (capsule).
Creatures are drawn with simple shapes for now. Put a PNG at `art/units/<planet id>.png`
(e.g. `art/units/glacia.png`, facing right) and it is used automatically for that planet's people.
