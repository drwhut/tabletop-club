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

extends Piece

class_name SpeakerPiece

signal started_playing()
signal stopped_playing()
signal track_changed(track_entry, music)
signal track_paused()
signal track_resumed()
signal unit_size_changed(unit_size)

onready var _audio_player = $AudioStreamPlayer3D

var _track_entry: Dictionary = {}

# Get the current playback position of the speaker.
# Returns: The current playback position in seconds.
func get_playback_position() -> float:
	return _audio_player.get_playback_position()

# Get the track entry of the track loaded in this speaker.
# Returns: The currently loaded track, an empty dictionary if no track is loaded.
func get_track() -> Dictionary:
	return _track_entry

# Get the unit size of the speaker.
# Returns: The unit size of the speaker.
func get_unit_size() -> float:
	return _audio_player.unit_size

# Check if the current track is a music track.
# Returns: If the current track is a music track. Otherwise, it is a sound track.
func is_music_track() -> bool:
	return _audio_player.bus == "Music"

# Check if the speaker is currently playing a track.
# Returns: If the speaker is playing a track.
func is_playing_track() -> bool:
	return _audio_player.playing

# Check if there is a track loaded in the player.
# Returns: If there is a track loaded.
func is_track_loaded() -> bool:
	return not _track_entry.empty()

# Check if the track is paused.
# Returns: If the track is paused.
func is_track_paused() -> bool:
	return _audio_player.stream_paused

# Pause the track at a given position.
# at: The number of seconds into the track to pause at.
remotesync func pause_track(at: float) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_audio_player.stream_paused = true
	_audio_player.seek(at)
	
	emit_signal("track_paused")

# Play the currently loaded track from a given position.
# from: The number of seconds from the start to start playing from.
remotesync func play_track(from: float = 0.0) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_audio_player.stream_paused = false
	_audio_player.play(from)
	emit_signal("started_playing")

# Request the server to pause the track.
master func request_pause_track() -> void:
	rpc("pause_track", get_playback_position())

# Request the server to start playing the loaded track.
# from: The number of seconds from the start to start playing from.
master func request_play_track(from: float = 0.0) -> void:
	rpc("play_track", from)

# Request the server to resume the track.
master func request_resume_track() -> void:
	rpc("resume_track")

# Request the server to set the player's track.
# track_entry: The next track's entry.
# music: True if it is a music track, false if it is a sound track.
master func request_set_track(track_entry: Dictionary, music: bool) -> void:
	rpc("set_track", track_entry, music)

# Request the server to set the unit size of the speaker.
# unit_size: The new unit size.
master func request_set_unit_size(unit_size: float) -> void:
	rpc("set_unit_size", unit_size)

# Request the server to stop playing the loaded track.
master func request_stop_track() -> void:
	rpc("stop_track")

# Called by the server to resume playback of the track.
remotesync func resume_track() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_audio_player.stream_paused = false
	
	emit_signal("track_resumed")

# Set the track the player will play using it's entry in the AssetDB.
# track_entry: The new track's entry.
# music: True if it is a music track, false if it is a sound track.
remotesync func set_track(track_entry: Dictionary, music: bool) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if track_entry.empty():
		_track_entry = {}
	
	elif track_entry.has("audio_path"):
		var audio_stream = ResourceManager.load_res(track_entry["audio_path"])
		if audio_stream is AudioStream:
			_track_entry = track_entry
			
			# Load the audio stream into the player ready to play!
			_audio_player.stream = audio_stream
			
			# Change the bus the audio player outputs to depending on if the
			# track is a music track or a sound track.
			_audio_player.bus = "Music" if music else "Sounds"
			
			emit_signal("track_changed", track_entry, music)
		else:
			push_error("Audio path in track entry is not an audio file!")
	else:
		push_error("Entry is not a track entry!")

# Set the unit size of the speaker.
# unit_size: The new unit size.
remotesync func set_unit_size(unit_size: float) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_audio_player.unit_size = unit_size
	emit_signal("unit_size_changed", unit_size)

# Stop playing the currently loaded track.
remotesync func stop_track() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_audio_player.stop()
	_audio_player.stream_paused = false
	emit_signal("stopped_playing")

func _ready():
	# Make sure that initially the track can be heard from across the table.
	_audio_player.unit_size = 50
	
	_audio_player.connect("finished", self, "_on_audio_player_finished")

func _on_audio_player_finished():
	emit_signal("stopped_playing")
