# open-tabletop
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows
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

extends RigidBody

class_name Piece

signal client_set_hover_position(piece)
signal piece_exiting_tree(piece)

const ANGULAR_FORCE_SCALAR = 25.0
const HELL_HEIGHT = -50.0
const HOVER_INACTIVE_DURATION = 5.0
const LINEAR_FORCE_SCALAR = 50.0
const ROTATION_LOCK_AT = 0.001
const SELECTED_COLOUR = Color.cyan
const SELECTED_ENERGY = 0.25
const SHAKING_THRESHOLD = 1000.0
const SPAWN_HEIGHT = 2.0
const TRANSFORM_LERP_ALPHA = 0.5

# Set if you know where the mesh instance is, and if there is only one mesh
# instance. Otherwise, the game will try and find it automatically when it
# needs it (e.g. when using a custom piece).
export(NodePath) var mesh_instance_path: String

var piece_entry: Dictionary = {}

# When setting these vectors, make sure you call set_angular_lock(false),
# otherwise the piece won't rotate towards the orientation!
var srv_hover_basis = Basis.IDENTITY
var srv_hover_position = Vector3()

var srv_retrieve_from_hell: bool = true

var _srv_hover_offset = Vector3()
var _srv_hover_player = 0

var _srv_hover_time_since_update = 0.0

var _last_server_state = {}

var _last_velocity = Vector3()
var _new_velocity = Vector3()

# Apply a texture to the piece.
# texture: The texture to apply.
func apply_texture(texture: Texture) -> void:
	for mesh_instance in get_mesh_instances():
		var material = SpatialMaterial.new()
		material.albedo_texture = texture
		
		mesh_instance.set_surface_material(0, material)

# If you are hovering this piece, ask the server to flip the piece vertically.
master func flip_vertically() -> void:
	if get_tree().get_rpc_sender_id() == _srv_hover_player:
		srv_hover_basis = srv_hover_basis.rotated(transform.basis.z, PI)
		srv_wake_up()

# Get the piece's collision shapes.
# Returns: An array of the piece's collision shapes.
func get_collision_shapes() -> Array:
	var out = []
	for child in get_children():
		if child is CollisionShape:
			out.append(child)
	return out

# Get the piece's mesh instances.
# Returns: An array of the piece's mesh instances.
func get_mesh_instances() -> Array:
	if mesh_instance_path:
		var mesh_instance = get_node(mesh_instance_path)
		if mesh_instance is MeshInstance:
			return [mesh_instance as MeshInstance]
	
	var out = []
	for collision_shape in get_collision_shapes():
		for child in collision_shape.get_children():
			if child is MeshInstance:
				out.append(child)
	return out

# Determines if the piece is being shaked.
# Returns: If the piece is being shaked.
func is_being_shaked() -> bool:
	if _new_velocity.dot(_last_velocity) < 0:
		return (_new_velocity - _last_velocity).length_squared() > SHAKING_THRESHOLD
	return false

# Is the piece locked, i.e. unable to move?
# Returns: If the piece is locked.
func is_locked() -> bool:
	return mode == MODE_STATIC

# Called by the server to lock the piece on all clients, with the given
# transform.
puppet func lock_client(locked_transform: Transform) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	mode = MODE_STATIC
	transform = locked_transform

# Called by the server to remove the piece from the game.
remotesync func remove_self() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if get_parent():
		get_parent().remove_child(self)
		queue_free()

# Request the server to lock the piece.
master func request_lock() -> void:
	srv_lock()

# Request the server to remove the piece.
master func request_remove_self() -> void:
	rpc("remove_self")

# Request the server to unlock the piece.
master func request_unlock() -> void:
	rpc("unlock")

# If you are hovering the piece, ask the server to reset the orientation of the
# piece.
master func reset_orientation() -> void:
	if get_tree().get_rpc_sender_id() == _srv_hover_player:
		srv_hover_basis = Basis.IDENTITY
		srv_wake_up()

# If you are hovering the piece, rotate it on the y-axis.
# rot: The amount to rotate it by in radians.
master func rotate_y(rot: float) -> void:
	if get_tree().get_rpc_sender_id() == _srv_hover_player:
		if rot == 0.0:
			return
		
		var current_euler = srv_hover_basis.get_euler()
		var current_y_scale = current_euler.y / abs(rot)
		# The .001 is to avoid floating point errors.
		var offset = 1.001
		var target_y_scale = current_y_scale
		if rot > 0.0:
			target_y_scale = floor(current_y_scale + offset)
		else:
			target_y_scale = ceil(current_y_scale - offset)
		var target_y_euler = current_euler
		target_y_euler.y = wrapf(target_y_scale * abs(rot), -PI, PI)
		srv_hover_basis = Basis(target_y_euler)
		
		srv_wake_up()

# Set the piece to appear like it is selected.
# selected: Should the piece appear selected?
func set_appear_selected(selected: bool) -> void:
	for mesh_instance in get_mesh_instances():
		var material = mesh_instance.get_surface_material(0)
		if material and material is SpatialMaterial:
			material.emission = SELECTED_COLOUR
			material.emission_energy = SELECTED_ENERGY
			
			material.emission_enabled = selected

# If you are hovering the piece, ask the server to set the hover position of the
# piece.
# hover_position: The position the hovering piece will go towards.
master func set_hover_position(hover_position: Vector3) -> void:
	# Only allow the hover position to be set if the request is coming from the
	# player that is hovering the piece.
	if get_tree().get_rpc_sender_id() == _srv_hover_player:
		srv_hover_position = hover_position
		srv_wake_up()
		emit_signal("client_set_hover_position", self)

# Called by the server to store the server's physics state locally.
# state: The server's physics state for this piece.
puppet func set_latest_server_physics_state(state: Dictionary) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_last_server_state = state
	sleeping = false

# Called by the server to set the translation of the piece.
# new_translation: The new translation.
remotesync func set_translation(new_translation: Vector3) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	translation = new_translation
	sleeping = false

# Get the hover offset of the piece.
# Returns: The hover offset of the piece.
func srv_get_hover_offset() -> Vector3:
	return _srv_hover_offset

# Get the ID of the player that is hovering the piece.
# Returns: The ID of the player hovering the piece. 0 if the piece is not being
# hovered.
func srv_get_hover_player() -> int:
	return _srv_hover_player

# Is the piece being hovered?
# Returns: If the piece is being hovered.
func srv_is_hovering() -> bool:
	return _srv_hover_player > 0

# Lock the piece server-side.
func srv_lock() -> void:
	mode = MODE_STATIC
	rpc("lock_client", transform)

# Start hovering the piece server-side.
# Returns: If the piece started hovering.
# player_id: The ID of the player hovering the piece.
# init_pos: The initial hover position.
# offset_pos: The hover position offset.
func srv_start_hovering(player_id: int, init_pos: Vector3, offset_pos: Vector3) -> bool:
	if not (srv_is_hovering() or is_locked()):
		srv_hover_basis = transform.basis
		srv_hover_position = init_pos
		
		_srv_hover_offset = offset_pos
		_srv_hover_player = player_id
		
		srv_wake_up()
		
		collision_layer = 2
		custom_integrator = true
		
		return true
	
	# If the piece is hovering, and it's the client that is hovering the piece,
	# send them the all clear, since they are already in control.
	if not is_locked():
		if player_id == _srv_hover_player:
			return true
	
	return false

# Wake the piece up if it is sleeping.
func srv_wake_up() -> void:
	sleeping = false
	_srv_hover_time_since_update = 0.0

# If you are hovering the piece, ask the server to stop hovering it. The server
# can also stop hovering the piece regardless of who is currently hovering it.
master func stop_hovering() -> void:
	var id = get_tree().get_rpc_sender_id()
	if id == _srv_hover_player or id == 1:
		_srv_hover_player = 0
		collision_layer = 1
		custom_integrator = false
		sleeping = false

# Called by the server to unlock the piece.
remotesync func unlock() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	mode = MODE_RIGID

func _ready():
	if not get_tree().is_network_server():
		# The clients are at the mercy of the server.
		custom_integrator = true
	
	connect("tree_exiting", self, "_on_tree_exiting")

func _process(delta):
	if get_tree().is_network_server():
		if srv_is_hovering() and not sleeping:
			_srv_hover_time_since_update += delta
			
			# If the hovering piece has not had a transform update in a certain
			# amount of time, put it to sleep so it doesn't send unnessesary
			# updates to all the clients.
			if _srv_hover_time_since_update > HOVER_INACTIVE_DURATION:
				sleeping = true

func _physics_process(delta):
	_last_velocity = _new_velocity
	_new_velocity  = linear_velocity
	
	if get_tree().is_network_server():
		if not (sleeping or is_locked()):
			rpc_unreliable("set_latest_server_physics_state", _last_server_state)

func _integrate_forces(state):
	if get_tree().is_network_server():
		
		# Only the server can apply what happens when a piece is hovered.
		if srv_is_hovering():
			_srv_apply_hover_to_state(state)
		
		# If the piece has fallen off the table and decended into hell, recover
		# it so the devil doesn't tickle it to death.
		elif srv_retrieve_from_hell and state.transform.origin.y < HELL_HEIGHT:
			state.transform = Transform.IDENTITY
			state.transform.origin.y += SPAWN_HEIGHT
			
			state.angular_velocity = Vector3.ZERO
			state.linear_velocity = Vector3.ZERO
		
		# The server piece needs to keep track of its physics properties in
		# order to send it to the client.
		_last_server_state = {
			"angular_velocity": state.angular_velocity,
			"linear_velocity": state.linear_velocity,
			"transform": state.transform
		}
	
	else:
		# The client, if it has received a new physics state from the
		# server, needs to update it here.
		
		if _last_server_state.has("angular_velocity"):
			state.angular_velocity = _last_server_state["angular_velocity"]
		if _last_server_state.has("linear_velocity"):
			state.linear_velocity = _last_server_state["linear_velocity"]
		if _last_server_state.has("transform"):
			
			# For the transform, we want to lerp into the new state to make it
			# as smooth as possible, even if the server fails to send the state.
			var server_transform = _last_server_state["transform"]
			var origin = transform.origin.linear_interpolate(server_transform.origin, TRANSFORM_LERP_ALPHA)
			var client_quat = Quat(transform.basis)
			var server_quat = Quat(server_transform.basis)
			var lerp_quat = client_quat.slerp(server_quat, TRANSFORM_LERP_ALPHA).normalized()
			
			var new_transform = Transform(lerp_quat)
			new_transform.origin = origin
			state.transform = new_transform

func _on_tree_exiting() -> void:
	emit_signal("piece_exiting_tree", self)

# Apply forces to the piece to get it to the desired hover position and
# orientation.
# state: The direct physics state of the piece.
func _srv_apply_hover_to_state(state: PhysicsDirectBodyState) -> void:
	# Force the piece to the given location.
	var linear_dir = srv_hover_position + _srv_hover_offset - translation
	state.apply_central_impulse(LINEAR_FORCE_SCALAR * mass * linear_dir)
	# Stops linear harmonic motion.
	state.apply_central_impulse(-mass * linear_velocity)
	
	# Force the piece to the given basis.
	var current_basis = transform.basis.orthonormalized()
	var target_basis = srv_hover_basis.orthonormalized()
	var rotation_basis = target_basis * current_basis.inverse()
	var rotation_euler = rotation_basis.get_euler()
	
	# For rigid bodies, applied torque is multiplied with the inverse of the
	# inertia tensor (a 3x3 matrix) to get the angular acceleration. But here
	# we want all pieces to rotate the same way, so we get the non-inverted
	# inertia tensor and multiply the torque by it to pretend all pieces have
	# the same inertia tensor.
	var inertia_tensor = get_inverse_inertia_tensor()
	if inertia_tensor.determinant() == 0:
		inertia_tensor = Basis.IDENTITY
	else:
		inertia_tensor = inertia_tensor.inverse()
	
	var applied_torque = inertia_tensor * rotation_euler
	state.apply_torque_impulse(ANGULAR_FORCE_SCALAR * applied_torque)
	
	# Stops angular harmonic motion.
	var angular_torque = inertia_tensor * angular_velocity
	state.apply_torque_impulse(-angular_torque)
