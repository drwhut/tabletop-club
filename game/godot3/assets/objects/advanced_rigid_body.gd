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


## A structure used internally to store shapes and transforms pre-scale.
class MeshData:
	extends Reference
	
	var shape: Shape = null
	var transform := Transform.IDENTITY


# A dictionary which saves the original albedo colour for each of the scene's
# materials.
var _original_albedo_map := {}

# A flag which states if the original albedo colours have been saved.
var _original_albedo_saved := false

# The last set value for the user albedo. By default, all scenes start off with
# a user albedo of pure white.
var _last_user_albedo := Color.white

# An array of original mesh data for each of the scene's collision shapes.
var _original_mesh_data_arr := []

# A flag which states if the original mesh data has been saved.
var _original_mesh_data_saved := false

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
	if new_scale.is_equal_approx(_last_user_scale):
		return
	
	var collision_shape_arr := get_collision_shapes()
	if collision_shape_arr.empty():
		return
	
	var initial_mesh_data_arr := _get_original_mesh_data_arr()
	if collision_shape_arr.size() != initial_mesh_data_arr.size():
		push_error("Number of collision shapes '%d' does not match number of initial transforms '%d'" % [
				collision_shape_arr.size(), initial_mesh_data_arr.size()])
		return
	
	for index in range(collision_shape_arr.size()):
		var collision_shape: CollisionShape = collision_shape_arr[index]
		var initial_mesh_data: MeshData = initial_mesh_data_arr[index]
		
		# Scale the collision shape's internal shape, NOT the collision shape
		# itself. Scaling the collision shape causes weird issues.
		var new_shape := ShapeUtil.scale_shape(initial_mesh_data.shape,
				new_scale)
		if new_shape != null:
			collision_shape.shape = new_shape
		
		# The mesh's translation is stored in the collision shape (in the event
		# that the centre-of-mass is changed).
		var new_origin := new_scale * initial_mesh_data.transform.origin
		collision_shape.transform.origin = new_origin
		
		# If the mesh instance exists for this collision shape, then give it
		# the new scaled basis.
		if collision_shape.get_child_count() > 0:
			var mesh_instance: MeshInstance = collision_shape.get_child(0)
			var new_basis := initial_mesh_data.transform.basis.scaled(new_scale)
			mesh_instance.transform.basis = new_basis
	
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


# Get the original mesh data for each of this body's collision shapes.
# The first time this function is called, the results are saved in the event
# that either the shape or transforms are changed.
# TODO: Make typed in 4.x
func _get_original_mesh_data_arr() -> Array:
	if not _original_mesh_data_saved:
		_original_mesh_data_arr = []
		for element in get_collision_shapes():
			var collision_shape: CollisionShape = element
			var mesh_data := MeshData.new()
			
			# The collision shape includes the mesh's translation, as well as
			# the shape itself.
			mesh_data.shape = collision_shape.shape
			mesh_data.transform.origin = collision_shape.transform.origin
			
			# The mesh instance (if it exists) contains the rotation and scale
			# for the mesh. It doesn't matter if the mesh instance does not
			# exist, since this data has already been embedded into the shape
			# (see ObjectBuilder).
			if collision_shape.get_child_count() > 0:
				var mesh_instance: MeshInstance = collision_shape.get_child(0)
				mesh_data.transform.basis = mesh_instance.transform.basis
			
			_original_mesh_data_arr.push_back(mesh_data)
		
		_original_mesh_data_saved = true
	
	return _original_mesh_data_arr
