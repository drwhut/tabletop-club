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

class_name PieceBuilder
extends Reference

## Used to build piece and table objects from their respective asset entries.
##
## TODO: Test this class once it is complete.


## Given a scene of nodes, extract all of the [MeshInstance] nodes out of the
## scene and return them in an array. The nodes are automatically removed from
## their parents, and each local transform is adjusted to be their original
## global transform.
## NOTE: [code]root_node[/code] is NOT checked as a [MeshInstance].
## TODO: Make typed in 4.x
func extract_mesh_instances(root_node: Node) -> Array:
	var output_arr := []
	_extract_mesh_instances_recursive(root_node, Transform.IDENTITY, output_arr)
	return output_arr


## Given a [MeshInstance], set up its materials so that each instance of them is
## unique, which allows us to modify each material separately.
func setup_materials(mesh_instance: MeshInstance) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		push_error("Mesh instance '%s' does not contain a mesh" % mesh_instance.name)
		return
	
	var num_surfaces := mesh.get_surface_count()
	for surface_index in range(num_surfaces):
		var material := mesh_instance.get_active_material(surface_index)
		if material == null:
			continue
		
		var unique_material := material.duplicate()
		
		# There seems to be a bug in OSX where the default cull mode inverts the
		# normals of the mesh.
		# See: https://github.com/godotengine/godot/issues/39936
		if OS.get_name() == "OSX":
			if material is SpatialMaterial:
				material.params_cull_mode = SpatialMaterial.CULL_BACK
		
		mesh_instance.set_surface_material(surface_index, unique_material)


## Given a [MeshInstance], create a single [Shape] representing the mesh for use
## in a [CollisionShape]. If [code]concave[/code] is [code]true[/code], the
## resulting shape will be concave, otherwise it will be convex.
func create_single_shape(mesh_instance: MeshInstance, concave: bool) -> Shape:
	var mesh := mesh_instance.mesh
	if mesh == null:
		push_error("Mesh instance '%s' does not contain a mesh" % mesh_instance.name)
		return null
	
	if concave:
		return mesh.create_trimesh_shape()
	else:
		return mesh.create_convex_shape()


# TODO: Check the number of vertices in the mesh isn't zero.
# TODO: Add function for adjusting the centre-of-mass, while giving the option
# to keep the current position for tables.
# TODO: Add an option to scale entire pieces (or do it while we have the list of
# mesh instances)?


## TODO: Make this function.
func create_multiple_shapes(mesh_instance: MeshInstance) -> Array:
	pass


# Recursively check through the child nodes of [code]current_node[/code], with
# [code]parent_transform[/code] being the global transform of it's parent, and
# extract all [MeshInstance] nodes to the output array.
func _extract_mesh_instances_recursive(current_node: Node,
		parent_transform: Transform, output_array: Array) -> void:
	
	var current_transform := parent_transform
	if current_node is Spatial:
		current_transform = parent_transform * current_node.transform
	
	for child in current_node.get_children():
		if child is MeshInstance:
			current_node.remove_child(child)
			child.transform = current_transform
			output_array.push_back(child)
		
		elif child.get_child_count() > 0:
			_extract_mesh_instances_recursive(child, current_transform,
					output_array)
