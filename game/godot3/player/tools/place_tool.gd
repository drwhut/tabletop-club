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

class_name PlaceTool
extends PlayerTool

## The tool used to add objects to the room.
##
## [b]NOTE:[/b] It should not be possible to switch to this tool in the UI, as
## it should only be enabled once an object has been selected in the objects
## menu.


## The alpha value used for the transparent previews.
const PREVIEW_ALPHA := 0.5


# The bounding box of the piece that is being placed.
# This is used to make adjustments to the preview's position.
var _preview_aabb: AABB


func _physics_process(_delta: float):
	perform_raycast(0x1, true, false)
	
	if get_child_count() == 0:
		return
	
	var preview: Spatial = get_child(0)
	preview.transform.origin = cursor_world_position
	
	# Adjust the position so that the bottom of the piece is flush with the
	# surface.
	preview.transform.origin.y += 0.5 * _preview_aabb.size.y


## Start placing the given piece, which will cause a transparent version of it
## to appear under the player's cursor.
func start_placing(piece_entry: AssetEntryScene) -> void:
	if get_child_count() > 0:
		push_error("Cannot start placing piece '%s', already placing one" % piece_entry.get_path())
		return
	
	var preview := _create_preview(piece_entry)
	if preview == null:
		# Error should have already been pushed.
		return
	
	# Save the piece's bounding box so that we can make adjustments to the
	# position.
	_preview_aabb = piece_entry.bounding_box
	
	add_child(preview)


## Stop placing a piece by freeing the visual representation from the scene tree.
func stop_placing() -> void:
	if get_child_count() == 0:
		push_warning("Cannot stop placing piece, already not placing one")
		return
	
	var preview := get_child(0)
	preview.queue_free()


# Using a piece entry, create a purely visual representation of the piece where
# the material is transparent.
# If there was an error creating this representation, null is returned.
func _create_preview(piece_entry: AssetEntryScene) -> Spatial:
	var builder := ObjectBuilder.new()
	var piece := builder.build_piece(piece_entry)
	if piece == null:
		push_error("Failed to build piece '%s', cannot place it" % piece_entry.get_path())
		return null
	
	var preview := Spatial.new()
	for child in piece.get_children():
		if child is CollisionShape:
			if child.get_child_count() == 0:
				continue
			
			# The CollisionShape can have a translation for the COM, but not a
			# rotation or a scale.
			var offset: Vector3 = child.transform.origin
			
			var mesh_instance: MeshInstance = child.get_child(0)
			mesh_instance.transform.origin += offset
			
			# Make all of the materials transparent.
			for surface_index in range(mesh_instance.get_surface_material_count()):
				var material: SpatialMaterial = mesh_instance.get_surface_material(surface_index)
				material.flags_transparent = true
				material.albedo_color.a = PREVIEW_ALPHA
			
			child.remove_child(mesh_instance)
			preview.add_child(mesh_instance)
	
	# Since it's position is determined by physics rays, have it use physics
	# interpolation so the movement of the preview is as smooth as possible.
	preview.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	
	piece.free()
	return preview
