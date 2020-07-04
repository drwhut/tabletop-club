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
const LINEAR_FORCE_SCALAR  = 20.0
const SHAKING_BOUND = 50.0

var piece_entry: Dictionary = {}

var _hover_back = Vector3.BACK
var _hover_player = 0
var _hover_position = Vector3()
var _hover_up = Vector3.UP

var _last_server_state = {}
var _new_server_state = false

var _last_velocity = Vector3()
var _new_velocity = Vector3()

master func flip_vertically() -> void:
	if get_tree().get_rpc_sender_id() == _hover_player:
		_hover_up = -_hover_up

func is_being_shaked() -> bool:
	return (_new_velocity - _last_velocity).length_squared() > SHAKING_BOUND

func is_hovering() -> bool:
	return _hover_player > 0

puppet func set_hover_player(player: int) -> void:
	_hover_player = player

master func set_hover_position(hover_position: Vector3) -> void:
	# Only allow the hover position to be set if the request is coming from the
	# player that is hovering the piece.
	if get_tree().get_rpc_sender_id() == _hover_player:
		_hover_position = hover_position

puppet func set_latest_server_physics_state(state: Dictionary) -> void:
	_last_server_state = state
	_new_server_state = true
	
	# Similarly to in start_hovering(), we want to make sure _integrate_forces
	# runs, even when we're not hovering anything.
	if state.has("sleeping"):
		sleeping = state["sleeping"]

master func start_hovering() -> void:
	if not is_hovering():
		_hover_player = get_tree().get_rpc_sender_id()
		rpc("set_hover_player", _hover_player)
		custom_integrator = true
		
		# Make sure _integrate_forces runs.
		sleeping = false
		
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

master func stop_hovering() -> void:
	_hover_player = 0
	rpc("set_hover_player", 0)
	custom_integrator = false

func _ready():
	if not get_tree().is_network_server():
		# The clients are at the mercy of the server.
		custom_integrator = true

func _physics_process(delta):
	_last_velocity = _new_velocity
	_new_velocity  = linear_velocity
	
	# If we are the server ...
	if get_tree().is_network_server():
		
		# ... then send this piece's physics state to the clients.
		rpc_unreliable("set_latest_server_physics_state", _last_server_state)

func _integrate_forces(state):
	if get_tree().is_network_server():
		
		# Only the server can apply what happens when a piece is hovered.
		if is_hovering():
			_apply_hover_to_state(state)
		
		# The server piece needs to keep track of its physics properties in
		# order to send it to the client.
		_last_server_state = {
			"angular_velocity": state.angular_velocity,
			"linear_velocity": state.linear_velocity,
			"sleeping": state.sleeping,
			"transform": state.transform
		}
	
	elif _new_server_state:
		# The client, if it has received a new physics state from the
		# server, needs to update it here.
		if _last_server_state.has("angular_velocity"):
			state.angular_velocity = _last_server_state["angular_velocity"]
		if _last_server_state.has("linear_velocity"):
			state.linear_velocity = _last_server_state["linear_velocity"]
		if _last_server_state.has("sleeping"):
			state.sleeping = _last_server_state["sleeping"]
		if _last_server_state.has("transform"):
			state.transform = _last_server_state["transform"]
		
		_new_server_state = false

func _apply_hover_to_state(state: PhysicsDirectBodyState) -> void:
	# Force the piece to the given location.
	state.apply_central_impulse(LINEAR_FORCE_SCALAR * (_hover_position - translation))
	# Stops linear harmonic motion.
	state.apply_central_impulse(-linear_velocity * mass)
	
	# Add some bias so that the pieces get to their desired state quicker,
	# but don't overshoot when they are at their desired state.
	var y_bias = sqrt(abs(_hover_up.dot(transform.basis.y) - 1) / 2)
	var z_bias = sqrt(abs(_hover_back.dot(transform.basis.z) - 1) / 2)
	
	# TODO: Are the following cross products worth optimising?
	
	# Torque the piece to the upright position on two axes.
	state.add_torque(y_bias * ANGULAR_FORCE_SCALAR * (transform.basis.y).cross(_hover_up - transform.basis.y).normalized())
	state.add_torque(z_bias * ANGULAR_FORCE_SCALAR * (transform.basis.z).cross(_hover_back - transform.basis.z).normalized())
	# Stops angular harmonic motion.
	state.add_torque(-angular_velocity)
