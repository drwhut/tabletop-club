# OpenTabletop
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

const VALID_TEXTURE_EXTENSIONS = ["png"]

onready var _room = $Room
onready var _ui = $GameUI

func _ready():
	var path = "res://OpenTabletop"
	
	var dir = Directory.new()
	
	if dir.open(path) == OK:
		
		if dir.dir_exists("dice"):
			dir.change_dir("dice")
			
			if dir.dir_exists("d6"):
				dir.change_dir("d6")
				
				# Get the list of d6 textures.
				dir.list_dir_begin(true, true)
				
				var file = dir.get_next()
				while file:
					if VALID_TEXTURE_EXTENSIONS.has(file.get_extension()):
						var name = file.substr(0, file.length() - file.get_extension().length() - 1)
						var full_path = dir.get_current_dir() + "/" + file
						
						_ui.add_d6(name, full_path)
						
					file = dir.get_next()
				
				dir.change_dir("..")
			
			dir.change_dir("..")
		
	else:
		push_error("Error reading " + path)

func _on_GameUI_piece_requested(path):
	_room.add_piece(path)
