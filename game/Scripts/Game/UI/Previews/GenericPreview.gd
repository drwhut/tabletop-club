# tabletop-club
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

extends Preview

class_name GenericPreview

onready var _description = $VBoxContainer/HBoxContainer/ScrollContainer/Description
onready var _name = $VBoxContainer/Name
onready var _selected_rect = $SelectedRect
onready var _texture = $VBoxContainer/HBoxContainer/Texture

export(bool) var imported_texture: bool = true

# Called when the preview is cleared.
func _clear_gui() -> void:
	_description.text = ""
	_name.text = ""
	_texture.texture = null

# Called when the preview entry is changed.
# entry: The new entry to display. It is guaranteed to not be empty.
func _set_entry_gui(entry: Dictionary) -> void:
	_description.text = entry["description"]
	_name.text = entry["name"]
	
	if entry.has("texture_path") and (not entry["texture_path"].empty()):
		_texture.visible = true
		
		if imported_texture:
			_texture.texture = load(entry["texture_path"])
		else:
			var image_file = File.new()
			if image_file.open(entry["texture_path"], File.READ) == OK:
				var buffer = image_file.get_buffer(image_file.get_len())
				image_file.close()
				
				var image = Image.new()
				if image.load_png_from_buffer(buffer) == OK:
					var texture = ImageTexture.new()
					texture.create_from_image(image)
					_texture.texture = texture
				else:
					push_error("Could not load PNG data from the buffer!")
			else:
				push_error("Could not open '%s'!" % entry["texture_path"])
	else:
		_texture.visible = false

# Called when the selected flag has been changed.
# selected: If the preview is now selected.
func _set_selected_gui(selected: bool) -> void:
	_selected_rect.color.a = 1.0 if selected else 0.0
