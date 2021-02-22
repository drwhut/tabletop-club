# open-tabletop
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows
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

extends WindowDialog

signal loading_track(track_entry, music)

onready var _music = $TabContainer/Music/MusicContainer
onready var _sounds = $TabContainer/Sounds/SoundContainer
onready var _tab_container = $TabContainer

# Set the track database contents, based on the database given.
# assets: The database from the AssetDB.
func set_piece_db(assets: Dictionary) -> void:
	for child in _music.get_children():
		_music.remove_child(child)
		child.queue_free()
	for child in _sounds.get_children():
		_sounds.remove_child(child)
		child.queue_free()
	
	for pack_name in assets:
		for type_name in ["music", "sounds"]:
			if assets[pack_name].has(type_name):
				for game_entry in assets[pack_name][type_name]:
					var preview = preload("res://Scenes/Game/UI/Previews/GenericPreview.tscn").instance()
					if type_name == "music":
						_music.add_child(preview)
					elif type_name == "sounds":
						_sounds.add_child(preview)
					preview.set_preview(pack_name, game_entry)
					
					preview.connect("load_pressed", self, "_on_load_pressed")

func _on_load_pressed(track_entry: Dictionary):
	emit_signal("loading_track", track_entry, _tab_container.current_tab == 0)
