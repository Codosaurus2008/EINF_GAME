class_name PlanetDev
extends RefCounted
## Data for developing freed planets (first draft): building types and example quests.
## The landscapes are in explore/biomes.gd. The player's progress (buildings, discoveries,
## where you stood) is stored in Game.planet_dev and saved with the game.
## Planet names, colours etc. come from Game.PLANETS.

## Number of building sites on every planet (placed on the round planet by SphereWorld)
const SITE_COUNT := 3

## Building types. Add new ones here (food mines, labs ...) - the planet screen lists them all.
## "price" can later hold several currencies; for now gem mines cost gems.
const BUILDINGS := {
	"gem_mine": {
		"name": "Gem Mine",
		"price": {"gems": 10},
		"desc": "Drills into the ground for precious gems. (Production comes in a later update.)",
	},
}

## Example quests per planet (title, description, reward placeholder). No logic yet.
const QUESTS := {
	"pebble": [
		["Grazer Trail", "Follow a Gravel Grazer and find out which rocks it licks.", "Reward: to be announced"],
		["Warm Metal", "Find out why the strange ore vein is warm on a frozen asteroid.", "Reward: to be announced"],
		["Floating Stones", "Measure the floating rocks near the craters.", "Reward: to be announced"],
	],
	"glacia": [
		["Lost Snowpuff", "A young Snowpuff got lost near the glaciers. Bring it home.", "Reward: to be announced"],
		["Something in the Ice", "Investigate the huge frozen air bubble.", "Reward: to be announced"],
		["Strider Crossing", "Watch the Frost Striders cross a frozen lake.", "Reward: to be announced"],
	],
	"mycelia": [
		["Spore Count", "Collect glowing spores from three giant mushrooms.", "Reward: to be announced"],
		["Heart of the Roots", "Find out what feeds the Root Heart.", "Reward: to be announced"],
		["Sick Shroomback", "The mushroom on a Shroomback is wilting. Help it.", "Reward: to be announced"],
	],
	"aquora": [
		["Crab Treasure", "The Reef Crabs hide shiny things. What are they collecting?", "Reward: to be announced"],
		["Leap Watch", "Watch a Sky Ray leap out of the water three times.", "Reward: to be announced"],
		["Glowing Pool", "Take a sample from the tide pool.", "Reward: to be announced"],
	],
	"verdis": [
		["Hide and Seek", "Find a Leaf Stalker before it notices you.", "Reward: to be announced"],
		["Sweet Scent", "Find out which creatures visit the giant flower.", "Reward: to be announced"],
		["Seed in Amber", "Free the seed trapped in the amber sap.", "Reward: to be announced"],
	],
	"ferrum": [
		["Beetle Bath", "Find where the Magma Beetles bathe in lava.", "Reward: to be announced"],
		["Eternal Fire", "Investigate the fire inside the old forge ruin.", "Reward: to be announced"],
		["Geyser Clock", "Time the eruptions of the steam geysers.", "Reward: to be announced"],
	],
	"voltara": [
		["Storm Herd", "Follow a herd of Rod Grazers to the hills during a storm.", "Reward: to be announced"],
		["Lightning Glass", "Find fulgurite where lightning struck.", "Reward: to be announced"],
		["Moth Signal", "Watch the Volt Moths before lightning strikes.", "Reward: to be announced"],
	],
	"solara": [
		["Rainbow Antlers", "Get close to a Prism Stag without scaring it away.", "Reward: to be announced"],
		["Too Bright", "Find a way to look into the Sun Prism.", "Reward: to be announced"],
		["Glass Garden", "Find where the glass flowers grow.", "Reward: to be announced"],
	],
}


static func has_world(planet_id: String) -> bool:
	return Biomes.ALL.has(planet_id)
