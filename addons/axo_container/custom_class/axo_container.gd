@tool
class_name AxoContainer
extends Container

enum GridType { ORTHOGONAL, STAGGERED }
enum OrderingMode { STANDARD, SPIRAL, REVERSE, BOTTOM_UP }
enum ContainMode { CENTERED, TOP_LEFT }

## Defines the geometric structure: a straight grid or a staggered brick-like pattern.
@export var grid_type: GridType = GridType.ORTHOGONAL:
	set(v):
		grid_type = v
		queue_sort()
		queue_redraw()
## When using STAGGERED, determines if even or odd rows lose a position and get offset.
@export var stagger_even_rows: bool = true:
	set(v):
		stagger_even_rows = v
		queue_sort()
		queue_redraw()
## If true, children with visible = false still occupy a slot in the grid (they will leave a visible gap).
@export var include_hidden_nodes: bool = true:
	set(v):
		include_hidden_nodes = v
		queue_sort()
		queue_redraw()
## Determines the sequence in which children fill the available grid slots.
@export var ordering: OrderingMode = OrderingMode.STANDARD:
	set(v):
		ordering = v
		queue_sort()
		queue_redraw()

## Total number of positions along the x axonometric axis.
@export_range(1, 20) var x_axis_count: int = 3:
	set(v):
		x_axis_count = v
		queue_sort()
		queue_redraw()
## Total number of positions along the y axonometric axis. 0 = automatic
@export_range(0, 20) var y_axis_count: int = 3:
	set(v):
		y_axis_count = v
		queue_sort()
		queue_redraw()

@export_group("Axonometric Angles")
## Angle in degrees for the x axis direction.
@export_range(-360.0, 360.0) var x_axis_angle: float = 0.0:
	set(v):
		x_axis_angle = v
		queue_sort()
		queue_redraw()
## Angle in degrees for the y axis direction.
@export_range(-360.0, 360.0) var y_axis_angle: float = 90.0:
	set(v):
		y_axis_angle = v
		queue_sort()
		queue_redraw()

@export_group("Spacing & Scale")
## How all children will be placed inside the container
@export var contain_mode = ContainMode.CENTERED:
	set(v):
		contain_mode = v
		queue_sort()
		queue_redraw()
## Horizontal distance multiplier between items along the x axis.
@export_range(0.1, 4.0) var x_axis_spacing: float = 1:
	set(v):
		x_axis_spacing = v
		queue_sort()
		queue_redraw()
## Vertical distance multiplier between items along the y axis.
@export_range(0.1, 4.0) var y_axis_spacing: float = 1:
	set(v):
		y_axis_spacing = v
		queue_sort()
		queue_redraw()
## Uniform scale applied to all children within the container.
@export_range(0.1, 4.0) var child_scale: float = 1:
	set(v):
		child_scale = v
		queue_sort()
		queue_redraw()

@export_group("Debug & Animation")
## Toggles the editor-only visualization of the grid lines and slot positions.
@export var show_debug_grid: bool = true:
	set(v):
		show_debug_grid = v
		queue_redraw()
## Duration in seconds for the smooth transition of children to their slots.
@export var tween_duration: float = 0.3


var _grid: Dictionary = {
	"x": x_axis_count,
	"y": y_axis_count,
	"origin": Vector2.ZERO,
	"dir_x": Vector2.RIGHT,
	"dir_y": Vector2.DOWN,
	"unit_x": 64.0,
	"unit_y": 64.0,
	"cell_size": Vector2.ONE * 64.0,
	"children": [],
	"slots": [],
	"min_rect": Rect2(),
}



func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_resort_children()


func _is_row_staggered(index: int) -> bool:
	if grid_type == GridType.ORTHOGONAL:
		return false
	return (index % 2 == 0) if stagger_even_rows else (index % 2 == 1)


func _update_grid() -> void:
	var children:= get_children().filter(
		func(c):
			return c is Control and (include_hidden_nodes or c.visible)
	) as Array

	var y_count:= y_axis_count
	if y_axis_count <= 0:
		y_count = ceil(children.size() / float(x_axis_count))

	var base_size:= Vector2(64, 64)
	for child: Control in children:
		var min_size:= child.get_combined_minimum_size()
		base_size.x = max(base_size.x, min_size.x)
		base_size.y = max(base_size.y, min_size.y)

	var unit_x:= base_size.x * x_axis_spacing
	var unit_y:= base_size.y * y_axis_spacing

	var dir_x:= Vector2.from_angle(deg_to_rad(x_axis_angle))
	var dir_y:= Vector2.from_angle(deg_to_rad(y_axis_angle))

	var min_rect:= _calc_minimun_rect()

	var origin:= Vector2.ZERO
	if contain_mode == ContainMode.CENTERED:
		origin = (min_rect.size / 2.0) - (dir_x * (x_axis_count - 1) * unit_x / 2.0) - (dir_y * (y_count - 1) * unit_y / 2.0)

	var slots = _get_sorted_slots(x_axis_count, y_count)

	_grid = {
		"x": x_axis_count,
		"y": y_count,
		"origin": origin,
		"dir_x": dir_x,
		"dir_y": dir_y,
		"unit_x": unit_x,
		"unit_y": unit_y,
		"cell_size": Vector2(unit_x, unit_y),
		"children": children,
		"slots": slots,
		"min_rect": min_rect,
	}



func _get_sorted_slots(x_count: int, y_count: int) -> Array[Vector2]:
	var slots: Array[Vector2] = []

	for s in range(y_count):
		var row_count = x_count - 1 if _is_row_staggered(s) else x_count
		for p in range(row_count):
			slots.append(Vector2(p, s))

	var center_x = (x_count - 1.0) / 2.0
	var center_y = (y_count - 1.0) / 2.0

	match ordering:
		OrderingMode.REVERSE:
			slots.reverse()
		OrderingMode.BOTTOM_UP:
			slots.sort_custom(func(a, b): return a.y > b.y if a.y != b.y else a.x < b.x)
		OrderingMode.SPIRAL:
			slots.sort_custom(
				func(a, b):
					var pos_a = Vector2(a.x + (0.5 if _is_row_staggered(int(a.y)) else 0.0), a.y)
					var pos_b = Vector2(b.x + (0.5 if _is_row_staggered(int(b.y)) else 0.0), b.y)
					return pos_a.distance_to(Vector2(center_x, center_y)) < pos_b.distance_to(Vector2(center_x, center_y))
			)
	return slots


func _get_slot_target(slot: Vector2) -> Vector2:
	var stagger = 0.5 if _is_row_staggered(int(slot.y)) else 0.0

	return _grid.origin \
		+ (_grid.dir_x * (slot.x + stagger) * _grid.unit_x) \
		+ (_grid.dir_y * slot.y * _grid.unit_y)


func _resort_children() -> void:
	_update_grid()
	if _grid.children.is_empty():
		return
	var slots = _grid.slots

	for i in range(_grid.children.size()):
		var child:= _grid.children[i] as Control
		child.pivot_offset_ratio = Vector2.ONE * 0.5
		child.pivot_offset_ratio = Vector2.ZERO
		child.scale = Vector2.ONE * child_scale
		if i < slots.size():
			var slot_coord = slots[i]
			var target_center = _get_slot_target(slot_coord)

			var final_pos = target_center
			if contain_mode == ContainMode.CENTERED:
				final_pos -= (child.size / 2.0)

			var tween = create_tween() \
				.set_parallel(true) \
				.set_trans(Tween.TRANS_QUART) \
				.set_ease(Tween.EASE_OUT)
			tween.tween_property(child, "position", final_pos, tween_duration)
	self.update_minimum_size()
	queue_redraw()


func _calc_minimun_rect() -> Rect2:
	var min_rect:= Rect2(0, 0, 0, 0)

	var grid_index:= 0

	for i in range(_grid.children.size()):
		var node = _grid.children[i]
		if not is_instance_valid(node): continue
		if grid_index >= _grid.slots.size(): break

		var child:= node as Control
		var slot = _grid.slots[grid_index]

		var target = _get_slot_target(slot)
		var slot_size = target + child.size
		if contain_mode == ContainMode.CENTERED:
			slot_size -= child.size/2

		min_rect = min_rect.expand(target).expand(slot_size)
		grid_index += 1

	return min_rect


func _get_minimum_size() -> Vector2:
	_update_grid()
	var min_rect:= _grid.min_rect as Rect2
	return min_rect.size + min_rect.position


func _draw() -> void:
	if not Engine.is_editor_hint() or not show_debug_grid:
		return
	_update_grid()
	var slots = _grid.slots
	var child_count = _grid.children.size()

	for s in range(_grid.y):
		var is_stag = _is_row_staggered(s)
		var row_count = _grid.x - 1 if is_stag else _grid.x
		var stagger = 0.5 if is_stag else 0.0
		var row_start = _grid.origin + (_grid.dir_x * stagger * _grid.unit_x) + (_grid.dir_y * s * _grid.unit_y)
		if row_count > 0:
			draw_line(row_start, row_start + (_grid.dir_x * (row_count - 1) * _grid.unit_x), Color.BLACK, 1.0)

		for p in range(row_count):
			var pos = row_start + (_grid.dir_x * p * _grid.unit_x)
			var is_filled = slots.slice(0, child_count).has(Vector2(p, s))
			draw_circle(pos, 4.0 if is_filled else 3.0, Color.RED if is_filled else Color.CORNFLOWER_BLUE)

	if grid_type == GridType.ORTHOGONAL:
		for p in range(_grid.x):
			var col_start = _grid.origin + (_grid.dir_x * p * _grid.unit_x)
			var col_end = col_start + (_grid.dir_y * (_grid.y - 1) * _grid.unit_y)
			draw_line(col_start, col_end, Color.BLACK, 1.0)

	draw_rect(_grid.min_rect, Color.ORANGE, false, 2)
	draw_circle(_grid.origin, 2, Color.WHITE)
