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

class_name StateLoader
extends Reference

## Load [code]*.tc[/code] files as [RoomState] resources.
##
## This class also includes helper functions for converting a [Dictionary] to
## a [RoomState], which may be used to help load states sent from the network.


## Convert a state in dictionary form to a [RoomState] resource.
static func dict_to_state(dict: Dictionary) -> RoomState:
	var state := RoomState.new()
	var dict_parser := DictionaryParser.new(dict)
	
	# If the dictionary contains information about player's hands, then we need
	# to include it by re-instancing the state to a subclass.
	if dict.has("hands"):
		var multiplayer_state := RoomStateMultiplayer.new()
		
		var hand_dict: Dictionary = dict_parser.get_strict_type("hands", {})
		for owner_id in hand_dict:
			if not owner_id is int:
				push_error("Invalid data type for hand owner ID in state (expected: Integer, got: %s)" %
						SanityCheck.get_type_name(typeof(owner_id)))
				continue
			
			var hand_detail_dict = hand_dict[owner_id]
			if not hand_detail_dict is Dictionary:
				push_error("Invalid data type for hand data in state (expected: Dictionary, got: %s)" %
						SanityCheck.get_type_name(typeof(hand_detail_dict)))
				continue
			
			var hand_state := HandState.new()
			hand_state.player_id = owner_id
			
			var hand_detail_parser := DictionaryParser.new(hand_detail_dict)
			hand_state.transform = hand_detail_parser.get_strict_type(
					"transform", hand_state.transform)
			
			multiplayer_state.player_hand_states.push_back(hand_state)
		
		# Cheeky workaround so we get full auto-completion for the new state.
		state = multiplayer_state
	
	var lamp_dict: Dictionary = dict_parser.get_strict_type("lamp", {})
	var lamp_parser := DictionaryParser.new(lamp_dict)
	
	state.lamp_color = lamp_parser.get_strict_type("color", state.lamp_color)
	state.lamp_intensity = lamp_parser.get_strict_type("intensity",
			state.lamp_intensity)
	state.is_lamp_sunlight = lamp_parser.get_strict_type("sunlight",
			state.is_lamp_sunlight)
	
	var skybox_entry_path: String = dict_parser.get_strict_type("skybox",
			state.skybox_entry.get_path())
	var skybox_entry := AssetDB.get_entry(skybox_entry_path) as AssetEntrySkybox
	if skybox_entry != null:
		state.skybox_entry = skybox_entry
	else:
		push_error("Missing skybox entry '%s'" % skybox_entry_path)
	
	var table_dict: Dictionary = dict_parser.get_strict_type("table", {})
	var table_parser := DictionaryParser.new(table_dict)
	
	var table_entry_path: String = table_parser.get_strict_type("entry_path",
			state.table_entry.get_path())
	var table_entry := AssetDB.get_entry(table_entry_path) as AssetEntryTable
	if table_entry != null:
		state.table_entry = table_entry
	else:
		push_error("Missing table entry '%s'" % table_entry_path)
	
	state.table_transform = table_parser.get_strict_type("transform",
			state.table_transform)
	state.is_table_rigid = table_parser.get_strict_type("is_rigid",
			state.is_table_rigid)
	
	var paint_image_data = table_dict.get("paint_image_data")
	if paint_image_data is PoolByteArray:
		# TODO: Use values from PaintPlane class once it is made.
		var paint_image := Image.new()
		paint_image.create_from_data(512, 512, false, Image.FORMAT_RGBA8,
				paint_image_data)
		state.table_paint_image = paint_image
	else:
		state.table_paint_image = null
	
	# Since the array is exported, we may need to create a new array if the
	# engine has decided that this array, and the piece state array should share
	# the same reference.
	state.hidden_area_states = []
	state.piece_states = []
	
	var hidden_area_dict: Dictionary = dict_parser.get_strict_type(
			"hidden_areas", {})
	for hidden_area_id in hidden_area_dict:
		var hidden_area_index := 0
		
		match typeof(hidden_area_id):
			TYPE_INT:
				hidden_area_index = hidden_area_id
			TYPE_STRING: # Backwards compatibility with v0.1.x!
				if hidden_area_id.is_valid_integer():
					hidden_area_index = int(hidden_area_id)
				else:
					push_error("ID of hidden area '%s' is invalid" % hidden_area_id)
					continue
			_:
				push_error("Hidden area ID is invalid data type (expected: Integer, got: %s)" %
						SanityCheck.get_type_name(typeof(hidden_area_id)))
				continue
		
		var hidden_area_detail_dict = hidden_area_dict[hidden_area_id]
		if not hidden_area_detail_dict is Dictionary:
			push_error("Invalid data type for hidden area data (expected: Dictionary, got: %s)" %
					SanityCheck.get_type_name(typeof(hidden_area_detail_dict)))
			continue
		
		var hidden_area_state := HiddenAreaState.new()
		hidden_area_state.index_id = hidden_area_index
		
		var detail_parser := DictionaryParser.new(hidden_area_detail_dict)
		hidden_area_state.player_id = detail_parser.get_strict_type("player_id",
				hidden_area_state.player_id)
		
		if hidden_area_detail_dict.has("transform"):
			hidden_area_state.transform = detail_parser.get_strict_type(
					"transform", hidden_area_state.transform)
		
		else: # Backwards compatibility with v0.1.x!
			var point1: Vector2 = detail_parser.get_strict_type("point1",
					Vector2.ZERO)
			var point2: Vector2 = detail_parser.get_strict_type("point2",
					Vector2.ZERO)
			
			# The two points represent two opposite corners of the hidden area,
			# with the y-axis emitted and assumed to be y=0.
			# TODO: Move this to a static function in the hidden area class?
			var hidden_area_transform := Transform.IDENTITY
			
			var min_point = Vector2(min(point1.x, point2.x), min(point1.y, point2.y))
			var max_point = Vector2(max(point1.x, point2.x), max(point1.y, point2.y))
			var avg_point = 0.5 * (min_point + max_point)
			var point_dif = max_point - min_point
			
			hidden_area_transform.origin = Vector3(avg_point.x, 5.0, avg_point.y)
			
			# In v0.1.x, the player could not rotate the hidden area.
			hidden_area_transform.basis = Basis.IDENTITY.scaled(Vector3(
					point_dif.x / 2.0, 5.0, point_dif.y / 2.0))
			
			hidden_area_state.transform = hidden_area_transform
		
		state.hidden_area_states.push_back(hidden_area_state)
	
	extract_piece_states(dict, state.piece_states)
	
	return state


## A helper function for [method dict_to_state] - given a [RoomState] in
## dictionary form, extract the piece states of all possible types and place the
## generated [PieceState] resources at the end of the output array.
static func extract_piece_states(dict: Dictionary, out: Array) -> void:
	extract_piece_states_of_type(dict, out, "containers")
	extract_piece_states_of_type(dict, out, "pieces")
	extract_piece_states_of_type(dict, out, "speakers")
	extract_piece_states_of_type(dict, out, "stacks")
	extract_piece_states_of_type(dict, out, "timers")


## A helper function for [method dict_to_state] - given a [RoomState] in
## dictionary form, extract the piece states of the given type and place the
## generated [PieceState] resources at the end of the output array.
static func extract_piece_states_of_type(dict: Dictionary, out: Array,
		type: String) -> void:
	
	var dict_parser := DictionaryParser.new(dict)
	var type_dict: Dictionary = dict_parser.get_strict_type(type, {})
	
	for piece_name in type_dict:
		var piece_index := 0
		
		match typeof(piece_name):
			TYPE_INT:
				piece_index = piece_name
			TYPE_STRING: # Backwards compatibility with v0.1.x!
				if piece_name.is_valid_integer():
					piece_index = int(piece_name)
				else:
					push_error("ID of piece '%s' is invalid" % piece_name)
					continue
			_:
				push_error("Piece ID is invalid data type (expected: Integer, got: %s)" %
						SanityCheck.get_type_name(typeof(piece_name)))
				continue
		
		var piece_detail_dict = type_dict[piece_name]
		if not piece_detail_dict is Dictionary:
			push_error("Invalid data type for piece data (expected: Dictionary, got: %s)" %
					SanityCheck.get_type_name(typeof(piece_detail_dict)))
			continue
		
		var piece_state := PieceState.new()
		match type:
			"containers":
				piece_state = ContainerState.new()
			"pieces":
				pass
			"speakers":
				piece_state = SpeakerState.new()
			"stacks":
				piece_state = ContainerState.new()
			"timers":
				piece_state = TimerState.new()
			_:
				push_warning("Unknown piece type '%s' in room state - likely loading state made with future version" %
						type)
		
		var detail_parser := DictionaryParser.new(piece_detail_dict)
		
		piece_state.index_id = piece_index
		piece_state.is_locked = detail_parser.get_strict_type("is_locked",
				piece_state.is_locked)
		piece_state.transform = detail_parser.get_strict_type("transform",
				piece_state.transform)
		piece_state.user_scale = detail_parser.get_strict_type("user_scale",
				piece_state.user_scale)
		piece_state.user_albedo = detail_parser.get_strict_type("color",
				piece_state.user_albedo)
		
		# Stacks are a special type of piece, in that they in themselves do not
		# display a mesh - what they look like entirely depends on their
		# contents. Therefore, we do not read the 'entry_path' value here, and
		# leave the relevant resource property as null.
		if type != "stacks":
			var scene_entry_path: String = detail_parser.get_strict_type(
					"entry_path", "")
			var scene_entry := AssetDB.get_entry(scene_entry_path) \
					as AssetEntryScene
			
			if scene_entry != null:
				piece_state.scene_entry = scene_entry
				
				# v0.1.x: If the "color" property is missing, then it means that
				# the user albedo was unchanged from the one in the entry.
				piece_state.user_albedo = detail_parser.get_strict_type("color",
						scene_entry.albedo_color)
			else:
				push_error("Missing scene entry '%s' for container" %
						scene_entry_path)
				continue
		
		if piece_state is ContainerState:
			# Since this array is exported, we need to make sure it does not
			# share a reference with its fellow arrays.
			piece_state.content_states = []
			
			if type == "containers":
				var contents_dict: Dictionary = detail_parser.get_strict_type(
						"pieces", {})
				extract_piece_states(contents_dict, piece_state.content_states)
			
			else:
				var contents_list: Array = detail_parser.get_strict_type(
					"pieces", [])
				for stack_piece_detail_dict in contents_list:
					if not stack_piece_detail_dict is Dictionary:
						push_error("Invalid data type for stack element data (expected: Dictionary, got: %s)" %
								SanityCheck.get_type_name(typeof(stack_piece_detail_dict)))
						continue
					
					var stack_piece_parser := DictionaryParser.new(
							stack_piece_detail_dict)
					
					var element_state := PieceState.new()
					element_state.index_id = -1 # Needs to be assigned later.
					
					var element_entry_path: String = \
							stack_piece_parser.get_strict_type("entry_path", "")
					var element_entry := AssetDB.get_entry(element_entry_path) \
							as AssetEntryScene
					if element_entry == null:
						push_error("Missing scene entry '%s' for stack element" %
								element_entry_path)
						continue
					element_state.scene_entry = element_entry
					
					var element_color: Color = stack_piece_parser.get_strict_type(
							"color", Color.white)
					element_state.user_albedo = element_color
					
					if stack_piece_detail_dict.has("transform"):
						var transform: Transform = \
								stack_piece_parser.get_strict_type("transform",
								Transform.IDENTITY)
						element_state.transform = transform
					else: # Backwards compatibility with v0.1.x!
						var flip_y: bool = stack_piece_parser.get_strict_type(
								"flip_y", false)
						var basis := element_state.transform.basis
						if flip_y:
							basis = basis.rotated(Vector3.BACK, PI)
						element_state.transform.basis = basis
					
					piece_state.content_states.push_back(element_state)
		
		if piece_state is SpeakerState:
			piece_state.is_using_music_bus = detail_parser.get_strict_type(
					"is_music_track", piece_state.is_using_music_bus)
			piece_state.is_playing = detail_parser.get_strict_type(
					"is_playing", piece_state.is_playing)
			piece_state.is_paused = detail_parser.get_strict_type(
					"is_track_paused", piece_state.is_paused)
			piece_state.is_positional = detail_parser.get_strict_type(
					"is_positional", piece_state.is_positional)
			piece_state.playback_position = detail_parser.get_strict_type(
					"playback_position", piece_state.playback_position)
			piece_state.unit_size = detail_parser.get_strict_type(
					"unit_size", piece_state.unit_size)
			
			var track_entry_path := ""
			if piece_detail_dict.has("track_entry"):
				var track_entry_data = piece_detail_dict["track_entry"]
				
				if track_entry_data is String:
					track_entry_path = track_entry_data
				
				# Backwards compatibility with v0.1.x!
				elif track_entry_data is Dictionary:
					var track_parser := DictionaryParser.new(track_entry_data)
					track_entry_path = track_parser.get_strict_type(
							"entry_path", "")
				
				else:
					push_error("Track entry data type is invalid (expected: String, got: %s)" %
							SanityCheck.get_type_name(typeof(track_entry_data)))
			
			if not track_entry_path.empty():
				var track_entry := AssetDB.get_entry(track_entry_path) \
						as AssetEntryAudio
				if track_entry != null:
					piece_state.track_entry = track_entry
				else:
					push_error("Missing track entry '%s'" % track_entry_path)
		
		if piece_state is TimerState:
			piece_state.is_timer_paused = detail_parser.get_strict_type(
					"is_timer_paused", piece_state.is_timer_paused)
			piece_state.timer_mode = detail_parser.get_strict_type(
					"mode", piece_state.timer_mode)
			piece_state.timer_time = detail_parser.get_strict_type(
					"time", piece_state.timer_time)
		
		out.push_back(piece_state)


## Load a state file (*.tc) as a [RoomState] - if the file does not exist, or
## it is corrupted, [code]null[/code] is returned instead.
static func load(path: String) -> RoomState:
	var file := File.new()
	var err := file.open_compressed(path, File.READ, File.COMPRESSION_ZSTD)
	if err != OK:
		push_error("Failed to open state file '%s' (error: %d)" % [path, err])
		return null
	
	var dict = file.get_var()
	file.close()
	
	if dict is Dictionary:
		var file_version := "<unknown>"
		
		if dict.has("version"):
			var parser := DictionaryParser.new(dict)
			file_version = parser.get_strict_type("version", "master")
		else:
			push_warning("Cannot determine what version of the game '%s' was saved with - best of luck o7")
		
		print("StateLoader: Parsing contents of '%s' (version: %s)" % [path,
				file_version])
		return dict_to_state(dict)
	else:
		push_error("Failed to read state file '%s', data is invalid" % path)
		return null
