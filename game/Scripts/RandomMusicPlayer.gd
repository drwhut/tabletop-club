# tabletop-club
# Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2025 Tabletop Club contributors (see game/CREDITS.tres).
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

extends Node

onready var _audio_player = $AudioStreamPlayer
onready var _track_label = $TrackLabel

var _music_queue = []
var _track_name = ""

# Play the next track in the queue.
func next_track() -> void:
	if _music_queue.empty():
		_track_name = tr("Nothing")
		update_label_text()
		return
	
	var track_entry = _music_queue.pop_front()
	_track_name = track_entry["name"]
	update_label_text()
	
	var track_stream = ResourceManager.load_res(track_entry["audio_path"])
	
	# Make sure the track doesn't loop, no matter what format it is.
	# NOTE: Why is looping a property of the stream and not the player??
	# This literally makes NO sense. - an annoyed drwhut.
	if track_stream is AudioStreamMP3:
		track_stream.loop = false
	elif track_stream is AudioStreamOGGVorbis:
		track_stream.loop = false
	elif track_stream is AudioStreamSample:
		track_stream.loop_mode = AudioStreamSample.LOOP_DISABLED
	
	_audio_player.stream = track_stream
	_audio_player.play()

# Update the label text.
func update_label_text() -> void:
	_track_label.text = tr("Now Playing: %s") % _track_name

func _ready():
	var asset_db = AssetDB.get_db()
	for pack in asset_db:
		if asset_db[pack].has("music"):
			for music_entry in asset_db[pack]["music"]:
				if music_entry["main_menu"]:
					_music_queue.push_back(music_entry)
	
	randomize()
	_music_queue.shuffle()

func _on_AudioStreamPlayer_finished():
	next_track()
