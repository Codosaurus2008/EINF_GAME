# Sunward Cartoon

A copy of Sunward (made from the stage 9 version) with a deliberately cartoon look.
It is its own project: open `versions/Sunward Cartoon/project.godot` in Godot. The main game in the
Sunward folder is unchanged.

## What is different
- **Toon lighting everywhere**: hard light/shadow steps, bright rim light on every edge
  (`scripts/cartoon.gd`, used by props, rocks, trees, animals, the explorer).
- **Much more intense colours**: every material is pushed to higher saturation and brightness,
  and the whole picture gets a colour grade (saturation 1.35, contrast 1.12, stronger glow).
- **Terrain**: posterised colour bands and a dark ink line along slopes and silhouettes.
- **Water**: flat colour bands from turquoise to deep blue, solid white foam, sparkle stars.
- **Bigger plants** (scale 0.24 instead of 0.18) - chunkier shapes.
- **2D animals**: every animal is a flat drawing (thick outline, bold colours, big eyes, a smile)
  standing upright in the world, always turned to the camera, flipped to the way it walks,
  switching between two poses when it moves/flies/swims (`scripts/explore/cartoon_critter.gd`).
  The giant Ferrum fly (4 wings, 4 yellow eyes, glowing spine) and the Glacia woolly giant have
  their own drawings.
- **Save**: the cartoon game has its own save file. On its very first start it copies your
  progress from the normal Sunward game once; after that the two saves are separate.

Switch the look off again: `const ON := false` in `scripts/cartoon.gd` (animals become 3D again;
the shader colour changes stay).
