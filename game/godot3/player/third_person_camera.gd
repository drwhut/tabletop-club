# tabletop-club
# Copyright (c) 2020-2024 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2024 Tabletop Club contributors (see game/CREDITS.tres).
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

extends CameraController

## The third-person camera, which is the default control scheme.


## How fast the camera accelerates as a ratio of the maximum speed.
const MOVEMENT_ACCEL_SCALAR := 0.125

## How fast the camera decelerates as a ratio of the maximum speed.
const MOVEMENT_DECEL_SCALAR := 0.25

## The maximum rotation of the camera on the vertical axis in radians.
const ROTATION_Y_MAX := -0.2

## The minimum rotation of the camera on the vertical axis in radians.
const ROTATION_Y_MIN := -1.5

## How fast the camera should zoom relative to the sensitivity.
const ZOOM_ACCEL_SCALAR := 3.0

## How far the near plane of the camera should be relative to the zoom.
const ZOOM_CAMERA_NEAR_SCALAR := 0.01

## How much continuous scroll actions (i.e. via the keyboard or controller)
## should be scaled by in order to match the amount of zoom caused when using
## the scroll wheel.
const ZOOM_SCROLL_ACTION_SCALAR := 15.0


## The maximum linear speed the camera can travel at.
export(float) var max_speed := 10.0

## How fast the camera zooms towards and away from the table.
export(float) var zoom_sensitivity := 1.0

## How far away the camera is initially from the surface of the table.
export(float) var initial_zoom := 10.0

## The maximum distance the camera can be from the table.
export(float) var max_zoom := 100.0

## The minimum distance the camera can be from the table.
export(float) var min_zoom := 1.0

## The initial rotation on the horizontal and vertical axis in radians.
export(Vector2) var initial_rotation := Vector2(0.0, -PI/4)

## How fast the camera rotates on the horizontal axis.
export(float) var rotation_sensitivity_x := -0.01

## How fast the camera rotates on the vertical axis.
export(float) var rotation_sensitivity_y := -0.01


# The current linear velocity of the camera parallel to the table.
var _movement_velocity := Vector3.ZERO

# The current horizontal and vertical rotation of the camera in radians.
var _current_rotation := Vector2.ZERO

# How far the camera should be from the spatial node.
var _target_zoom := 0.0

# Has the player moved the mouse since wanting to rotate the camera?
var _has_mouse_moved_during_rotate := false


onready var _camera: Camera = $Camera


func _ready():
	# NOTE: When the first person camera is added, we will need to apply the
	# game config on initialisation, since the switch between first and third
	# person will be able to happen outside of the options being applied.
	GameConfig.connect("applying_settings", self, "apply_options")
	
	reset_transform()


func _process(delta: float):
	_process_movement(delta)
	_process_rotation(delta)
	_process_zoom(delta)


func _input(event: InputEvent):
	if event.is_action_pressed("game_rotate"):
		_has_mouse_moved_during_rotate = false


func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("game_rotate"):
			# TODO: Ideally should not be affected if resolution changes.
			# TODO: Ensure cursor wraps around the window:
			#     Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_adjust_rotation(event.relative)
			get_tree().set_input_as_handled()
			
			_has_mouse_moved_during_rotate = true
	
	elif event is InputEventMouseButton:
		if event.is_action_pressed("game_zoom_in", false):
			_adjust_zoom(-1.0)
			get_tree().set_input_as_handled()
		elif event.is_action_pressed("game_zoom_out", false):
			_adjust_zoom(1.0)
			get_tree().set_input_as_handled()
	
	elif event is InputEventPanGesture:
		_adjust_zoom(event.delta.y)
		get_tree().set_input_as_handled()


func get_camera() -> Camera:
	return _camera


func is_using_mouse() -> bool:
	return _has_mouse_moved_during_rotate and Input.is_action_pressed("game_rotate")


func reset_transform() -> void:
	transform.origin = Vector3.ZERO
	
	_current_rotation = initial_rotation
	_apply_rotation()
	
	_camera.translation.z = initial_zoom
	_target_zoom = initial_zoom


## Apply the options given by the [GameConfig] to this camera.
## TODO: Determine if we should test this function.
func apply_options() -> void:
	rotation_sensitivity_x = -0.1 * GameConfig.control_horizontal_sensitivity
	if GameConfig.control_horizontal_invert:
		rotation_sensitivity_x *= -1.0
	
	rotation_sensitivity_y = -0.1 * GameConfig.control_vertical_sensitivity
	if GameConfig.control_vertical_invert:
		rotation_sensitivity_y *= -1.0
	
	max_speed = 10.0 + 190.0 * GameConfig.control_camera_movement_speed
	
	zoom_sensitivity = 1.0 + 15.0 * GameConfig.control_zoom_sensitivity
	if GameConfig.control_zoom_invert:
		zoom_sensitivity *= -1.0
	
	_camera.fov = GameConfig.video_fov


# Read player input and adjust the position of the camera accordingly.
func _process_movement(delta: float) -> void:
	var movement_input := Vector2.ZERO
	if not (ignore_key_events or Input.is_physical_key_pressed(KEY_CONTROL)):
		movement_input = Input.get_vector("game_left", "game_right",
				"game_down", "game_up")
	
	# Moving left/right is trivial, since the x-basis should always be parallel
	# to the table...
	var movement_dir := movement_input.x * transform.basis.x
	
	# ... but since the camera can be rotated such that the z-basis goes through
	# the table, we need to manually create a new basis from it that is parallel
	# to it instead.
	var new_z_basis := -transform.basis.z
	new_z_basis.y = 0.0
	new_z_basis = new_z_basis.normalized()
	movement_dir += movement_input.y * new_z_basis
	
	var movement_accel := max_speed
	if movement_dir.dot(_movement_velocity) > 0.0:
		movement_accel *= MOVEMENT_ACCEL_SCALAR
	else:
		movement_accel *= MOVEMENT_DECEL_SCALAR
	
	var target_velocity := max_speed * movement_dir
	var delta_velocity := clamp(delta * movement_accel, 0.0, 1.0)
	_movement_velocity = _movement_velocity.linear_interpolate(target_velocity,
			delta_velocity)
	
	# Translate the controller in global space, as we want to move parallel to
	# the table regardless of the orientation of the camera.
	translation += delta * _movement_velocity


# Read player input and adjust the rotation of the camera accordingly.
func _process_rotation(delta: float) -> void:
	# TODO: Add the ability to invert directions here? Or use sensitivity?
	var rotate_input := Vector2.ZERO
	if not ignore_key_events:
		rotate_input = Input.get_vector("game_rotate_left", "game_rotate_right",
				"game_rotate_down", "game_rotate_up")
	
	# TODO: Replace 200.0 with a constant or consistent variable, once the way
	# rotation input is read in has changed.
	_adjust_rotation(200.0 * delta * rotate_input)


# Read player input and adjust how far the camera is from the table accordingly.
func _process_zoom(delta: float) -> void:
	# As well as receiving discrete scroll wheel events in _unhandled_input(),
	# also receive continuous inputs from both the keyboard and the controller
	# every frame in this function.
	var scroll_input := 0.0
	if not ignore_key_events:
		scroll_input -= Input.get_action_strength("game_zoom_in")
		scroll_input += Input.get_action_strength("game_zoom_out")
	_adjust_zoom(ZOOM_SCROLL_ACTION_SCALAR * delta * scroll_input)
	
	# Go towards the target zoom level.
	var target_offset = Vector3(0, 0, _target_zoom)
	var zoom_accel = abs(zoom_sensitivity) * ZOOM_ACCEL_SCALAR
	var zoom_delta = clamp(zoom_accel * delta, 0.0, 1.0)
	_camera.translation = _camera.translation.linear_interpolate(target_offset,
			zoom_delta)
	
	# Adjust the near value of the camera based on how far away the camera is
	# from the table. If the camera is really far away, it probably won't have
	# anything directly in front of it, so we can make the depth buffer more
	# accurate by having it cover a smaller area.
	_camera.near = clamp(ZOOM_CAMERA_NEAR_SCALAR * _target_zoom, 0.05, 2.0)


# Change the rotation of the camera using a relative delta vector.
func _adjust_rotation(relative: Vector2) -> void:
	_current_rotation.x += relative.x * rotation_sensitivity_x
	_current_rotation.y += relative.y * rotation_sensitivity_y
	
	_current_rotation.y = max(_current_rotation.y, ROTATION_Y_MIN)
	_current_rotation.y = min(_current_rotation.y, ROTATION_Y_MAX)
	
	_apply_rotation()


# Set the rotation using the current value of _current_rotation.
func _apply_rotation() -> void:
	transform.basis = Basis.IDENTITY
	rotate_x(_current_rotation.y)
	rotate_y(_current_rotation.x)


# Change how far away the camera is from the table, given an input delta.
func _adjust_zoom(delta: float) -> void:
	var new_zoom = _target_zoom + (zoom_sensitivity * delta)
	_target_zoom = max(min(new_zoom, max_zoom), min_zoom)
