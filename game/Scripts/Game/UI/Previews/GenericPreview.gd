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

extends Control

signal load_pressed(game_entry)

onready var _description = $HBoxContainer/VBoxContainer/Description
onready var _name = $Name
onready var _pack = $HBoxContainer/VBoxContainer/Pack

var _entry: Dictionary = {}

# Set the preview details using an entry from the AssetDB.
# pack_name: The name of the pack the entry belongs to.
# entry: The entry this preview should represent.
func set_preview(pack_name: String, entry: Dictionary) -> void:
	_entry = entry
	
	_name.text = entry["name"]
	_pack.text = "from " + pack_name
	_description.text = entry["description"]

func _on_LoadButton_pressed():
	emit_signal("load_pressed", _entry)
