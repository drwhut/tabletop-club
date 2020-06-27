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

const MOVEMENT_ACCEL = 0.1
const MOVEMENT_DECEL = 0.3
const MOVEMENT_MAX_SPEED = 3.0
const ROTATION_SENSITIVITY = -0.01
const ROTATION_Y_MAX = -0.1
const ROTATION_Y_MIN = -1.3
const ZOOM_AMOUNT = 0.25
const ZOOM_DISTANCE_MIN = 0.1
const ZOOM_DISTANCE_MAX = 10.0

var _last_non_zero_movement_dir: Vector3
var _movement_dir: Vector3
var _movement_speed = 0.0
var _rotation: Vector2

func _ready():
	
	# Get the current rotation so we can get our _rotation accumulator set up
	# no matter how the camera is initially positioned.
	_rotation = Vector2(rotation.y, rotation.x)

func _physics_process(delta):
	_process_input(delta)
	_process_movement(delta)

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
	translation += _last_non_zero_movement_dir * _movement_speed * delta

func _unhandled_input(event):
	if event is InputEventMouseButton and event.is_pressed():
		
		# Zooming the camera in and away from the controller.
		# TODO: Implement smooth zooming.
		var offset = 0
		
		if event.button_index == BUTTON_WHEEL_UP:
			offset = -ZOOM_AMOUNT
		elif event.button_index == BUTTON_WHEEL_DOWN:
			offset = ZOOM_AMOUNT
			
		var distance = _camera.translation.z
		
		if distance + offset > ZOOM_DISTANCE_MAX:
			offset = ZOOM_DISTANCE_MAX - distance
		if distance + offset < ZOOM_DISTANCE_MIN:
			offset = ZOOM_DISTANCE_MIN - distance
		
		_camera.translate(Vector3(0, 0, offset))
	
	elif event is InputEventMouseMotion and Input.is_action_pressed("game_rotate"):
		
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
