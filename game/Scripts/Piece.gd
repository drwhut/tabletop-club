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

const ANGULAR_FORCE_SCALAR = 20.0
const HELL_HEIGHT = -50.0
const LINEAR_FORCE_SCALAR  = 20.0
const ROTATION_LOCK_AT = 0.001
const SHAKING_THRESHOLD = 50.0
const SPAWN_HEIGHT = 2.0
const TRANSFORM_LERP_ALPHA = 0.5

var piece_entry: Dictionary = {}

var _mesh_instance: MeshInstance = null

# When setting these vectors, make sure you call set_angular_lock(false),
# otherwise the piece won't rotate towards the orientation!
var _hover_back = Vector3.BACK
var _hover_up = Vector3.UP

var _hover_player = 0
var _hover_position = Vector3()

var _last_server_state = {}

var _last_velocity = Vector3()
var _new_velocity = Vector3()

func apply_texture(texture: Texture) -> void:
	if _mesh_instance != null:
		var material = SpatialMaterial.new()
		material.albedo_texture = texture
		
		_mesh_instance.set_surface_material(0, material)

master func flip_vertically() -> void:
	if get_tree().get_rpc_sender_id() == _hover_player:
		_hover_up = -_hover_up
		set_angular_lock(false)

func is_being_shaked() -> bool:
	return (_new_velocity - _last_velocity).length_squared() > SHAKING_THRESHOLD

func is_hovering() -> bool:
	return _hover_player > 0

remotesync func remove_self() -> void:
	if get_parent():
		get_parent().remove_child(self)
		queue_free()

master func reset_orientation() -> void:
	if get_tree().get_rpc_sender_id() == _hover_player:
		_hover_up = Vector3.UP
		_hover_back = Vector3.BACK
		set_angular_lock(false)

func set_angular_lock(lock: bool) -> void:
	axis_lock_angular_x = lock
	axis_lock_angular_y = lock
	axis_lock_angular_z = lock

master func set_hover_position(hover_position: Vector3) -> void:
	# Only allow the hover position to be set if the request is coming from the
	# player that is hovering the piece.
	if get_tree().get_rpc_sender_id() == _hover_player:
		_hover_position = hover_position

puppet func set_latest_server_physics_state(state: Dictionary) -> void:
	_last_server_state = state
	
	# Similarly to in start_hovering(), we want to make sure _integrate_forces
	# runs, even when we're not hovering anything.
	if state.has("sleeping"):
		sleeping = state["sleeping"]

func start_hovering(player_id: int) -> bool:
	if not is_hovering():
		_hover_player = player_id
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
					_hover_up = Vector3.RIGHT
				else:
					_hover_up = Vector3.LEFT
			else:
				if y_back_dot > 0:
					_hover_up = Vector3.BACK
				else:
					_hover_up = Vector3.FORWARD
		elif abs(y_up_dot) > abs(y_back_dot):
			if y_up_dot > 0:
				_hover_up = Vector3.UP
			else:
				_hover_up = Vector3.DOWN
		else:
			if y_back_dot > 0:
				_hover_up = Vector3.BACK
			else:
				_hover_up = Vector3.FORWARD
		
		var z_right_dot = transform.basis.z.dot(Vector3.RIGHT)
		var z_up_dot    = transform.basis.z.dot(Vector3.UP)
		var z_back_dot  = transform.basis.z.dot(Vector3.BACK)
		
		if abs(z_right_dot) > abs(z_up_dot):
			if abs(z_right_dot) > abs(z_back_dot):
				if z_right_dot > 0:
					_hover_back = Vector3.RIGHT
				else:
					_hover_back = Vector3.LEFT
			else:
				if z_back_dot > 0:
					_hover_back = Vector3.BACK
				else:
					_hover_back = Vector3.FORWARD
		elif abs(z_up_dot) > abs(z_back_dot):
			if z_up_dot > 0:
				_hover_back = Vector3.UP
			else:
				_hover_back = Vector3.DOWN
		else:
			if z_back_dot > 0:
				_hover_back = Vector3.BACK
			else:
				_hover_back = Vector3.FORWARD
		
		return true
	
	return false

master func stop_hovering() -> void:
	if get_tree().get_rpc_sender_id() == _hover_player:
		_hover_player = 0
		custom_integrator = false
		
		set_angular_lock(false)

func _ready():
	if not get_tree().is_network_server():
		# The clients are at the mercy of the server.
		custom_integrator = true

func _physics_process(delta):
	_last_velocity = _new_velocity
	_new_velocity  = linear_velocity
	
	# If we are the server ...
	if get_tree().is_network_server():
		
		# ... and the piece is moving ...
		if linear_velocity.length_squared() > 0 or angular_velocity.length_squared() > 0:
		
			# ... then send this piece's physics state to the clients.
			rpc_unreliable("set_latest_server_physics_state", _last_server_state)

func _integrate_forces(state):
	if get_tree().is_network_server():
		
		# Only the server can apply what happens when a piece is hovered.
		if is_hovering():
			_apply_hover_to_state(state)
		
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
			"sleeping": state.sleeping,
			"transform": state.transform
		}
	
	else:
		# The client, if it has received a new physics state from the
		# server, needs to update it here.
		if _last_server_state.has("angular_velocity"):
			state.angular_velocity = _last_server_state["angular_velocity"]
		if _last_server_state.has("linear_velocity"):
			state.linear_velocity = _last_server_state["linear_velocity"]
		if _last_server_state.has("sleeping"):
			state.sleeping = _last_server_state["sleeping"]
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

func _apply_hover_to_state(state: PhysicsDirectBodyState) -> void:
	# Force the piece to the given location.
	state.apply_central_impulse(LINEAR_FORCE_SCALAR * (_hover_position - translation))
	# Stops linear harmonic motion.
	state.apply_central_impulse(-linear_velocity * mass)
	
	# Figure out how far away we are from the orientation we're supposed to be
	# at.
	var y_diff = (1 - _hover_up.dot(transform.basis.y)) / 2
	var z_diff = (1 - _hover_back.dot(transform.basis.z)) / 2
	
	# If we're close enough to the orientation, lock our angular axes.
	if y_diff < ROTATION_LOCK_AT and z_diff < ROTATION_LOCK_AT:
		set_angular_lock(true)
	else:
		# TODO: Are the following cross products worth optimising?
		# Torque the piece to the upright position on two axes.
		state.add_torque(ANGULAR_FORCE_SCALAR * (transform.basis.y).cross(_hover_up - transform.basis.y).normalized())
		state.add_torque(ANGULAR_FORCE_SCALAR * (transform.basis.z).cross(_hover_back - transform.basis.z).normalized())
		# Stops angular harmonic motion.
		state.add_torque(-angular_velocity)
