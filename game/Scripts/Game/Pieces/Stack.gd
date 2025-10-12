# tabletop-club
# Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2025 Tabletop Club contributors (see game/CREDITS.tres).
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

extends StackablePiece

class_name Stack

enum {
	STACK_AUTO,
	STACK_BOTTOM,
	STACK_TOP
}

enum {
	FLIP_AUTO,
	FLIP_NO,
	FLIP_YES
}

export(NodePath) var collision_shape_path: String
export(NodePath) var outline_mesh_path: String

# TODO: export(RandomAudioSample)
# See: https://github.com/godotengine/godot/pull/44879
export(Resource) var card_add_sounds
export(Resource) var card_orient_sounds
export(Resource) var card_remove_sounds
export(Resource) var card_shuffle_sounds
export(Resource) var chip_add_sounds
export(Resource) var chip_orient_sounds
export(Resource) var chip_remove_sounds
export(Resource) var chip_shuffle_sounds

# This should only be useful for stacks of cards.
var over_hands: Array = []

var _collision_unit_height = 0
var _mesh_unit_height = 0

# Add a piece to the stack.
# piece_entry: The piece entry of the piece to add.
# piece_transform: The transform of the piece.
# on: Where to put the piece in the stack.
# flip: If the piece should be flipped when entering the stack.
func add_piece(piece_entry: Dictionary, piece_transform: Transform,
	on: int = STACK_AUTO, flip: int = FLIP_AUTO) -> void:
	
	var on_top = false
	match on:
		STACK_AUTO:
			if transform.origin.y < piece_transform.origin.y:
				on_top = transform.basis.y.y > 0
			else:
				on_top = transform.basis.y.y < 0
		STACK_BOTTOM:
			on_top = false
		STACK_TOP:
			on_top = true
		_:
			push_error("Invalid stack option %d!" % on)
			return
	var pos = get_piece_count() if on_top else 0
	
	var flip_y = false
	match flip:
		FLIP_AUTO:
			flip_y = is_piece_flipped(piece_transform)
		FLIP_NO:
			flip_y = false
		FLIP_YES:
			flip_y = true
		_:
			push_error("Invalid flip option %d!" % flip)
			return
	
	var collision_shape = get_collision_shape()
	if empty():
		self.piece_entry = piece_entry
		
		var new_shape: Shape = null
		var piece_instance = PieceBuilder.build_piece(piece_entry, false)
		
		var piece_collision_shapes = piece_instance.get_collision_shapes()
		if piece_collision_shapes.size() != 1:
			push_error("Piece must have only and only one collision shape!")
			return
		var piece_collision_shape = piece_collision_shapes[0]
		
		var piece_mesh_instances = piece_instance.get_mesh_instances()
		if piece_mesh_instances.size() != 1:
			push_error("Piece must have one and only one mesh instance!")
			return
		var piece_mesh_instance = piece_mesh_instances[0]
		
		if piece_collision_shape.shape is BoxShape:
			new_shape = BoxShape.new()
			new_shape.extents = piece_collision_shape.shape.extents
			new_shape.extents.y *= piece_collision_shape.scale.y
			
			_collision_unit_height = new_shape.extents.y * 2
		elif piece_collision_shape.shape is CylinderShape:
			new_shape = CylinderShape.new()
			new_shape.height = piece_collision_shape.shape.height
			new_shape.height *= piece_collision_shape.scale.y
			new_shape.radius = piece_collision_shape.shape.radius
			
			_collision_unit_height = new_shape.height
		else:
			push_error("Piece has an unsupported collision shape!")
			return
		
		if new_shape != null:
			collision_shape.shape = new_shape
			collision_shape.scale = piece_collision_shape.scale
			collision_shape.scale.y = 1.0
			
			_mesh_unit_height = piece_collision_shape.scale.y * piece_mesh_instance.scale.y
			
			var outline_mesh_instance = get_outline_mesh_instance()
			if new_shape is BoxShape:
				var cube_mesh = CubeMesh.new()
				cube_mesh.size = Vector3.ONE
				outline_mesh_instance.mesh = cube_mesh
			elif new_shape is CylinderShape:
				var cylinder_mesh = CylinderMesh.new()
				cylinder_mesh.bottom_radius = 0.5
				cylinder_mesh.top_radius = 0.5
				cylinder_mesh.height = 1.0
				outline_mesh_instance.mesh = cylinder_mesh
			
			# Avoid z-ordering glitches.
			outline_mesh_instance.scale.x = 1.001
			outline_mesh_instance.scale.z = 1.001
			
			outline_mesh_instance.scale.y = piece_collision_shape.scale.y
			setup_outline_material()
		
		ResourceManager.free_object(piece_instance)
	else:
		var current_height = get_total_height()
		var new_height = _mesh_unit_height * get_piece_count()
		var extra_height = max(new_height - current_height, 0)
		
		if collision_shape.shape is BoxShape:
			collision_shape.shape.extents.y += (extra_height / 2)
		elif collision_shape.shape is CylinderShape:
			collision_shape.shape.height += extra_height
		
		get_outline_mesh_instance().scale.y = new_height + 0.001
	
	# We just changed the collision shape, so make sure the stack is awake.
	sleeping = false
	
	mass += piece_entry["mass"]
	
	_add_piece_at_pos(piece_entry, pos, flip_y)
	
	if is_card_stack():
		if card_add_sounds != null:
			play_effect(card_add_sounds.random_stream())
	else:
		if chip_add_sounds != null:
			play_effect(chip_add_sounds.random_stream())

# Check if the stack is empty.
# Returns: If the stack is empty.
func empty() -> bool:
	return get_piece_count() == 0

# Get the collision shape of the stack.
# Returns: The stack's collision shape.
func get_collision_shape() -> CollisionShape:
	var node = get_node(collision_shape_path)
	if node is CollisionShape:
		return node
	
	return null

# Get the outline mesh instance of the stack.
# Returns: The stack's outline mesh instance.
func get_outline_mesh_instance() -> MeshInstance:
	var node = get_node(outline_mesh_path)
	if node is MeshInstance:
		return node
	
	return null

# Get the number of pieces in the stack.
# Returns: The number of pieces in the stack.
func get_piece_count() -> int:
	return 0

# Get the current list of pieces in the stack.
# Returns: An array of dictionaries for every piece, containing "piece_entry"
# and "flip_y" elements.
func get_pieces() -> Array:
	return []

# Get the size of the stack.
# Returns: A Vector3 representing the size of the stack in all three axes.
func get_size() -> Vector3:
	var collision_scale = get_collision_shape().scale
	return Vector3(collision_scale.x, get_total_height(), collision_scale.z)

# Get the height of the collision shape.
# Returns: The height of the collision shape.
func get_total_height() -> float:
	var shape = get_collision_shape().shape
	
	if shape is BoxShape:
		return 2.0 * shape.extents.y
	elif shape is CylinderShape:
		return shape.height
	
	return 0.0

# Get the unit height of the collision shape, i.e. how much height one piece
# contributes to the total height.
# Returns: The unit collision height.
func get_unit_height() -> float:
	return _collision_unit_height

# Is the stack a stack of cards?
# Returns: If the stack is a stack of cards.
func is_card_stack() -> bool:
	if get_piece_count() > 0:
		return piece_entry["scene_path"] == "res://Pieces/Card.tscn"
	
	return false

# Is the piece's orientation flipped relative to the stack's orientation?
# Returns: If the piece's orientation is flipped.
# piece_transform: The piece transform to query.
func is_piece_flipped(piece_transform: Transform) -> bool:
	return transform.basis.y.dot(piece_transform.basis.y) < 0.0

# Called by the server to orient all of the pieces in the stack in a particular
# direction.
# up: Should all of the pieces be facing up?
remotesync func orient_pieces(_up: bool) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if is_card_stack():
		if card_orient_sounds != null:
			play_effect(card_orient_sounds.random_stream())
	else:
		if chip_orient_sounds != null:
			play_effect(chip_orient_sounds.random_stream())

# Pop a piece from the stack.
# Returns: A dictionary containing "piece_entry" and "transform" elements,
# an empty dictionary if the stack is empty.
# from: Where to pop the stack from.
func pop_piece(from: int = STACK_AUTO) -> Dictionary:
	var pos = pop_index(from)
	if pos < 0:
		return {}
	
	return remove_piece(pos)

# Get the index of the piece that is on the top of the stack.
# Returns: The index of the piece at the top of the stack.
# from: Where to pop the stack from.
func pop_index(from: int = STACK_AUTO) -> int:
	match from:
		STACK_AUTO:
			if transform.basis.y.y > 0:
				return get_piece_count() - 1
			else:
				return 0
		STACK_BOTTOM:
			return 0
		STACK_TOP:
			return get_piece_count() - 1
		_:
			push_error("Invalid from option %d!" % from)
			return -1

# Remove a piece from the stack by it's index.
# Returns: A dictionary containing "piece_entry" and "transform" elements,
# an empty dictionary if the stack is empty.
# index: The index of the piece to remove.
puppet func remove_piece(index: int) -> Dictionary:
	if not (get_tree().is_network_server() or get_tree().get_rpc_sender_id() == 1):
		return {}
	
	if index < 0 or index >= get_piece_count():
		push_error("Cannot remove index %d from the stack!" % index)
		return {}
	
	var current_height = get_total_height()
	var new_height = _mesh_unit_height * (get_piece_count() - 1)
	new_height = max(new_height, _collision_unit_height)
	var height_lost = max(current_height - new_height, 0)
	
	var collision_shape = get_collision_shape()
	if collision_shape.shape is BoxShape:
		collision_shape.shape.extents.y -= (height_lost / 2)
	elif collision_shape.shape is CylinderShape:
		collision_shape.shape.height -= height_lost
	else:
		push_error("Stack has an unsupported collision shape!")
		return {}
	
	get_outline_mesh_instance().scale.y = new_height + 0.001
	
	# We just changed the collision shape, so make sure the stack is awake.
	sleeping = false
	
	if is_card_stack():
		if card_remove_sounds != null:
			play_effect(card_remove_sounds.random_stream())
	else:
		if chip_remove_sounds != null:
			play_effect(chip_remove_sounds.random_stream())
	
	var piece_meta = _remove_piece_at_pos(index)
	mass -= piece_meta["piece_entry"]["mass"]
	
	return piece_meta

# Request the server to orient all of the pieces in the stack in a particular
# direction.
# up: Should all of the pieces be facing up?
master func request_orient_pieces(up: bool) -> void:
	# If the stack is upside down, orient the opposite direction.
	if transform.basis.y.y < 0:
		up = !up
	
	rpc("orient_pieces", up)

# Request the server to shuffle the stack.
master func request_shuffle() -> void:
	var order = []
	for i in range(get_piece_count()):
		order.append(i)
	
	randomize()
	order.shuffle()
	
	rpc("set_piece_order", order)

# Request the server to sort the stack by a given key in the item's entries.
# key: The key whose values to sort.
master func request_sort(key: String) -> void:
	var index = 0
	var items = []
	var num_numbers = 0
	var num_strings = 0
	for piece_meta in get_pieces():
		var piece_entry = piece_meta["piece_entry"]
		var piece_name = piece_entry["name"]
		
		if not piece_entry.has(key):
			push_error("Cannot sort stack, entry of piece %s has no key %s!" % [piece_name, key])
			return
		
		var value = piece_entry[key]
		if value == null:
			push_error("Cannot sort stack, value of piece %s is null!" % piece_name)
			return
		elif value is int or value is float:
			num_numbers += 1
		elif value is String:
			num_strings += 1
		else:
			push_error("Cannot sort stack, value of piece %s is neither a number nor a string!" % piece_name)
			return
		
		items.append({
			"index": index,
			"name": piece_name,
			"value": value
		})
		index += 1
	
	if num_numbers > 0 and num_strings > 0:
		push_warning("Stack values are a mixture of numbers and strings, converting values to strings.")
		for item in items:
			if not item["value"] is String:
				item["value"] = str(item["value"])
	
	var items2 = items.duplicate()
	_merge_sort(items, items2, 0, items.size())
	
	var order = []
	for item in items:
		order.push_back(item["index"])
	
	rpc("set_piece_order", order)

# Called by the server to set the order of pieces in the stack.
# order: The piece indicies in their new order.
remotesync func set_piece_order(_order: Array) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if is_card_stack():
		if card_shuffle_sounds != null:
			play_effect(card_shuffle_sounds.random_stream())
	else:
		if chip_shuffle_sounds != null:
			play_effect(chip_shuffle_sounds.random_stream())

# Add the outline material to the outline mesh instance.
func setup_outline_material():
	var outline_shader = preload("res://Shaders/OutlineShader.shader")
	
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = outline_shader
	_outline_material.set_shader_param("OutlineColor", Color.transparent)
	
	get_outline_mesh_instance().set_surface_material(0, _outline_material)

func _ready():
	_expose_albedo_color = false

func _physics_process(_delta):
	# If the stack is being shaken, then get the server to send a list of
	# shuffled names to each client (including itself).
	if get_tree().is_network_server() and is_being_shaked():
		request_shuffle()

# Add a piece to the stack at a given position.
# piece_entry: The piece entry of the piece to add.
# pos: The position of the new piece in the stack.
# flip_y: If the piece should be flipped when entering the stack.
func _add_piece_at_pos(_piece_entry: Dictionary, _pos: int, _flip_y: bool) -> void:
	return

# Remove the piece at the given position from the stack.
# Returns: A dictionary containing "piece_entry" and "transform" elements,
# an empty dictionary if the stack is empty.
# pos: The position to remove the piece from.
func _remove_piece_at_pos(_pos: int) -> Dictionary:
	return {}

# Use the merge sort algorithm to sort the pieces by their texture paths.
# array: The array to sort.
# copy: A copy of the original array.
# begin: The beginning of the merge sort (inclusive).
# end: The end of the merge sort (exclusive).
func _merge_sort(array: Array, copy: Array, begin: int, end: int) -> void:
	if end - begin <= 1:
		return
	
	var middle = int(float(begin + end) / 2)
	
	_merge_sort(copy, array, begin, middle)
	_merge_sort(copy, array, middle, end)
	
	var i = begin
	var j = middle
	
	for k in range(begin, end):
		var increment_i = false
		if i < middle:
			if j >= end:
				increment_i = true
			else:
				# If the values are the same, fall back on the name for sorting.
				# This way, if there are lots of pieces with the same value, they
				# should not be a subset of pieces that are effectively random.
				var less_than_or_equal = true
				if copy[i]["value"] == copy[j]["value"]:
					less_than_or_equal = (copy[i]["name"] <= copy[j]["name"])
				else:
					less_than_or_equal = (copy[i]["value"] <= copy[j]["value"])
				
				increment_i = less_than_or_equal
		
		if increment_i:
			array[k] = copy[i]
			i += 1
		else:
			array[k] = copy[j]
			j += 1
