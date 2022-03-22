# tabletop-club
# Copyright (c) 2020-2022 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2022 Tabletop Club contributors (see game/CREDITS.tres).
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

extends Spatial

signal setting_spawn_point(position)
signal spawning_piece_at(position)
signal spawning_piece_in_container(container_name)
signal table_flipped()
signal table_unflipped()
signal undo_stack_empty()
signal undo_stack_pushed()

onready var _camera_controller = $CameraController
onready var _hand_positions = $Table/HandPositions
onready var _hands = $Hands
onready var _hidden_areas = $HiddenAreas
onready var _hidden_area_preview = $HiddenAreaPreview
onready var _paint_plane = $Table/PaintPlane
onready var _pieces = $Pieces
onready var _spot_light = $SpotLight
onready var _sun_light = $SunLight
onready var _table = $Table
onready var _world_environment = $WorldEnvironment

const UNDO_STACK_SIZE_LIMIT = 10
const UNDO_STATE_EVENT_TIMERS = {
	"add_piece": 10,
	"flip_table": 0,
	"remove_piece": 5
}

var _srv_allow_card_stacking = true
var _srv_hand_setup_frames = -1
var _srv_next_piece_name = 0
var _srv_retrieve_pieces_from_hell = true

var _srv_undo_stack: Array = []
var _srv_events_add_states: bool = true #this is so events that normally add states like add_piece don't add a state when they are called as a part of set_state

var _srv_undo_state_events: Dictionary = {
	"add_piece": 0,
	"flip_table": 0,
	"remove_piece": 0
} #all timers start at 0 because the first time the event is called it will save the state

# If clients start hovering multiple pieces at a time, then keep track here of
# which pieces they hover, so that the client doesn't have to send multiple
# requests with the same position.
var _client_hover_pieces: Dictionary = {}

var _table_body: RigidBody = null

# Add a hand to the game for a given player.
# player: The ID of the player the hand should belong to.
# transform: The transform of the new hand.
remotesync func add_hand(player: int, transform: Transform) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	var hand = preload("res://Scenes/Game/3D/Hand.tscn").instance()
	hand.name = str(player)
	hand.transform = transform

	_hands.add_child(hand)
	hand.update_owner_display()

# Called by the server to add a piece to the room.
# name: The name of the new piece.
# transform: The initial transform of the new piece.
# piece_entry: The piece's entry in the AssetDB.
# hover_player: If set to > 0, it will initially be in a hover state by the
# player with the given ID.
remotesync func add_piece(name: String, transform: Transform,
	piece_entry: Dictionary) -> void:

	if get_tree().get_rpc_sender_id() != 1:
		return

	if get_tree().is_network_server() and _srv_events_add_states:
		#if not waiting for a timer or disabled because set_state wil be called
		if _srv_undo_state_events["add_piece"] <= 0:
			push_undo_state()	#make host add an undo state
		_srv_undo_state_events["add_piece"] = UNDO_STATE_EVENT_TIMERS["add_piece"]	#if you try to add a piece before timer is up, timer resets

	var piece = PieceBuilder.build_piece(piece_entry)

	piece.name = name
	piece.transform = transform

	if get_tree().is_network_server():
		piece.srv_retrieve_from_hell = _srv_retrieve_pieces_from_hell

	piece.connect("piece_exiting_tree", self, "_on_piece_exiting_tree")

	# If it is a stackable piece, make sure we attach the signal it emits when
	# it wants to create a stack.
	if piece is StackablePiece:
		piece.connect("stack_requested", self, "_on_stack_requested")

	# If it is a container, make sure we attach the signal it emits when it
	# wants to absorb or release a piece.
	if piece is PieceContainer:
		piece.connect("absorbing_hovered", self, "_on_container_absorbing_hovered")
		piece.connect("releasing_random_piece", self, "_on_container_releasing_random_piece")

	_pieces.add_child(piece)

# Called by the server to add a piece to a container, a.k.a. having the piece
# be "absorbed" by the container.
# container_name: The name of the container that is absorbing the piece.
# piece_name: The name of the piece that the container is absorbing.
remotesync func add_piece_to_container(container_name: String, piece_name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	var container = _pieces.get_node(container_name)
	var piece     = _pieces.get_node(piece_name)

	if not container:
		push_error("Container " + container_name + " does not exist!")
		return

	if not piece:
		push_error("Piece " + piece_name + " does not exist!")
		return

	if not container is PieceContainer:
		push_error("Piece " + container_name + " is not a container!")
		return

	if not piece is Piece:
		push_error("Object " + piece_name + " is not a piece!")
		return

	if get_tree().is_network_server():
		piece.stop_hovering()

	_pieces.remove_child(piece)
	container.add_piece(piece)

# Called by the server to add a piece to a stack.
# piece_name: The name of the piece.
# stack_name: The name of the stack.
# on: Where to add the piece to in the stack.
# flip: Should the piece be flipped upon entering the stack?
remotesync func add_piece_to_stack(piece_name: String, stack_name: String,
	on: int = Stack.STACK_AUTO, flip: int = Stack.FLIP_AUTO) -> void:

	if get_tree().get_rpc_sender_id() != 1:
		return

	var piece = _pieces.get_node(piece_name)
	var stack = _pieces.get_node(stack_name)

	if not piece:
		push_error("Piece " + stack_name + " does not exist!")
		return

	if not stack:
		push_error("Stack " + stack_name + " does not exist!")
		return

	if not piece is StackablePiece:
		push_error("Piece " + piece_name + " is not stackable!")
		return

	if not stack is Stack:
		push_error("Piece " + stack_name + " is not a stack!")
		return

	_pieces.remove_child(piece)

	var piece_entry = piece.piece_entry
	if piece.is_albedo_color_exposed():
		piece_entry["color"] = piece.get_albedo_color()
	stack.add_piece(piece.piece_entry, piece.transform, on, flip)

	piece.queue_free()

# Called by the server to add a stack to the room with 2 initial pieces.
# name: The name of the new stack.
# transform: The initial transform of the new stack.
# piece1_name: The name of the first piece to add to the stack.
# piece2_name: The name of the second piece to add to the stack.
remotesync func add_stack(name: String, transform: Transform,
	piece1_name: String, piece2_name: String) -> void:

	if get_tree().get_rpc_sender_id() != 1:
		return

	var piece1 = _pieces.get_node(piece1_name)
	var piece2 = _pieces.get_node(piece2_name)

	if not piece1:
		push_error("Stackable piece " + piece1_name + " does not exist!")
		return

	if not piece2:
		push_error("Stackable piece " + piece2_name + " does not exist!")
		return

	if not piece1 is StackablePiece:
		push_error("Piece " + piece1_name + " is not stackable!")
		return

	if not piece2 is StackablePiece:
		push_error("Piece " + piece2_name + " is not stackable!")
		return

	var sandwich_stack = (piece1.piece_entry["scene_path"] == "res://Pieces/Card.tscn")
	add_stack_empty(name, transform, sandwich_stack)

	add_piece_to_stack(piece1.name, name)
	add_piece_to_stack(piece2.name, name)

# Called by the server to add an empty stack to the room.
# name: The name of the new stack.
# transform: The initial transform of the new stack.
# sandwich: If true, add a StackSandwich. If false, add a StackLasagne.
puppet func add_stack_empty(name: String, transform: Transform, sandwich: bool) -> Stack:

	# Special case here, where we don't want the RPC to be sent to the server,
	# but the server needs the stack to be returned.
	if not (get_tree().is_network_server() or get_tree().get_rpc_sender_id() == 1):
		return null

	var stack: Stack = null
	if sandwich:
		stack = preload("res://Pieces/StackSandwich.tscn").instance()
	else:
		stack = preload("res://Pieces/StackLasagne.tscn").instance()

	stack.name = name
	stack.transform = transform

	if get_tree().is_network_server():
		stack.srv_retrieve_from_hell = _srv_retrieve_pieces_from_hell

	_pieces.add_child(stack)

	stack.connect("piece_exiting_tree", self, "_on_piece_exiting_tree")
	stack.connect("stack_requested", self, "_on_stack_requested")

	return stack

# Called by the server to add a pre-filled stack to the room.
# name: The name of the new stack.
# transform: The initial transform of the new stack.
# stack_entry: The stack's entry in the AssetDB.
remotesync func add_stack_filled(name: String, transform: Transform,
	stack_entry: Dictionary) -> void:

	var sandwich_stack = (stack_entry["scene_path"] == "res://Pieces/Card.tscn")

	var stack = add_stack_empty(name, transform, sandwich_stack)
	PieceBuilder.fill_stack(stack, stack_entry)

# Called by the server to merge the contents of one stack into another stack.
# stack1_name: The name of the stack to merge contents from.
# stack2_name: The name of the stack to merge contents to.
remotesync func add_stack_to_stack(stack1_name: String, stack2_name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	var stack1 = _pieces.get_node(stack1_name)
	var stack2 = _pieces.get_node(stack2_name)

	if not stack1:
		push_error("Stack " + stack1_name + " does not exist!")
		return

	if not stack2:
		push_error("Stack " + stack2_name + " does not exist!")
		return

	if not stack1 is Stack:
		push_error("Piece " + stack1_name + " is not a stack!")
		return

	if not stack2 is Stack:
		push_error("Piece " + stack2_name + " is not a stack!")
		return

	# If there are no children in the first stack, don't bother doing anything.
	if stack1.empty():
		return

	# We need to determine in which order to add the children of the first stack
	# to the second stack.
	# NOTE: In stacks, children are stored bottom-first.
	var reverse = false

	if stack1.transform.origin.y > stack2.transform.origin.y:
		reverse = stack1.transform.basis.y.y < 0
	else:
		reverse = stack1.transform.basis.y.y > 0

	var pieces = stack1.get_pieces()
	if reverse:
		pieces.invert()
	_pieces.remove_child(stack1)

	for piece_meta in pieces:
		var piece_entry = piece_meta["piece_entry"]
		var flip_y = piece_meta["flip_y"]

		var piece_transform = stack1.transform
		if flip_y:
			piece_transform = piece_transform.rotated(Vector3.BACK, PI)

		stack2.add_piece(piece_entry, piece_transform)

	stack1.queue_free()

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	_camera_controller.apply_options(config)

	var radiance = Sky.RADIANCE_SIZE_128
	var radiance_index = config.get_value("video", "skybox_radiance_detail")

	match radiance_index:
		0:
			radiance = Sky.RADIANCE_SIZE_128
		1:
			radiance = Sky.RADIANCE_SIZE_256
		2:
			radiance = Sky.RADIANCE_SIZE_512
		3:
			radiance = Sky.RADIANCE_SIZE_1024
		4:
			radiance = Sky.RADIANCE_SIZE_2048

	_world_environment.environment.background_sky.radiance_size = radiance

	var ssao_enabled = true
	var ssao_quality = Environment.SSAO_QUALITY_LOW
	var ssao_index = config.get_value("video", "ssao")

	match ssao_index:
		0:
			ssao_enabled = false
		1:
			ssao_quality = Environment.SSAO_QUALITY_LOW
		2:
			ssao_quality = Environment.SSAO_QUALITY_MEDIUM
		3:
			ssao_quality = Environment.SSAO_QUALITY_HIGH

	_world_environment.environment.ssao_enabled = ssao_enabled
	_world_environment.environment.ssao_quality = ssao_quality

	var dof_enabled = true
	var dof_quality = Environment.DOF_BLUR_QUALITY_LOW
	var dof_index = config.get_value("video", "depth_of_field")

	match dof_index:
		0:
			dof_enabled = false
		1:
			dof_quality = Environment.DOF_BLUR_QUALITY_LOW
		2:
			dof_quality = Environment.DOF_BLUR_QUALITY_MEDIUM
		3:
			dof_quality = Environment.DOF_BLUR_QUALITY_HIGH

	var dof_amount = 0.1 * config.get_value("video", "depth_of_field_amount")
	var dof_distance = 15 + 85 * config.get_value("video", "depth_of_field_distance")

	_world_environment.environment.dof_blur_far_amount = dof_amount
	_world_environment.environment.dof_blur_far_distance = dof_distance
	_world_environment.environment.dof_blur_far_enabled = dof_enabled
	_world_environment.environment.dof_blur_far_quality = dof_quality
	_world_environment.environment.dof_blur_far_transition = 10.0

	_world_environment.environment.dof_blur_near_amount = dof_amount
	_world_environment.environment.dof_blur_near_distance = 5.0
	_world_environment.environment.dof_blur_near_enabled = dof_enabled
	_world_environment.environment.dof_blur_near_quality = dof_quality
	_world_environment.environment.dof_blur_near_transition = 1.0

	var paint_filtering = config.get_value("video", "table_paint_filtering")
	_paint_plane.set_filtering_enabled(paint_filtering)

# Compress the given room state.
# Returns: A dictionary, where "data" is the compressed version of the room
# state, and "size" is the size of the uncompressed data.
# state: The room state to compress.
func compress_state(state: Dictionary) -> Dictionary:
	var bytes = var2bytes(state)
	return {
		"data": bytes.compress(File.COMPRESSION_FASTLZ),
		"size": bytes.size()
	}

# Flip the table.
# camera_basis: The basis matrix of the player flipping the table.
remotesync func flip_table(camera_basis: Basis) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if _table_body == null:
		return

	if get_tree().is_network_server() and _srv_events_add_states:
		#if not waiting for a timer or disabled because set_state wil be called
		if _srv_undo_state_events["flip_table"] <= 0:
			push_undo_state()	#make host add an undo state
		_srv_undo_state_events["flip_table"] = UNDO_STATE_EVENT_TIMERS["flip_table"]	#if they try to save a state with this event again before the timer has run out, it will reset the timer

	# Unlock all pieces after we've saved the state so that the table doesn't
	# get blocked.
	for piece in _pieces.get_children():
		if piece is Piece:
			piece.mode = RigidBody.MODE_RIGID

	_table_body.mode = RigidBody.MODE_RIGID

	var left = -camera_basis.x
	var diagonal = -camera_basis.z
	diagonal.y = 0.5
	diagonal = diagonal.normalized()
	_table_body.apply_central_impulse(_table_body.mass * 100 * diagonal)
	_table_body.apply_torque_impulse(_table_body.mass * 2000 * left)

	if get_tree().is_network_server():
		srv_set_retrieve_pieces_from_hell(false)

	emit_signal("table_flipped")

# Get the player camera's hover position.
# Returns: The current hover position.
func get_camera_hover_position() -> Vector3:
	return _camera_controller.get_hover_position()

# Get the camera controller's transform.
# Returns: The camera controller's transform.
func get_camera_transform() -> Transform:
	return _camera_controller.transform

# Get the color of the room lamp.
# Returns: The color of the lamp.
func get_lamp_color() -> Color:
	if _sun_light.visible:
		return _sun_light.light_color
	else:
		return _spot_light.light_color

# Get the intensity of the room lamp.
# Returns: The intensity of the lamp.
func get_lamp_intensity() -> float:
	if _sun_light.visible:
		return _sun_light.light_energy
	else:
		return _spot_light.light_energy

# Get the type of light the room lamp is emitting.
# Returns: True if the lamp is sunlight, false if it is a spotlight.
func get_lamp_type() -> bool:
	return _sun_light.visible

# Get a piece in the room with a given name.
# Returns: The piece with the given name.
# name: The name of the piece.
func get_piece_with_name(name: String) -> Piece:
	return _pieces.get_node(name)

# Get the list of pieces in the room.
# Returns: The list of pieces in the room.
func get_pieces() -> Array:
	return _pieces.get_children()

# Get the number of pieces in the room.
# Returns: The number of pieces in the room.
func get_piece_count() -> int:
	return _pieces.get_child_count()

# Get the current skybox's entry in the asset DB.
# Returns: The current skybox's entry, empty if it is using the default skybox.
func get_skybox() -> Dictionary:
	if _world_environment.has_meta("skybox_entry"):
		var skybox_entry = _world_environment.get_meta("skybox_entry")
		if skybox_entry.has("texture_path"):
			if not skybox_entry["texture_path"].empty():
				return skybox_entry

	return {}

# Get the current room state.
# Returns: The current room state.
# hands: Should the hand states be included?
# collisions: Should collision data be included?
func get_state(hands: bool = false, collisions: bool = false) -> Dictionary:
	var out = {}
	out["version"] = ProjectSettings.get_setting("application/config/version")

	out["lamp"] = {
		"color": get_lamp_color(),
		"intensity": get_lamp_intensity(),
		"sunlight": get_lamp_type()
	}

	out["skybox"] = get_skybox()

	# If the paint image is blank (it's default state), don't bother storing
	# any image data in the state.
	var paint_image = _paint_plane.get_paint()
	var paint_image_data = null
	if not paint_image.is_invisible():
		paint_image_data = paint_image.get_data()

	out["table"] = {
		"entry": get_table(),
		"is_rigid": false,
		"paint_image_data": paint_image_data,
		"transform": Transform.IDENTITY
	}
	if _table_body:
		out["table"]["is_rigid"] = _table_body.mode == RigidBody.MODE_RIGID
		out["table"]["transform"] = _table_body.transform

	if hands:
		var hand_dict = {}
		for hand in _hands.get_children():
			var hand_meta = {
				"transform": hand.transform
			}

			hand_dict[hand.owner_id()] = hand_meta

		out["hands"] = hand_dict

	var hidden_area_dict = {}
	for hidden_area in _hidden_areas.get_children():
		if hidden_area is HiddenArea:
			# Convert the transform of the hidden area to corner points so the
			# set_state() function can re-use the function that creates the
			# hidden area.
			var area_origin = hidden_area.transform.origin
			var area_scale  = hidden_area.transform.basis.get_scale()
			var point1_v3 = area_origin - area_scale
			var point2_v3 = area_origin + area_scale
			var hidden_area_meta = {
				"player_id": hidden_area.player_id,
				"point1": Vector2(point1_v3.x, point1_v3.z),
				"point2": Vector2(point2_v3.x, point2_v3.z)
			}

			hidden_area_dict[hidden_area.name] = hidden_area_meta

	out["hidden_areas"] = hidden_area_dict

	_append_piece_states(out, _pieces.get_children(), collisions)

	return out

# Get the current room state as a compressed byte array.
# Returns: A dictionary, where "data" is the compressed version of the room
# state, and "size" is the size of the uncompressed data.
# hands: Should the hand states be included?
# collisions: Should collision data be included?
func get_state_compressed(hands: bool = false, collisions: bool = false) -> Dictionary:
	return compress_state(get_state(hands, collisions))

# Get the current table's entry in the asset DB.
# Returns: The current table's entry, empty if there is no table.
func get_table() -> Dictionary:
	if _table_body:
		if _table_body.has_meta("table_entry"):
			return _table_body.get_meta("table_entry")

	return {}

# Called by the server to paste the contents of a clipboard to the room.
# clipboard: The clipboard contents (from _append_piece_states).
remotesync func paste_clipboard(clipboard: Dictionary) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	_extract_piece_states(clipboard, _pieces)

# Called by the server to place a hidden area for a given player.
# area_name: The name of the new hidden area.
# player_id: The player the hidden area is registered to.
# point1: One corner of the hidden area.
# point2: The opposite corner of the hidden area.
remotesync func place_hidden_area(area_name: String, player_id: int,
	point1: Vector2, point2: Vector2) -> void:

	if get_tree().get_rpc_sender_id() != 1:
		return

	var hidden_area: HiddenArea = preload("res://Scenes/Game/3D/HiddenArea.tscn").instance()
	hidden_area.name = area_name
	hidden_area.player_id = player_id
	_set_hidden_area_transform(hidden_area, point1, point2)

	_hidden_areas.add_child(hidden_area)
	hidden_area.update_player_color()

#takes an undo state off of the undo stack if possible
#Returns: nothing(void)
master func pop_undo_state() -> void:
	#if there is an undo state, pop it off and restore the table with set_state()
	if _srv_undo_stack.size() > 0:
		var state_to_restore = _srv_undo_stack.pop_back()
		_srv_events_add_states = false	#we don't want add_piece adding states when it's called as a part of set state
		# TODO: Consider pushing compressed states to the undo stack?
		rpc("set_state_compressed", compress_state(state_to_restore))	#set the state for everyone
		_srv_events_add_states = true
	
	# Let all players know if the undo stack is now empty.
	if _srv_undo_stack.empty():
		rpc("_on_undo_stack_empty")

#adds an undo state to the undo stack if possible
#Returns: nothing(void)
func push_undo_state() -> void:
	if _srv_undo_stack.size() >= UNDO_STACK_SIZE_LIMIT:
		_srv_undo_stack.pop_front()
	
	_srv_undo_stack.push_back(get_state(false,false))
	
	# Let all players know that the undo stack has been pushed to.
	rpc("_on_undo_stack_pushed")

# Remove a player's hand from the room.
# player: The ID of the player whose hand to remove.
remotesync func remove_hand(player: int) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	var hand = _hands.get_node(str(player))
	if hand:
		_hands.remove_child(hand)
		hand.queue_free()

# Called by the server to remove a hidden area from the table.
# area_name: The name of the hidden area to remove.
remotesync func remove_hidden_area(area_name: String) -> void:
	var hidden_area = _hidden_areas.get_node(area_name)

	if not hidden_area:
		push_error("Hidden area " + area_name + " does not exist!")
		return

	if not hidden_area is HiddenArea:
		push_error("Node " + area_name + " is not a hidden area!")
		return

	_hidden_areas.remove_child(hidden_area)
	hidden_area.queue_free()

# Called by the server to remove a piece from a container, a.k.a. having the
# piece be "released" by the container.
# container_name: The name of the container that is absorbing the piece.
# piece_name: The name of the piece that the container is releasing.
remotesync func remove_piece_from_container(container_name: String, piece_name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	var container = _pieces.get_node(container_name)

	if not container:
		push_error("Container " + container_name + " does not exist!")
		return

	if not container is PieceContainer:
		push_error("Piece " + container_name + " is not a container!")
		return

	if not container.has_piece(piece_name):
		push_error("Container " + container_name + " does not contain piece " + piece_name)
		return

	var piece = container.remove_piece(piece_name)
	_pieces.add_child(piece)

# Request the server to add a piece to the game.
# Returns: The name of the new piece.
# piece_entry: The piece's entry in the AssetDB.
# position: The position to spawn the piece at.
master func request_add_piece(piece_entry: Dictionary, position: Vector3) -> String:
	var transform = Transform(Basis.IDENTITY, position)

	# Is the piece a pre-filled stack?
	if piece_entry.has("texture_paths") and (not piece_entry.has("texture_path")):
		return request_add_stack_filled(transform, piece_entry)
	else:
		# Send the call to create the piece to everyone.
		var piece_name = srv_get_next_piece_name()
		rpc("add_piece", piece_name, transform, piece_entry)
		return piece_name

# Request the server to add a piece into a container.
# piece_entry: The piece's entry in the AssetDB.
# container_name: The name of the container to add the piece to.
master func request_add_piece_in_container(piece_entry: Dictionary, container_name: String) -> void:
	# Spawn the piece far away so the players don't see it.
	var piece_name = request_add_piece(piece_entry, Vector3(9999, 9999, 9999))

	rpc("add_piece_to_container", container_name, piece_name)

# Request the server to add the given pieces to a container's contents.
# container_name: The name of the container to add the pieces to.
# piece_names: The names of the pieces to add to the container.
master func request_add_pieces_to_container(container_name: String, piece_names: Array) -> void:
	for piece_name in piece_names:
		if piece_name is String:
			if piece_name != container_name:
				rpc("add_piece_to_container", container_name, piece_name)

# Request the server to add cards to the given hand.
# card_names: The names of the cards to add to the hand. Note that the names
# of stacks are also allowed.
# hand_id: The player ID of the hand to add the cards to.
master func request_add_cards_to_hand(card_names: Array, hand_id: int) -> void:
	var hand_name = str(hand_id)
	if hand_id <= 0:
		push_error("Hand ID " + hand_name + " is invalid!")
		return

	var hand = _hands.get_node(str(hand_id))
	if not hand:
		push_error("Hand " + hand_name + " does not exist!")
		return

	var cards = []
	for card_name in card_names:
		var piece = _pieces.get_node(card_name)

		if not piece:
			push_error("Piece " + card_name + " does not exist!")
			continue

		if not piece is Piece:
			push_error("Object " + card_name + " is not a piece!")
			continue

		if piece is Card:
			cards.append(piece)
		elif piece is Stack:
			var is_card = piece.is_card_stack()

			if not is_card:
				push_error("Stack " + card_name + " does not contain cards!")
				continue

			var new_card_names = []
			var last_card_name = srv_get_next_piece_name()
			for i in range(piece.get_piece_count() - 1):
				var new_name = request_pop_stack(card_name, 1, false, i + 1.0,
					last_card_name)
				new_card_names.append(new_name)
			new_card_names.append(last_card_name)

			for name in new_card_names:
				var card: Card = _pieces.get_node(name)
				cards.append(card)
		else:
			push_error("Piece " + card_name + " is not a card or a stack!")
			continue

	for card in cards:
		var success = hand.srv_add_card(card)
		if not success:
			push_error("Card " + card.name + " could not be hovered!")

# Request the server to add cards to the nearest hand. The hand is decided
# based on the card's hover offsets.
# card_names: The names of the cards to add to the hand. Note that the names
# of stacks of cards are also allowed.
master func request_add_cards_to_nearest_hand(card_names: Array) -> void:
	var hand_id = 0
	var min_dist = null

	for card_name in card_names:
		var piece = _pieces.get_node(card_name)

		if not piece:
			push_error("Piece " + card_name + " does not exist!")
			continue

		if not piece is Piece:
			push_error("Object " + card_name + " is not a piece!")
			continue

		if piece.get("over_hand") == null:
			push_error("Piece " + card_name + " does not have the over_hand property!")
			continue

		if piece.over_hand > 0:
			var piece_dist = piece.hover_offset.length()
			if (min_dist == null) or (piece_dist < min_dist):
				hand_id = piece.over_hand
				min_dist = piece_dist

	if hand_id <= 0:
		push_error("None of the cards were over a hand!")
		return

	request_add_cards_to_hand(card_names, hand_id)

# Request the server to add a pre-filled stack.
# Returns: The name of the new stack.
# stack_transform: The transform the new stack should have.
# stack_entry: The stack's entry in the AssetDB.
master func request_add_stack_filled(stack_transform: Transform, stack_entry: Dictionary) -> String:
	var stack_name = srv_get_next_piece_name()
	rpc("add_stack_filled", stack_name, stack_transform, stack_entry)

	return stack_name

# Request the server to collect a set of pieces and, if possible, put them into
# stacks.
# piece_names: The names of the pieces to try and collect.
master func request_collect_pieces(piece_names: Array) -> void:
	var pieces = []
	for piece_name in piece_names:
		var piece = _pieces.get_node(piece_name)
		if piece and piece is StackablePiece:
			pieces.append(piece)

	if pieces.size() <= 1:
		return

	var add_to = pieces.pop_front()

	while add_to:
		for i in range(pieces.size() - 1, -1, -1):
			var add_from = pieces[i]

			if add_to.matches(add_from):
				if add_to is Stack:
					if add_from is Stack:
						rpc("add_stack_to_stack", add_from.name, add_to.name)
					else:
						rpc("add_piece_to_stack", add_from.name, add_to.name)
				else:
					if add_from is Stack:
						rpc("add_piece_to_stack", add_to.name, add_from.name)

						# add_to (Piece) has been added to add_from (Stack), so
						# in future, we need to add pieces to add_from.
						add_to = add_from
					else:
						var new_stack_name = srv_get_next_piece_name()
						rpc("add_stack", new_stack_name, add_to.transform,
							add_to.name, add_from.name)
						add_to = _pieces.get_node(new_stack_name)

				pieces.remove(i)

		add_to = pieces.pop_front()

# Called by the server when the request to release a piece from a container was
# accepted.
# piece_name: The name of the piece that was just released from a container.
remotesync func request_container_release_accepted(piece_name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	# The server has allowed us to hover the piece that has just poped off the
	# stack!
	request_hover_piece_accepted(piece_name)

# Request the server to randomly release a set amount of pieces from a
# container.
# container_name: The name of the container to release pieces from.
# n: The number of pieces to release from the container.
# hover: Do we want to start hovering the piece afterwards?
master func request_container_release_random(container_name: String, n: int, hover: bool) -> void:
	if n < 1:
		return

	var container = _pieces.get_node(container_name)

	if not container:
		push_error("Container " + container_name + " does not exist!")
		return

	if not container is PieceContainer:
		push_error("Piece " + container_name + " is not a container!")
		return

	var names = container.get_piece_names()
	if names.size() == 0:
		return

	# We want the selection to be random!
	if n < names.size():
		randomize()
		names.shuffle()
		names = names.slice(0, n - 1)

	request_container_release_these(container_name, names, hover)

# Request the server to release a given set of pieces from a container.
# container_name: The name of the container to release the pieces from.
# release_names: The list of names of the pieces to be released from the
# container.
# hover: Do we want to start hovering the piece afterwards?
master func request_container_release_these(container_name: String,
	release_names: Array, hover: bool) -> void:

	if release_names.size() == 0:
		return

	var player_id = get_tree().get_rpc_sender_id()
	var container = _pieces.get_node(container_name)

	if not container:
		push_error("Container " + container_name + " does not exist!")
		return

	if not container is PieceContainer:
		push_error("Piece " + container_name + " is not a container!")
		return

	var hover_box_pos   = Vector3.ZERO
	var hover_box_size  = Vector3.ZERO
	var hover_direction = 0

	var max_y_pos = 0

	for piece_name in release_names:
		if container.has_piece(piece_name):
			rpc("remove_piece_from_container", container_name, piece_name)

			if hover:
				var piece: Piece = _pieces.get_node(piece_name)
				var piece_size = piece.get_size()
				var piece_offset = hover_box_pos

				if piece.transform.origin.y > max_y_pos:
					max_y_pos = piece.transform.origin.y

					# TODO: Ideally should only be called once.
					_camera_controller.rpc_id(player_id, "set_hover_height",
						max_y_pos)

				if hover_direction == 0:
					piece_offset.x += (hover_box_size.x + piece_size.x) / 2
				elif hover_direction == 1:
					piece_offset.z += (hover_box_size.z + piece_size.z) / 2
				elif hover_direction == 2:
					piece_offset.x -= (hover_box_size.x + piece_size.x) / 2
				else:
					piece_offset.z -= (hover_box_size.z + piece_size.z) / 2

				hover_box_pos = 0.5 * (hover_box_pos + piece_offset)
				if hover_direction % 2 == 0:
					hover_box_size.x += piece_size.x
					hover_box_size.z = max(hover_box_size.z, piece_size.z)
				else:
					hover_box_size.x = max(hover_box_size.x, piece_size.x)
					hover_box_size.z += piece_size.z
				hover_direction = (hover_direction + 1) % 4

				if piece.srv_start_hovering(player_id, piece.transform.origin, piece_offset):
					rpc_id(player_id, "request_container_release_accepted", piece_name)

# Request the server to deal cards from a stack to all players.
# stack_name: The name of the stack of cards.
# n: The number of cards to deal to each player.
master func request_deal_cards(stack_name: String, n: int) -> void:
	if n < 1:
		return

	var stack = _pieces.get_node(stack_name)

	if not stack:
		push_error("Piece " + stack_name + " does not exist!")
		return

	if not stack is Stack:
		push_error("Piece " + stack_name + " is not a stack!")
		return

	var is_card_stack = stack.is_card_stack()

	if not is_card_stack:
		push_error("Stack " + stack_name + " does not contain cards!")
		return

	var last_name = ""
	for _i in range(n):
		for hand in _hands.get_children():
			if not last_name.empty():
				request_add_cards_to_hand([last_name], hand.owner_id())
				break
			elif not stack.empty():
				if stack.get_piece_count() == 2:
					last_name = srv_get_next_piece_name()

				var card_name = request_pop_stack(stack_name, 1, false, 1.0, last_name)
				request_add_cards_to_hand([card_name], hand.owner_id())
			else:
				break

# Request the server to flip the table.
# camera_basis: The basis matrix of the player flipping the table.
master func request_flip_table(camera_basis: Basis) -> void:
	rpc("flip_table", camera_basis)

# Request the server to hover a piece.
# Returns: If the request was successful.
# piece_name: The name of the piece to hover.
# init_pos: The initial hover position.
# offset_pos: The hover position offset.
master func request_hover_piece(piece_name: String, init_pos: Vector3,
	offset_pos: Vector3) -> bool:

	var piece = _pieces.get_node(piece_name)

	if not piece:
		push_error("Piece " + piece_name + " does not exist!")
		return false

	if not piece is Piece:
		push_error("Object " + piece_name + " is not a piece!")
		return false

	var player_id = get_tree().get_rpc_sender_id()

	if piece.srv_start_hovering(player_id, init_pos, offset_pos):
		rpc_id(player_id, "request_hover_piece_accepted", piece_name)
		return true
	
	return false

# Request the server to hover a set of pieces. The server will remember the
# list of pieces given, and use it to re-set the hover position of those pieces
# if the client wishes to update it.
# piece_names: The names of the pieces to hover.
# init_pos: The initial hover position.
# offset_pos_arr: The hover position offsets for each piece.
master func request_hover_pieces(piece_names: Array, init_pos: Vector3,
	offset_pos_arr: Array) -> void:
	
	if piece_names.size() != offset_pos_arr.size():
		push_error("Name and offset arrays differ in size (name = %d, offset = %d)!" % [piece_names.size(), offset_pos_arr.size()])
		return
	
	var player_id = get_tree().get_rpc_sender_id()
	_client_hover_pieces[player_id] = []
	
	for i in range(len(piece_names)):
		var piece_name: String = piece_names[i]
		var offset_pos: Vector3 = offset_pos_arr[i]
		if request_hover_piece(piece_name, init_pos, offset_pos):
			_client_hover_pieces[player_id].append(piece_name)
	
	# Send the hover pieces to the other clients so that they can hover the
	# pieces when the hovering player sends an update.
	rpc("set_client_hover_pieces", player_id, piece_names)

# Called by the server if the request to hover a piece was accepted.
# piece_name: The name of the piece we are now hovering.
remotesync func request_hover_piece_accepted(piece_name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	var piece = _pieces.get_node(piece_name)

	if not piece:
		push_error("Piece " + piece_name + " does not exist!")
		return

	if not piece is Piece:
		push_error("Object " + piece_name + " is not a piece!")
		return

	_camera_controller.append_selected_pieces([piece])
	_camera_controller.set_is_hovering(true)

# Request the server to load a compressed table state.
# compressed_state: The compressed state to load.
master func request_load_table_state(compressed_state: Dictionary) -> void:
	rpc("set_state_compressed", compressed_state)

# Request the server to paste the contents of a clipboard to the room.
# clipboard: The clipboard contents (from _append_piece_states).
# offset: Offset the positions of the pasted pieces by this value.
master func request_paste_clipboard(clipboard: Dictionary, offset: Vector3) -> void:
	_modify_piece_states(clipboard, offset)
	rpc("paste_clipboard", clipboard)

# Request the server to place a hidden area registered to you.
# point1: One corner of the new hidden area.
# point2: The opposite corner of the new hidden area.
master func request_place_hidden_area(point1: Vector2, point2: Vector2) -> void:
	var player_id = get_tree().get_rpc_sender_id()
	rpc("place_hidden_area", srv_get_next_piece_name(), player_id, point1, point2)

# Request the server to pop the piece at the top of a stack.
# Returns: The name of the new piece.
# stack_name: The name of the stack to pop.
# n: The number of pieces to pop from the stack.
# hover: Do we want to start hovering the piece afterwards?
# split_dist: How far away do we want the piece from the stack when it is poped?
# last_name: If there is only one piece left in the stack, it is optionally
# given this name.
master func request_pop_stack(stack_name: String, n: int, hover: bool,
	split_dist: float, last_name: String = "") -> String:

	var player_id = get_tree().get_rpc_sender_id()
	var stack = _pieces.get_node(stack_name)

	if not stack:
		push_error("Stack " + stack_name + " does not exist!")
		return ""

	if not stack is Stack:
		push_error("Object " + stack_name + " is not a stack!")
		return ""

	var new_piece: Piece = null

	if n < 1:
		return ""
	elif n < stack.get_piece_count():
		var unit_height = stack.get_unit_height()
		var total_height = stack.get_total_height()
		var removed_height = unit_height * n

		# NOTE: We normalise the basis here to reset the piece's scale, because
		# add_piece will use the piece entry to scale the piece again.
		var new_basis = stack.transform.basis.orthonormalized()
		var new_origin = stack.transform.origin
		new_origin.y += total_height / 2
		# Get the new piece away from the stack so it doesn't collide with it
		# again.
		new_origin.y += split_dist + removed_height / 2

		var new_name = srv_get_next_piece_name()

		if n == 1:
			var index = stack.pop_index()
			var piece_meta = stack.remove_piece(index)
			stack.rpc("remove_piece", index)

			var piece_entry = piece_meta["piece_entry"]
			var piece_transform = piece_meta["transform"]
			new_basis = (stack.transform.basis * piece_transform.basis).orthonormalized()
			rpc("add_piece", new_name, Transform(new_basis, new_origin), piece_entry)
			new_piece = _pieces.get_node(new_name)
		else:
			var new_transform = Transform(new_basis, new_origin)

			new_piece = add_stack_empty(new_name, new_transform, stack is StackSandwich)
			rpc("add_stack_empty", new_name, new_transform)

			rpc("transfer_stack_contents", stack_name, new_name, n)

		# Move the stack down to it's new location.
		var new_stack_translation = stack.translation
		var offset = stack.transform.basis.y.normalized()
		if offset.y > 0:
			offset = -offset
		new_stack_translation += offset * (removed_height / 2)
		stack.rpc("set_translation", new_stack_translation)

		# If there is only one piece left in the stack, turn it into a normal
		# piece.
		if stack.get_piece_count() == 1:
			if last_name.empty():
				last_name = srv_get_next_piece_name()

			var piece_meta = stack.remove_piece(0)
			var piece_entry = piece_meta["piece_entry"]
			var piece_transform = piece_meta["transform"]
			stack.rpc("remove_self")

			new_basis = (stack.transform.basis * piece_transform.basis).orthonormalized()
			rpc("add_piece", last_name,
				Transform(new_basis, new_stack_translation), piece_entry)
	else:
		new_piece = stack

	if new_piece and hover:
		if new_piece.srv_start_hovering(player_id, new_piece.transform.origin, Vector3()):
			rpc_id(player_id, "request_pop_stack_accepted", new_piece.name)

	return new_piece.name

# Called by the server if the request to pop a stack was accepted, and we are
# now hovering the new piece.
# piece_name: The name of the piece that is now hovering.
remotesync func request_pop_stack_accepted(piece_name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	# The server has allowed us to hover the piece that has just poped off the
	# stack!
	request_hover_piece_accepted(piece_name)

# Request the server to remove a hidden area.
# area_name: The name of the hidden area to remove.
master func request_remove_hidden_area(area_name: String) -> void:
	var hidden_area = _hidden_areas.get_node(area_name)

	if not hidden_area:
		push_error("Hidden area " + area_name + " does not exist!")
		return

	if not hidden_area is HiddenArea:
		push_error("Node " + area_name + " is not a hidden area!")
		return

	rpc("remove_hidden_area", area_name)

# Request the server to set the lamp color.
# color: The color to set the lamp to.
master func request_set_lamp_color(color: Color) -> void:
	rpc("set_lamp_color", color)

# Request the server to set the lamp intensity.
# intensity: The intensity to set the lamp to.
master func request_set_lamp_intensity(intensity: float) -> void:
	rpc("set_lamp_intensity", intensity)

# Request the server to set the lamp type.
# sunlight: True for sunlight, false for a spotlight.
master func request_set_lamp_type(sunlight: bool) -> void:
	rpc("set_lamp_type", sunlight)

# Request the server to set the room skybox.
# skybox_entry: The skybox's entry in the asset DB.
master func request_set_skybox(skybox_entry: Dictionary) -> void:
	rpc("set_skybox", skybox_entry)

# Request the server to set the room table.
# table_entry: The table's entry in the asset DB.
master func request_set_table(table_entry: Dictionary) -> void:
	rpc("set_table", table_entry)

# Request the server to get a stack to collect all of the pieces that it can
# stack.
# stack_name: The name of the collecting stack.
# collect_stacks: Do we want to collect other stacks? If false, it only collects
# individual pieces.
master func request_stack_collect_all(stack_name: String, collect_stacks: bool) -> void:
	var stack = _pieces.get_node(stack_name)

	if not stack:
		push_error("Stack " + stack_name + " does not exist!")
		return

	if not stack is Stack:
		push_error("Object " + stack_name + " is not a stack!")
		return

	for piece in get_pieces():
		if piece is StackablePiece and piece.name != stack_name:
			if stack.matches(piece):
				if piece is Stack:
					if collect_stacks:
						rpc("add_stack_to_stack", piece.name, stack_name)
					else:
						continue
				else:
					rpc("add_piece_to_stack", piece.name, stack_name, Stack.STACK_TOP)

# Called by the server to set a client's hovering pieces.
remote func set_client_hover_pieces(player_id: int, piece_names: Array) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_client_hover_pieces[player_id] = piece_names

# Request the server to set the hover position of multiple pieces - note that
# the pieces that are updated are defined when calling request_hover_pieces.
# hover_position: The new hover position.
master func set_hover_position_multiple(hover_position: Vector3) -> void:
	rpc_unreliable("set_hover_position_multiple_client",
		get_tree().get_rpc_sender_id(), hover_position)

# Called by the server to set the hover position of multiple pieces.
# player_id: The ID of the player updating the hover positions.
# hover_position: The new hover position.
remotesync func set_hover_position_multiple_client(player_id: int,
	hover_position: Vector3) -> void:
	
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var piece_names = _client_hover_pieces[player_id]
	
	for piece_name in piece_names:
		var piece = _pieces.get_node(piece_name)

		if not piece:
			push_error("Piece " + piece_name + " does not exist!")
			return

		if not piece is Piece:
			push_error("Object " + piece_name + " is not a piece!")
			return
		
		piece.set_hover_position(hover_position)

# Set the color of the room lamp.
# color: The color of the lamp.
remotesync func set_lamp_color(color: Color) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	_spot_light.light_color = color
	_sun_light.light_color = color

# Set the intensity of the room lamp.
# intensity: The new intensity of the lamp.
remotesync func set_lamp_intensity(intensity: float) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	_spot_light.light_energy = intensity
	_sun_light.light_energy = intensity

# Set the type of light the room lamp is emitting.
# sunlight: True for sunlight, false for a spotlight.
remotesync func set_lamp_type(sunlight: bool) -> void:
	_spot_light.visible = not sunlight
	_sun_light.visible = sunlight

# Set the room's skybox.
# skybox_entry: The skybox's entry in the asset DB. If either the texture path
# or the entry are empty, the default skybox is used.
remotesync func set_skybox(skybox_entry: Dictionary) -> void:
	if get_tree().has_network_peer():
		if get_tree().get_rpc_sender_id() != 1:
			return

	# Changing the skybox can take a long time if the radiance size is big, so
	# avoid doing it if the skybox being set is the same as the current skybox.
	if _world_environment.has_meta("skybox_entry"):
		var current_entry = _world_environment.get_meta("skybox_entry")
		if current_entry.hash() == skybox_entry.hash():
			return

	var skybox: Sky = ProceduralSky.new()
	if not skybox_entry.empty():
		if skybox_entry.has("texture_path"):
			var texture_path = skybox_entry["texture_path"]
			if not texture_path.empty():
				var texture: Texture = load(texture_path)
				skybox = PanoramaSky.new()
				skybox.panorama = texture

	var radiance = _world_environment.environment.background_sky.radiance_size
	skybox.radiance_size = radiance
	_world_environment.environment.background_sky = skybox

	_world_environment.environment.background_sky_rotation_degrees = skybox_entry["rotation"]
	_world_environment.environment.background_energy = skybox_entry["strength"]

	_world_environment.set_meta("skybox_entry", skybox_entry)

# Set the room state.
# state: The new room state.
func set_state(state: Dictionary) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return

	if state.has("lamp"):
		var lamp_meta = state["lamp"]
		set_lamp_color(lamp_meta["color"])
		set_lamp_intensity(lamp_meta["intensity"])
		set_lamp_type(lamp_meta["sunlight"])

	if state.has("skybox"):
		set_skybox(state["skybox"])

	if state.has("table"):
		var table_meta = state["table"]

		set_table(table_meta["entry"])

		if _table_body:
			if table_meta["is_rigid"]:
				_table_body.mode = RigidBody.MODE_RIGID
			else:
				_table_body.mode = RigidBody.MODE_STATIC

			_table_body.transform = table_meta["transform"]

		if table_meta["is_rigid"]:
			emit_signal("table_flipped")
		else:
			emit_signal("table_unflipped")
		if get_tree().is_network_server():
			srv_set_retrieve_pieces_from_hell(not table_meta["is_rigid"])

		var paint_image_data = table_meta["paint_image_data"]
		if paint_image_data == null:
			_paint_plane.clear_paint()
		else:
			var paint_image = Image.new()
			var paint_image_size = _paint_plane.get_paint_size()
			paint_image.create_from_data(paint_image_size.x, paint_image_size.y,
				false, _paint_plane.PAINT_FORMAT, paint_image_data)
			_paint_plane.set_paint(paint_image)

	if state.has("hands"):
		for hand in _hands.get_children():
			_hands.remove_child(hand)
			hand.queue_free()

		for hand_id in state["hands"]:
			var hand_name = str(hand_id)
			var hand_meta = state["hands"][hand_id]

			if not hand_meta.has("transform"):
				push_error("Hand " + hand_name + " in new state has no transform!")
				return

			if not hand_meta["transform"] is Transform:
				push_error("Hand " + hand_name + " transform is not a transform!")
				return

			add_hand(hand_id, hand_meta["transform"])

	if state.has("hidden_areas"):
		for hidden_area in _hidden_areas.get_children():
			_hidden_areas.remove_child(hidden_area)
			hidden_area.queue_free()

		for hidden_area_name in state["hidden_areas"]:
			# Make sure the server doesn't duplicate names! We need to do this
			# because hidden areas use the same naming system as pieces do.
			if get_tree().is_network_server():
				var name_int = int(hidden_area_name)
				if name_int >= _srv_next_piece_name:
					_srv_next_piece_name = name_int + 1

			var hidden_area_meta = state["hidden_areas"][hidden_area_name]

			if not hidden_area_meta.has("player_id"):
				push_error("Hidden area " + hidden_area_name + " in new state has no player ID!")
				return

			if not hidden_area_meta["player_id"] is int:
				push_error("Hidden area " + hidden_area_name + " player ID is not an integer!")
				return

			if not hidden_area_meta.has("point1"):
				push_error("Hidden area " + hidden_area_name + " in new state has no point 1!")
				return

			if not hidden_area_meta["point1"] is Vector2:
				push_error("Hidden area" + hidden_area_name + " point 1 is not a Vector2!")
				return

			if not hidden_area_meta.has("point2"):
				push_error("Hidden area " + hidden_area_name + " in new state has no point 2!")
				return

			if not hidden_area_meta["point2"] is Vector2:
				push_error("Hidden area" + hidden_area_name + " point 2 is not a Vector2!")
				return

			var player_id = hidden_area_meta["player_id"]
			var point1 = hidden_area_meta["point1"]
			var point2 = hidden_area_meta["point2"]
			place_hidden_area(hidden_area_name, player_id, point1, point2)

	for child in _pieces.get_children():
		_pieces.remove_child(child)
		child.queue_free()

	_extract_piece_states(state, _pieces)

	# Wait a few physics frames for the hands to detect the cards, then add the
	# cards to the hands.
	if get_tree().is_network_server():
		_srv_allow_card_stacking = false
		_srv_hand_setup_frames = 5

# Set the room state with a compressed version of a state.
# compressed_state: The compressed state from get_state_compressed().
remotesync func set_state_compressed(compressed_state: Dictionary) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if not compressed_state.has("data"):
		push_error("Compressed state does not contain data!")
		return
	
	if not compressed_state["data"] is PoolByteArray:
		push_error("Compressed state data is not a byte array!")
		return
	
	if not compressed_state.has("size"):
		push_error("Compressed state does not have size information!")
		return
	
	if not compressed_state["size"] is int:
		push_error("Compressed state size information is not an integer!")
		return
	
	var data = compressed_state["data"]
	var size = compressed_state["size"]
	
	var bytes = data.decompress(size, File.COMPRESSION_FASTLZ)
	var state = bytes2var(bytes)
	if state is Dictionary:
		set_state(state)
	else:
		push_error("Failed to decode the uncompressed state!")

# Set the room table.
# table_entry: The table's entry in the asset DB.
remotesync func set_table(table_entry: Dictionary) -> void:
	if get_tree().has_network_peer():
		if get_tree().get_rpc_sender_id() != 1:
			return

	if _table_body != null:
		# Changing the table can take a while if the model is very detailed,
		# so avoid doing it if the table being set is the same as the one
		# already in the room.
		if _table_body.has_meta("table_entry"):
			var current_entry = _table_body.get_meta("table_entry")
			if current_entry.hash() == table_entry.hash():
				return

		_table.remove_child(_table_body)
		_table_body.queue_free()
		_table_body = null

	for hand_pos in _hand_positions.get_children():
		_hand_positions.remove_child(hand_pos)
		hand_pos.queue_free()

	if not table_entry.empty():
		if table_entry.has("scene_path"):
			if not table_entry["scene_path"].empty():
				_table_body = PieceBuilder.build_table(table_entry)
				_table.add_child(_table_body)

				for hand_meta in table_entry["hands"]:
					var pos: Vector3 = hand_meta["pos"]
					var dir: float = deg2rad(hand_meta["dir"])

					var hand = Spatial.new()
					hand.transform = hand.transform.rotated(Vector3.UP, dir)
					hand.transform.origin = pos

					_hand_positions.add_child(hand)

	if get_tree().has_network_peer():
		if get_tree().is_network_server():
			srv_update_hand_transforms()

	var paint_plane_size = table_entry["paint_plane"]
	_paint_plane.scale = Vector3(paint_plane_size.x, 1.0, paint_plane_size.y)
	_paint_plane.clear_paint()

# Get the next hand transform. Note that there may not be a next transform, in
# which case the function returns the identity transform.
# Returns: The next hand transform.
func srv_get_next_hand_transform() -> Transform:
	var potential = []

	for position in _hand_positions.get_children():
		potential.append(position.transform)

	for hand in _hands.get_children():
		if potential.has(hand.transform):
			potential.erase(hand.transform)

	if potential.empty():
		return Transform.IDENTITY
	else:
		return potential[0]

# Get the next piece name.
# Returns: The next piece name.
func srv_get_next_piece_name() -> String:
	var next_name = str(_srv_next_piece_name)
	_srv_next_piece_name += 1
	return next_name

# Set whether the server should retrieve pieces from hell.
# retrieve: If the server should retrieve pieces from hell.
func srv_set_retrieve_pieces_from_hell(retrieve: bool) -> void:
	_srv_retrieve_pieces_from_hell = retrieve

	for piece in _pieces.get_children():
		if piece is Piece:
			piece.srv_retrieve_from_hell = retrieve

# Stop a player from currently hovering any pieces.
# player: The player to stop from hovering.
func srv_stop_player_hovering(player: int) -> void:
	for piece in _pieces.get_children():
		if piece.hover_player == player:
			piece.rpc_id(1, "request_stop_hovering")

# Update the transforms of the hands to match the table entry's hand positions.
func srv_update_hand_transforms() -> void:
	var hand_index = 0
	for hand in _hands.get_children():
		var hand_player = int(hand.name)
		if hand_index < _hand_positions.get_child_count():
			var hand_transform = _hand_positions.get_child(hand_index).transform
			hand.rpc("update_transform", hand_transform)
		else:
			rpc("remove_hand", hand_player)

		hand_index += 1

	var player_ids = Lobby.get_player_list()
	var next_transform = srv_get_next_hand_transform()
	while (not player_ids.empty()) and next_transform != Transform.IDENTITY:
		var player_id = player_ids.pop_front()
		if not _hands.has_node(str(player_id)):
			rpc("add_hand", player_id, next_transform)

		next_transform = srv_get_next_hand_transform()

# Start sending the player's 3D cursor position to the server.
func start_sending_cursor_position() -> void:
	_camera_controller.send_cursor_position = true

# Transfer the contents at the top of one stack to the top of another.
# stack1_name: The name of the stack to transfer contents from.
# stack2_name: The name of the stack to transfer contents to.
# n: The number of contents to transfer.
remotesync func transfer_stack_contents(stack1_name: String, stack2_name: String,
	n: int) -> void:

	if get_tree().get_rpc_sender_id() != 1:
		return

	var stack1 = _pieces.get_node(stack1_name)
	var stack2 = _pieces.get_node(stack2_name)

	if not stack1:
		push_error("Stack " + stack1_name + " does not exist!")
		return

	if not stack2:
		push_error("Stack " + stack2_name + " does not exist!")
		return

	if not stack1 is Stack:
		push_error("Piece " + stack1_name + " is not a stack!")
		return

	if not stack2 is Stack:
		push_error("Piece " + stack2_name + " is not a stack!")
		return

	n = int(min(n, stack1.get_piece_count()))
	if n < 1:
		return

	var contents = []
	for _i in range(n):
		var index = stack1.pop_index()
		contents.push_back(stack1.remove_piece(index))

	while not contents.empty():
		var piece_meta = contents.pop_back()
		var piece_entry = piece_meta["piece_entry"]
		var piece_transform = piece_meta["transform"]
		stack2.add_piece(piece_entry, piece_transform, Stack.STACK_TOP)

func _ready():
	var skybox = AssetDB.random_asset("TabletopClub", "skyboxes", true)
	if not skybox.empty():
		set_skybox(skybox)

	var table = AssetDB.random_asset("TabletopClub", "tables", true)
	if not table.empty():
		set_table(table)

func _physics_process(_delta):
	var timers_to_manage = _srv_undo_state_events.keys()

	for key in timers_to_manage:
		#if the timer is = 0, that means it's event is ready to add a state
		if _srv_undo_state_events[key] <= 0:
			pass
		#if a timer is != 0, that means it is waiting until it is ready to add a state again
		else:
			_srv_undo_state_events[key] -= _delta	#this is so that the timer is accurate even if the physics frames last longer than expected

	if not get_tree().has_network_peer():
		return

	if get_tree().is_network_server():
		# TODO: This does not need to be done every frame, find a way to run
		# this just whenever the number of active pieces changes.
		_srv_update_bandwidth_throttle()
		
		if _srv_hand_setup_frames >= 0:
			_srv_hand_setup_frames -= 1

			if _srv_hand_setup_frames == 0:
				for piece in _pieces.get_children():
					if piece is Card:
						if piece.over_hand > 0:
							var hand_name = str(piece.over_hand)
							if _hands.has_node(hand_name):
								var hand = _hands.get_node(hand_name)
								var ok = hand.srv_add_card(piece)
								if not ok:
									push_error("Failed to add card %s to the hand of player %s!" %
										[piece.name, hand_name])

				_srv_allow_card_stacking = true

# Append the states of pieces to a given dictionary.
# state: The dictionary to add the states to.
# pieces: The list of pieces to scan from.
# collisions: Should collision data be included in the state?
func _append_piece_states(state: Dictionary, pieces: Array, collisions: bool) -> void:
	state["containers"] = {}
	state["pieces"] = {}
	state["speakers"] = {}
	state["stacks"] = {}
	state["timers"] = {}

	for piece in pieces:
		var piece_meta = {
			"is_locked": piece.is_locked(),
			"piece_entry": piece.piece_entry,
			"transform": piece.transform
		}

		if piece.is_albedo_color_exposed():
			var color = piece.get_albedo_color()
			if piece.piece_entry["color"] != color:
				piece_meta["color"] = color

		if piece is PieceContainer:
			var child_pieces = {}
			if piece.has_node("Pieces"):
				var children = piece.get_node("Pieces").get_children()
				_append_piece_states(child_pieces, children, collisions)

			piece_meta["pieces"] = child_pieces
			state["containers"][piece.name] = piece_meta

		elif piece is Stack:
			# If the piece is a stack, we don't need to store the stack's piece
			# entry, as it will figure it out itself once the first piece is
			# added.
			piece_meta.erase("piece_entry")

			var child_pieces = []
			for child_piece in piece.get_pieces():
				var child_piece_meta = {
					"flip_y": child_piece["flip_y"],
					"piece_entry": child_piece["piece_entry"]
				}

				child_pieces.push_back(child_piece_meta)

			piece_meta["pieces"] = child_pieces
			state["stacks"][piece.name] = piece_meta

		elif piece is SpeakerPiece or piece is TimerPiece:
			piece_meta["is_music_track"] = piece.is_music_track()
			piece_meta["is_playing"] = piece.is_playing_track()
			piece_meta["is_track_paused"] = piece.is_track_paused()
			piece_meta["playback_position"] = piece.get_playback_position()
			piece_meta["track_entry"] = piece.get_track()
			piece_meta["unit_size"] = piece.get_unit_size()

			if piece is TimerPiece:
				piece_meta["is_timer_paused"] = piece.is_timer_paused()
				piece_meta["mode"] = piece.get_mode()
				piece_meta["time"] = piece.get_time()

				state["timers"][piece.name] = piece_meta
			else:
				state["speakers"][piece.name] = piece_meta

		else:
			if collisions:
				if piece is Card:
					piece_meta["is_collisions_on"] = piece.is_collisions_on()

			state["pieces"][piece.name] = piece_meta

# Extract the pieces from a room state, and add them to the scene tree.
# state: The state to extract the pieces from.
# parent: The node to add the pieces to as children.
func _extract_piece_states(state: Dictionary, parent: Node) -> void:
	_extract_piece_states_type(state, parent, "containers")
	_extract_piece_states_type(state, parent, "pieces")
	_extract_piece_states_type(state, parent, "speakers")
	_extract_piece_states_type(state, parent, "stacks")
	_extract_piece_states_type(state, parent, "timers")

# A helper function when extracting piece states from a room state.
# state: The state to extract the pieces from.
# parent: The node to add the pieces to as children.
# type_key: The key to extract from the state.
func _extract_piece_states_type(state: Dictionary, parent: Node, type_key: String) -> void:
	if not state.has(type_key):
		return

	for piece_name in state[type_key]:
		var piece_meta = state[type_key][piece_name]

		# Make sure the server doesn't duplicate piece names!
		if get_tree().is_network_server():
			var name_int = int(piece_name)
			if name_int >= _srv_next_piece_name:
				_srv_next_piece_name = name_int + 1

		if not piece_meta.has("is_locked"):
			push_error("Piece " + type_key + "/" + piece_name + " in new state has no is locked value!")
			return

		if not piece_meta["is_locked"] is bool:
			push_error("Piece " + type_key + "/" + piece_name + " is locked value is not a boolean!")
			return

		if not piece_meta.has("transform"):
			push_error("Piece " + type_key + "/" + piece_name + " in new state has no transform!")
			return

		if not piece_meta["transform"] is Transform:
			push_error("Piece " + type_key + "/" + piece_name + " transform is not a transform!")
			return

		# Stacks don't include their piece entry, since they can figure it out
		# themselves once the first piece is added.
		if type_key != "stacks":
			if not piece_meta.has("piece_entry"):
				push_error("Piece " + type_key + "/" + piece_name + " in new state has no piece entry!")
				return

			if not piece_meta["piece_entry"] is Dictionary:
				push_error("Piece " + type_key + "/" + piece_name + " entry is not a dictionary!")
				return

		if type_key == "stacks":
			var pieces: Array = piece_meta["pieces"]
			if pieces.empty():
				push_error("Piece " + type_key + "/" + piece_name + " has an empty 'pieces' array!")
				return
			var element_meta: Dictionary = pieces[0]
			if not element_meta.has("piece_entry"):
				push_error("Piece " + type_key + "/" + piece_name + " element meta has no piece entry!")
				return
			var piece_entry: Dictionary = element_meta["piece_entry"]

			var sandwich_stack = (piece_entry["scene_path"] == "res://Pieces/Card.tscn")
			add_stack_empty(piece_name, piece_meta["transform"], sandwich_stack)
		else:
			add_piece(piece_name, piece_meta["transform"], piece_meta["piece_entry"])

		var piece: Piece = _pieces.get_node(piece_name)
		if piece_meta["is_locked"]:
			piece.lock_client(piece_meta["transform"])

		if piece_meta.has("color"):
			if not piece_meta["color"] is Color:
				push_error("Piece " + type_key + "/" + piece_name + " color is not a color!")
				return

			var color = piece_meta["color"]
			if piece.is_albedo_color_exposed():
				piece.set_albedo_color_client(color)

		if type_key == "containers":
			if not piece_meta.has("pieces"):
				push_error("Container piece does not have a pieces entry!")
				return

			if not piece_meta["pieces"] is Dictionary:
				push_error("Container pieces entry is not a dictionary!")
				return

			_extract_piece_states(piece_meta["pieces"], piece.get_node("Pieces"))
			if piece is PieceContainer:
				piece.recalculate_mass()

		elif type_key == "piece":
			if piece is Card:
				# The state can choose not to have this data.
				if piece_meta.has("is_collisions_on"):
					if not piece_meta["is_collisions_on"] is bool:
						push_error("Card " + piece_name + " collisions on is not a boolean!")
						return

					piece.set_collisions_on(piece_meta["is_collisions_on"])

		elif type_key == "stacks":
			for stack_piece_meta in piece_meta["pieces"]:

				if not stack_piece_meta is Dictionary:
					push_error("Stack piece is not a dictionary!")
					return

				if not stack_piece_meta.has("flip_y"):
					push_error("Stack piece does not have a flip value!")
					return

				if not stack_piece_meta["flip_y"] is bool:
					push_error("Stack piece flip value is not a boolean!")
					return

				if not stack_piece_meta.has("piece_entry"):
					push_error("Stack piece does not have a piece entry!")
					return

				if not stack_piece_meta["piece_entry"] is Dictionary:
					push_error("Stack piece entry is not a dictionary!")
					return

				var stack_piece_entry = stack_piece_meta["piece_entry"]

				# Add it to the stack at the top (since we're going through the
				# list in order from bottom to top).
				var flip = Stack.FLIP_NO
				if stack_piece_meta["flip_y"]:
					flip = Stack.FLIP_YES

				piece.add_piece(stack_piece_entry, Transform.IDENTITY,
					Stack.STACK_TOP, flip)

		elif type_key == "speakers" or type_key == "timers":
			if not piece_meta.has("is_music_track"):
				push_error("Speaker " + piece_name + " does not have an is music track value!")
				return

			if not piece_meta["is_music_track"] is bool:
				push_error("Speaker " + piece_name + " is music track value is not a boolean!")
				return

			if not piece_meta.has("is_playing"):
				push_error("Speaker " + piece_name + " does not have an is playing value!")
				return

			if not piece_meta["is_playing"] is bool:
				push_error("Speaker " + piece_name + " is playing value is not a boolean!")
				return

			if not piece_meta.has("is_track_paused"):
				push_error("Speaker " + piece_name + " does not have an is track paused value!")
				return

			if not piece_meta["is_track_paused"] is bool:
				push_error("Speaker " + piece_name + " is track paused value is not a boolean!")
				return

			if not piece_meta.has("playback_position"):
				push_error("Speaker " + piece_name + " does not have a playback position value!")
				return

			if not piece_meta["playback_position"] is float:
				push_error("Speaker " + piece_name + " playback position value is not a float!")
				return

			if not piece_meta.has("track_entry"):
				push_error("Speaker " + piece_name + " does not have a track entry!")
				return

			if not piece_meta["track_entry"] is Dictionary:
				push_error("Speaker " + piece_name + " track entry is not a dictionary!")
				return

			if not piece_meta.has("unit_size"):
				push_error("Speaker " + piece_name + " does not have a unit size value!")
				return

			if not piece_meta["unit_size"] is float:
				push_error("Speaker " + piece_name + " unit size value is not a float!")
				return

			if piece is SpeakerPiece:
				piece.set_track(piece_meta["track_entry"], piece_meta["is_music_track"])
				piece.set_unit_size(piece_meta["unit_size"])

				if piece_meta["is_playing"]:
					piece.play_track(piece_meta["playback_position"])

				if piece_meta["is_track_paused"]:
					piece.pause_track(piece_meta["playback_position"])

			if type_key == "timers":
				if not piece_meta.has("is_timer_paused"):
					push_error("Timer " + piece_name + " does not have an is timer paused value!")
					return

				if not piece_meta["is_timer_paused"] is bool:
					push_error("Timer " + piece_name + " is timer paused value is not a boolean!")
					return

				if not piece_meta.has("mode"):
					push_error("Timer " + piece_name + " does not have a mode value!")
					return

				if not piece_meta["mode"] is int:
					push_error("Timer " + piece_name + " mode value is not an integer!")
					return

				if not piece_meta.has("time"):
					push_error("Timer " + piece_name + " does not have a time value!")
					return

				if not piece_meta["time"] is float:
					push_error("Timer " + piece_name + " time value is not a float!")
					return

				if piece is TimerPiece:
					piece.set_mode(piece_meta["mode"])
					if piece_meta["is_timer_paused"]:
						piece.pause_timer_at(piece_meta["time"])
					else:
						piece.set_time(piece_meta["time"])

		# Finally, we may need to move the piece in the scene tree so it has a
		# different parent.
		if parent != _pieces:
			_pieces.remove_child(piece)
			parent.add_child(piece)

# Modify piece states such that the pieces have new names, and their positions
# are offset by a given amount.
# state: The state to modify.
# offset: How much to offset the piece's positions by.
func _modify_piece_states(state: Dictionary, offset: Vector3) -> void:
	for type in state:
		var type_dict = state[type]
		if type_dict is Dictionary:
			var names = type_dict.keys()
			for name in names:
				var piece_meta = type_dict[name]

				# If the piece is a container, we need to also modify the
				# container's contents.
				if type == "containers":
					if piece_meta.has("pieces"):
						var pieces = piece_meta["pieces"]
						if pieces is Dictionary:
							_modify_piece_states(pieces, Vector3.ZERO)

				# Offset the position.
				if piece_meta.has("transform"):
					var piece_transform = piece_meta["transform"]
					if piece_transform is Transform:
						piece_transform.origin += offset
						piece_meta["transform"] = piece_transform

				# Give the piece a new name.
				type_dict.erase(name)
				type_dict[srv_get_next_piece_name()] = piece_meta

# Set the transform of a hidden area based on two corner points.
# hidden_area: The hidden area to set the transform of.
# point1: One corner.
# point2: The opposite corner.
func _set_hidden_area_transform(hidden_area: HiddenArea, point1: Vector2, point2: Vector2) -> void:
	var min_point = Vector2(min(point1.x, point2.x), min(point1.y, point2.y))
	var max_point = Vector2(max(point1.x, point2.x), max(point1.y, point2.y))
	var avg_point = 0.5 * (min_point + max_point)
	var point_dif = max_point - min_point

	hidden_area.transform.origin.x = avg_point.x
	hidden_area.transform.origin.z = avg_point.y

	# We're assuming here that the hidden area is never rotated.
	hidden_area.transform.basis.x.x = point_dif.x / 2
	hidden_area.transform.basis.z.z = point_dif.y / 2

# Update the rate at which state updates are sent to the client, based on the
# number of active pieces in the room.
func _srv_update_bandwidth_throttle() -> void:
	# TODO: Instead of using the total number of pieces, use the number of
	# pieces that are NOT sleeping. This could be done with
	# PhysicsServer.get_process_info, but it has not been implemented with the
	# Bullet physics engine.
	# See: https://github.com/godotengine/godot/issues/59279
	var physics_frames_per_update = floor(1.0 + _pieces.get_child_count() / Global.SRV_PIECE_UPDATE_TRANSMIT_LIMIT)
	if Global.srv_num_physics_frames_per_state_update != physics_frames_per_update:
		Global.srv_num_physics_frames_per_state_update = physics_frames_per_update
		print("State update rate set to %dHz." % (60 / physics_frames_per_update))

func _on_container_absorbing_hovered(container: PieceContainer, player_id: int) -> void:
	if get_tree().is_network_server():
		var names = []
		var main: Piece = null

		# TODO: Optimize this by using groups?
		for piece in _pieces.get_children():
			if piece is Piece:
				if piece.hover_player == player_id:
					names.append(piece.name)
					if piece.hover_offset == Vector3.ZERO:
						main = piece

		if main != null:
			# If there is a lot of space inbetween the container and the main
			# piece the player is hovering, then it's possible that another
			# piece bumped into the container by accident, so only add the
			# pieces is the main piece is close to the container.
			var distance = (container.transform.origin - main.transform.origin).length()
			var container_radius = container.get_radius()
			var piece_radius = main.get_radius()

			var space = distance - container_radius - piece_radius
			if space > 15.0:
				return

		request_add_pieces_to_container(container.name, names)

func _on_container_releasing_random_piece(container: PieceContainer) -> void:
	if get_tree().is_network_server():
		rpc_id(1, "request_container_release_random", container.name, 1, false)

func _on_piece_exiting_tree(piece: Piece) -> void:
	if get_tree().is_network_server() and _srv_events_add_states:
		#if not waiting for a timer or disabled because set_state wil be called
		if _srv_undo_state_events["remove_piece"] <= 0:
			push_undo_state()	#make host add an undo state
		_srv_undo_state_events["remove_piece"] = UNDO_STATE_EVENT_TIMERS["remove_piece"]	#if they trigger this again before timer is done, reset the timer

	_camera_controller.erase_selected_pieces(piece)

func _on_stack_requested(piece1: StackablePiece, piece2: StackablePiece) -> void:
	if get_tree().is_network_server():
		if not _srv_allow_card_stacking:
			if piece1 is Card or piece2 is Card:
				return

		if piece1 is Stack and piece2 is Stack:
			rpc("add_stack_to_stack", piece1.name, piece2.name)
		elif piece1 is Stack:
			rpc("add_piece_to_stack", piece2.name, piece1.name)
		elif piece2 is Stack:
			rpc("add_piece_to_stack", piece1.name, piece2.name)
		else:
			rpc("add_stack", srv_get_next_piece_name(), piece1.transform, piece1.name,
				piece2.name)

# Called by the server when the undo stack is empty.
remotesync func _on_undo_stack_empty():
	emit_signal("undo_stack_empty")

# Called by the server when the undo stack is pushed to.
remotesync func _on_undo_stack_pushed():
	emit_signal("undo_stack_pushed")

func _on_CameraController_adding_cards_to_hand(cards: Array, id: int):
	var names = []
	for card in cards:
		if card.get("over_hand") != null:
			names.append(card.name)

	if id > 0:
		rpc_id(1, "request_add_cards_to_hand", names, id)
	else:
		rpc_id(1, "request_add_cards_to_nearest_hand", names)

func _on_CameraController_adding_pieces_to_container(container: PieceContainer, pieces: Array):
	var piece_names = []
	for piece in pieces:
		if piece != container:
			piece_names.append(piece.name)
	rpc_id(1, "request_add_pieces_to_container", container.name, piece_names)

func _on_CameraController_clipboard_paste(position: Vector3):
	# If we are the server, then duplicate the clipboard contents, as the
	# request will modify the contents by reference otherwise.
	var clipboard = _camera_controller.clipboard_contents
	if get_tree().is_network_server():
		clipboard = clipboard.duplicate(true)

	var offset = position - _camera_controller.clipboard_yank_position

	rpc_id(1, "request_paste_clipboard", clipboard, offset)

func _on_CameraController_clipboard_yank(pieces: Array):
	_append_piece_states(_camera_controller.clipboard_contents, pieces, false)

func _on_CameraController_collect_pieces_requested(pieces: Array):
	var names = []
	for piece in pieces:
		if piece is StackablePiece:
			names.append(piece.name)
	rpc_id(1, "request_collect_pieces", names)

func _on_CameraController_container_release_random_requested(container: PieceContainer, n: int):
	rpc_id(1, "request_container_release_random", container.name, n, true)

func _on_CameraController_container_release_these_requested(container: PieceContainer, names: Array):
	var good_names = []
	for check_name in names:
		if check_name is String:
			if container.has_piece(check_name):
				good_names.append(check_name)
	rpc_id(1, "request_container_release_these", container.name, good_names, true)

func _on_CameraController_dealing_cards(stack: Stack, n: int):
	rpc_id(1, "request_deal_cards", stack.name, n)

func _on_CameraController_erasing(position: Vector3, size: float):
	_paint_plane.rpc_unreliable_id(1, "request_push_paint_queue", position,
		Color.transparent, size)

func _on_CameraController_hover_piece_requested(piece: Piece):
	rpc_id(1, "request_hover_piece", piece.name,
		_camera_controller.get_hover_position(), Vector3.ZERO)

func _on_CameraController_hover_pieces_requested(pieces: Array, offsets: Array):
	var names = []
	for piece in pieces:
		if piece is Piece:
			names.append(piece.name)
	
	if names.size() != offsets.size():
		push_error("Name and offset arrays differ in size (name = %d, offset = %d)!" % [names.size(), offsets.size()])
		return
	
	rpc_id(1, "request_hover_pieces", names,
		_camera_controller.get_hover_position(), offsets)

func _on_CameraController_painting(position: Vector3, color: Color, size: float):
	_paint_plane.rpc_unreliable_id(1, "request_push_paint_queue", position,
		color, size)

func _on_CameraController_placing_hidden_area(point1: Vector2, point2: Vector2):
	rpc_id(1, "request_place_hidden_area", point1, point2)

func _on_CameraController_pop_stack_requested(stack: Stack, n: int):
	rpc_id(1, "request_pop_stack", stack.name, n, true, 1.0)

func _on_CameraController_removing_hidden_area(hidden_area: HiddenArea):
	if _hidden_areas.is_a_parent_of(hidden_area):
		rpc_id(1, "request_remove_hidden_area", hidden_area.name)

func _on_CameraController_selecting_all_pieces():
	var pieces = _pieces.get_children()
	_camera_controller.append_selected_pieces(pieces)

func _on_CameraController_setting_hidden_area_preview_points(point1: Vector2, point2: Vector2):
	_set_hidden_area_transform(_hidden_area_preview, point1, point2)

func _on_CameraController_setting_hidden_area_preview_visible(is_visible: bool):
	_hidden_area_preview.visible = is_visible
	_hidden_area_preview.collision_layer = 1 if is_visible else 2

func _on_CameraController_setting_hover_position_multiple(position: Vector3):
	rpc_unreliable_id(1, "set_hover_position_multiple", position)

func _on_CameraController_setting_spawn_point(position: Vector3):
	emit_signal("setting_spawn_point", position)

func _on_CameraController_spawning_piece_at(position: Vector3):
	emit_signal("spawning_piece_at", position)

func _on_CameraController_spawning_piece_in_container(container_name: String):
	emit_signal("spawning_piece_in_container", container_name)

func _on_CameraController_stack_collect_all_requested(stack: Stack, collect_stacks: bool):
	rpc_id(1, "request_stack_collect_all", stack.name, collect_stacks)

func _on_GameUI_clear_pieces():
	for piece in _pieces.get_children():
		if piece is Piece:
			piece.rpc_id(1, "request_remove_self")

func _on_GameUI_rotation_amount_updated(rotation_amount: float):
	_camera_controller.set_piece_rotation_amount(rotation_amount)

func _on_GameUI_undo_state():
	rpc_id(1, "pop_undo_state")
