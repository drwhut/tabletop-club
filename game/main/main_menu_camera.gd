# tabletop-club
# Copyright (c) 2020-2023 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2023 Tabletop Club contributors (see game/CREDITS.tres).
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

class_name MainMenuCamera
extends Camera

## A cinematic camera used to show the room when the main menu is active.


## Defines what state the camera is in, which determines what it does.
enum CameraState {
	STATE_ORBIT,           ## Orbiting around the centre of the room.
	STATE_ORBIT_TO_PLAYER, ## Transitioning to the player camera.
	STATE_PLAYER,          ## Control has been given to the player controller.
	STATE_PLAYER_TO_ORBIT, ## Transitioning back into orbit.
	STATE_MAX,             ## Used for validation only.
}


## The height at which the camera orbits above the horizontal plane.
export(float) var orbit_height := 0.0

## The radius at which the camera orbits around the origin.
export(float) var orbit_radius := 1.0

## The speed at which the camera orbits around the origin.
export(float) var orbit_speed := 1.0

## The state the main menu camera is currently in.
export(CameraState) var state := CameraState.STATE_ORBIT setget set_state

## The amount of time transitions should take.
export(float) var transition_duration_sec := 1.0


## The camera to start going towards when we are no longer in orbit.
var camera_transition_to: Camera = null

# How much time has passed since the camera started moving.
var _time_passed_in_orbit := 0.0

# How much time has passed since the transition started.
var _time_passed_transitioning := 0.0

# The starting position during a transition.
var _init_position := Vector3.ZERO

# The starting rotation during a transition.
var _init_rotation := Basis.IDENTITY


func _process(delta: float):
	if state == CameraState.STATE_ORBIT or \
		state == CameraState.STATE_PLAYER_TO_ORBIT:
			_time_passed_in_orbit += delta
	
	if state == CameraState.STATE_ORBIT:
		transform = _get_orbit_transform(_time_passed_in_orbit)
	
	elif state == CameraState.STATE_ORBIT_TO_PLAYER or \
		state == CameraState.STATE_PLAYER_TO_ORBIT:
			_time_passed_transitioning += delta
			
			if _time_passed_transitioning > transition_duration_sec or \
				is_zero_approx(transition_duration_sec):
					if state == CameraState.STATE_ORBIT_TO_PLAYER:
						set_state(CameraState.STATE_PLAYER)
					else:
						set_state(CameraState.STATE_ORBIT)
					
					return
			
			var target := Transform.IDENTITY
			if state == CameraState.STATE_PLAYER_TO_ORBIT:
				target = _get_orbit_transform(_time_passed_in_orbit)
			
			elif camera_transition_to != null:
				target = camera_transition_to.global_transform
			
			var time_along_exp := 10.0 * _time_passed_transitioning / transition_duration_sec
			var lerp_weight := 1.0 - (1.0 / exp(time_along_exp))
			
			transform.basis = _init_rotation.slerp(target.basis, lerp_weight)
			transform.origin = _init_position.linear_interpolate(target.origin,
					lerp_weight)


func set_state(value: int) -> void:
	if value < 0 or value >= CameraState.STATE_MAX:
		push_error("Invalid value '%d' for CameraState" % value)
		return
	
	if camera_transition_to == null:
		push_error("Camera to transition towards has not been set")
		return
	
	state = value
	
	match state:
		CameraState.STATE_ORBIT:
			pass
		
		CameraState.STATE_ORBIT_TO_PLAYER:
			_time_passed_transitioning = 0.0
			_init_position = transform.origin
			_init_rotation = transform.basis
		
		CameraState.STATE_PLAYER:
			camera_transition_to.current = true
			printt(camera_transition_to.current, current)
		
		CameraState.STATE_PLAYER_TO_ORBIT:
			current = true
			_time_passed_in_orbit = 0.0
			_time_passed_transitioning = 0.0
			_init_position = camera_transition_to.global_translation
			_init_rotation = camera_transition_to.global_rotation
	
	# We don't need to do anything with the main menu camera if the player
	# controller is now active.
	set_process(state != CameraState.STATE_PLAYER)


# Get the transform the camera would have after a given number of seconds in
# orbit around the centre of the room.
func _get_orbit_transform(time_in_orbit: float) -> Transform:
	var angle := orbit_speed * time_in_orbit
	var position := orbit_radius * Vector3(sin(angle), 0.0, cos(angle))
	position.y = orbit_height
	
	var basis := Basis(Vector3.UP, angle)
	
	return Transform(basis, position)
