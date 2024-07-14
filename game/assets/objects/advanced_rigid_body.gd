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


# The list of albedo colours corresponding to each of the scene's materials.
# NOTE: This system assumes that the node structure does not change through the
# course of play.
var _original_albedo_arr := []

# A flag which determines if we can safely read _original_albedo_arr.
var _original_albedo_saved := false

# The list of transforms corresponding to each of the scene's collision shapes.
# NOTE: This system assumes that the node structure does not change through the
# course of play.
var _original_transform_arr := []

# A flag which determines if we can safely read _original_transform_arr.
var _original_transform_saved := false


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
	var material_arr := get_materials()
	if material_arr.empty():
		return Color.white
	
	var first_material: SpatialMaterial = material_arr[0]
	var initial_albedo_arr := _get_original_albedo_arr()
	if initial_albedo_arr.empty():
		return Color.white
	
	# We don't want to get just the current albedo, instead we want to get the
	# current colour in relation to the material's original colour.
	var initial_color: Color = initial_albedo_arr[0]
	var current_color := first_material.albedo_color
	
	var r := 1.0 if is_zero_approx(initial_color.r) else \
			current_color.r / initial_color.r
	var g := 1.0 if is_zero_approx(initial_color.g) else \
			current_color.g / initial_color.g
	var b := 1.0 if is_zero_approx(initial_color.b) else \
			current_color.b / initial_color.b
	
	r = min(max(0.0, r), 1.0)
	g = min(max(0.0, g), 1.0)
	b = min(max(0.0, b), 1.0)
	
	return Color(r, g, b)


## Set the custom albedo colour applied to this body.
func set_user_albedo(new_albedo: Color) -> void:
	var material_arr := get_materials()
	var initial_albedo_arr := _get_original_albedo_arr()
	
	if material_arr.size() != initial_albedo_arr.size():
		push_error("Number of materials '%d' does not match number of initial albedo colours '%d'" % [
				material_arr.size(), initial_albedo_arr.size()])
		return
	
	for index in range(material_arr.size()):
		var material: SpatialMaterial = material_arr[index]
		var initial_albedo: Color = initial_albedo_arr[index]
		
		material.albedo_color = initial_albedo * new_albedo


## Get the custom scale applied to this body.
func get_user_scale() -> Vector3:
	var collision_shape_arr := get_collision_shapes()
	if collision_shape_arr.empty():
		return Vector3.ONE
	
	var first_collision_shape: CollisionShape = collision_shape_arr[0]
	var initial_transform_arr := _get_original_transform_arr()
	if initial_transform_arr.empty():
		return Vector3.ONE
	
	# The custom scale should have been set for all collision shapes, so it
	# doesn't matter which collision shape we use, so we'll use the first one.
	# NOTE: We don't want to return just the current scale, we need to return
	# the scale RELATIVE to the initial scale.
	var first_initial_transform: Transform = initial_transform_arr[0]
	var first_current_transform: Transform = first_collision_shape.transform
	
	# TODO: If the collision shape is rotated in a different direction to the
	# rigid body, then get_scale() can give unexpected results... for example,
	# this is the case with the Red Cup container.
	# Try and find a way to make this step more consistent, whilst also
	# respecting whatever scale was saved in v0.1.x save files.
	# NOTE: It could be that we are scaling the transform wrong in
	# set_user_scale()! Although, we want to make sure that the position is
	# adjusted correctly there still.
	var initial_scale := first_initial_transform.basis.get_scale()
	var current_scale := first_current_transform.basis.get_scale()
	
	var x := 1.0 if is_zero_approx(initial_scale.x) else \
			current_scale.x / initial_scale.x
	var y := 1.0 if is_zero_approx(initial_scale.y) else \
			current_scale.y / initial_scale.y
	var z := 1.0 if is_zero_approx(initial_scale.z) else \
			current_scale.z / initial_scale.z
	
	return Vector3(x, y, z)


## Set the custom scale applied to this body.
func set_user_scale(new_scale: Vector3) -> void:
	var collision_shape_arr := get_collision_shapes()
	var initial_transform_arr := _get_original_transform_arr()
	
	if collision_shape_arr.size() != initial_transform_arr.size():
		push_error("Number of collision shapes '%d' does not match number of initial transforms '%d'" % [
				collision_shape_arr.size(), initial_transform_arr.size()])
		return
	
	for index in range(collision_shape_arr.size()):
		var collision_shape: CollisionShape = collision_shape_arr[index]
		var initial_transform: Transform = initial_transform_arr[index]
		
		collision_shape.transform = initial_transform.scaled(new_scale)
	
	reset_physics_interpolation()


# Get the original albedo colours assigned to the materials that belong to this
# rigid body. The first time this function is called, the results are saved in
# the event that the albedo colours are changed.
func _get_original_albedo_arr() -> Array:
	if not _original_albedo_saved:
		_original_albedo_arr = []
		for element in get_materials():
			var material: SpatialMaterial = element
			_original_albedo_arr.push_back(material.albedo_color)
		
		_original_albedo_saved = true
	
	return _original_albedo_arr


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
