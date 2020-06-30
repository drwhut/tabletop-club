# OpenTabletop
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

onready var _camera = $Camera

const HOVER_Y_LEVEL = 1.0
const MOVEMENT_ACCEL = 0.1
const MOVEMENT_DECEL = 0.3
const MOVEMENT_MAX_SPEED = 3.0
const RAY_LENGTH = 1000
const ROTATION_SENSITIVITY = -0.01
const ROTATION_Y_MAX = -0.1
const ROTATION_Y_MIN = -1.3
const ZOOM_AMOUNT = 0.25
const ZOOM_DISTANCE_MIN = 0.1
const ZOOM_DISTANCE_MAX = 10.0

var _grab_piece_screen_position = null
var _last_non_zero_movement_dir = Vector3()
var _movement_dir = Vector3()
var _movement_speed = 0.0
var _piece_grabbed: Piece = null
var _rotation = Vector2()

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

func _ready():
	
	# Get the current rotation so we can get our _rotation accumulator set up
	# no matter how the camera is initially positioned.
	_rotation = Vector2(rotation.y, rotation.x)

func _process(delta):
	if Input.is_action_just_pressed("game_flip") and _piece_grabbed:
		_piece_grabbed.hover_up = -_piece_grabbed.hover_up

func _physics_process(delta):
	_process_input(delta)
	_process_movement(delta)
	
	if _grab_piece_screen_position:
		
		# Perform a raycast out into the world from the camera.
		var from = _camera.project_ray_origin(_grab_piece_screen_position)
		var to = from + _camera.project_ray_normal(_grab_piece_screen_position) * RAY_LENGTH
		
		var space_state = get_world().direct_space_state
		var result = space_state.intersect_ray(from, to)
		
		# Was the thing that collided a game piece? If so, we should grab it.
		if result.has("collider"):
			if result.collider is Piece:
				_piece_grabbed = result.collider
				_piece_grabbed.start_hovering()
				_piece_grabbed.hover_position = _calculate_hover_position(_grab_piece_screen_position)
		
		# Set back to null so we don't do the same calculation the next frame.
		_grab_piece_screen_position = null

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
	
	# If we ended up moving, and we are hovering a piece, move the pieces
	# hover position.
	if translation != old_translation and _piece_grabbed:
		var mouse_position = get_viewport().get_mouse_position()
		_piece_grabbed.hover_position = _calculate_hover_position(mouse_position)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		
		if event.button_index == BUTTON_LEFT:
			if event.is_pressed():
				_grab_piece_screen_position = event.position
			elif _piece_grabbed:
				_piece_grabbed.stop_hovering()
				_piece_grabbed = null
		
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
		
		if _piece_grabbed:
			
			# Set the hover position of the piece based on where the mouse is
			# pointed, such that it is hovering at a particular Y-level in
			# front of the mouse.
			_piece_grabbed.hover_position = _calculate_hover_position(event.position)
		
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
