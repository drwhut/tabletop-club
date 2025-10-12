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

extends Stack

class_name StackSandwich

export(NodePath) var sandwich_path: String

var _pieces = []

# Get the number of pieces in the stack.
# Returns: The number of pieces in the stack.
func get_piece_count() -> int:
	return _pieces.size()

# Get the current list of pieces in the stack.
# Returns: An array of dictionaries for every piece, containing "piece_entry"
# and "flip_y" elements.
func get_pieces() -> Array:
	return _pieces

# Get the sandwich mesh.
# Return: The sandwich mesh.
func get_sandwich() -> MeshInstance:
	var node = get_node(sandwich_path)
	if node is MeshInstance:
		return node
	
	return null

# Called by the server to orient all of the pieces in the stack in a particular
# direction.
# up: Should all of the pieces be facing up?
remotesync func orient_pieces(up: bool) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	# Play sound effects.
	.orient_pieces(up)

	for i in range(get_piece_count()):
		_pieces[i]["flip_y"] = not up
	
	call_deferred("_set_sandwich_display")

# Called by the server to set the order of pieces in the stack.
# order: The piece indicies in their new order.
remotesync func set_piece_order(order: Array) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	# Play sound effects.
	.set_piece_order(order)

	var new_list = []
	
	for index in order:
		new_list.append(_pieces[index])
	
	_pieces = new_list
	_set_sandwich_display()

# Add a piece to the stack at a given position.
# piece_entry: The piece entry of the piece to add.
# pos: The position of the new piece in the stack.
# flip_y: If the piece should be flipped when entering the stack.
func _add_piece_at_pos(piece_entry: Dictionary, pos: int, flip_y: bool) -> void:
	_pieces.insert(pos, {
		"piece_entry": piece_entry,
		"flip_y": flip_y
	})
	
	_set_sandwich_display()

# Remove the piece at the given position from the stack.
# Returns: A dictionary containing "piece_entry" and "transform" elements,
# an empty dictionary if the stack is empty.
# pos: The position to remove the piece from.
func _remove_piece_at_pos(pos: int) -> Dictionary:
	var out = _pieces[pos]
	_pieces.remove(pos)
	
	var piece_transform = Transform.IDENTITY
	if out["flip_y"]:
		piece_transform = piece_transform.rotated(Vector3.BACK, PI)
	out["transform"] = piece_transform
	
	_set_sandwich_display()
	
	return out

# Set the size and textures shown at either end of the sandwich.
func _set_sandwich_display() -> void:
	if _pieces.empty():
		return
	
	var sandwich = get_sandwich()
	sandwich.scale.y = _mesh_unit_height * get_piece_count()
	
	var front_meta = _pieces[get_piece_count() - 1]
	var front_entry = front_meta["piece_entry"]
	var front_flip = front_meta["flip_y"]
	
	var front_key = "texture_path"
	if front_flip:
		front_key += "_1"
	var front_path: String = front_entry[front_key]
	var front_texture: Texture
	if not front_path.empty():
		front_texture = ResourceManager.load_res(front_path)
	else:
		front_texture = preload("res://Images/BlackTexture.png")
	
	var front_material = SpatialMaterial.new()
	front_material.albedo_color = front_entry["color"]
	front_material.albedo_texture = front_texture
	sandwich.set_surface_material(0, front_material)
	
	var back_meta = _pieces[0]
	var back_entry = back_meta["piece_entry"]
	var back_flip = back_meta["flip_y"]
	
	var back_key = "texture_path"
	if not back_flip:
		back_key += "_1"
	var back_path: String = back_entry[back_key]
	var back_texture: Texture
	if not back_path.empty():
		back_texture = ResourceManager.load_res(back_path)
	else:
		back_texture = preload("res://Images/BlackTexture.png")
	
	var back_material = SpatialMaterial.new()
	back_material.albedo_color = back_entry["color"]
	back_material.albedo_texture = back_texture
	sandwich.set_surface_material(1, back_material)
