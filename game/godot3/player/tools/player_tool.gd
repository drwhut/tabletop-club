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

class_name PlayerTool
extends Spatial

## Base class for tools that can be used by the player to perform actions.


## The maximum distance of raycasts.
const RAY_LENGTH = 1000.0


## A reference to the camera currently being used by the player.
## [b]NOTE:[/b] This should be set as soon as possible.
var camera: Camera = null

## The [Area] that the cursor is currently over, or [code]null[/code] if it is
## not currently over an area, or the ray was not configured to detect areas.
var cursor_over_area: Area = null setget set_cursor_over_area, get_cursor_over_area

## The [RigidBody] that the cursor is currently over, or [code]null[/code] if it
## is not currently over a [RigidBody], or the ray was not configured to detect
## them.
var cursor_over_body: RigidBody = null setget set_cursor_over_body, \
		get_cursor_over_body

## Does the ray cast by the cursor intersect the y=0 plane?
var cursor_over_plane := true setget set_cursor_over_plane

## The 3D position of the cursor.
## [b]NOTE:[/b] Depending on the mask that was used in [method perform_raycast],
## the position might not be visible, that is, if it is behind a piece that was
## not detected by the ray.
## [b]NOTE:[/b] If the ray did not intersect anything (that is, if
## [member cursor_over_body] is [code]false[/code]), then the position will be
## where the ray intersects the y=0 plane.
var cursor_world_position := Vector3.ZERO setget set_cursor_world_position

## Is the tool currently being used by the player?
var enabled: bool setget set_enabled, is_enabled


## Perform a raycast from the cursor's position on the screen to the game world.
##
## The results of the raycast will be set to this tool's global variables.
##
## A collision mask is passed to specify what type of objects should be detected
## by the ray - this will vary depending on the tool. You can also make it so
## that only areas are detected by the ray, which can be helpful if the tool
## should only interact with hidden areas.
##
## [b]NOTE:[/b] [member camera] must be set before using this function, and it
## must be used within [method _physics_process].
func perform_raycast(mask: int, detect_bodies: bool, detect_areas: bool) -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_from := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	
	var result := {}
	
	# Don't bother performing the raycast if we aren't trying to detect either
	# bodies or areas.
	if detect_bodies or detect_areas:
		var ray_to := ray_from + ray_dir * RAY_LENGTH
		
		var space_state := get_world().direct_space_state
		result = space_state.intersect_ray(ray_from, ray_to, [], mask,
				detect_bodies, detect_areas)
	
	cursor_over_area = null
	cursor_over_body = null
	cursor_over_plane = (ray_dir.y < -0.00001) # Epsilon value used in engine.
	
	# If the ray did not intersect anything, then we at least want to figure out
	# where the ray intersects the y=0 plane, if at all.
	if result.empty():
		if not cursor_over_plane:
			return
		
		var k := -ray_from.y / ray_dir.y
		cursor_world_position = ray_from + ray_dir * k
		return
	
	var collided_with = result["collider"]
	if collided_with is RigidBody:
		cursor_over_body = collided_with
	elif collided_with is Area:
		cursor_over_area = collided_with
	else:
		push_warning("Unexpected collider: %s" + str(collided_with))
	
	cursor_world_position = result["position"]


func get_cursor_over_area() -> Area:
	# TODO: Consider other safeguards we want to have in place.
	if cursor_over_area != null:
		if cursor_over_area.is_queued_for_deletion():
			return null
	
	return cursor_over_area


func get_cursor_over_body() -> RigidBody:
	if cursor_over_body != null:
		if cursor_over_body.is_queued_for_deletion():
			return null
	
	return cursor_over_body


func is_enabled() -> bool:
	return is_processing()


# Don't use values given from the outside world.
func set_cursor_over_area(_value: Area) -> void:
	return


# Don't use values given from the outside world.
func set_cursor_over_body(_value: RigidBody) -> void:
	return


# Don't use values given from the outside world.
func set_cursor_over_plane(_value: bool) -> void:
	return


# Don't use values given from the outside world.
func set_cursor_world_position(_value: Vector3) -> void:
	return


func set_enabled(value: bool) -> void:
	set_physics_process(value)
	set_process(value)
	set_process_input(value)
	set_process_unhandled_input(value)
	set_process_unhandled_key_input(value)
