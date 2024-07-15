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

class_name AdvancedRigidBody3D
extends RigidBody

## A [RigidBody] with more features, given a few constraints.
##
## This class assumes that there is one or more [CollisionShape] children, and
## that each of those children have exactly zero or one [MeshInstance] children.
## It also assumes that all [SpatialMaterial] used by the mesh instances are
## assigned to the [MeshInstance], not the [Mesh] inside.
##
## [b]NOTE:[/b] This class also assumes that the node structure of the children
## does not change throughout the game.
## [b]TODO:[/b] Test this class fully once it is complete.


# A dictionary which saves the original albedo colour for each of the scene's
# materials.
var _original_albedo_map := {}

# A flag which states if the original albedo colours have been saved.
var _original_albedo_saved := false

# The last set value for the user albedo. By default, all scenes start off with
# a user albedo of pure white.
var _last_user_albedo := Color.white

# An array of transforms for each of the scene's collision shapes.
var _original_transform_arr := []

# A flag which states if the original transforms have been saved.
var _original_transform_saved := false

# The last set value for the user scale. By default, all scenes start off with
# a user scale of (1, 1, 1).
var _last_user_scale := Vector3.ONE


## Get the list of [CollisionShape] nodes that this rigid body uses.
## TODO: Make typed in 4.x
func get_collision_shapes() -> Array:
	var out := []
	
	for child in get_children():
		if child is CollisionShape:
			out.push_back(child)
	
	return out


## Get the list of [MeshInstance] nodes that this rigid body uses.
## TODO: Make typed in 4.x
func get_mesh_instances() -> Array:
	var out := []
	
	for element in get_collision_shapes():
		var collision_shape: CollisionShape = element
		for child in collision_shape.get_children():
			if child is MeshInstance:
				out.push_back(child)
	
	return out


## Get the list of [SpatialMaterial] used by the various meshes this rigid body
## uses. Note that the list does not include the outline materials by
## themselves, but they can still be accessed via the [code]next_pass[/code]
## property.
## TODO: Make typed in 4.x
func get_materials() -> Array:
	var out := []
	
	for element in get_mesh_instances():
		var mesh_instance: MeshInstance = element
		for surface in range(mesh_instance.get_surface_material_count()):
			var material = mesh_instance.get_surface_material(surface)
			if material is SpatialMaterial:
				out.push_back(material)
	
	return out


## Get the custom albedo colour applied to this body by the player.
func get_user_albedo() -> Color:
	return _last_user_albedo


## Set the custom albedo colour applied to this body.
func set_user_albedo(new_albedo: Color) -> void:
	var initial_albedo_map := _get_original_albedo_map()
	if initial_albedo_map.empty():
		return
	
	for key in initial_albedo_map:
		var material: SpatialMaterial = key
		var initial_albedo: Color = initial_albedo_map[material]
		
		material.albedo_color = initial_albedo * new_albedo
	
	_last_user_albedo = new_albedo


## Get the custom scale applied to this body.
func get_user_scale() -> Vector3:
	return _last_user_scale


## Set the custom scale applied to this body.
func set_user_scale(new_scale: Vector3) -> void:
	var collision_shape_arr := get_collision_shapes()
	if collision_shape_arr.empty():
		return
	
	var initial_transform_arr := _get_original_transform_arr()
	if collision_shape_arr.size() != initial_transform_arr.size():
		push_error("Number of collision shapes '%d' does not match number of initial transforms '%d'" % [
				collision_shape_arr.size(), initial_transform_arr.size()])
		return
	
	for index in range(collision_shape_arr.size()):
		var collision_shape: CollisionShape = collision_shape_arr[index]
		var initial_transform: Transform = initial_transform_arr[index]
		
		collision_shape.transform = initial_transform.scaled(new_scale)
	
	_last_user_scale = new_scale
	
	reset_physics_interpolation()


# Get the original albedo colours assigned to the materials that belong to this
# rigid body. The first time this function is called, the results are saved in
# the event that the albedo colours are changed.
func _get_original_albedo_map() -> Dictionary:
	if not _original_albedo_saved:
		_original_albedo_map = {}
		for element in get_materials():
			var material: SpatialMaterial = element
			_original_albedo_map[material] = material.albedo_color
		
		_original_albedo_saved = true
	
	return _original_albedo_map


# Get the original transforms assigned to each of this body's collision shapes.
# The first time this function is called, the results are saved in the event
# that the transforms are changed.
# TODO: Make typed in 4.x
func _get_original_transform_arr() -> Array:
	if not _original_transform_saved:
		_original_transform_arr = []
		for element in get_collision_shapes():
			var collision_shape: CollisionShape = element
			_original_transform_arr.push_back(collision_shape.transform)
		
		_original_transform_saved = true
	
	return _original_transform_arr
