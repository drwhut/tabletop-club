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

class_name Piece
extends AdvancedRigidBody3D

## A dynamic physics object that can be selected and moved by players.


## The name of the group of pieces that are selected.
## TODO: Change to StringName in 4.x.
const SELECTED_GROUP := "sel_pcs"

## The name of the group of pieces that are in limbo. See [method put_in_limbo].
const LIMBO_GROUP := "lmbo"


## The outline colour when the piece is neither selected or locked.
const OUTLINE_COLOR_NORMAL := Color(0.0, 0.0, 0.0, 0.5)

## The outline colour when the piece is locked, but not selected.
const OUTLINE_COLOR_LOCKED := Color(0.5, 0.5, 0.5, 0.5)

## The outline colour when the piece is selected, but not locked.
const OUTLINE_COLOR_SELECTED := Color(1.0, 1.0, 1.0, 0.5)

## The outline colour when the piece is both locked and selected.
const OUTLINE_COLOR_LOCKED_SELECTED := Color(0.75, 0.75, 0.75, 0.5)


## Is the piece locked into place?
var locked := false setget set_locked, is_locked

## Has the piece been selected by the player?
var selected := false setget set_selected, is_selected


# The outline shader material, which is set as the next render pass for all of
# the piece's materials.
var _outline_material := ShaderMaterial.new()


func _ready():
	# Create a ShaderMaterial for the piece's outline, and add it as a render
	# pass to all of the piece's materials.
	_outline_material.shader = preload("res://shaders/outline.shader")
	var material_arr := get_materials()
	for element in material_arr:
		var spatial_mat: SpatialMaterial = element
		spatial_mat.next_pass = _outline_material
	
	if material_arr.empty():
		push_warning("Piece '%s' has no materials" % name)
	
	# The piece can't be selected outside of the scene tree, but it may have
	# been locked.
	if is_locked():
		_set_outline_color(OUTLINE_COLOR_LOCKED)
	else:
		_set_outline_color(OUTLINE_COLOR_NORMAL)


## Check if the piece is in limbo, i.e. is it about to be freed from memory?
func is_in_limbo() -> bool:
	return collision_layer == 0


## Put the piece into limbo. Once it is put into limbo, it cannot come out of
## limbo.
##
## This will remove the piece from active play, but not from the scene tree.
## Only after a certain amount of time the PieceManager will remove pieces that
## are in limbo from the scene tree.
##
## The reason this is needed is because not all clients will remove the piece
## from the scene tree at the same time - this can cause RPCs to arrive after
## a piece has been removed from the scene tree, causing errors. By delaying
## when the piece is freed from memory, it gives time for those RPCs to arrive
## and be ignored.
func put_in_limbo() -> void:
	if not is_inside_tree():
		push_error("Cannot put piece '%s' in limbo, not inside tree" % name)
		return
	
	collision_layer = 0
	collision_mask = 0
	mode = MODE_STATIC
	visible = false
	
	set_process(false)
	set_process_internal(false)
	
	set_physics_process(false)
	set_physics_process_internal(false)
	
	if is_in_group(SELECTED_GROUP):
		remove_from_group(SELECTED_GROUP)
	
	add_to_group(LIMBO_GROUP)


func is_locked() -> bool:
	return mode == MODE_STATIC


func is_selected() -> bool:
	if not is_inside_tree():
		return false
	
	return is_in_group(SELECTED_GROUP)


func set_locked(value: bool) -> void:
	if is_in_limbo():
		return
	
	mode = MODE_STATIC if value else MODE_RIGID
	_update_outline_color()


func set_selected(value: bool) -> void:
	if is_in_limbo():
		return
	
	if not is_inside_tree():
		push_error("Cannot set 'selected' of piece '%s', not in scene tree" % name)
		return
	
	if value:
		# NOTE: If already in the group, nothing happens.
		add_to_group(SELECTED_GROUP)
	else:
		# NOTE: If not in the group, an error is thrown.
		remove_from_group(SELECTED_GROUP)
	
	_update_outline_color()


func _set_outline_color(color: Color) -> void:
	_outline_material.set_shader_param("OutlineColor", color)


# Update the outline colour depending on the piece's current state.
func _update_outline_color() -> void:
	if is_locked():
		if is_selected():
			_set_outline_color(OUTLINE_COLOR_LOCKED_SELECTED)
		else:
			_set_outline_color(OUTLINE_COLOR_LOCKED)
	else:
		if is_selected():
			_set_outline_color(OUTLINE_COLOR_SELECTED)
		else:
			_set_outline_color(OUTLINE_COLOR_NORMAL)
