# open-tabletop
# Copyright (c) 2020 drwhut
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

extends Spatial

onready var _pieces = $Pieces

var _next_piece_name = 0

remotesync func add_piece(name: String, piece_entry: Dictionary) -> void:
	var piece = load(piece_entry["model_path"]).instance()
	piece.name = name
	piece.piece_entry = piece_entry
	
	# Spawn the piece at a height.
	piece.translation.y = Piece.SPAWN_HEIGHT
	
	_pieces.add_child(piece)
	
	# If it is a stackable piece, make sure we attach the signal it emits when
	# it wants to create a stack.
	if piece is StackablePiece:
		piece.connect("stack_requested", self, "_on_stack_requested")
	
	# Apply a generic texture to the die.
	var texture: Texture = load(piece_entry["texture_path"])
	texture.set_flags(0)
	
	piece.apply_texture(texture)

remotesync func add_stack(name: String, transform: Transform,
	piece1_name: String, piece2_name: String) -> void:
	
	var piece1 = _pieces.get_node(piece1_name)
	var piece2 = _pieces.get_node(piece2_name)
	
	if not piece1:
		push_error("Stackable piece " + piece1_name + " does not exist!")
		return
	
	if not piece2:
		push_error("Stackable piece " + piece2_name + " does not exist!")
		return
	
	if not piece1 is StackablePiece:
		push_error("Piece " + piece1_name + " is not stackable!")
		return
	
	if not piece2 is StackablePiece:
		push_error("Piece " + piece2_name + " is not stackable!")
		return
	
	_pieces.remove_child(piece1)
	_pieces.remove_child(piece2)
	
	var piece1_mesh = _get_stack_piece_mesh(piece1)
	var piece2_mesh = _get_stack_piece_mesh(piece2)
	
	var piece1_shape = _get_stack_piece_shape(piece1)
	var piece2_shape = _get_stack_piece_shape(piece2)
	
	if not (piece1_mesh and piece2_mesh and piece1_shape and piece2_shape):
		return
	
	var stack = preload("res://Pieces/Stack.tscn").instance()
	stack.name = name
	stack.transform = transform
	
	if piece1.transform.origin.y < piece2.transform.origin.y:
		stack.add_piece_top(piece1_mesh, piece1_shape)
		stack.add_piece_top(piece2_mesh, piece2_shape)
	else:
		stack.add_piece_top(piece2_mesh, piece2_shape)
		stack.add_piece_top(piece1_mesh, piece1_shape)
	
	_pieces.add_child(stack)
	
	piece1.queue_free()
	piece2.queue_free()

func add_piece_to_stack(piece_name: String, stack_name: String) -> void:
	var piece = _pieces.get_node(piece_name)
	var stack = _pieces.get_node(stack_name)
	
	if not piece:
		push_error("Piece " + stack_name + " does not exist!")
		return
	
	if not stack:
		push_error("Stack " + stack_name + " does not exist!")
		return
	
	if not piece is StackablePiece:
		push_error("Piece " + piece_name + " is not stackable!")
		return
	
	if not stack is Stack:
		push_error("Piece " + stack_name + " is not a stack!")
		return
	
	_pieces.remove_child(piece)
	
	var piece_mesh = _get_stack_piece_mesh(piece)
	var piece_shape = _get_stack_piece_shape(piece)
	
	if not (piece_mesh and piece_shape):
		return
	
	if piece.translation.y > stack.translation.y:
		if stack.transform.basis.y.dot(Vector3.UP) > 0:
			stack.add_piece_top(piece_mesh, piece_shape)
		else:
			stack.add_piece_bottom(piece_mesh, piece_shape)
	else:
		if stack.transform.basis.y.dot(Vector3.UP) > 0:
			stack.add_piece_bottom(piece_mesh, piece_shape)
		else:
			stack.add_piece_top(piece_mesh, piece_shape)
	
	piece.queue_free()

func get_next_piece_name() -> String:
	var next_name = str(_next_piece_name)
	_next_piece_name += 1
	return next_name

func get_pieces() -> Array:
	return _pieces.get_children()

func get_pieces_count() -> int:
	return _pieces.get_child_count()

func _get_stack_piece_mesh(piece: StackablePiece) -> StackPieceInstance:
	var piece_mesh = StackPieceInstance.new()
	piece_mesh.name = piece.name
	piece_mesh.transform = piece.transform
	piece_mesh.piece_entry = piece.piece_entry
	
	var piece_mesh_inst = piece.get_node("MeshInstance")
	if not piece_mesh_inst:
		push_error("Piece " + piece.name + " does not have a MeshInstance child!")
		return null
	
	piece_mesh.mesh = piece_mesh_inst.mesh
	piece_mesh.set_surface_material(0, piece_mesh_inst.get_surface_material(0))
	
	return piece_mesh

func _get_stack_piece_shape(piece: StackablePiece) -> Shape:
	var piece_collision_shape = piece.get_node("CollisionShape")
	if not piece_collision_shape:
		push_error("Piece " + piece.name + " does not have a CollisionShape child!")
		return null
	
	return piece_collision_shape.shape

func _on_stack_requested(piece1: StackablePiece, piece2: StackablePiece) -> void:
	if piece1 is Stack and piece2 is Stack:
		pass
	elif piece1 is Stack:
		add_piece_to_stack(piece2.name, piece1.name)
	elif piece2 is Stack:
		add_piece_to_stack(piece1.name, piece2.name)
	else:
		rpc("add_stack", get_next_piece_name(), piece1.transform, piece1.name,
			piece2.name)
