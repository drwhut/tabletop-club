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

signal hover_piece_requested(piece)
signal pieces_context_menu_requested(pieces)
signal pop_stack_requested(stack)
signal started_hovering_card(card)
signal stopped_hovering_card(card)

onready var _camera = $Camera

const GRABBING_SLOW_TIME = 0.25
const HOVER_Y_LEVEL = 4.0
const MOVEMENT_ACCEL = 1.0
const MOVEMENT_DECEL = 3.0
const MOVEMENT_MAX_SPEED = 30.0
const RAY_LENGTH = 1000
const ROTATION_SENSITIVITY = -0.01
const ROTATION_Y_MAX = -0.2
const ROTATION_Y_MIN = -1.3
const ZOOM_AMOUNT = 2.0
const ZOOM_DISTANCE_MIN = 2.0
const ZOOM_DISTANCE_MAX = 80.0

var _grabbing_time = 0.0
var _is_grabbing_selected = false
var _is_hovering_selected = false
var _last_non_zero_movement_dir = Vector3()
var _movement_dir = Vector3()
var _movement_speed = 0.0
var _piece_mouse_is_over: Piece = null
var _right_click_pos = Vector2()
var _rotation = Vector2()
var _selected_pieces = []

func append_selected_pieces(pieces: Array) -> void:
	for piece in pieces:
		if piece is Piece and (not piece in _selected_pieces):
			_selected_pieces.append(piece)
			piece.set_appear_selected(true)

func clear_selected_pieces() -> void:
	for piece in _selected_pieces:
		piece.set_appear_selected(false)
	
	_selected_pieces.clear()

func erase_selected_pieces(piece: Piece) -> void:
	if _selected_pieces.has(piece):
		_selected_pieces.erase(piece)
		piece.set_appear_selected(false)

func get_hover_position() -> Vector3:
	return _calculate_hover_position(get_viewport().get_mouse_position())

func get_selected_pieces() -> Array:
	return _selected_pieces

func set_is_hovering(is_hovering: bool) -> void:
	_is_hovering_selected = is_hovering

func set_selected_pieces(pieces: Array) -> void:
	clear_selected_pieces()
	append_selected_pieces(pieces)

func _ready():
	
	# Get the current rotation so we can get our _rotation accumulator set up
	# no matter how the camera is initially positioned.
	_rotation = Vector2(rotation.y, rotation.x)

func _process(delta):
	if _is_grabbing_selected:
		_grabbing_time += delta
		
		# Have we been grabbing this piece for a long time?
		if _grabbing_time > GRABBING_SLOW_TIME:
			_start_hovering_grabbed_piece(false)
	
	if _is_hovering_selected:
		if Input.is_action_just_pressed("game_flip"):
			for piece in _selected_pieces:
				piece.rpc_id(1, "flip_vertically")
		elif Input.is_action_just_pressed("game_reset"):
			for piece in _selected_pieces:
				piece.rpc_id(1, "reset_orientation")

func _physics_process(delta):
	_process_input(delta)
	_process_movement(delta)
	
	# Perform a raycast out into the world from the camera.
	var mouse_pos = get_viewport().get_mouse_position()
	var from = _camera.project_ray_origin(mouse_pos)
	var to = from + _camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	
	var space_state = get_world().direct_space_state
	var result = space_state.intersect_ray(from, to)
	
	_piece_mouse_is_over = null
	
	# Was the thing that collided a game piece?
	if result.has("collider"):
		if result.collider is Piece:
			_piece_mouse_is_over = result.collider

func _process_input(delta):
	
	# Calculating the direction the user wants to move parallel to the table.
	var movement_input = Vector2()
	
	if Input.is_action_pressed("game_left"):
		movement_input.x -= 1
	if Input.is_action_pressed("game_right"):
		movement_input.x += 1
	if Input.is_action_pressed("game_up"):
		movement_input.y += 1
	if Input.is_action_pressed("game_down"):
		movement_input.y -= 1
	
	movement_input = movement_input.normalized()
	
	_movement_dir = Vector3()
	
	# Moving side-to-side is fine, since the x basis should always be parallel
	# to the table...
	_movement_dir += transform.basis.x * movement_input.x
	
	# ... but we want to move forward along the horizontal plane parallel to
	# the table, and since we can move the camera to be looking at the table,
	# we need to adjust the z basis here.
	var z_basis = transform.basis.z
	z_basis.y = 0
	z_basis = z_basis.normalized()
	_movement_dir += -z_basis * movement_input.y
	
	var is_accelerating = not (movement_input.x == 0 and movement_input.y == 0)
	
	# Keep track of the latest non-zero movement direction so that if we slow
	# down, we keep slowing down in the direction we were going.
	if is_accelerating:
		_last_non_zero_movement_dir = _movement_dir
	
	# Calculating the speed of the movement parallel to the table.
	if is_accelerating:
		_movement_speed += MOVEMENT_ACCEL
		_movement_speed = min(_movement_speed, MOVEMENT_MAX_SPEED)
	else:
		_movement_speed -= MOVEMENT_DECEL
		_movement_speed = max(_movement_speed, 0.0)

func _process_movement(delta):
	# A global translation, as we want to move on the plane parallel to the
	# table, regardless of the direction we are facing.
	var old_translation = translation
	translation += _last_non_zero_movement_dir * _movement_speed * delta
	
	# If we ended up moving...
	if translation != old_translation:
		_start_moving()

func _unhandled_input(event):
	if event is InputEventMouseButton:
		
		if event.button_index == BUTTON_LEFT:
			if event.is_pressed():
				if _piece_mouse_is_over:
					if event.control:
						append_selected_pieces([_piece_mouse_is_over])
					else:
						set_selected_pieces([_piece_mouse_is_over])
						_is_grabbing_selected = true
						_grabbing_time = 0.0
				else:
					clear_selected_pieces()
			else:
				_is_grabbing_selected = false
				
				if _is_hovering_selected:
					for piece in _selected_pieces:
						piece.rpc_id(1, "stop_hovering")
						
						if piece is Card:
							emit_signal("stopped_hovering_card", piece)
					
					_is_hovering_selected = false
		
		elif event.button_index == BUTTON_RIGHT:
			# Only bring up the context menu if the mouse didn't move between
			# the press and the release of the RMB.
			if event.is_pressed():
				if _piece_mouse_is_over:
					set_selected_pieces([_piece_mouse_is_over])
				else:
					clear_selected_pieces()
				_right_click_pos = event.position
			else:
				if event.position == _right_click_pos:
					emit_signal("pieces_context_menu_requested", _selected_pieces)
		
		elif event.is_pressed() and (event.button_index == BUTTON_WHEEL_UP or
			event.button_index == BUTTON_WHEEL_DOWN):
		
			# Zooming the camera in and away from the controller.
			# TODO: Implement smooth zooming.
			var offset = 0
			
			if event.button_index == BUTTON_WHEEL_UP:
				offset = -ZOOM_AMOUNT
			else:
				offset = ZOOM_AMOUNT
			
			var distance = _camera.translation.z
			
			if distance + offset > ZOOM_DISTANCE_MAX:
				offset = ZOOM_DISTANCE_MAX - distance
			if distance + offset < ZOOM_DISTANCE_MIN:
				offset = ZOOM_DISTANCE_MIN - distance
			
			_camera.translate(Vector3(0, 0, offset))
			
			get_tree().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		
		# Check if by moving the mouse, we either started hovering a piece, or
		# we have moved the hovered pieces position.
		if _start_moving():
			pass
		
		elif Input.is_action_pressed("game_rotate"):
		
			# Rotating the controller-camera system to get the camera to rotate
			# around a point, where the controller is.
			_rotation.x += event.relative.x * ROTATION_SENSITIVITY
			_rotation.y += event.relative.y * ROTATION_SENSITIVITY
			
			# Bound the rotation along the X axis.
			_rotation.y = max(_rotation.y, ROTATION_Y_MIN)
			_rotation.y = min(_rotation.y, ROTATION_Y_MAX)
			
			transform.basis = Basis()
			rotate_x(_rotation.y)
			rotate_y(_rotation.x)
			
			get_tree().set_input_as_handled()

func _calculate_hover_position(mouse_position: Vector2) -> Vector3:
	# Get vectors representing a raycast from the camera.
	var from = _camera.project_ray_origin(mouse_position)
	var to = from + _camera.project_ray_normal(mouse_position) * RAY_LENGTH
	
	# Figure out at which point along this line the piece should hover at,
	# given we want it to hover at a particular Y-level.
	var lambda = (HOVER_Y_LEVEL - from.y) / (to.y - from.y)
	
	var x = from.x + lambda * (to.x - from.x)
	var z = from.z + lambda * (to.z - from.z)
	
	return Vector3(x, HOVER_Y_LEVEL, z)

func _start_hovering_grabbed_piece(fast: bool) -> void:
	if _is_grabbing_selected:
		# NOTE: The server might not accept our request to hover a particular
		# piece, so we'll clear the list of selected pieces, and add the pieces
		# that are accepted back in to the list. For this reason, we'll need to
		# make a copy of the list.
		var selected = []
		for piece in _selected_pieces:
			selected.append(piece)
		
		clear_selected_pieces()
		
		for piece in selected:
			if selected.size() == 1 and piece is Stack and fast:
				emit_signal("pop_stack_requested", piece)
			else:
				emit_signal("hover_piece_requested", piece)
		
		_is_grabbing_selected = false

func _start_moving() -> bool:
	# If we were grabbing a piece while moving...
	if _is_grabbing_selected:
		
		# ... then send out a signal to start hovering the piece fast.
		_start_hovering_grabbed_piece(true)
		return true
	
	# Or if we were hovering a piece already...
	if _is_hovering_selected:
		
		# ... then send out a signal with the new hover position.
		for piece in _selected_pieces:
			piece.rpc_unreliable_id(1, "set_hover_position", get_hover_position())
		return true
	
	return false
