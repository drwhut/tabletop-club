# tabletop-club
# Copyright (c) 2020-2024 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2024 Tabletop Club contributors (see game/CREDITS.tres).
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

class_name AssetButton
extends Control

## A button with multiple appearances that represents an asset in the AssetDB.


## Fired when the button is pressed.
signal pressed()


## The ways in which the button can appear.
enum ButtonType {
	VERTICAL,
	HORIZONTAL,
}


## The size of the detail icons in the top-right corner.
const DETAIL_ICON_SIZE := Vector2(20.0, 20.0)

## The margin given to the detail icons relative to the edge of the button.
const DETAIL_ICON_MARGIN := 2.0


## Sets what the button looks like.
export(ButtonType) var appearance: int setget set_appearance, get_appearance

## Sets the text that the button displays.
## TODO: Do we want the text to be able to scroll? Or do we rely on being able
## to show the entire text?
export(String) var text: String setget set_text, get_text

## Sets the icon that the button displays.
export(Texture) var texture: Texture setget set_texture, get_texture

## Set the hint that is displayed when the button is hovered over.
export(String) var hint: String setget set_hint, get_hint

## Set the font used to render the button text.
export(Font) var font_override: Font setget set_font_override, get_font_override

## Set if the button represents a folder.
export(bool) var folder: bool setget set_folder, is_folder

## Set if the button represents a stack.
export(bool) var stack: bool setget set_stack, is_stack


# The button that is used when in vertical mode.
var _button_vertical: VerticalButton = null

# The button that is used when in horizontal mode.
var _button_horizontal: Button = null

# The icon that shows the button represents a folder.
var _folder_icon: TextureRect = null

# The icon that shows the button represents a stack.
var _stack_icon: TextureRect = null


func _init():
	_button_vertical = VerticalButton.new()
	_button_vertical.anchor_right = 1
	_button_vertical.anchor_bottom = 1
	_button_vertical.connect("pressed", self, "_on_button_pressed")
	add_child(_button_vertical)
	
	_button_horizontal = Button.new()
	_button_horizontal.clip_text = true
	_button_horizontal.expand_icon = true
	_button_horizontal.anchor_right = 1
	_button_horizontal.anchor_bottom = 1
	_button_horizontal.visible = false
	_button_horizontal.connect("pressed", self, "_on_button_pressed")
	add_child(_button_horizontal)
	
	var icon_container := HBoxContainer.new()
	icon_container.anchor_left = 1
	icon_container.anchor_right = 1
	icon_container.margin_top = DETAIL_ICON_MARGIN
	icon_container.margin_right = -DETAIL_ICON_MARGIN
	icon_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_container)
	
	_folder_icon = TextureRect.new()
	_folder_icon.texture = preload("res://icons/folder_icon.svg")
	_folder_icon.expand = true
	_folder_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_folder_icon.rect_min_size = DETAIL_ICON_SIZE
	_folder_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folder_icon.visible = false
	icon_container.add_child(_folder_icon)
	
	_stack_icon = TextureRect.new()
	_stack_icon.texture = preload("res://icons/stack_icon.svg")
	_stack_icon.expand = true
	_stack_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_stack_icon.rect_min_size = DETAIL_ICON_SIZE
	_stack_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack_icon.visible = false
	icon_container.add_child(_stack_icon)


## Have the button take focus, no matter which button type is being displayed.
func take_focus() -> void:
	if _button_vertical.visible:
		_button_vertical.grab_focus()
	elif _button_horizontal.visible:
		_button_horizontal.grab_focus()


func get_appearance() -> int:
	if _button_vertical.visible:
		return ButtonType.VERTICAL
	elif _button_horizontal.visible:
		return ButtonType.HORIZONTAL
	
	return 0


func get_text() -> String:
	# Any of the buttons should work fine here.
	return _button_horizontal.text


func get_texture() -> Texture:
	return _button_horizontal.texture


func get_hint() -> String:
	return _button_horizontal.hint_tooltip


func get_font_override() -> Font:
	return _button_horizontal.get_font("font")


func is_folder() -> bool:
	return _folder_icon.visible


func is_stack() -> bool:
	return _stack_icon.visible


func set_appearance(new_value: int) -> void:
	if new_value < ButtonType.VERTICAL or new_value > ButtonType.HORIZONTAL:
		push_error("Invalid value '%d' for asset button appearance" % new_value)
		return
	
	_button_vertical.visible = (new_value == ButtonType.VERTICAL)
	_button_horizontal.visible = (new_value == ButtonType.HORIZONTAL)


func set_text(new_value: String) -> void:
	_button_vertical.vertical_text = new_value
	_button_horizontal.text = new_value


func set_texture(new_value: Texture) -> void:
	_button_vertical.texture = new_value
	_button_horizontal.icon = new_value


func set_hint(new_value: String) -> void:
	_button_vertical.hint_tooltip = new_value
	_button_horizontal.hint_tooltip = new_value


func set_font_override(new_value: Font) -> void:
	_button_vertical.font_override = new_value
	_button_horizontal.add_font_override("font", new_value)


func set_folder(new_value: bool) -> void:
	_folder_icon.visible = new_value


func set_stack(new_value: bool) -> void:
	_stack_icon.visible = new_value


func _on_button_pressed():
	emit_signal("pressed")
