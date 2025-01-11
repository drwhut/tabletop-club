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

extends Spatial

## Handles all room logic, which mostly consists of 3D elements.


onready var piece_manager: PieceManager = $PieceManager

onready var _hidden_area_manager := $HiddenAreaManager
onready var _light_manager := $LightManager
onready var _room_environment := $RoomEnvironment
onready var _table_manager := $TableManager


func _ready():
	Lobby.connect("player_added", self, "_on_Lobby_player_added")
	
	DataBroadcaster.connect("transfer_complete", self,
			"_on_DataBroadcaster_transfer_complete")
	
	# Look through the command-line arguments to see if "--preload" was passed
	# with a path to a save file.
	var cmdline_args := OS.get_cmdline_args()
	var preload_index := cmdline_args.find("--preload")
	if preload_index < 0:
		return
	
	# Need at least one more string after the argument.
	if preload_index == cmdline_args.size() - 1:
		push_error("--preload requires a file path to a *.tc file")
		return
	
	var state_file_path: String = cmdline_args[preload_index + 1]
	# TODO: Add requirement for the extension to be *.tc?
	
	print("Room: Pre-loading state from '%s' ..." % state_file_path)
	var state := StateLoader.load(state_file_path)
	if state != null:
		set_state(state)


## Get the state of the room as a [RoomState].
## TODO: May also want to get hand positions, handle this in both get_state and
## set_state.
func get_state() -> RoomState:
	var state := RoomState.new()
	
	state.lamp_color = _light_manager.light_color
	state.lamp_intensity = _light_manager.light_intensity
	state.is_lamp_sunlight = _light_manager.sun_light_enabled
	
	# TODO: How best to deal with null being returned here? Within the struct
	# itself, or elsewhere, i.e. the StateLoader/StateSaver?
	state.skybox_entry = _room_environment.get_skybox()
	
	state.table_entry = _table_manager.get_table()
	state.table_transform = _table_manager.table_transform
	# TODO: Set state.is_table_rigid.
	
	state.table_paint_image = null
	var paint_plane = _table_manager.get_paint_plane()
	if paint_plane != null:
		var paint_viewport: Viewport = paint_plane.paint_viewport
		var paint_image: Image = paint_viewport.get_image()
		
		# Only put the image into the state if it has colour within it...
		# otherwise we can just set it to null to save on memory and bandwidth.
		if not paint_image.is_invisible():
			state.table_paint_image = paint_image
	
	state.hidden_area_states = _hidden_area_manager.get_hidden_area_state_all()
	state.piece_states = piece_manager.get_piece_state_all()
	
	return state


## Set the state of the room with a [RoomState].
func set_state(state: RoomState) -> void:
	_light_manager.light_color = state.lamp_color
	_light_manager.light_intensity = state.lamp_intensity
	_light_manager.sun_light_enabled = state.is_lamp_sunlight
	
	_room_environment.set_skybox(state.skybox_entry)
	
	_table_manager.set_table(state.table_entry)
	# Don't set the table's transform if it hasn't been flipped.
	#_table_manager.set_table_transform(state.table_transform)
	# TODO: Set if the table is rigid or not.
	
	# TODO: If there is no image, clear the paint viewport.
	if state.table_paint_image != null:
		var paint_plane = _table_manager.get_paint_plane()
		if paint_plane != null:
			paint_plane.paint_viewport.set_image(state.table_paint_image)
	
	_hidden_area_manager.remove_all_children()
	for element in state.hidden_area_states:
		var hidden_area_state: HiddenAreaState = element
		_hidden_area_manager.add_hidden_area(
				_hidden_area_manager.get_next_index(),
				hidden_area_state.transform)
	
	# TODO: Need to think about multiplayer when calling this function,
	# we may want to provide an argument that chooses whether we queue_free()
	# the pieces, or put them in limbo - and we will need to re-name pieces
	# that are about to be overwritten.
	piece_manager.remove_all_children()
	for element in state.piece_states:
		var piece_state: PieceState = element
		if piece_state.scene_entry == null:
			continue
		
		# TODO: Use the piece index given to us by the state. Make sure a node
		# doesn't already exist with the same name.
		var piece := piece_manager.add_piece(piece_manager.get_next_index(),
				piece_state.scene_entry, piece_state.transform)
		
		piece.set_user_albedo(piece_state.user_albedo)
		piece.set_user_scale(piece_state.user_scale)


## Same as [method get_state], but instead of returning a [RoomState], the
## structure is converted into a dictionary with [StateSaver] and compressed
## with the FastLZ algorithm, and placed in a [PartialData] which contains
## information about the uncompressed size of the data.
func get_state_compressed() -> PartialData:
	var room_state := get_state()
	var room_dict := StateSaver.state_to_dict(room_state)
	var room_bytes := var2bytes(room_dict, false)
	var uncompressed_size := room_bytes.size()
	
	room_bytes = room_bytes.compress(File.COMPRESSION_FASTLZ)
	var compressed_size := room_bytes.size()
	
	var data := PartialData.new()
	# TODO: Change name depending on if this is a RoomStateMultiplayer or not.
	data.name = "state" + str(OS.get_ticks_usec())
	data.type = PartialData.TYPE_STATE
	data.size_uncompressed = uncompressed_size
	data.size_compressed = compressed_size
	data.bytes = room_bytes
	return data


## Same as [method set_state], but instead of using a [RoomState], it uses a
## [PartialData] which contains compressed byte array, either from a file or
## from a transfer over the network, e.g. DataBroadcaster.
func set_state_compressed(state_data: PartialData) -> void:
	var byte_data := state_data.bytes
	byte_data = byte_data.decompress(state_data.size_uncompressed,
			File.COMPRESSION_FASTLZ)
	
	# Convert the byte data into a Godot dictionary, which we can then convert
	# into a RoomState to use with set_state.
	var state_dict = bytes2var(byte_data, false)
	if typeof(state_dict) != TYPE_DICTIONARY:
		push_error("Uncompressed state data is not a dictionary")
		return
	
	var room_state := StateLoader.dict_to_state(state_dict)
	set_state(room_state)


func _on_Lobby_player_added(player: Player):
	if not get_tree().is_network_server():
		return
	
	if player.id == 1:
		return
	
	# If we are the server, we need to transfer the current state of the room
	# to the new player so they are in sync with the rest of the lobby.
	var transfer_plan := TransferPlanState.new()
	transfer_plan.receiver_ids = [ player.id ]
	
	DataBroadcaster.add_to_queue(transfer_plan)


# NOTE: As the server, we need a way to be able to distinguish between states
# that we generated ourselves to send to new players, vs. ones that are fresh
# from clients that we need to set. Maybe this is shown via the transfer name,
# or using a flag within this class?
# NOTE: This also depends on whether the byte data contains hand positions or
# not, i.e. is it a RoomStateMultiplayer? Although we shouldn't need to
# decompress the data as the server to check this - but the clients will need
# to know the difference. Maybe the data name is the way forward.
func _on_DataBroadcaster_transfer_complete(data: PartialData):
	if get_tree().is_network_server():
		return
	
	if data.type != PartialData.TYPE_STATE:
		return
	
	set_state_compressed(data)
