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

extends Piece

class_name PieceContainer

signal absorbing_hovered(container, player_id)
signal releasing_random_piece(container)

onready var _pieces = $Pieces

var _srv_is_locked: bool = false

# Add a piece as a child to the container. Note that the piece cannot already
# have a parent!
# piece: The piece to add to the container.
func add_piece(piece: Piece) -> void:
	# Move the piece out of the way of the table so it is not visible, and make
	# sure it cannot move.
	piece.transform.origin = Vector3(9999, 9999, 9999)
	piece.mode = MODE_STATIC
	
	_pieces.add_child(piece)
	mass += piece.mass

# Duplicate the given piece and return the duplicate.
# Returns: A duplicate of the piece with the given name in the container, null
# if the piece doesn't exist.
# piece_name: The name of the piece to duplicate.
func duplicate_piece(piece_name: String) -> Piece:
	if has_piece(piece_name):
		var original: Piece = _pieces.get_node(piece_name)
		var duplicate: Piece = original.duplicate(DUPLICATE_SCRIPTS)
		duplicate.piece_entry = original.piece_entry
		return duplicate
	
	return null

# Get the number of pieces that the container is holding.
# Returns: The number of pieces inside the container.
func get_piece_count() -> int:
	return _pieces.get_child_count()

# Get the names of the pieces that the container is holding.
# Returns: An array of the names of the pieces.
func get_piece_names() -> Array:
	var out = []
	for piece in _pieces.get_children():
		out.append(piece.name)
	return out

# Does the container have the given piece?
# Returns: If the container has the given piece inside of it.
# piece_name: The name of the piece to check for.
func has_piece(piece_name: String) -> bool:
	return _pieces.has_node(piece_name)

# Is the piece locked, i.e. unable to move?
# Returns: If the piece is locked.
func is_locked() -> bool:
	if _srv_is_locked:
		return true
	return .is_locked()

# Called by the server to lock the piece on all clients, with the given
# transform.
puppet func lock_client(locked_transform: Transform) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if get_tree().is_network_server():
		transform = locked_transform
		_srv_set_locked_container(true)
	else:
		.lock_client(locked_transform)

# Recalculate the mass of the container, based on the items inside it.
# You should use this if you added a piece to the container, but not via the
# add_piece() function.
func recalculate_mass() -> void:
	mass = piece_entry["mass"]
	
	for piece in _pieces.get_children():
		if piece is Piece:
			mass += piece.mass

# Release the given piece from the container, and return it with a new
# transform such that it is just above the top of the container.
# Returns: The release piece as an orphan node, null if the piece isn't in the
# container.
# piece_name: The name of the piece to release.
func remove_piece(piece_name: String) -> Piece:
	if has_piece(piece_name):
		var piece: Piece = _pieces.get_node(piece_name)
		mass -= piece.mass
		_pieces.remove_child(piece)
		
		# NOTE: For some reason (my theory is the physics interpolation patch:
		# https://github.com/drwhut/godot/commit/5d56dd72b13d261c88602d9b37ada1063c5c4b57
		# ), the basis of the transform may drift slightly while in the
		# container, even if the piece is in static mode. This line is a
		# workaround to prevent that from affecting the physics state.
		# TODO: Maybe this can be removed when using Godot 3.5?
		piece.transform.basis = piece.transform.basis.orthonormalized()
		
		# Reverse the modifications done to the piece when it was absorbed.
		# NOTE: Rigidbodies themselves are not scaled, only their collision
		# shapes are.
		var adj_piece_size = Global.rotate_bounding_box(piece.get_size(),
				piece.transform.basis)
		var piece_slice_height = abs(transform.basis.y.dot(adj_piece_size))
		var distance = 0.5 * (get_size().y + piece_slice_height) + 1.0
		var new_origin = transform.origin + distance * transform.basis.y
		piece.transform.origin = new_origin
		
		piece.mode = MODE_RIGID
		
		return piece
	
	return null

# Lock the piece server-side.
func srv_lock() -> void:
	_srv_set_locked_container(true)
	rpc("lock_client", transform)

# Called by the server to unlock the piece.
remotesync func unlock() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if get_tree().is_network_server():
		_srv_set_locked_container(false)
		sleeping = false
	else:
		.unlock()

func _physics_process(_delta):
	if get_tree().is_network_server():
		var shakable: bool = piece_entry["shakable"]
		if shakable:
			# If the container is upside down, and it is being shaken, then
			# randomly release a piece to simulate what would happen in reality.
			if transform.basis.y.y < -0.9 and is_being_shaked():
				emit_signal("releasing_random_piece", self)

func _integrate_forces(state):
	if not _srv_is_locked:
		._integrate_forces(state)

# Set if the container is locked on the server.
# NOTE: Locking a container on the server side is different to every other
# piece, since it still needs to emit signals when locked.
# is_locked: If the container will be locked.
func _srv_set_locked_container(is_locked: bool) -> void:
	_srv_is_locked = is_locked
	
	axis_lock_angular_x = is_locked
	axis_lock_angular_y = is_locked
	axis_lock_angular_z = is_locked
	axis_lock_linear_x = is_locked
	axis_lock_linear_y = is_locked
	axis_lock_linear_z = is_locked
	
	# Disables in-built physics, as well as physics from Piece.
	custom_integrator = is_locked

func _on_body_entered(body) -> void:
	._on_body_entered(body)
	
	if get_tree().is_network_server():
		
		# If a piece has collided with this container, then figure out if the
		# piece was being hovered by a player. If it is, then we can add it to
		# the container!
		if body is Piece:
			if body.is_hovering():
				emit_signal("absorbing_hovered", self, body.hover_player)
