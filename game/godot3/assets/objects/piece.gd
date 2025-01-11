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


## The distinct modes that a piece can be in, and transfer between.
##
## [b]NOTE:[/b] These modes are saved in room states. Therefore, to ensure that
## future versions of the game are backwards compatible, additional modes need
## to be added at the [i]end[/i] of the list, rather than in the middle.
enum {
	## The piece is invisible and does not interact with the world.
	##
	## This is the mode the piece should be in before it is removed from the
	## scene tree. Once a piece is in limbo, it cannot be taken out of limbo.
	##
	## The reason this is needed is because not all clients will remove the
	## piece from the scene tree at the same time - this can cause RPCs to
	## arrive after a piece has been removed from the scene tree, causing
	## errors. By delaying when the piece is freed from memory, it gives time
	## for those RPCs to arrive and be ignored.
	MODE_LIMBO,
	
	## The piece is interacting with the world, but it is not moving.
	##
	## This is an optimised state by the physics engine if the piece is not
	## moving, then it will not process the piece until another object collides
	## with it.
	##
	## It does however introduct a potential de-sync where a sleeping piece is
	## collided with client-side, but the collision did not occur server-side,
	## and thus the server piece continues sleeping while the client piece
	## becomes active.
	MODE_SLEEP,
	
	## The piece is being driven entirely by the physics engine.
	##
	## This is the piece as a regular rigid body, with no external forces being
	## applied to it.
	MODE_NORMAL,
	
	## The piece is locked in place, and acts as a static body.
	MODE_LOCKED,
	
	## Used for verification only.
	MODE_MAX,
}


## The name of the group of pieces that are selected.
## TODO: Change to StringName in 4.x.
const SELECTED_GROUP := "sel_pcs"

## The name of the group of pieces that are in limbo.
const LIMBO_GROUP := "lmbo"


## The outline colour when the piece is neither selected or locked.
const OUTLINE_COLOR_NORMAL := Color(0.0, 0.0, 0.0, 0.5)

## The outline colour when the piece is locked, but not selected.
const OUTLINE_COLOR_LOCKED := Color(0.5, 0.5, 0.5, 0.5)

## The outline colour when the piece is selected, but not locked.
const OUTLINE_COLOR_SELECTED := Color(1.0, 1.0, 1.0, 0.5)

## The outline colour when the piece is both locked and selected.
const OUTLINE_COLOR_LOCKED_SELECTED := Color(0.75, 0.75, 0.75, 0.5)


## The [AssetEntryScene] that was used to build this piece.
## TODO: Provide a default value!
var entry_built_with: AssetEntryScene = null


## Has the piece been selected by the player?
var selected := false setget set_selected, is_selected

## The mode that the piece is in, which determines it's behaviour.
##
## See the [code]MODE_*[/code] constants for possible values.
var state_mode := MODE_NORMAL setget set_state_mode

## A basis that contains information about the piece's position and velocity
## in the latest server state.
##
## X: Position
## Y: Linear Velocity
## Z: Angular Velocity
var state_pos_and_vecs := Basis()

## The piece's rotation in the latest server state.
var state_rot := Quat.IDENTITY


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
	if state_mode == MODE_LOCKED:
		_set_outline_color(OUTLINE_COLOR_LOCKED)
	else:
		_set_outline_color(OUTLINE_COLOR_NORMAL)
	
	connect("sleeping_state_changed", self, "_on_sleeping_state_changed")


func _physics_process(_delta: float):
	# TODO: Add limiter if there are many pieces, like in v0.1.x.
	if get_tree().is_network_server():
		if state_mode == MODE_NORMAL:
			# Send the latest server state to all clients.
			var pos_and_vecs := Basis(transform.origin, linear_velocity,
					angular_velocity)
			var rot_as_quat := transform.basis.get_rotation_quat()
			rpc("ss", pos_and_vecs, rot_as_quat)
	else:
		# TEMP
		if state_mode == MODE_NORMAL:
			transform.basis = Basis(state_rot)
			transform.origin = state_pos_and_vecs.x
			linear_velocity = state_pos_and_vecs.y
			angular_velocity = state_pos_and_vecs.z


func is_selected() -> bool:
	if not is_inside_tree():
		return false
	
	return is_in_group(SELECTED_GROUP)


func set_selected(value: bool) -> void:
	if state_mode == MODE_LIMBO:
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


func set_state_mode(new_value: int) -> void:
	if new_value < 0 or new_value >= MODE_MAX:
		push_error("Invalid value '%d' for state mode" % new_value)
		return
	
	# Check to see if we can enter this new mode from the mode we are currently
	# in.
	match state_mode:
		MODE_LIMBO:
			push_error("Cannot change state mode of '%s', piece is already in limbo" % name)
			return
	
	# Some modes require that the piece is in the scene tree, since they could
	# add the piece to a group.
	if new_value == MODE_LIMBO:
		if not is_inside_tree():
			push_error("Cannot put piece '%s' into limbo, piece is not in scene tree" % name)
			return
	
	state_mode = new_value
	
	# Adjust the piece's physics properties based on the new mode.
	collision_layer = 0 if state_mode == MODE_LIMBO else 1
	collision_mask = 0 if state_mode == MODE_LIMBO else 1
	mode = MODE_STATIC if state_mode == MODE_LIMBO or state_mode == MODE_LOCKED \
			else MODE_RIGID
	
	can_sleep = true # TODO: Don't sleep when flying or hovering.
	sleeping = (state_mode == MODE_SLEEP)
	
	# TODO: Account for being in another player's hidden area.
	visible = (state_mode != MODE_LIMBO)
	
	if state_mode == MODE_LIMBO:
		# Disable the piece entirely if it is in limbo, and add it to the limbo
		# group so the PieceManager can detect and remove it from the scene tree.
		set_process(false)
		set_process_internal(false)
		
		set_physics_process(false)
		set_physics_process_internal(false)
		
		if is_in_group(SELECTED_GROUP):
			remove_from_group(SELECTED_GROUP)
		
		add_to_group(LIMBO_GROUP)
	else:
		# Adjust the appearance of the piece if needed.
		_update_outline_color()


func _set_outline_color(color: Color) -> void:
	_outline_material.set_shader_param("OutlineColor", color)


## Called by the server when it sends us a state update for the piece in normal
## mode.
##
## [b]NOTE:[/b] 'ss' stands for 'set_state'. The reason for the compressed name
## is because this is the most sent RPC in the entire game, and so we want to
## try and reduce the amount of network traffic this function causes as much as
## we can.
puppet func ss(pos_and_vecs: Basis, rot: Quat) -> void:
	state_pos_and_vecs = pos_and_vecs
	state_rot = rot


## Called by the server when the piece has started sleeping.
puppet func start_sleep(pos: Vector3, rot: Quat) -> void:
	state_pos_and_vecs.x = pos
	state_pos_and_vecs.y = Vector3.ZERO
	state_pos_and_vecs.z = Vector3.ZERO
	state_rot = rot
	
	transform.basis = Basis(rot)
	transform.origin = pos
	reset_physics_interpolation()
	
	set_state_mode(MODE_SLEEP)


## Called by the server when the piece has stopped sleeping.
puppet func stop_sleep() -> void:
	set_state_mode(MODE_NORMAL)


# Update the outline colour depending on the piece's current state.
func _update_outline_color() -> void:
	if state_mode == MODE_LOCKED:
		if is_selected():
			_set_outline_color(OUTLINE_COLOR_LOCKED_SELECTED)
		else:
			_set_outline_color(OUTLINE_COLOR_LOCKED)
	else:
		if is_selected():
			_set_outline_color(OUTLINE_COLOR_SELECTED)
		else:
			_set_outline_color(OUTLINE_COLOR_NORMAL)


func _on_sleeping_state_changed():
	if get_tree().is_network_server():
		if sleeping:
			# TODO: Could we not just set the variable itself rather than call
			# the setter for optimisation? Need to think about what modes we
			# could be in beforehand.
			set_state_mode(MODE_SLEEP)
			rpc("start_sleep", transform.origin,
					transform.basis.get_rotation_quat())
		else:
			set_state_mode(MODE_NORMAL)
			rpc("stop_sleep")
	else:
		if sleeping and state_mode != MODE_SLEEP:
			# If the piece just went to sleep, but the server has not sent us
			# a signal to suggest that the piece is sleeping, keep it awake.
			sleeping = false
		elif (not sleeping) and state_mode == MODE_SLEEP:
			# If the piece has just woken up, and the server has not told us
			# that it has woken, put it back to sleep.
			# This prevents the piece from drifting away due to the fact that
			# the server does not send us any state updates.
			transform.basis = Basis(state_rot)
			transform.origin = state_pos_and_vecs.x
			reset_physics_interpolation()
			
			sleeping = true
