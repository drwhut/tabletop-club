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

class_name ControllerCrosshair
extends CenterContainer

## Hides the mouse and centers it so controllers always point in the middle of
## the game window.


## The texture that is displayed to represent the crosshair.
export(Texture) var texture: Texture setget set_texture, get_texture

## The size of the crosshair in pixels.
export(Vector2) var icon_size: Vector2 setget set_icon_size, get_icon_size


# The control that displays the crosshair.
var _texture_rect: TextureRect = null


func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_texture_rect = TextureRect.new()
	_texture_rect.expand = true
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_child(_texture_rect)

func _ready():
	# Assume that a keyboard and mouse is being used at the start.
	_on_ControllerDetector_using_keyboard_and_mouse()
	
	ControllerDetector.connect("using_controller", self,
			"_on_ControllerDetector_using_controller")
	ControllerDetector.connect("using_keyboard_and_mouse", self,
			"_on_ControllerDetector_using_keyboard_and_mouse")


func get_icon_size() -> Vector2:
	if _texture_rect == null:
		return Vector2.ZERO
	
	return _texture_rect.rect_min_size


func get_texture() -> Texture:
	if _texture_rect == null:
		return null
	
	return _texture_rect.texture


func set_icon_size(new_value: Vector2) -> void:
	if _texture_rect == null:
		return
	
	_texture_rect.rect_min_size = new_value


func set_texture(new_value: Texture) -> void:
	if _texture_rect == null:
		return
	
	_texture_rect.texture = new_value


func _on_ControllerDetector_using_controller():
	visible = true
	# This mode puts the mouse in the centre of the screen for us.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_ControllerDetector_using_keyboard_and_mouse():
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
