# tabletop-club
# Copyright (c) 2020-2023 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2023 Tabletop Club contributors (see game/CREDITS.tres).
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

tool
class_name VerticalButton
extends Button

## A button that shows its icon and label in a vertical layout.


## The container margin when the button is being hovered over.
const CONTAINER_MARGIN_ON_HOVER := 3

## The container margin when the button is not being hovered over.
const CONTAINER_MARGIN_DEFAULT := 5


## The texture to use as the icon for this button.
export(Texture) var texture: Texture = null setget set_texture, get_texture

## The text to display for this button.
export(String) var vertical_text := "" setget set_vertical_text, get_vertical_text

## The font to use for the new label.
export(Font) var font_override: Font = null setget set_font_override, get_font_override


## The vertical container for the texture and label.
var _vbox_container: VBoxContainer = null

## The texture rectangle showing the given icon.
var _texture_rect: TextureRect = null

## The label for the button.
var _label: Label = null


func _init():
	_vbox_container = VBoxContainer.new()
	_vbox_container.anchor_left = 0.0
	_vbox_container.anchor_top = 0.0
	_vbox_container.anchor_right = 1.0
	_vbox_container.anchor_bottom = 1.0
	_vbox_container.margin_left = 0.0
	_vbox_container.margin_top = CONTAINER_MARGIN_DEFAULT
	_vbox_container.margin_right = 0.0
	_vbox_container.margin_bottom = -CONTAINER_MARGIN_DEFAULT
	add_child(_vbox_container)
	
	_texture_rect = TextureRect.new()
	_texture_rect.texture = texture
	_texture_rect.expand = true
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox_container.add_child(_texture_rect)
	
	_label = Label.new()
	_label.text = vertical_text
	_label.align = Label.ALIGN_CENTER
	_label.clip_text = true
	if font_override != null:
		_label.add_font_override("font", font_override)
	_vbox_container.add_child(_label)
	
	if not Engine.editor_hint:
		connect("mouse_entered", self, "_on_mouse_entered")
		connect("mouse_exited", self, "_on_mouse_exited")


func get_texture() -> Texture:
	if _texture_rect == null:
		return null
	
	return _texture_rect.texture


func get_vertical_text() -> String:
	if _label == null:
		return ""
	
	return _label.text


func get_font_override() -> Font:
	if _label == null:
		return null
	
	return _label.get_font("font")


func set_texture(new_texture: Texture) -> void:
	if _texture_rect == null:
		return
	
	_texture_rect.texture = new_texture


func set_vertical_text(new_text: String) -> void:
	if _label == null:
		return
	
	_label.text = new_text


func set_font_override(new_font: Font) -> void:
	if _label == null:
		return
	
	_label.add_font_override("font", new_font)


func _on_mouse_entered():
	_vbox_container.margin_top = CONTAINER_MARGIN_ON_HOVER
	_vbox_container.margin_bottom = -CONTAINER_MARGIN_ON_HOVER


func _on_mouse_exited():
	_vbox_container.margin_top = CONTAINER_MARGIN_DEFAULT
	_vbox_container.margin_bottom = -CONTAINER_MARGIN_DEFAULT
