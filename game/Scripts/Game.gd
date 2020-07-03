# open-tabletop
# Copyright (c) 2020 drwhut
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

onready var _piece_db = $PieceDB
onready var _room = $Room
onready var _ui = $GameUI

master func request_game_piece(piece_entry: Dictionary) -> void:
	# Generate a unique name for the piece.
	var name = str(_room.pieces_count())
	
	# Send the call to create the piece to everyone.
	_room.rpc("add_piece", name, piece_entry)

func _ready():
	_piece_db.import_all()
	_ui.set_piece_tree_from_db(_piece_db.get_db())

func _on_GameUI_piece_requested(piece_entry: Dictionary):
	rpc("request_game_piece", piece_entry)
