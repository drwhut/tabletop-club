# open-tabletop
# Copyright (c) 2020 Benjamin 'drwhut' Beddows
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

signal loading_game(game_entry)

onready var _games = $MarginContainer/ScrollContainer/Games

# Set the game database contents, based on the database given.
# assets: The database from the AssetDB.
func set_piece_db(assets: Dictionary) -> void:
	for child in _games.get_children():
		_games.remove_child(child)
		child.queue_free()
	
	for pack_name in assets:
		if assets[pack_name].has("games"):
			for game_entry in assets[pack_name]["games"]:
				var preview = preload("res://Scenes/GamePreview.tscn").instance()
				_games.add_child(preview)
				preview.set_game(pack_name, game_entry)
				
				preview.connect("load_game_pressed", self, "_on_load_game_pressed")

func _on_load_game_pressed(game_entry: Dictionary):
	emit_signal("loading_game", game_entry)
