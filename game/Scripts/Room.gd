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

extends Spatial

onready var _pieces = $Pieces

remotesync func add_piece(name: String, piece_entry: Dictionary) -> void:
	var d6 = load(piece_entry["model_path"]).instance()
	d6.name = name
	d6.piece_entry = piece_entry
	
	# Spawn the piece at a height.
	d6.translation.y = Piece.SPAWN_HEIGHT
	
	_pieces.add_child(d6)
	
	# Apply a generic texture to the die.
	var texture: Texture = load(piece_entry["texture_path"])
	texture.set_flags(0)
	
	d6.apply_texture(texture)

func get_pieces() -> Array:
	return _pieces.get_children()

func get_pieces_count() -> int:
	return _pieces.get_child_count()
