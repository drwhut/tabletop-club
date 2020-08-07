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

extends RigidBody

class_name Piece

signal piece_exiting_tree(piece)

const ANGULAR_FORCE_SCALAR = 20.0
const HELL_HEIGHT = -50.0
const LINEAR_FORCE_SCALAR  = 20.0
const ROTATION_LOCK_AT = 0.001
const SELECTED_COLOUR = Color.cyan
const SELECTED_ENERGY = 0.25
const SHAKING_THRESHOLD = 1000.0
const SPAWN_HEIGHT = 2.0
const TRANSFORM_LERP_ALPHA = 0.5

var piece_entry: Dictionary = {}

var _mesh_instance: MeshInstance = null

# When setting these vectors, make sure you call set_angular_lock(false),
# otherwise the piece won't rotate towards the orientation!
var _srv_hover_back = Vector3.BACK
var _srv_hover_up = Vector3.UP

var _srv_hover_player = 0
var _srv_hover_position = Vector3()

var _last_server_state = {}

var _last_velocity = Vector3()
var _new_velocity = Vector3()

# Apply a texture to the piece.
# texture: The texture to apply.
func apply_texture(texture: Texture) -> void:
	if _mesh_instance:
		var material = SpatialMaterial.new()
		material.albedo_texture = texture
		
		_mesh_instance.set_surface_material(0, material)

# If you are hovering this piece, ask the server to flip the piece vertically.
master func flip_vertically() -> void:
	if get_tree().get_rpc_sender_id() == _srv_hover_player:
		_srv_hover_up = -_srv_hover_up
		set_angular_lock(false)

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
		_srv_hover_up = Vector3.UP
		set_angular_lock(false)

# Set the angular lock on all 3 rotational axis.
# lock: If the rotational axis are locked.
func set_angular_lock(lock: bool) -> void:
	# It's.. it's Kurt Angle! He's got the Angle Lock in on The Rock!!!
	axis_lock_angular_x = lock
	axis_lock_angular_y = lock
	axis_lock_angular_z = lock

# Set the piece to appear like it is selected.
# selected: Should the piece appear selected?
func set_appear_selected(selected: bool) -> void:
	if _mesh_instance:
		var material = _mesh_instance.get_surface_material(0)
		if material is SpatialMaterial:
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
		_srv_hover_position = hover_position

# Called by the server to store the server's physics state locally.
# state: The server's physics state for this piece.
puppet func set_latest_server_physics_state(state: Dictionary) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_last_server_state = state
	sleeping = false

# Get the ID of the player that is hovering the piece.
# Returns: The ID of the player hovering the piece. 0 if the piece is not being
# hovered.
func srv_get_hovering_player() -> int:
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
func srv_start_hovering(player_id: int) -> bool:
	if not (srv_is_hovering() or is_locked()):
		_srv_hover_player = player_id
		custom_integrator = true
		
		# Make sure _integrate_forces runs.
		sleeping = false
		
		set_angular_lock(false)
		
		# Determine which basis is closest to "up" and "back", and set it so
		# that the piece doesn't dance around trying to get back to the
		# direction it was in before it was dropped.
		var y_right_dot = transform.basis.y.dot(Vector3.RIGHT)
		var y_up_dot    = transform.basis.y.dot(Vector3.UP)
		var y_back_dot  = transform.basis.y.dot(Vector3.BACK)
		
		if abs(y_right_dot) > abs(y_up_dot):
			if abs(y_right_dot) > abs(y_back_dot):
				if y_right_dot > 0:
					_srv_hover_up = Vector3.RIGHT
				else:
					_srv_hover_up = Vector3.LEFT
			else:
				if y_back_dot > 0:
					_srv_hover_up = Vector3.BACK
				else:
					_srv_hover_up = Vector3.FORWARD
		elif abs(y_up_dot) > abs(y_back_dot):
			if y_up_dot > 0:
				_srv_hover_up = Vector3.UP
			else:
				_srv_hover_up = Vector3.DOWN
		else:
			if y_back_dot > 0:
				_srv_hover_up = Vector3.BACK
			else:
				_srv_hover_up = Vector3.FORWARD
		
		var z_right_dot = transform.basis.z.dot(Vector3.RIGHT)
		var z_up_dot    = transform.basis.z.dot(Vector3.UP)
		var z_back_dot  = transform.basis.z.dot(Vector3.BACK)
		
		if abs(z_right_dot) > abs(z_up_dot):
			if abs(z_right_dot) > abs(z_back_dot):
				if z_right_dot > 0:
					_srv_hover_back = Vector3.RIGHT
				else:
					_srv_hover_back = Vector3.LEFT
			else:
				if z_back_dot > 0:
					_srv_hover_back = Vector3.BACK
				else:
					_srv_hover_back = Vector3.FORWARD
		elif abs(z_up_dot) > abs(z_back_dot):
			if z_up_dot > 0:
				_srv_hover_back = Vector3.UP
			else:
				_srv_hover_back = Vector3.DOWN
		else:
			if z_back_dot > 0:
				_srv_hover_back = Vector3.BACK
			else:
				_srv_hover_back = Vector3.FORWARD
		
		return true
	
	return false

# If you are hovering the piece, ask the server to stop hovering it.
master func stop_hovering() -> void:
	if get_tree().get_rpc_sender_id() == _srv_hover_player:
		_srv_hover_player = 0
		custom_integrator = false
		sleeping = false
		
		set_angular_lock(false)

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

func _physics_process(delta):
	_last_velocity = _new_velocity
	_new_velocity  = linear_velocity
	
	# If we are the server ...
	if get_tree().is_network_server():
		
		# ... and the piece isn't sleeping ...
		if not sleeping:
		
			# ... then send this piece's physics state to the clients.
			rpc_unreliable("set_latest_server_physics_state", _last_server_state)

func _integrate_forces(state):
	if get_tree().is_network_server():
		
		# Only the server can apply what happens when a piece is hovered.
		if srv_is_hovering():
			_srv_apply_hover_to_state(state)
		
		# If the piece has fallen off the table and decended into hell, recover
		# it so the devil doesn't tickle it to death.
		elif state.transform.origin.y < HELL_HEIGHT:
			state.transform.basis.x = Vector3.RIGHT
			state.transform.basis.y = Vector3.UP
			state.transform.basis.z = Vector3.BACK
			state.transform.origin = Vector3(0, SPAWN_HEIGHT, 0)
			
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
	state.apply_central_impulse(LINEAR_FORCE_SCALAR * (_srv_hover_position - translation))
	# Stops linear harmonic motion.
	state.apply_central_impulse(-linear_velocity * mass)
	
	# Figure out how far away we are from the orientation we're supposed to be
	# at.
	var y_diff = (1 - _srv_hover_up.dot(transform.basis.y)) / 2
	var z_diff = (1 - _srv_hover_back.dot(transform.basis.z)) / 2
	
	# If we're close enough to the orientation, lock our angular axes.
	if y_diff < ROTATION_LOCK_AT and z_diff < ROTATION_LOCK_AT:
		set_angular_lock(true)
	else:
		# TODO: Are the following cross products worth optimising?
		# Torque the piece to the upright position on two axes.
		
		# If the basis is the exact opposite of where we need it, the normal
		# cross product calculations will just be 0 - so we will need to give
		# the piece a nudge!
		if y_diff == 1:
			state.add_torque(ANGULAR_FORCE_SCALAR * (transform.basis.y.cross(transform.basis.z)).cross(_srv_hover_up).normalized())
		else:
			state.add_torque(ANGULAR_FORCE_SCALAR * (transform.basis.y).cross(_srv_hover_up - transform.basis.y).normalized())
		
		if z_diff == 1:
			state.add_torque(ANGULAR_FORCE_SCALAR * (transform.basis.z.cross(transform.basis.y)).cross(_srv_hover_back).normalized())
		else:
			state.add_torque(ANGULAR_FORCE_SCALAR * (transform.basis.z).cross(_srv_hover_back - transform.basis.z).normalized())
		
		# Stops angular harmonic motion.
		state.add_torque(-angular_velocity)
