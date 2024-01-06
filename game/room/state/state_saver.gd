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

class_name StateSaver
extends Reference

## Save [RoomState] resources to [code]*.tc[/code] files.
##
## This class also includes helper functions for converting [RoomState]
## resources into [Dictionary] form, which can then be sent over the network.


## Convert the given [RoomState] into an equivalent [Dictionary] form.
static func state_to_dict(state: RoomState) -> Dictionary:
	# For backwards compatibility with v0.1.x, rather than putting in an empty
	# byte array when there is no image data to be saved, put null instead.
	var paint_image_data = null
	if state.table_paint_image != null:
		paint_image_data = state.table_paint_image.get_data()
	
	var out := {
		"version": ProjectSettings.get_setting("application/config/version"),
		
		"lamp": {
			"color": state.lamp_color,
			"intensity": state.lamp_intensity,
			"sunlight": state.is_lamp_sunlight
		},
		
		"skybox": state.skybox_entry.get_path() \
				if state.skybox_entry != null else "",
		
		"table": {
			"entry_path": state.table_entry.get_path() \
					if state.table_entry != null else "",
			"is_rigid": state.is_table_rigid,
			# TODO: Make sure an image is not put in the state if it is empty.
			"paint_image_data": paint_image_data,
			"transform": state.table_transform
		}
	}
	
	var hidden_area_dict := {}
	for element in state.hidden_area_states:
		var hidden_area_state: HiddenAreaState = element
		hidden_area_dict[hidden_area_state.index_id] = {
			"player_id": hidden_area_state.player_id,
			"transform": hidden_area_state.transform
		}
	
	out["hidden_areas"] = hidden_area_dict
	
	embed_piece_states(state.piece_states, out)
	
	if state is RoomStateMultiplayer:
		var hand_dict := {}
		
		for element in state.player_hand_states:
			var hand_state: HandState = element
			
			if hand_dict.has(hand_state.player_id):
				push_warning("Duplicate hand player ID '%d' will be overwritten" %
						hand_state.player_id)
			
			hand_dict[hand_state.player_id] = {
				"transform": hand_state.transform
			}
		
		out["hands"] = hand_dict
	
	return out


## A helper function for [method state_to_dict] - given a list of [PieceState],
## set up a dictionary to contain the full list of states.
static func embed_piece_states(state_list: Array, out: Dictionary) -> void:
	var containers_dict := {}
	var pieces_dict := {}
	var speakers_dict := {}
	var stacks_dict := {}
	var timers_dict := {}
	
	for element in state_list:
		var piece_state: PieceState = element
		var piece_dict := {
			"entry_path": piece_state.scene_entry.get_path() \
					if piece_state.scene_entry != null else "",
			"is_locked": piece_state.is_locked,
			"transform": piece_state.transform,
			"user_scale": piece_state.user_scale,
			"color": piece_state.user_albedo
		}
		
		var target_dict := pieces_dict
		
		if piece_state is ContainerState:
			# Containers are represented as their own mesh, can store any type
			# of object, and do not store them in any particular order, so we
			# need to represent the contents in a dictionary.
			if piece_state.scene_entry != null:
				target_dict = containers_dict
				
				var content_dict := {}
				embed_piece_states(piece_state.content_states, content_dict)
				piece_dict["pieces"] = content_dict
			
			# Stacks do not have their own mesh, can only store specific
			# objects, and they store them in a particular order, so we need to
			# represent them in a special array.
			else:
				target_dict = stacks_dict
				
				var content_arr := []
				for subelement in piece_state.content_states:
					var subpiece_state: PieceState = subelement
					var subpiece_dict := {
						"entry_path": subpiece_state.scene_entry.get_path() \
								if subpiece_state.scene_entry != null else "",
						"transform": subpiece_state.transform,
						"color": subpiece_state.user_albedo
					}
					content_arr.push_back(subpiece_dict)
				
				piece_dict["pieces"] = content_arr
		
		if piece_state is SpeakerState:
			target_dict = speakers_dict
			
			piece_dict["is_music_track"] = piece_state.is_using_music_bus
			piece_dict["is_playing"] = piece_state.is_playing
			piece_dict["is_positional"] = piece_state.is_positional
			piece_dict["is_track_paused"] = piece_state.is_paused
			piece_dict["playback_position"] = piece_state.playback_position
			piece_dict["track_entry"] = piece_state.track_entry.get_path() \
					if piece_state.track_entry != null else ""
			piece_dict["unit_size"] = piece_state.unit_size
		
		if piece_state is TimerState:
			target_dict = timers_dict
			
			piece_dict["is_timer_paused"] = piece_state.is_timer_paused
			piece_dict["mode"] = piece_state.timer_mode
			piece_dict["time"] = piece_state.timer_time
		
		target_dict[piece_state.index_id] = piece_dict
	
	out["containers"] = containers_dict
	out["pieces"] = pieces_dict
	out["speakers"] = speakers_dict
	out["stacks"] = stacks_dict
	out["timers"] = timers_dict


## Save the given [RoomState] as a file at the given path. Returns an error
## code.
static func save(path: String, state: RoomState) -> int:
	var file := File.new()
	var err := file.open_compressed(path, File.WRITE, File.COMPRESSION_ZSTD)
	if err != OK:
		push_error("Failed to open file at '%s' (error: %d)" % [path, err])
		return err
	
	var dict := state_to_dict(state)
	file.store_var(dict)
	file.close()
	
	return OK
