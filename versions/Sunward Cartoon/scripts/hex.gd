class_name Hex
extends RefCounted
## Hexagon board helpers ("pointy top" hexes, every odd row is shifted half a hex to the right).
## A cell is Vector2i(col, row). Positions for drawing are in "hex units" (hex radius = 1).

const SQ3 := 1.7320508


## Centre of a cell in hex units
static func center(cell: Vector2i) -> Vector2:
	return Vector2(SQ3 * (cell.x + 0.5 * (cell.y & 1)), 1.5 * cell.y)


static func _cube(cell: Vector2i) -> Vector3i:
	var x := cell.x - (cell.y - (cell.y & 1)) / 2
	var z := cell.y
	return Vector3i(x, -x - z, z)


## Number of steps between two cells
static func distance(a: Vector2i, b: Vector2i) -> int:
	var ca := _cube(a)
	var cb := _cube(b)
	return maxi(maxi(absi(ca.x - cb.x), absi(ca.y - cb.y)), absi(ca.z - cb.z))


## The 6 cells around a cell (some may be outside the board)
static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var dirs: Array
	if (cell.y & 1) == 0:
		dirs = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	else:
		dirs = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var out: Array[Vector2i] = []
	for d in dirs:
		out.append(cell + d)
	return out


static func inside(cell: Vector2i, cols: int, rows: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


## Corner points of a hex (for drawing), radius in pixels
static func corners(c: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 30.0)
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	return pts
