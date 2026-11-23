class_name Interactable
extends Node3D
## Anything the player can look at and use with E (animals, objects, building sites, the landing pod).
## The ExploreScreen finds it with a ray from the camera (collision layer 2).
## Subclasses override prompt() and interact().

const LAYER := 2

var title := ""
var key := ""             # unique save key, e.g. "animal:snowpuff"
var reach := 4.5          # how close the player must be (metres)


## Invisible sphere that the look-ray hits
func add_hitbox(radius: float, offset := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER
	body.collision_mask = 0
	body.set_meta("interactable", self)
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	cs.shape = s
	cs.position = offset
	body.add_child(cs)
	add_child(body)
	return body


## Text next to the crosshair, e.g. "Observe Snowpuff"
func prompt() -> String:
	return "Interact"


## Called when the player presses E. Usually opens a window on the screen.
func interact(_screen: Node) -> void:
	pass
